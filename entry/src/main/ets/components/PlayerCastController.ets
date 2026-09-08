import { CastSession } from '../common/utils/CastSession';
import { CastPhase, DlnaDevice } from '../common/utils/DlnaTypes';
import { PlayerAv } from '../common/utils/PlayerAv';
import { markCastStartSec, peekCastStartSec } from './PlayerCastSheet';
import { PlayerAudioBridge } from './PlayerAudioBridge';
import { PlayerPlaybackState, ProgressCallback } from './PlayerPlaybackState';
import { PlayerStallWatcher } from './PlayerStallWatcher';

export interface PlayerCastHost {
  state: PlayerPlaybackState;
  playerAv: PlayerAv;
  watcher: PlayerStallWatcher;
  audioBridge: PlayerAudioBridge;
  videoUrl: string;
  title: string;
  hasNext: () => boolean;
  volumeIndex: number;
  onEnded?: () => void;
  onProgress?: ProgressCallback;
  syncFromState: () => void;
  syncKeepScreen: () => void;
  remountPlayer: () => void;
  pulseHud: () => void;
  closeCastDialog: () => void;
  closeSpeedDialog: () => void;
  openCastSheet: () => void;
  onCastUi: () => void;
  toast: (msg: string) => void;
  fullNow: () => boolean;
  exitFullForCast: () => void;
  logicalPlayhead: () => number;
}

/** Cast orchestration: park/resume local player, recast, volume. Session owns SOAP/poll. */
export class PlayerCastController {
  session: CastSession = new CastSession();
  device: DlnaDevice | null = null;
  deviceName: string = '';
  connectedUsn: string = '';
  startSec: number = 0;
  wasPlaying: boolean = false;
  pausedForPicker: boolean = false;
  keepCastForNext: boolean = false;

  private host: PlayerCastHost | null = null;
  private endingCast: boolean = false;
  private absorbingSource: boolean = false;
  private lastCastVolPct: number = -1;
  private castVolBusy: boolean = false;
  private relTimeToasted: boolean = false;

  updateHost(host: PlayerCastHost): void {
    this.host = host;
  }

  bindCallbacks(): void {
    this.session.onFailed = (pos: number) => {
      this.handleCastPlaybackFailed(pos);
    };
    this.session.onCompleted = () => {
      this.handleCastCompleted();
    };
    this.session.onDisconnected = (pos: number) => {
      this.handleCastDisconnected(pos);
    };
    this.session.onState = () => {
      this.onCastState();
    };
  }

  isCasting(): boolean {
    return !!this.connectedUsn || !!this.deviceName || this.session.active;
  }

  openCastDialog(): void {
    const host: PlayerCastHost | null = this.host;
    if (!host || host.fullNow() || !host.videoUrl || !host.videoUrl.trim()) {
      return;
    }
    host.closeSpeedDialog();
    this.startSec = host.logicalPlayhead();
    markCastStartSec(this.startSec);
    this.wasPlaying = host.state.playRequested && !host.state.errorText && !host.state.completed;
    console.info(`[PlayerCastController] snapshot startSec=${this.startSec} wasPlaying=${this.wasPlaying}`);
    if (this.wasPlaying) {
      this.pausedForPicker = true;
      host.state.playRequested = false;
      host.state.isPlaying = false;
      host.playerAv.pause();
      host.syncFromState();
    }
    host.openCastSheet();
    host.pulseHud();
  }

  resumeAfterPickerCancel(): void {
    const host: PlayerCastHost | null = this.host;
    if (!host || !this.pausedForPicker || this.isCasting()) {
      this.pausedForPicker = false;
      return;
    }
    this.pausedForPicker = false;
    host.state.playRequested = true;
    host.playerAv.play();
    host.syncFromState();
  }

  bindCastDevice(device: DlnaDevice): void {
    const host: PlayerCastHost | null = this.host;
    if (!host) {
      return;
    }
    this.pausedForPicker = false;
    this.device = device;
    this.deviceName = device.friendlyName;
    this.connectedUsn = device.usn;
    this.relTimeToasted = false;
    this.session.attach(device);
    const start: number = Math.max(this.startSec, peekCastStartSec(), host.state.currentTime);
    this.session.beginLaunch(start, host.state.duration);
    console.info(`[PlayerCastController] bind start=${start} dur=${host.state.duration}`);
    this.lastCastVolPct = -1;
    this.pushCastVolume();
    host.exitFullForCast();
    this.parkPlayerForCast();
    host.onCastUi();
    host.closeCastDialog();
    host.pulseHud();
  }

  /** @returns true if source change is consumed (recast / absorb); skip remount. */
  handleSourceChange(): boolean {
    if (this.keepCastForNext && this.isCasting()) {
      this.keepCastForNext = false;
      this.absorbingSource = true;
      this.recastCurrentUrl();
      setTimeout(() => {
        this.absorbingSource = false;
      }, 0);
      return true;
    }
    if (this.absorbingSource) {
      return true;
    }
    if (this.isCasting() && !this.endingCast) {
      this.session.stopRemote();
      this.clearCastLocal();
    }
    return false;
  }

  handleCastCompleted(): void {
    const host: PlayerCastHost | null = this.host;
    if (!host) {
      return;
    }
    if (host.hasNext() && host.onEnded) {
      this.keepCastForNext = true;
      console.info('[PlayerCastController] completed → onEnded keepCast');
      host.onEnded();
      return;
    }
    this.finishCastCompleted();
  }

  endCastByUser(): void {
    if (this.endingCast || !this.isCasting()) {
      return;
    }
    this.endingCast = true;
    const host: PlayerCastHost | null = this.host;
    const pos: number = Math.max(this.session.positionSec, host ? host.state.currentTime : 0);
    const play: boolean = this.wasPlaying;
    this.session.stopRemote().then(() => {
      this.clearCastLocal();
      this.resumePlayerAfterCast(pos, play);
      if (host) {
        host.toast('已停止投屏');
        host.pulseHud();
      }
      this.endingCast = false;
    });
  }

  stopSession(): void {
    this.session.stopRemote();
    this.clearCastLocal();
  }

  resumeCastSync(): void {
    if (!this.session.active) {
      if (this.device) {
        this.session.attach(this.device);
      } else {
        return;
      }
    }
    this.session.startPoll(this.deviceName ? 1000 : 2000);
    this.session.refreshVolume();
  }

  syncCastProgressToState(): void {
    const host: PlayerCastHost | null = this.host;
    if (!host || !this.isCasting()) {
      return;
    }
    if (this.session.positionSec > 0) {
      host.state.currentTime = this.session.positionSec;
    }
    if (this.session.durationSec > 0) {
      host.state.duration = this.session.durationSec;
    }
    host.syncFromState();
  }

  pushCastVolume(): void {
    if (!this.isCasting()) {
      return;
    }
    const host: PlayerCastHost | null = this.host;
    const device: DlnaDevice | null = this.device;
    if (!host || !device || !device.renderingControlURL) {
      return;
    }
    const max: number = Math.max(1, host.audioBridge.max);
    const pct: number = Math.max(0, Math.min(100, Math.round(host.volumeIndex / max * 100)));
    if (pct === this.lastCastVolPct || this.castVolBusy) {
      return;
    }
    this.lastCastVolPct = pct;
    this.castVolBusy = true;
    this.session.setVolume(pct).then(() => {
      this.castVolBusy = false;
      const latest: number = Math.max(0, Math.min(100, Math.round(host.volumeIndex / max * 100)));
      if (latest !== this.lastCastVolPct) {
        this.pushCastVolume();
      }
    }).catch((err: Object) => {
      this.castVolBusy = false;
      console.info(`[PlayerCastController] cast volume skip: ${JSON.stringify(err)}`);
    });
  }

  private onCastState(): void {
    const host: PlayerCastHost | null = this.host;
    if (!host) {
      return;
    }
    host.state.currentTime = this.session.positionSec;
    if (this.session.durationSec > 0 || this.session.phase === CastPhase.LAUNCHING) {
      host.state.duration = this.session.durationSec;
    }
    host.syncFromState();
    host.onCastUi();
    host.state.emitProgress(host.onProgress, false);
    if (this.session.needRelTimeToast && !this.relTimeToasted) {
      this.session.needRelTimeToast = false;
      this.relTimeToasted = true;
      host.toast('设备不支持进度同步');
    }
  }

  private parkPlayerForCast(): void {
    const host: PlayerCastHost | null = this.host;
    if (!host) {
      return;
    }
    host.watcher.clearOpenWatch();
    host.watcher.clearSeekWatch();
    host.watcher.clearHide();
    host.state.bootGen += 1;
    host.state.playerOn = false;
    host.state.errorText = '';
    host.state.opening = false;
    host.state.stalled = false;
    host.state.playRequested = false;
    host.state.isPlaying = false;
    host.state.ready = false;
    host.state.seeking = false;
    host.playerAv.release();
    host.syncFromState();
    host.syncKeepScreen();
    host.pulseHud();
  }

  private resumePlayerAfterCast(resumeAt: number, resumePlay: boolean = true): void {
    const host: PlayerCastHost | null = this.host;
    if (!host) {
      return;
    }
    const t: number = Math.max(0, resumeAt);
    host.state.currentTime = t;
    host.state.pendingResumeSec = t;
    host.state.errorText = '';
    host.state.completed = false;
    host.state.stalled = false;
    host.state.playRequested = resumePlay;
    host.state.isPlaying = false;
    host.state.ready = false;
    host.state.opening = !!host.videoUrl;
    host.syncFromState();
    host.pulseHud();
    host.remountPlayer();
  }

  private handleCastPlaybackFailed(resumeAt: number): void {
    if (this.endingCast) {
      return;
    }
    this.endingCast = true;
    const host: PlayerCastHost | null = this.host;
    const play: boolean = this.wasPlaying;
    const pos: number = Math.max(resumeAt, this.startSec, host ? host.state.currentTime : 0);
    this.clearCastLocal();
    if (host) {
      host.closeCastDialog();
      this.resumePlayerAfterCast(pos, play);
      host.toast('投屏失败，已回到手机');
      host.pulseHud();
    }
    this.endingCast = false;
  }

  private handleCastDisconnected(resumeAt: number): void {
    if (this.endingCast) {
      return;
    }
    this.endingCast = true;
    const host: PlayerCastHost | null = this.host;
    this.clearCastLocal();
    if (host) {
      host.closeCastDialog();
      this.resumePlayerAfterCast(resumeAt, this.wasPlaying);
      host.toast('电视已停止投屏');
      host.pulseHud();
    }
    this.endingCast = false;
  }

  private finishCastCompleted(): void {
    const host: PlayerCastHost | null = this.host;
    const pos: number = this.session.positionSec;
    const dur: number = this.session.durationSec;
    this.session.clearLocal();
    this.clearCastLocal();
    if (!host) {
      return;
    }
    host.closeCastDialog();
    host.state.currentTime = pos > 0 ? pos : dur;
    if (dur > 0) {
      host.state.duration = dur;
    }
    host.state.completed = true;
    host.state.playRequested = false;
    host.state.isPlaying = false;
    host.state.errorText = '';
    host.state.opening = false;
    host.state.stalled = false;
    host.state.pendingResumeSec = host.state.currentTime;
    host.syncFromState();
    host.remountPlayer();
    host.pulseHud();
  }

  private recastCurrentUrl(): void {
    const host: PlayerCastHost | null = this.host;
    const device: DlnaDevice | null = this.session.device || this.device;
    if (!host || !device) {
      this.failRecast();
      return;
    }
    this.session.replaceUri(host.videoUrl, host.title || 'EcoHub', 0).then(() => {
      console.info('[PlayerCastController] recast ok');
    }).catch((err: Object) => {
      console.error(`[PlayerCastController] recast fail: ${JSON.stringify(err)}`);
      this.failRecast();
    });
  }

  private failRecast(): void {
    const host: PlayerCastHost | null = this.host;
    this.session.clearLocal();
    this.clearCastLocal();
    if (!host) {
      return;
    }
    host.toast('续投失败，已在手机播放');
    host.state.completed = false;
    host.state.playRequested = true;
    host.syncFromState();
    host.remountPlayer();
    host.pulseHud();
  }

  private clearCastLocal(): void {
    this.device = null;
    this.deviceName = '';
    this.connectedUsn = '';
    this.lastCastVolPct = -1;
    this.castVolBusy = false;
    this.relTimeToasted = false;
    this.keepCastForNext = false;
    if (this.session.active) {
      this.session.clearLocal();
    }
    if (this.host) {
      this.host.onCastUi();
    }
  }

}
