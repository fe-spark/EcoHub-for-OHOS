import { DlnaClient } from './DlnaClient';
import { CastPhase, DlnaDevice } from '../../types/DlnaTypes';
import { CastPollHost, CastSessionPoll } from './CastSessionPoll';

/**
 * Unique cast session: device, phase, poll, Stop, launch confirm, EOS vs disconnect.
 */
export class CastSession implements CastPollHost {
  private static readonly TAG: string = '[CastSession]';
  private static readonly SLOW_MS: number = 35000;
  private static readonly FAST_MS: number = 20000;
  private static readonly HUD_POLL_MS: number = 1000;
  private static readonly BG_POLL_MS: number = 2000;
  private static readonly SLOW_NAME_SUBSTR: string[] = ['macast', 'kodi', 'mpv', 'xbmc'];

  device: DlnaDevice | null = null;
  positionSec: number = 0;
  durationSec: number = 0;
  volume: number = 50;
  volumeSupported: boolean = false;
  transportState: string = '';
  phase: string = CastPhase.IDLE;
  relTimeUnavailable: boolean = false;
  needRelTimeToast: boolean = false;
  pendingStartSec: number = -1;

  onFailed: ((positionSec: number) => void) | null = null;
  onCompleted: (() => void) | null = null;
  onDisconnected: ((positionSec: number) => void) | null = null;
  onState: (() => void) | null = null;

  client: DlnaClient = new DlnaClient();
  pollToken: number = 0;
  pollBusy: boolean = false;
  terminal: boolean = false;
  failStreak: number = 0;
  relNiStreak: number = 0;
  originMs: number = 0;
  launchAtMs: number = 0;
  timeoutMs: number = CastSession.FAST_MS;
  stoppedStreak: number = 0;
  eosStopStreak: number = 0;
  startSeekTries: number = 0;
  startSeeking: boolean = false;
  private pollTimer: number = -1;
  private hudPolling: boolean = false;
  private poller: CastSessionPoll = new CastSessionPoll();

  get active(): boolean {
    return this.device !== null;
  }

  get usn(): string {
    return this.device ? this.device.usn : '';
  }

  get deviceName(): string {
    return this.device ? this.device.friendlyName : '';
  }

  /** Set device only. Progress is assigned by beginLaunch / replaceUri. */
  attach(device: DlnaDevice): void {
    this.device = device;
    this.transportState = '';
    this.relTimeUnavailable = false;
    this.needRelTimeToast = false;
    this.relNiStreak = 0;
    this.resetHealthCounters();
    this.timeoutMs = CastSession.matchSlow(device) ? CastSession.SLOW_MS : CastSession.FAST_MS;
  }

  beginLaunch(positionSec: number, durationSec: number): void {
    if (positionSec >= 0) {
      this.positionSec = positionSec;
    }
    if (durationSec > 0) {
      this.durationSec = durationSec;
    }
    this.pendingStartSec = positionSec >= 2 ? positionSec : -1;
    this.startSeekTries = 0;
    this.startSeeking = false;
    this.originMs = 0;
    this.terminal = false;
    this.launchAtMs = Date.now();
    this.setPhase(CastPhase.LAUNCHING);
    this.startPoll(this.pollInterval());
    this.emitState();
  }

  clearLocal(): void {
    this.stopPoll();
    this.device = null;
    this.positionSec = 0;
    this.durationSec = 0;
    this.volume = 50;
    this.volumeSupported = false;
    this.transportState = '';
    this.pendingStartSec = -1;
    this.relTimeUnavailable = false;
    this.needRelTimeToast = false;
    this.originMs = 0;
    this.terminal = false;
    this.resetHealthCounters();
    this.setPhase(CastPhase.IDLE);
  }

  setHudPolling(on: boolean): void {
    this.hudPolling = on;
    if (this.device) {
      this.startPoll(this.pollInterval());
    }
  }

  startPoll(intervalMs: number = CastSession.BG_POLL_MS): void {
    this.stopPoll();
    if (!this.device || !this.device.controlURL) {
      return;
    }
    this.pollToken += 1;
    const token: number = this.pollToken;
    this.poller.tickOnce(this, token);
    this.pollTimer = setInterval(() => {
      this.poller.tickOnce(this, token);
    }, intervalMs) as number;
  }

  stopPoll(): void {
    this.pollToken += 1;
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  async refreshVolume(): Promise<void> {
    const device: DlnaDevice | null = this.device;
    if (!device || !device.renderingControlURL) {
      this.volumeSupported = false;
      return;
    }
    try {
      this.volume = await this.client.getVolume(device);
      this.volumeSupported = true;
    } catch (err) {
      console.error(`${CastSession.TAG} GetVolume fail: ${JSON.stringify(err)}`);
      this.volumeSupported = false;
    }
  }

  async setVolume(pct: number): Promise<void> {
    const device: DlnaDevice | null = this.device;
    if (!device || !device.renderingControlURL) {
      return;
    }
    await this.client.setVolume(device, pct);
  }

  async play(): Promise<void> {
    const device: DlnaDevice | null = this.device;
    if (!device) {
      return;
    }
    await this.client.play(device);
    this.transportState = 'PLAYING';
    this.originMs = Date.now() - Math.max(0, this.positionSec) * 1000;
    this.setPhase(CastPhase.PLAYING);
    this.emitState();
  }

  async pause(): Promise<void> {
    const device: DlnaDevice | null = this.device;
    if (!device) {
      return;
    }
    await this.client.pause(device);
    this.transportState = 'PAUSED_PLAYBACK';
    this.originMs = 0;
    this.setPhase(CastPhase.PAUSED);
    this.emitState();
  }

  async seek(positionSec: number): Promise<void> {
    const device: DlnaDevice | null = this.device;
    if (!device) {
      return;
    }
    const target: number = this.durationSec > 0 ?
      Math.max(0, Math.min(positionSec, this.durationSec)) : Math.max(0, positionSec);
    await this.client.seek(device, target);
    this.pendingStartSec = -1;
    this.positionSec = target;
    this.originMs = Date.now() - target * 1000;
    this.emitState();
  }

  /** Unique Stop SOAP entry. */
  async stopRemote(): Promise<void> {
    if (this.phase === CastPhase.STOPPING) {
      return;
    }
    this.setPhase(CastPhase.STOPPING);
    const device: DlnaDevice | null = this.device;
    this.clearLocal();
    if (!device) {
      return;
    }
    try {
      await this.client.stop(device);
    } catch (err) {
      console.error(`${CastSession.TAG} stop failed: ${JSON.stringify(err)}`);
    }
  }

  async replaceUri(url: string, title: string, startSec: number): Promise<void> {
    const device: DlnaDevice | null = this.device;
    if (!device || !device.controlURL) {
      throw new Error('投屏设备已断开');
    }
    this.stopPoll();
    try {
      await this.client.stop(device);
    } catch (_e) {
    }
    this.positionSec = startSec;
    this.durationSec = 0;
    this.pendingStartSec = startSec >= 2 ? startSec : -1;
    this.relTimeUnavailable = false;
    this.needRelTimeToast = false;
    this.relNiStreak = 0;
    this.originMs = 0;
    this.startSeekTries = 0;
    this.startSeeking = false;
    this.terminal = false;
    this.resetHealthCounters();
    this.transportState = '';
    this.launchAtMs = Date.now();
    this.timeoutMs = CastSession.matchSlow(device) ? CastSession.SLOW_MS : CastSession.FAST_MS;
    this.setPhase(CastPhase.LAUNCHING);
    this.emitState();
    await this.client.cast(device, url, title, startSec, 0);
    this.startPoll(this.pollInterval());
  }

  confirmed(): boolean {
    return this.phase === CastPhase.PLAYING || this.phase === CastPhase.PAUSED;
  }

  setPhase(next: string): void {
    if (this.phase === next) {
      return;
    }
    console.info(`${CastSession.TAG} phase ${this.phase} -> ${next}`);
    this.phase = next;
  }

  emitState(): void {
    if (this.onState) {
      this.onState();
    }
  }

  private resetHealthCounters(): void {
    this.stoppedStreak = 0;
    this.failStreak = 0;
    this.eosStopStreak = 0;
  }

  private pollInterval(): number {
    return this.hudPolling ? CastSession.HUD_POLL_MS : CastSession.BG_POLL_MS;
  }

  private static matchSlow(device: DlnaDevice): boolean {
    const blob: string = `${device.manufacturer} ${device.friendlyName}`.toLowerCase();
    for (let i = 0; i < CastSession.SLOW_NAME_SUBSTR.length; i++) {
      if (blob.indexOf(CastSession.SLOW_NAME_SUBSTR[i]) >= 0) {
        return true;
      }
    }
    return false;
  }
}
