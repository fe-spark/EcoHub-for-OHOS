import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { AVVolumePanel } from '@kit.AudioKit';
import { AppTheme } from '../common/constants/AppTheme';
import { PlayerWindow } from '../common/utils/PlayerWindow';
import { PlayerTipKind } from '../common/utils/PlayerPan';
import { PlayerStallWatcher } from './PlayerStallWatcher';
import { PlayerVideoLayer } from './PlayerVideoLayer';
import { PlayerAudioBridge } from './PlayerAudioBridge';
import { PlayerGestureCoordinator } from './PlayerGestureCoordinator';
import { PlayerSpeedController } from './PlayerSpeedController';
import { PlayerPlaybackState } from './PlayerPlaybackState';
import { PlayerSkinEvents, PlayerSkinView } from './PlayerSkinView';
import { PlayerObserverHost, PlayerVideoObserver } from './PlayerVideoObserver';
import { PlayerSpeedSheet } from './PlayerSpeedSheet';
import { markCastStartSec, peekCastStartSec, PlayerCastSheet } from './PlayerCastSheet';
import { PlayerCastHud } from './PlayerCastHud';
import { DlnaClient } from '../common/utils/DlnaClient';
import { DlnaDevice } from '../common/utils/DlnaTypes';
import { CastSession } from '../common/utils/CastSession';
import { PlayerScale, PlayerScaleMode } from '../common/utils/PlayerScale';
import { PlayerScaleController } from './PlayerScaleController';
import { PlayerAv } from '../common/utils/PlayerAv';

@Component
export struct VideoPlayer {
  @Prop @Watch('onUrlChange') videoUrl: string = '';
  @Prop @Watch('onReloadTokenChange') reloadToken: number = 0;
  @Prop title: string = '';
  @Prop poster: string = '';
  @Prop initialTime: number = 0;
  @Prop showBack: boolean = false;
  @Prop isFull: boolean = false;
  @Prop hasPrev: boolean = false;
  @Prop hasNext: boolean = false;
  @Prop topInset: number = 0;
  @Prop leftInset: number = 0;
  @Prop rightInset: number = 0;
  @Prop bottomInset: number = 0;
  @Prop edgeHud: boolean = false;
  @Prop @Watch('onPageActiveChange') pageActive: boolean = true;
  onEnded?: () => void;
  onProgress?: (current: number, duration: number) => void;
  onBack?: () => void;
  onPrev?: () => void;
  onNext?: () => void;
  onFullscreenChange?: (full: boolean, isPortrait?: boolean) => void;

  private static readonly SEEK_STEP_SEC: number = 10;
  private static readonly PLAY_TOGGLE_DEBOUNCE_MS: number = 280;

  @State private duration: number = 0;
  @State private currentTime: number = 0;
  @State private isPlaying: boolean = false;
  @State private playRequested: boolean = true;
  @State private completed: boolean = false;
  @State private showHud: boolean = true;
  @State private nonce: number = 0;
  @State private innerFull: boolean = false;
  @State private muted: boolean = false;
  @State private volumeIndex: number = 8;
  @State private opening: boolean = true;
  @State private errorText: string = '';
  @State private seeking: boolean = false;
  @State private stalled: boolean = false;
  @State private ready: boolean = false;
  @State private videoWidth: number = 0;
  @State private videoHeight: number = 0;
  @State private longPressing: boolean = false;
  @State private feedback: string = '';
  @State private feedbackKind: number = PlayerTipKind.NONE;
  @State private speedIndex: number = 1;
  @State private speedLabel: string = '1.0x';
  @State private scaleMode: number = PlayerScaleMode.FIT;
  @State private scaleLabel: string = '适应';
  @State private playSrc: string = '';
  @State private playerOn: boolean = false;
  @State private speedOpenSeq: number = 0;
  @State private castOpenSeq: number = 0;
  @State private castDeviceName: string = '';
  @State private castConnectedUsn: string = '';
  @State private castDevice: DlnaDevice | null = null;
  @State private castStartSec: number = 0;
  private pausedForPicker: boolean = false;
  /** Phone was playing when the picker opened; restore this on auto-exit / fail. */
  private castWasPlaying: boolean = false;

  private playerAv: PlayerAv = new PlayerAv();
  private watcher: PlayerStallWatcher = new PlayerStallWatcher();
  private audioBridge: PlayerAudioBridge = new PlayerAudioBridge();
  private gestures: PlayerGestureCoordinator = new PlayerGestureCoordinator();
  private speedCtrl: PlayerSpeedController = new PlayerSpeedController();
  private scaleCtrl: PlayerScaleController = new PlayerScaleController();
  private state: PlayerPlaybackState = new PlayerPlaybackState();
  private observer: PlayerVideoObserver | null = null;
  private pageWasHidden: boolean = false;
  private playerW: number = 1;
  private playerH: number = 1;
  private volumeSub: (() => void) | null = null;
  private lastCastVolPct: number = -1;
  private castVolBusy: boolean = false;
  private endingCast: boolean = false;
  private castClient: DlnaClient = new DlnaClient();
  private castSession: CastSession = new CastSession();

  aboutToAppear() {
    this.castSession.onRemoteDisconnected = (positionSec: number) => {
      this.handleRemoteCastDisconnect(positionSec);
    };
    this.observer = new PlayerVideoObserver(this.observerHost());
    this.setupPlayerAvListener();
    this.nonce = 1;
    this.state.bootGen = 1;
    this.state.mountGen = 1;
    this.state.reset(this.videoUrl);
    this.state.playerOn = !!this.videoUrl;
    this.syncFromState();
    this.armHide();
    this.playerAv.setMuted(this.muted || this.volumeIndex <= 0);
    this.playerAv.setSpeedIndex(this.speedIndex);
    if (this.videoUrl) {
      this.armOpenWatch();
      this.playerAv.open(this.videoUrl);
    }
    this.audioBridge.sync((vol, _max, isMuted) => {
      this.volumeIndex = vol;
      this.muted = isMuted;
      this.playerAv.setMuted(isMuted);
      this.gestures.pan.primeVolume(this.audioBridge.max > 0 ? vol / this.audioBridge.max : 0);
    });
    this.volumeSub = PlayerWindow.subscribeVolumeChange((info) => {
      this.audioBridge.updateFromSystem(info);
      this.volumeIndex = info.current;
      this.muted = this.audioBridge.muted;
      this.playerAv.setMuted(this.muted);
      this.gestures.pan.primeVolume(info.max > 0 ? info.current / info.max : 0);
      this.pushCastVolume();
    });
  }

  private setupPlayerAvListener(): void {
    this.playerAv.listener.onPrepared = (dur: number) => { if (this.observer) this.observer.handlePrepared(dur); };
    this.playerAv.listener.onStart = () => { if (this.observer) this.observer.handleStart(); };
    this.playerAv.listener.onPause = () => { if (this.observer) this.observer.handlePause(); };
    this.playerAv.listener.onTime = (time: number) => { if (this.observer) this.observer.handleTime(time); };
    this.playerAv.listener.onFinish = () => { if (this.observer) this.observer.handleFinish(); };
    this.playerAv.listener.onError = (detail?: string) => { if (this.observer) this.observer.handleError(detail); };
    this.playerAv.listener.onSeeked = (timeSec: number, seq: number) => { if (this.observer) this.observer.handleSeeked(timeSec, seq); };
    this.playerAv.listener.onVideoSize = (w: number, h: number) => {
      if (this.observer) this.observer.handleVideoSize(w, h);
      this.scaleLabel = this.scaleCtrl.label(this.isPortraitVideo());
    };
    this.playerAv.listener.onStalled = (stalled: boolean) => {
      if (this.state.live()) { this.state.stalled = stalled; this.syncFromState(); }
    };
  }

  aboutToDisappear() {
    if (this.volumeSub) {
      this.volumeSub();
      this.volumeSub = null;
    }
    this.closeCastDialog();
    // True leave of PlayPage (navigate away). Screen-off uses onPageHide → pageActive=false
    // and must NOT Stop the TV — that path only closes the cast dialog UI.
    this.stopCastSession();
    this.playerAv.release();
    this.watcher.clearAll();
    this.closeSpeedDialog();
    this.state.bootGen++;
    this.syncCastProgressToState();
    if (this.state.currentTime > 0) this.state.emitProgress(this.onProgress, true);
    const ctx = this.ctx();
    PlayerWindow.resetBrightness(ctx);
    PlayerWindow.setKeepScreenOn(ctx, false);
    if (this.fullNow()) {
      PlayerWindow.setFullscreen(ctx, false, false);
    }
  }

  onUrlChange(): void { this.resetPlayState(); this.remountPlayer(); }
  onReloadTokenChange(): void { this.resetPlayState(); this.remountPlayer(); }

  private observerHost(): PlayerObserverHost {
    return {
      playerAv: this.playerAv, state: this.state, watcher: this.watcher, initialTime: this.initialTime,
      videoUrl: this.videoUrl, onProgress: this.onProgress, onEnded: this.onEnded,
      syncKeepScreen: () => this.syncKeepScreen(), armHide: () => this.armHide(),
      armSeekWatch: () => this.armSeekWatch(),
      revealHud: () => { this.showHud = true; this.watcher.clearHide(); },
      onUIUpdate: () => this.syncFromState()
    };
  }

  private syncFromState(): void {
    this.duration = this.state.duration; this.currentTime = this.state.currentTime;
    this.isPlaying = this.state.isPlaying; this.playRequested = this.state.playRequested;
    this.completed = this.state.completed; this.opening = this.state.opening;
    this.errorText = this.state.errorText; this.seeking = this.state.seeking;
    this.stalled = this.state.stalled; this.ready = this.state.ready;
    this.videoWidth = this.state.videoWidth; this.videoHeight = this.state.videoHeight;
  }

  private resetPlayState(): void {
    this.watcher.clearOpenWatch();
    this.watcher.clearSeekWatch();
    this.state.reset(this.videoUrl);
    this.syncFromState();
    this.showHud = true;
    this.closeSpeedDialog();
    this.speedCtrl.reset();
    this.speedIndex = this.speedCtrl.index;
    this.speedLabel = this.speedCtrl.label;
    this.longPressing = false;
    this.feedback = '';
    this.feedbackKind = PlayerTipKind.NONE;
    this.watcher.clearTip();
    this.gestures.pan.reset();
    this.armHide();
  }

  onPageActiveChange(): void {
    if (this.pageActive) {
      this.audioBridge.sync((vol, _max, isMuted) => {
        this.volumeIndex = vol;
        this.muted = isMuted;
        this.playerAv.setMuted(isMuted);
        this.gestures.pan.primeVolume(this.audioBridge.max > 0 ? vol / this.audioBridge.max : 0);
      });
      // Wake / page show while still casting: resume progress sync only; do not re-cast
      // and do not resume local AVPlayer (TV is the playback surface).
      if (this.castSession.active || this.castConnectedUsn) {
        this.pageWasHidden = false;
        this.state.stalled = false;
        this.syncFromState();
        this.resumeCastSync();
        return;
      }
      if (!this.pageWasHidden || !this.videoUrl || this.state.completed || this.state.errorText) return;
      this.pageWasHidden = false;
      this.state.stalled = false;
      this.syncFromState();
      if (this.state.playRequested) this.playerAv.play();
    } else {
      this.pageWasHidden = true;
      this.state.stalled = false;
      this.watcher.clearHide();
      this.closeSpeedDialog();
      // Close cast *dialog* only — keep castDevice / connectedUsn / session; TV keeps playing.
      this.closeCastDialog();
      this.syncCastProgressToState();
      this.syncFromState();
      if (this.state.currentTime > 0) this.state.emitProgress(this.onProgress, true);
      if (this.state.isPlaying) this.playerAv.pause();
    }
  }

  private ctx(): common.UIAbilityContext | undefined { return this.getUIContext().getHostContext() as common.UIAbilityContext; }
  private fullNow(): boolean { return this.isFull || this.innerFull; }
  private pulseHud(): void { this.showHud = true; this.armHide(); }

  private armHide(): void {
    const canHide = this.state.playRequested && !this.state.completed && !this.state.errorText &&
      !this.state.opening && !this.state.dragging && !this.state.seeking && !this.state.stalled;
    this.watcher.armHide(() => {
      if (this.state.playRequested && !this.state.completed && !this.state.errorText) this.showHud = false;
    }, canHide);
  }

  private togglePlay(): void {
    if (this.isCasting()) {
      return;
    }
    const now = Date.now();
    if (now - this.state.lastToggleAt < VideoPlayer.PLAY_TOGGLE_DEBOUNCE_MS) return;
    this.state.lastToggleAt = now;
    if (!this.state.canPlay() && !this.state.completed) return;
    if (this.state.completed) {
      this.state.playRequested = true; this.state.completed = false; this.state.currentTime = 0;
      this.syncFromState(); this.seekTo(0); this.pulseHud();
      return;
    }
    if (this.state.playRequested) {
      this.state.playRequested = false; this.state.isPlaying = false; this.playerAv.pause();
      this.syncFromState(); this.syncKeepScreen(); this.showHud = true; this.watcher.clearHide();
    } else {
      this.state.playRequested = true; this.playerAv.play(); this.syncFromState(); this.pulseHud();
    }
  }

  private isCasting(): boolean {
    return !!this.castConnectedUsn || !!this.castDeviceName || this.castSession.active;
  }

  private toggleFull(): void {
    const next = !this.fullNow();
    if (next && this.isCasting()) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '投屏中无法全屏，请先停止投屏' });
      } catch (_e) {
      }
      return;
    }
    this.closeCastDialog();
    const isPort = this.state.isPortrait();
    console.info(`[VideoPlayer] 点击全屏 -> targetFull: ${next}, isPortrait: ${isPort}, dimensions: ${this.state.videoWidth}x${this.state.videoHeight}`);
    this.innerFull = next;
    this.pulseHud();
    if (this.onFullscreenChange) this.onFullscreenChange(next, isPort);
    else PlayerWindow.setFullscreen(this.ctx(), next, isPort);
    this.syncKeepScreen();
  }

  private syncKeepScreen(): void {
    const on = this.pageActive && this.state.playRequested && this.state.isPlaying && !this.state.completed && !this.state.errorText;
    PlayerWindow.setKeepScreenOn(this.ctx(), on);
  }

  private toggleMute(): void {
    const res = this.audioBridge.toggleMute();
    this.volumeIndex = res.volume;
    this.muted = res.muted;
    this.playerAv.setMuted(this.muted);
    this.gestures.pan.primeVolume(this.audioBridge.max > 0 ? res.volume / this.audioBridge.max : 0);
    this.pushCastVolume();
    this.watcher.showTip(res.label, PlayerTipKind.VOLUME, (msg, k) => { this.feedback = msg; this.feedbackKind = k; }, () => { this.feedback = ''; this.feedbackKind = PlayerTipKind.NONE; });
    this.pulseHud();
  }

  private retry(): void {
    this.state.prepareRetry(); this.syncFromState(); this.showHud = true; this.remountPlayer();
  }

  private remountPlayer(): void {
    const gen = ++this.state.bootGen;
    this.state.mountGen = gen; this.state.playerOn = !!this.videoUrl;
    if (this.observer) this.observer.updateHost(this.observerHost());
    this.armOpenWatch();
    if (!this.videoUrl) {
      this.watcher.clearOpenWatch(); this.state.opening = false;
      this.syncFromState(); this.playerAv.release(); return;
    }
    this.playerAv.open(this.videoUrl);
  }

  private armOpenWatch(): void {
    this.watcher.armOpenWatch(() => {
      if (this.state.live() && this.state.opening && !this.state.ready && !this.state.errorText) {
        console.warn('[VideoPlayer] 视频打开超时(15s)，触发自动降级 failOpen 并释放播放器');
        this.watcher.clearSeekWatch();
        this.state.failOpen(this.videoUrl, 'Timeout (15s)');
        this.playerAv.release();
        this.syncFromState();
        this.syncKeepScreen();
        this.showHud = true;
      }
    }, this.state.opening);
  }

  private seekTo(time: number): void {
    const prevSeq = this.state.seekSeq;
    this.state.seek(time, this.playerAv);
    if (this.state.seeking && this.state.seekSeq !== prevSeq) {
      this.armSeekWatch();
    } else if (!this.state.seeking) {
      this.watcher.clearSeekWatch();
    }
    this.syncFromState();
  }

  private armSeekWatch(): void {
    this.watcher.armSeekWatch(() => {
      if (!this.state.live() || !this.state.seeking) {
        return;
      }
      console.warn('[VideoPlayer] seek 超时，解除 seeking 锁定，等待 timeUpdate 校准');
      this.playerAv.abandonSeeksUpTo(this.state.seekSeq);
      this.state.seeking = false;
      this.state.seekTarget = -1;
      this.state.seekSeq = 0;
      this.syncFromState();
      this.armHide();
    }, this.state.seeking);
  }

  private isPortraitVideo(): boolean {
    return this.state.isPortrait();
  }

  private openSpeedDialog(): void { this.speedCtrl.setShowing(true); this.speedOpenSeq += 1; }
  private closeSpeedDialog(): void { this.speedCtrl.setShowing(false); this.speedOpenSeq = 0; }
  private logicalPlayhead(): number {
    const live: number = this.state.currentTime;
    const hist: number = this.initialTime;
    if (this.state.ready && live >= 1) {
      return live;
    }
    return Math.max(live, hist, 0);
  }

  private openCastDialog(): void {
    if (this.fullNow()) {
      return;
    }
    this.closeSpeedDialog();
    this.castStartSec = this.logicalPlayhead();
    markCastStartSec(this.castStartSec);
    this.castWasPlaying = this.state.playRequested && !this.state.errorText && !this.state.completed;
    console.info(`[VideoPlayer] cast snapshot startSec=${this.castStartSec} current=${this.state.currentTime} initial=${this.initialTime} wasPlaying=${this.castWasPlaying}`);
    if (this.castWasPlaying) {
      this.pausedForPicker = true;
      this.state.playRequested = false;
      this.state.isPlaying = false;
      this.playerAv.pause();
      this.syncFromState();
    }
    this.castOpenSeq += 1;
    this.pulseHud();
  }
  private closeCastDialog(): void {
    this.castOpenSeq = 0;
    this.resumeAfterPickerCancel();
  }

  private resumeAfterPickerCancel(): void {
    if (!this.pausedForPicker || this.isCasting()) {
      this.pausedForPicker = false;
      return;
    }
    this.pausedForPicker = false;
    this.state.playRequested = true;
    this.playerAv.play();
    this.syncFromState();
  }

  private hudOwnsPoll(): boolean {
    return !!this.castDeviceName && !this.fullNow();
  }

  private syncCastProgressToState(): void {
    if (!this.isCasting()) {
      return;
    }
    const p: number = this.castSession.positionSec;
    const d: number = this.castSession.durationSec;
    if (p > 0) {
      this.state.currentTime = p;
    }
    if (d > 0) {
      this.state.duration = d;
    }
    this.syncFromState();
  }
  /** Tear down local AVPlayer while TV is the playback surface (Bilibili-style). */
  private parkPlayerForCast(): void {
    this.watcher.clearOpenWatch();
    this.watcher.clearSeekWatch();
    this.watcher.clearHide();
    this.state.bootGen += 1;
    this.state.playerOn = false;
    this.state.errorText = '';
    this.state.opening = false;
    this.state.stalled = false;
    this.state.playRequested = false;
    this.state.isPlaying = false;
    this.state.ready = false;
    this.state.seeking = false;
    this.playerAv.release();
    this.syncFromState();
    this.syncKeepScreen();
    this.showHud = true;
  }

  private resumePlayerAfterCast(resumeAt: number, resumePlay: boolean = true): void {
    const t: number = Math.max(0, resumeAt);
    this.state.currentTime = t;
    this.state.pendingResumeSec = t;
    this.state.errorText = '';
    this.state.completed = false;
    this.state.stalled = false;
    this.state.playRequested = resumePlay;
    this.state.isPlaying = false;
    this.state.ready = false;
    this.state.opening = !!this.videoUrl;
    this.syncFromState();
    this.showHud = true;
    this.remountPlayer();
  }
  private resumeCastSync(): void {
    if (!this.castSession.active) {
      if (this.castDevice) {
        this.castSession.attach(this.castDevice);
      } else {
        return;
      }
    }
    if (this.hudOwnsPoll()) {
      this.castSession.stopPoll();
      return;
    }
    this.castSession.startPoll(2000);
    this.castSession.refreshVolume();
  }
  private bindCastDevice(device: DlnaDevice): void {
    this.castDevice = device;
    this.castDeviceName = device.friendlyName;
    this.castConnectedUsn = device.usn;
    this.castSession.attach(device);
    const start: number = Math.max(this.castStartSec, peekCastStartSec(), this.state.currentTime);
    this.castSession.positionSec = start;
    this.castSession.durationSec = this.state.duration;
    console.info(`[VideoPlayer] bindCast start=${start} dur=${this.state.duration}`);
    this.lastCastVolPct = -1;
    this.pushCastVolume();
    this.exitFullForCast();
  }

  /** Map phone MEDIA volume 0–max → TV RenderingControl 0–100. No HUD slider. */
  private pushCastVolume(): void {
    if (!this.isCasting()) {
      return;
    }
    const device: DlnaDevice | null = this.castDevice;
    if (!device || !device.renderingControlURL) {
      return;
    }
    const max: number = Math.max(1, this.audioBridge.max);
    const pct: number = Math.max(0, Math.min(100, Math.round(this.volumeIndex / max * 100)));
    if (pct === this.lastCastVolPct || this.castVolBusy) {
      return;
    }
    this.lastCastVolPct = pct;
    this.castVolBusy = true;
    this.castClient.setVolume(device, pct).then(() => {
      this.castVolBusy = false;
      const latest: number = Math.max(0, Math.min(100, Math.round(this.volumeIndex / max * 100)));
      if (latest !== this.lastCastVolPct) {
        this.pushCastVolume();
      }
    }).catch((err: Object) => {
      this.castVolBusy = false;
      console.info(`[VideoPlayer] cast volume skip: ${JSON.stringify(err)}`);
    });
  }

  private exitFullForCast(): void {
    if (!this.fullNow()) {
      return;
    }
    this.innerFull = false;
    const isPort = this.state.isPortrait();
    if (this.onFullscreenChange) {
      this.onFullscreenChange(false, isPort);
    } else {
      PlayerWindow.setFullscreen(this.ctx(), false, isPort);
    }
  }
  private clearCastLocal(): void {
    this.castDevice = null;
    this.castDeviceName = '';
    this.castConnectedUsn = '';
    this.lastCastVolPct = -1;
    this.castVolBusy = false;
    this.castSession.clearLocal();
  }
  /** TV stopped / powered off / network drop — local clear only, no Stop SOAP. */
  private handleRemoteCastDisconnect(resumeAt: number): void {
    if (this.endingCast) {
      return;
    }
    this.endingCast = true;
    this.clearCastLocal();
    this.closeCastDialog();
    this.resumePlayerAfterCast(resumeAt, this.castWasPlaying);
    try {
      this.getUIContext().getPromptAction().showToast({ message: '电视已停止投屏' });
    } catch (_e) {
    }
    this.endingCast = false;
    this.pulseHud();
  }

  /** SetURI/Play 成功但电视未真正起播，或进度/状态一直无效。 */
  private handleCastPlaybackFailed(resumeAt: number): void {
    if (this.endingCast) {
      return;
    }
    this.endingCast = true;
    const device: DlnaDevice | null = this.castDevice || this.castSession.device;
    const play: boolean = this.castWasPlaying;
    const pos: number = Math.max(resumeAt, this.castStartSec, this.state.currentTime);
    this.clearCastLocal();
    this.closeCastDialog();
    if (device) {
      this.castClient.stop(device).catch((err: Object) => {
        console.error(`[VideoPlayer] fail-stop: ${JSON.stringify(err)}`);
      });
    }
    this.resumePlayerAfterCast(pos, play);
    try {
      this.getUIContext().getPromptAction().showToast({ message: '投屏失败，已回到手机' });
    } catch (_e) {
    }
    this.endingCast = false;
    this.pulseHud();
  }
  private stopCastSession(): void {
    const device: DlnaDevice | null = this.castDevice || this.castSession.device;
    this.clearCastLocal();
    if (!device) {
      return;
    }
    this.castClient.stop(device).catch((err: Object) => {
      console.error(`[VideoPlayer] cast stop failed: ${JSON.stringify(err)}`);
    });
  }

  private async endCastByUser(): Promise<void> {
    if (this.endingCast || !this.isCasting()) {
      return;
    }
    this.endingCast = true;
    const device: DlnaDevice | null = this.castDevice || this.castSession.device;
    const pos: number = Math.max(this.castSession.positionSec, this.state.currentTime);
    this.clearCastLocal();
    try {
      if (device) {
        await this.castClient.stop(device);
      }
    } catch (err) {
      console.error(`[VideoPlayer] end cast failed: ${JSON.stringify(err)}`);
    }
    this.endingCast = false;
    this.resumePlayerAfterCast(pos, this.castWasPlaying);
    try {
      this.getUIContext().getPromptAction().showToast({ message: '已停止投屏' });
    } catch (_e) {
    }
  }
  private cycleScaleMode(): void {
    const next = this.scaleCtrl.cycle();
    this.scaleMode = next;
    this.scaleLabel = this.scaleCtrl.label(this.isPortraitVideo());
    this.pulseHud();
    this.watcher.showTip(`画面：${this.scaleLabel}`, PlayerTipKind.SCALE,
      (msg, k) => { this.feedback = msg; this.feedbackKind = k; },
      () => { this.feedback = ''; this.feedbackKind = PlayerTipKind.NONE; });
  }

  private panMove(event: GestureEvent): void {
    const res = this.gestures.move(event, this.longPressing, this.fullNow(), this.duration, this.playerW, this.playerH);
    if (!res) return;
    if (res.mode === 2 && res.time !== undefined) {
      this.state.dragging = true; this.currentTime = res.time; this.state.currentTime = res.time;
      this.feedback = res.feedback; this.feedbackKind = res.feedbackKind; this.watcher.clearHide();
    } else if (res.mode === 3 && res.bright !== undefined && res.bright >= 0) {
      PlayerWindow.setBrightness(this.ctx(), res.bright); this.feedback = res.feedback; this.feedbackKind = res.feedbackKind;
    } else if (res.mode === 4 && res.volumeRatio !== undefined && res.volumeRatio >= 0) {
      const vol = this.audioBridge.applyRatio(res.volumeRatio);
      this.volumeIndex = vol; this.muted = vol <= 0; this.playerAv.setMuted(this.muted); this.feedback = res.feedback; this.feedbackKind = res.feedbackKind;
    }
  }

  private finishPanSeek(): void {
    const res = this.gestures.finish(this.currentTime);
    this.watcher.clearTip(); this.feedback = ''; this.feedbackKind = PlayerTipKind.NONE;
    if (res.shouldSeek) this.seekTo(res.targetTime);
    this.state.dragging = false; this.pulseHud();
  }

  private showErrorDetail(): void {
    const rawErr = this.errorText;
    this.getUIContext().showAlertDialog({
      title: '播放异常详情', message: rawErr,
      primaryButton: {
        value: '复制', fontColor: AppTheme.ACCENT,
        action: () => {
          if (rawErr) {
            try {
              const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, rawErr);
              pasteboard.getSystemPasteboard().setDataSync(data);
              this.getUIContext().getPromptAction().showToast({ message: '已复制报错信息' });
            } catch (_e) {}
          }
        }
      },
      secondaryButton: { value: '知道了', action: () => {} }
    });
  }

  private skinEvents(): PlayerSkinEvents {
    return {
      onBack: () => { if (this.fullNow()) this.toggleFull(); else if (this.onBack) this.onBack(); },
      onPlay: () => this.togglePlay(), onFull: () => this.toggleFull(), onMute: () => this.toggleMute(),
      onPrev: () => { if (this.onPrev) this.onPrev(); }, onNext: () => { if (this.onNext) this.onNext(); },
      onSpeed: () => this.openSpeedDialog(), onScale: () => this.cycleScaleMode(),
      onRetry: () => this.retry(), onErrorDetail: () => this.showErrorDetail(),
      onSeekBack: () => { this.seekTo(this.currentTime - VideoPlayer.SEEK_STEP_SEC); this.pulseHud(); },
      onSeekForward: () => { this.seekTo(this.currentTime + VideoPlayer.SEEK_STEP_SEC); this.pulseHud(); },
      onSeekStart: (val) => { this.state.dragging = true; this.currentTime = val; this.state.currentTime = val; this.watcher.clearHide(); this.showHud = true; },
      onSeekUpdate: (val) => { this.currentTime = val; this.state.currentTime = val; },
      onSeekEnd: (val) => { this.currentTime = val; this.state.currentTime = val; this.seekTo(val); this.state.dragging = false; this.pulseHud(); },
      onToggleHud: () => {
        if (this.speedCtrl.showing || this.gestures.pan.mode > 1 || this.longPressing) return;
        if (this.showHud) {
          if (!this.playRequested || this.completed) return;
          this.showHud = false; this.watcher.clearHide();
        } else {
          this.showHud = true; this.armHide();
        }
      },
      onLongPress: () => {
        if (this.isCasting()) {
          return;
        }
        if (this.speedCtrl.beginFastForward(this.state.canPlay(), this.isPlaying)) {
          this.longPressing = true; this.speedIndex = this.speedCtrl.index; this.speedLabel = this.speedCtrl.label;
          this.playerAv.setSpeedIndex(this.speedIndex);
          this.feedback = ''; this.feedbackKind = PlayerTipKind.NONE; this.showHud = false;
        }
      },
      onLongPressEnd: () => {
        if (this.speedCtrl.endFastForward()) {
          this.longPressing = false; this.speedIndex = this.speedCtrl.index; this.speedLabel = this.speedCtrl.label;
          this.playerAv.setSpeedIndex(this.speedIndex); this.pulseHud();
        }
      },
      onPanStart: (e) => {
        if (this.isCasting()) {
          return;
        }
        this.gestures.start(e, this.state.canPlay(), this.longPressing, this.currentTime, this.playerW, this.ctx());
      },
      onPanMove: (e) => this.panMove(e), onPanEnd: () => this.finishPanSeek(), onPanCancel: () => this.finishPanSeek(),
      onCast: () => this.openCastDialog(),
      onStopCast: () => this.endCastByUser()
    };
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AVVolumePanel({ volumeLevel: this.volumeIndex })
        .width(1).height(1).hitTestBehavior(HitTestMode.None).opacity(0)

      PlayerVideoLayer({
        poster: this.poster,
        ready: this.ready,
        opening: this.opening,
        videoWidth: this.videoWidth,
        videoHeight: this.videoHeight,
        scaleMode: this.scaleMode,
        containerWidth: this.playerW,
        containerHeight: this.playerH,
        onSurfaceCreated: (sId: string) => {
          console.info(`[VideoPlayer] 关联主播放器 Surface: ${sId}`);
          this.playerAv.setSurface(sId);
        }
      })

      PlayerSpeedSheet({
        openSeq: this.speedOpenSeq,
        speedLabel: this.speedLabel,
        onPick: (index: number) => {
          this.speedCtrl.pick(index);
          this.speedIndex = index;
          this.speedLabel = this.speedCtrl.label;
          this.playerAv.setSpeedIndex(index);
          this.closeSpeedDialog();
          this.pulseHud();
        },
        onClosed: () => this.speedCtrl.setShowing(false)
      })

      if (this.castDeviceName && !this.fullNow()) {
        Column() {
          PlayerCastHud({
            deviceName: this.castDeviceName,
            seedDuration: this.duration,
            seedDevice: this.castDevice,
            castSession: this.castSession,
            onStopped: (positionSec: number) => {
              this.clearCastLocal();
              this.resumePlayerAfterCast(positionSec, this.castWasPlaying);
            },
            onFailed: (positionSec: number) => {
              this.handleCastPlaybackFailed(positionSec);
            },
            onProgress: (positionSec: number, durationSec: number) => {
              if (positionSec > 0) {
                this.state.currentTime = positionSec;
              }
              if (durationSec > 0) {
                this.state.duration = durationSec;
              }
              this.syncFromState();
              this.state.emitProgress(this.onProgress, false);
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 12 })
        .hitTestBehavior(HitTestMode.Transparent)
        .zIndex(20)
      }

      PlayerSkinView({
        isFull: this.fullNow(), showHud: this.showHud, showBack: this.showBack, title: this.title,
        playRequested: this.playRequested, isPlaying: this.isPlaying, completed: this.completed,
        opening: this.opening, seeking: this.seeking, stalled: this.stalled, errorText: this.errorText,
        currentTime: this.currentTime, duration: this.duration, muted: this.muted || this.volumeIndex <= 0,
        speedLabel: this.speedLabel, scaleLabel: this.scaleCtrl.label(this.isPortraitVideo()),
        hasPrev: this.hasPrev, hasNext: this.hasNext, longPressing: this.longPressing,
        feedback: this.feedback, feedbackKind: this.feedbackKind,
        topInset: this.topInset, leftInset: this.leftInset, rightInset: this.rightInset, bottomInset: this.bottomInset,
        edgeHud: this.edgeHud, ready: this.ready, castDeviceName: this.castDeviceName,
        events: this.skinEvents()
      })
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
        .zIndex(80)

      PlayerCastSheet({
        openSeq: this.castOpenSeq,
        mediaUrl: this.videoUrl,
        mediaTitle: this.title,
        startPosition: this.castStartSec,
        startDuration: this.state.duration,
        getStartPosition: () => this.castStartSec > 0 ? this.castStartSec : this.logicalPlayhead(),
        connectedUsn: this.castConnectedUsn,
        seedDevice: this.castDevice,
        onCasted: (device: DlnaDevice) => {
          this.pausedForPicker = false;
          this.bindCastDevice(device);
          this.parkPlayerForCast();
          this.closeCastDialog();
          this.pulseHud();
        },
        onClosed: () => this.closeCastDialog()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .clip(true)
    .onAreaChange((_old: Area, area: Area) => {
      this.playerW = Number(area.width);
      this.playerH = Number(area.height);
      this.scaleLabel = this.scaleCtrl.label(this.isPortraitVideo());
    })
  }
}
