import { DlnaClient } from './DlnaClient';
import { CastPhase, DlnaDevice, DlnaPositionInfo, isRelTimeUnavailable } from './DlnaTypes';

/** Session surface used by the poll tick. Avoids a circular import. */
export interface CastPollHost {
  device: DlnaDevice | null;
  positionSec: number;
  durationSec: number;
  transportState: string;
  phase: string;
  relTimeUnavailable: boolean;
  needRelTimeToast: boolean;
  pendingStartSec: number;
  onFailed: ((positionSec: number) => void) | null;
  onCompleted: (() => void) | null;
  onDisconnected: ((positionSec: number) => void) | null;
  client: DlnaClient;
  pollToken: number;
  pollBusy: boolean;
  terminal: boolean;
  failStreak: number;
  relNiStreak: number;
  originMs: number;
  launchAtMs: number;
  timeoutMs: number;
  stoppedStreak: number;
  eosStopStreak: number;
  startSeekTries: number;
  startSeeking: boolean;
  confirmed(): boolean;
  setPhase(next: string): void;
  emitState(): void;
  stopPoll(): void;
  clearLocal(): void;
  stopRemote(): Promise<void>;
}

/** GetTransportInfo + GetPositionInfo tick: launch confirm, EOS, disconnect. */
export class CastSessionPoll {
  private static readonly TAG: string = '[CastSession]';
  private static readonly FAIL_THRESHOLD: number = 3;
  private static readonly STOPPED_DISCONNECT: number = 3;
  private static readonly EOS_STOP_TICKS: number = 2;
  private static readonly REL_NI_TICKS: number = 3;
  private static readonly START_SEEK_MAX: number = 8;

  async tickOnce(s: CastPollHost, token: number): Promise<void> {
    if (token !== s.pollToken || s.pollBusy || s.terminal) {
      return;
    }
    s.pollBusy = true;
    try {
      await this.pollTickBody(s, token);
    } finally {
      s.pollBusy = false;
    }
  }

  private async pollTickBody(s: CastPollHost, token: number): Promise<void> {
    if (token !== s.pollToken) {
      return;
    }
    const device: DlnaDevice | null = s.device;
    if (!device || !device.controlURL) {
      return;
    }
    let positionOk: boolean = false;
    let transportOk: boolean = false;
    try {
      const info: DlnaPositionInfo = await s.client.getPositionInfo(device);
      if (token !== s.pollToken) {
        return;
      }
      positionOk = true;
      this.applyPosition(s, info);
    } catch (err) {
      console.error(`${CastSessionPoll.TAG} GetPositionInfo fail: ${JSON.stringify(err)}`);
    }
    try {
      const state: string = await s.client.getTransportInfo(device);
      if (token !== s.pollToken) {
        return;
      }
      transportOk = true;
      s.transportState = state ? state : '';
    } catch (_e) {
    }
    if (token !== s.pollToken || !s.device) {
      return;
    }
    if (positionOk || transportOk) {
      s.failStreak = 0;
    } else {
      s.failStreak += 1;
      if (s.confirmed() && s.failStreak >= CastSessionPoll.FAIL_THRESHOLD) {
        this.disconnectRemote(s, `poll fail x${s.failStreak}`);
        return;
      }
    }
    this.judgeTick(s);
    if (s.device && s.confirmed()) {
      this.applyPendingStart(s, device);
    }
    s.emitState();
  }

  private applyPosition(s: CastPollHost, info: DlnaPositionInfo): void {
    if (isRelTimeUnavailable(info.relTime)) {
      s.relNiStreak += 1;
      if (s.relNiStreak >= CastSessionPoll.REL_NI_TICKS && !s.relTimeUnavailable) {
        s.relTimeUnavailable = true;
        s.needRelTimeToast = true;
        console.info(`${CastSessionPoll.TAG} RelTime unavailable`);
      }
    } else {
      s.relNiStreak = 0;
    }
    if (info.durationSec > 0) {
      s.durationSec = info.durationSec;
    }
    const upper: string = (s.transportState || '').toUpperCase();
    if (s.pendingStartSec >= 2) {
      if (info.positionSec > 0 && Math.abs(info.positionSec - s.pendingStartSec) <= 8) {
        s.pendingStartSec = -1;
        s.positionSec = info.positionSec;
        s.originMs = Date.now() - info.positionSec * 1000;
      } else {
        s.positionSec = s.pendingStartSec;
      }
      return;
    }
    if (!s.relTimeUnavailable && info.positionSec > 0) {
      s.positionSec = info.positionSec;
      s.originMs = Date.now() - info.positionSec * 1000;
      return;
    }
    if (s.confirmed() && upper === 'PLAYING') {
      if (s.originMs <= 0) {
        s.originMs = Date.now() - Math.max(0, s.positionSec) * 1000;
      }
      let est: number = (Date.now() - s.originMs) / 1000;
      if (s.durationSec > 1) {
        est = Math.min(est, s.durationSec);
      }
      s.positionSec = Math.max(0, est);
    }
  }

  private judgeTick(s: CastPollHost): void {
    if (s.terminal) {
      return;
    }
    const upper: string = (s.transportState || '').toUpperCase();
    if (upper === 'ERROR') {
      this.failLaunch(s, 'ERROR');
      return;
    }
    if (s.phase === CastPhase.LAUNCHING) {
      this.judgeLaunching(s, upper);
      return;
    }
    if (!s.confirmed()) {
      return;
    }
    if (this.isEosCandidate(s, upper)) {
      s.eosStopStreak += 1;
      s.stoppedStreak = 0;
      if (s.eosStopStreak >= CastSessionPoll.EOS_STOP_TICKS) {
        this.completeCurrent(s);
      }
      return;
    }
    s.eosStopStreak = 0;
    if (upper === 'STOPPED' || upper === 'NO_MEDIA_PRESENT') {
      s.stoppedStreak += 1;
      if (s.stoppedStreak >= CastSessionPoll.STOPPED_DISCONNECT) {
        this.disconnectRemote(s, `${upper} x${s.stoppedStreak}`);
      }
      return;
    }
    s.stoppedStreak = 0;
    if (upper === 'PAUSED_PLAYBACK') {
      s.setPhase(CastPhase.PAUSED);
    } else if (upper === 'PLAYING') {
      s.setPhase(CastPhase.PLAYING);
    }
  }

  private judgeLaunching(s: CastPollHost, upper: string): void {
    // RelTime side-signal only after pending resume seek is cleared — never treat
    // positionSec=pendingStartSec as device RelTime evidence (would false-confirm).
    const relOk: boolean = !s.relTimeUnavailable && s.pendingStartSec < 2 && s.positionSec > 0;
    const playLike: boolean = upper === 'PLAYING' || upper === 'PAUSED_PLAYBACK';
    if (playLike || relOk) {
      s.setPhase(upper === 'PAUSED_PLAYBACK' ? CastPhase.PAUSED : CastPhase.PLAYING);
      s.stoppedStreak = 0;
      s.failStreak = 0;
      s.eosStopStreak = 0;
      console.info(`${CastSessionPoll.TAG} launch confirmed state=${upper} pos=${s.positionSec}`);
      return;
    }
    if (Date.now() - s.launchAtMs >= s.timeoutMs) {
      this.failLaunch(s, 'timeout');
    }
  }

  private isEosCandidate(s: CastPollHost, upper: string): boolean {
    if (!s.confirmed() || s.relTimeUnavailable) {
      return false;
    }
    if (s.durationSec <= 1 || s.positionSec < s.durationSec - 3) {
      return false;
    }
    return upper === 'STOPPED' || upper === 'NO_MEDIA_PRESENT';
  }

  private completeCurrent(s: CastPollHost): void {
    if (s.terminal) {
      return;
    }
    s.terminal = true;
    s.stopPoll();
    s.setPhase(CastPhase.COMPLETED);
    console.info(`${CastSessionPoll.TAG} completed pos=${s.positionSec} dur=${s.durationSec}`);
    s.emitState();
    if (s.onCompleted) {
      s.onCompleted();
    }
  }

  private disconnectRemote(s: CastPollHost, reason: string): void {
    if (s.terminal || !s.device) {
      return;
    }
    s.terminal = true;
    const pos: number = s.positionSec;
    const cb: ((positionSec: number) => void) | null = s.onDisconnected;
    console.info(`${CastSessionPoll.TAG} disconnected: ${reason} pos=${pos}`);
    s.setPhase(CastPhase.DISCONNECTED);
    s.clearLocal();
    if (cb) {
      cb(pos);
    }
  }

  private async failLaunch(s: CastPollHost, reason: string): Promise<void> {
    if (s.terminal || s.phase === CastPhase.FAILED || s.phase === CastPhase.STOPPING) {
      return;
    }
    s.terminal = true;
    console.info(`${CastSessionPoll.TAG} failed: ${reason}`);
    s.setPhase(CastPhase.FAILED);
    const pos: number = s.positionSec;
    const cb: ((positionSec: number) => void) | null = s.onFailed;
    await s.stopRemote();
    if (cb) {
      cb(pos);
    }
  }

  private applyPendingStart(s: CastPollHost, device: DlnaDevice): void {
    if (s.pendingStartSec < 2 || s.startSeeking || s.startSeekTries >= CastSessionPoll.START_SEEK_MAX) {
      return;
    }
    const waited: number = Date.now() - s.launchAtMs;
    if (s.durationSec <= 1 && waited < 2500) {
      return;
    }
    const target: number = s.durationSec > 1 ?
      Math.min(s.pendingStartSec, Math.max(0, s.durationSec - 1)) : s.pendingStartSec;
    s.startSeeking = true;
    s.startSeekTries += 1;
    console.info(`${CastSessionPoll.TAG} resume seek try=${s.startSeekTries} target=${target}`);
    s.client.seek(device, target).then(() => {
      s.startSeeking = false;
    }).catch((err: Object) => {
      s.startSeeking = false;
      console.error(`${CastSessionPoll.TAG} resume seek fail: ${JSON.stringify(err)}`);
      if (s.startSeekTries >= CastSessionPoll.START_SEEK_MAX) {
        s.pendingStartSec = -1;
      }
    });
  }
}
