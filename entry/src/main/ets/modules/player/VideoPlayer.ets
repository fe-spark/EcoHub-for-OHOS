import { common } from '@kit.AbilityKit';
import { AVVolumePanel } from '@kit.AudioKit';
import { PlayerWindow } from './PlayerWindow';
import { PlayerTipKind } from './PlayerPan';
import { PlayerStallWatcher } from './PlayerStallWatcher';
import { PlayerVideoLayer } from './PlayerVideoLayer';
import { PlayerPlaybackState } from './PlayerPlaybackState';
import { PlayerSkinView } from './PlayerSkinView';
import { PlayerObserverHost, PlayerVideoObserver } from './PlayerVideoObserver';
import { PlayerSpeedSheet } from './PlayerSpeedSheet';
import { PlayerCastSheet } from '../cast/PlayerCastSheet';
import { PlayerCastHud } from '../cast/PlayerCastHud';
import { PlayerCastHost } from '../cast/PlayerCastController';
import { PlayerCastBridge } from './PlayerCastBridge';
import { PlayerPipHud } from './PlayerPipHud';
import { PlayerPipCoordinator, PlayerPipHost } from './PlayerPipCoordinator';
import { PlayerActionCoordinator, PlayerActionHost } from './PlayerActionCoordinator';
import { PlayerDialogHelper } from './PlayerDialogHelper';
import { DlnaDevice } from '../../types/DlnaTypes';
import { PlayerScaleMode } from './PlayerScale';
import { PlayerAv } from './PlayerAv';
import { AppToast } from '../../common/utils/AppToast';

@Component
export struct VideoPlayer {
  @Prop @Watch('onUrlChange') videoUrl: string = '';
  @Prop @Watch('onReloadTokenChange') reloadToken: number = 0;
  @Prop title: string = '';
  @Prop poster: string = '';
  @Prop initialTime: number = 0;
  @Prop showBack: boolean = false;
  @Prop isFull: boolean = false;
  @Prop @Watch('onPrevNextChange') hasPrev: boolean = false;
  @Prop @Watch('onPrevNextChange') hasNext: boolean = false;
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
  onFullscreenChange?: (full: boolean, isPortrait?: boolean, isLandscape?: boolean) => void;
  onVideoSize?: (width: number, height: number) => void;

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
  @State private castPhase: string = '';
  @State private castTransport: string = '';
  @State private isPipActive: boolean = false;
  @StorageLink('SETTING_PIP_AUTO_START') @Watch('onSettingPipAutoStartChange') private settingPipAutoStart: boolean = true;

  private playerAv: PlayerAv = new PlayerAv();
  private watcher: PlayerStallWatcher = new PlayerStallWatcher();
  private actions: PlayerActionCoordinator = new PlayerActionCoordinator();
  private state: PlayerPlaybackState = new PlayerPlaybackState();
  private observer: PlayerVideoObserver | null = null;
  private castBridge: PlayerCastBridge = new PlayerCastBridge();
  private pipCoord: PlayerPipCoordinator = new PlayerPipCoordinator();
  private xComponentController: XComponentController = new XComponentController();
  private pageWasHidden: boolean = false;
  private sentW: number = 0;
  private sentH: number = 0;
  private playerW: number = 1;
  private playerH: number = 1;

  aboutToAppear() {
    this.castBridge.init(this.castHost());
    this.observer = new PlayerVideoObserver(this.observerHost());
    this.setupPlayerAvListener();
    this.pipCoord.setup(this.pipHost(), this.xComponentController, this.videoWidth, this.videoHeight);
    this.pipCoord.setSettingPipAutoStart(this.settingPipAutoStart);
    this.pipCoord.syncControls();
    this.nonce = 1; this.state.bootGen = 1; this.state.mountGen = 1;
    this.state.reset(this.videoUrl); this.state.playerOn = !!this.videoUrl;
    this.syncFromState(); this.armHide();
    this.playerAv.setMuted(this.muted || this.volumeIndex <= 0);
    this.playerAv.setSpeedIndex(this.speedIndex);
    if (this.videoUrl) { this.armOpenWatch(); this.playerAv.open(this.videoUrl); }
    this.actions.initAudio((v: number, m: boolean) => {
      this.volumeIndex = v; this.muted = m; this.playerAv.setMuted(m);
    }, () => this.castBridge.pushCastVolume());
  }

  aboutToDisappear() {
    this.pipCoord.destroy(); this.actions.destroyAudio();
    this.closeCastDialog(); this.castBridge.stopSession();
    this.playerAv.release(); this.watcher.clearAll(); this.closeSpeedDialog();
    this.state.bootGen++; this.castBridge.syncCastProgressToState();
    if (this.state.currentTime > 0) this.state.emitProgress(this.onProgress, true);
    const ctx = this.ctx();
    PlayerWindow.resetBrightness(ctx); PlayerWindow.setKeepScreenOn(ctx, false);
    if (this.fullNow()) PlayerWindow.setFullscreen(ctx, false, false);
  }

  onUrlChange(): void { this.handleSourceChange(); }
  onReloadTokenChange(): void { this.handleSourceChange(); }
  private onSettingPipAutoStartChange(): void { this.pipCoord.setSettingPipAutoStart(this.settingPipAutoStart); }
  private onPrevNextChange(): void { this.pipCoord.syncControls(); }

  private handleSourceChange(): void {
    this.pipCoord.handleSourceChange();
    if (this.castBridge.handleSourceChange()) { this.syncCastUi(); return; }
    this.resetPlayState(); this.remountPlayer();
  }

  private setupPlayerAvListener(): void {
    const l = this.playerAv.listener;
    l.onPrepared = (d) => { if (this.observer) this.observer.handlePrepared(d); this.pipCoord.syncAutoStart(); };
    l.onStart = () => { if (this.observer) this.observer.handleStart(); this.pipCoord.syncPlayStatus(true); };
    l.onPause = () => { if (this.observer) this.observer.handlePause(); this.pipCoord.syncPlayStatus(false); };
    l.onTime = (t) => { if (this.observer) this.observer.handleTime(t); };
    l.onFinish = () => { if (this.observer) this.observer.handleFinish(); this.pipCoord.syncPlayStatus(false); };
    l.onError = (d) => { this.pipCoord.handleError(); if (this.observer) this.observer.handleError(d); };
    l.onSeeked = (t, s) => { if (this.observer) this.observer.handleSeeked(t, s); };
    l.onVideoSize = (w, h) => {
      this.pipCoord.updateSize(w, h);
      if (this.observer) this.observer.handleVideoSize(w, h);
      this.scaleLabel = this.actions.scaleCtrl.label(this.state.isPortrait());
    };
    l.onStalled = (s) => { if (this.state.live()) { this.state.stalled = s; this.syncFromState(); } };
  }

  onPageActiveChange(): void {
    if (this.pageActive) {
      this.pipCoord.handlePageShow();
      if (this.castBridge.isCasting() || this.castConnectedUsn) {
        this.pageWasHidden = false; this.state.stalled = false; this.syncFromState();
        this.castBridge.resumeCastSync(); return;
      }
      if (!this.pageWasHidden || !this.videoUrl || this.state.completed || this.state.errorText) return;
      this.pageWasHidden = false; this.state.stalled = false; this.syncFromState();
      if (this.state.playRequested && !this.state.isPlaying) this.playerAv.play();
    } else {
      this.pageWasHidden = true; this.state.stalled = false; this.watcher.clearHide();
      this.closeSpeedDialog(); this.closeCastDialog();
      this.castBridge.syncCastProgressToState(); this.syncFromState();
      if (this.state.currentTime > 0) this.state.emitProgress(this.onProgress, true);
      this.pipCoord.handlePageHide();
    }
  }

  private ctx(): common.UIAbilityContext | undefined {
    try {
      const c = getContext(this) as common.UIAbilityContext;
      if (c) return c;
    } catch (_e) {}
    try {
      return this.getUIContext().getHostContext() as common.UIAbilityContext;
    } catch (_e) { return undefined; }
  }
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
    if (this.castBridge.isCasting()) return;
    const now = Date.now();
    if (now - this.state.lastToggleAt < VideoPlayer.PLAY_TOGGLE_DEBOUNCE_MS) return;
    this.state.lastToggleAt = now;
    if (!this.state.canPlay() && !this.state.completed) return;
    if (this.state.completed) {
      this.state.playRequested = true; this.state.completed = false; this.state.currentTime = 0;
      this.syncFromState(); this.seekTo(0); this.pulseHud(); return;
    }
    if (this.state.playRequested) {
      this.state.playRequested = false; this.state.isPlaying = false; this.playerAv.pause();
      this.syncFromState(); this.syncKeepScreen(); this.showHud = true; this.watcher.clearHide();
    } else {
      this.state.playRequested = true; this.playerAv.play(); this.syncFromState(); this.pulseHud();
    }
  }

  private toggleFull(): void {
    const next = !this.fullNow();
    if (next && this.castBridge.isCasting()) { AppToast.show('投屏中无法全屏，请先停止投屏'); return; }
    this.closeCastDialog(); this.innerFull = next; this.pulseHud();
    if (this.onFullscreenChange) this.onFullscreenChange(next, this.state.isPortrait(), this.state.isLandscape());
    else PlayerWindow.setFullscreen(this.ctx(), next, this.state.isPortrait());
    this.syncKeepScreen();
  }

  private syncKeepScreen(): void {
    const on = this.pageActive && this.state.playRequested && this.state.isPlaying && !this.state.completed && !this.state.errorText;
    PlayerWindow.setKeepScreenOn(this.ctx(), on);
  }

  private toggleMute(): void {
    const res = this.actions.toggleMute();
    this.volumeIndex = res.volume; this.muted = res.muted;
    this.playerAv.setMuted(this.muted); this.castBridge.pushCastVolume();
    this.watcher.showTip(res.label, PlayerTipKind.VOLUME, (m, k) => { this.feedback = m; this.feedbackKind = k; }, () => { this.feedback = ''; this.feedbackKind = PlayerTipKind.NONE; });
    this.pulseHud();
  }

  private retry(): void {
    this.state.prepareRetry(); this.syncFromState(); this.showHud = true; this.remountPlayer();
  }

  private remountPlayer(): void {
    this.state.bootGen++; this.state.mountGen = this.state.bootGen; this.state.playerOn = !!this.videoUrl;
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
        this.watcher.clearSeekWatch(); this.pipCoord.handleError();
        this.state.failOpen(this.videoUrl, 'Timeout (15s)');
        this.playerAv.release(); this.syncFromState(); this.syncKeepScreen(); this.showHud = true;
      }
    }, this.state.opening);
  }

  private seekTo(time: number): void {
    const prevSeq = this.state.seekSeq;
    this.state.seek(time, this.playerAv);
    if (this.state.seeking && this.state.seekSeq !== prevSeq) {
      this.watcher.armSeekWatch(() => {
        if (!this.state.live() || !this.state.seeking) return;
        this.playerAv.abandonSeeksUpTo(this.state.seekSeq);
        this.state.seeking = false; this.state.seekTarget = -1; this.state.seekSeq = 0;
        this.syncFromState(); this.armHide();
      }, this.state.seeking);
    } else if (!this.state.seeking) {
      this.watcher.clearSeekWatch();
    }
    this.syncFromState();
  }

  private openSpeedDialog(): void { this.actions.speedCtrl.setShowing(true); this.speedOpenSeq += 1; }
  private closeSpeedDialog(): void { this.actions.speedCtrl.setShowing(false); this.speedOpenSeq = 0; }
  private openCastDialog(): void { this.castBridge.openCastDialog(); this.syncCastUi(); }
  private closeCastDialog(): void { this.castOpenSeq = 0; this.castBridge.closeCastDialog(); }

  private syncCastUi(): void {
    this.castDevice = this.castBridge.device; this.castDeviceName = this.castBridge.deviceName;
    this.castConnectedUsn = this.castBridge.connectedUsn; this.castStartSec = this.castBridge.startSec;
    this.castPhase = this.castBridge.phase; this.castTransport = this.castBridge.transportState;
    this.currentTime = this.castBridge.positionSec;
    this.duration = this.castBridge.durationSec > 0 ? this.castBridge.durationSec : this.duration;
  }

  private cycleScaleMode(): void {
    const res = this.actions.cycleScale(this.state.isPortrait());
    this.scaleMode = res.mode; this.playerAv.setScaleMode(res.mode); this.scaleLabel = res.label;
    this.pulseHud();
    this.watcher.showTip(`画面：${res.label}`, PlayerTipKind.SCALE,
      (m, k) => { this.feedback = m; this.feedbackKind = k; },
      () => { this.feedback = ''; this.feedbackKind = PlayerTipKind.NONE; });
  }

  private resetPlayState(): void {
    this.actions.bumpEpoch(); this.watcher.clearOpenWatch(); this.watcher.clearSeekWatch();
    this.state.reset(this.videoUrl); this.sentW = 0; this.sentH = 0;
    this.syncFromState(); this.showHud = true; this.closeSpeedDialog();
    this.actions.speedCtrl.reset(); this.speedIndex = this.actions.speedCtrl.index;
    this.speedLabel = this.actions.speedCtrl.label; this.longPressing = false;
    this.feedback = ''; this.feedbackKind = PlayerTipKind.NONE;
    this.watcher.clearTip(); this.actions.resetGestures(); this.armHide();
  }

  private logicalPlayhead(): number {
    return this.state.ready && this.state.currentTime >= 1 ? this.state.currentTime : Math.max(this.state.currentTime, this.initialTime, 0);
  }

  private observerHost(): PlayerObserverHost {
    return {
      playerAv: this.playerAv, state: this.state, watcher: this.watcher, initialTime: this.initialTime,
      videoUrl: this.videoUrl, onProgress: this.onProgress, onEnded: this.onEnded,
      syncKeepScreen: () => this.syncKeepScreen(), armHide: () => this.armHide(),
      armSeekWatch: () => {}, revealHud: () => { this.showHud = true; this.watcher.clearHide(); },
      onUIUpdate: () => this.syncFromState()
    };
  }

  private pipHost(): PlayerPipHost {
    return {
      getContext: () => this.ctx(), isCasting: () => this.castBridge.isCasting(),
      getVideoUrl: () => this.videoUrl, hasPrev: () => this.hasPrev, hasNext: () => this.hasNext,
      onPrev: this.onPrev, onNext: this.onNext,
      isPlaying: () => this.state.isPlaying, isCompleted: () => this.state.completed,
      getErrorText: () => this.state.errorText, getDuration: () => this.duration,
      getCurrentTime: () => this.currentTime, seekTo: (t: number) => this.seekTo(t),
      pulseHud: () => this.pulseHud(),
      play: () => { this.state.playRequested = true; this.playerAv.play(); this.syncFromState(); },
      pause: () => { this.state.playRequested = false; this.playerAv.pause(); this.syncFromState(); },
      fullNow: () => this.fullNow(), exitFull: () => this.toggleFull(),
      isPageActive: () => this.pageActive,
      emitProgress: (isFinal?: boolean) => this.state.emitProgress(this.onProgress, isFinal),
      onPipActiveChanged: (active: boolean) => { this.isPipActive = active; }
    };
  }

  private castHost(): PlayerCastHost {
    return {
      state: this.state, playerAv: this.playerAv, watcher: this.watcher, audioBridge: this.actions.audioBridge,
      videoUrl: this.videoUrl, title: this.title, hasNext: () => this.hasNext, volumeIndex: this.volumeIndex,
      onEnded: this.onEnded, onProgress: this.onProgress,
      syncFromState: () => this.syncFromState(), syncKeepScreen: () => this.syncKeepScreen(),
      remountPlayer: () => this.remountPlayer(), pulseHud: () => this.pulseHud(),
      closeCastDialog: () => this.closeCastDialog(), closeSpeedDialog: () => this.closeSpeedDialog(),
      openCastSheet: () => { this.castOpenSeq += 1; }, onCastUi: () => this.syncCastUi(),
      toast: (msg: string) => AppToast.show(msg), fullNow: () => this.fullNow(),
      exitFullForCast: () => { if (this.fullNow()) this.toggleFull(); },
      logicalPlayhead: () => this.logicalPlayhead(),
      setPipAutoStart: (en: boolean) => this.pipCoord.setAutoStart(en),
      stopPip: () => { this.pipCoord.stop(); }
    };
  }

  private syncFromState(): void {
    this.duration = this.state.duration; this.currentTime = this.state.currentTime;
    this.isPlaying = this.state.isPlaying; this.playRequested = this.state.playRequested;
    this.completed = this.state.completed; this.opening = this.state.opening;
    this.errorText = this.state.errorText; this.seeking = this.state.seeking;
    this.stalled = this.state.stalled; this.ready = this.state.ready;
    this.videoWidth = this.state.videoWidth; this.videoHeight = this.state.videoHeight;
    if (this.videoWidth > 0 && this.videoHeight > 0 && (this.videoWidth !== this.sentW || this.videoHeight !== this.sentH)) {
      this.sentW = this.videoWidth; this.sentH = this.videoHeight;
      if (this.onVideoSize) this.onVideoSize(this.videoWidth, this.videoHeight);
    }
  }

  private skinActionHost(): PlayerActionHost {
    return {
      fullNow: () => this.fullNow(), toggleFull: () => this.toggleFull(),
      togglePlay: () => this.togglePlay(), toggleMute: () => this.toggleMute(),
      openSpeedDialog: () => this.openSpeedDialog(), cycleScaleMode: () => this.cycleScaleMode(),
      retry: () => this.retry(),
      showErrorDetail: () => PlayerDialogHelper.showErrorDetail(this.getUIContext(), this.errorText),
      seekTo: (t: number) => this.seekTo(t), pulseHud: () => this.pulseHud(),
      armHide: () => this.armHide(), clearHide: () => this.watcher.clearHide(),
      onBack: this.onBack, onPrev: this.onPrev, onNext: this.onNext,
      onCast: () => this.openCastDialog(), onStopCast: () => this.castBridge.endCastByUser(),
      onPip: this.pipCoord.enabled ? () => this.pipCoord.startManual() : undefined,
      isCasting: () => this.castBridge.isCasting(), canPlay: () => this.state.canPlay(),
      isPlaying: () => this.state.isPlaying, isReady: () => this.state.ready,
      isOpening: () => this.state.opening, isDragging: () => this.state.dragging,
      setDragging: (d: boolean) => { this.state.dragging = d; },
      getDuration: () => this.duration, getCurrentTime: () => this.currentTime,
      setCurrentTime: (t: number) => { this.currentTime = t; this.state.currentTime = t; },
      getPlayerW: () => this.playerW, getPlayerH: () => this.playerH, getContext: () => this.ctx(),
      getTopInset: () => this.topInset,
      setLongPressing: (lp: boolean) => { this.longPressing = lp; },
      setSpeed: (idx: number, lbl: string) => { this.speedIndex = idx; this.speedLabel = lbl; this.playerAv.setSpeedIndex(idx); },
      setFeedback: (msg: string, k: number) => { this.feedback = msg; this.feedbackKind = k; },
      clearTip: () => this.watcher.clearTip(),
      setVolumeState: (v: number, m: boolean) => { this.volumeIndex = v; this.muted = m; this.playerAv.setMuted(m); },
      isShowHud: () => this.showHud, setShowHud: (s: boolean) => { this.showHud = s; },
      isPlayRequested: () => this.state.playRequested, isCompleted: () => this.state.completed
    };
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AVVolumePanel({ volumeLevel: this.volumeIndex })
        .width(1).height(1).hitTestBehavior(HitTestMode.None).opacity(0)

      PlayerVideoLayer({
        xComponentController: this.xComponentController,
        poster: this.poster, ready: this.ready, opening: this.opening,
        videoWidth: this.videoWidth, videoHeight: this.videoHeight, scaleMode: this.scaleMode,
        containerWidth: this.playerW, containerHeight: this.playerH,
        onSurfaceCreated: (sId: string) => this.playerAv.setSurface(sId)
      })

      PlayerSpeedSheet({
        openSeq: this.speedOpenSeq, speedLabel: this.speedLabel,
        onPick: (idx: number) => {
          this.actions.speedCtrl.pick(idx);
          this.speedIndex = idx; this.speedLabel = this.actions.speedCtrl.label;
          this.playerAv.setSpeedIndex(idx);
          this.closeSpeedDialog(); this.pulseHud();
        },
        onClosed: () => this.actions.speedCtrl.setShowing(false)
      })

      if (this.castDeviceName && !this.fullNow()) {
        Column() {
          PlayerCastHud({
            deviceName: this.castDeviceName, positionSec: this.currentTime, durationSec: this.duration,
            phase: this.castPhase, transportState: this.castTransport, castSession: this.castBridge.session
          })
        }
        .width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .padding({ top: 12 }).hitTestBehavior(HitTestMode.Transparent).zIndex(20)
      }

      if (!this.isPipActive) {
        PlayerSkinView({
          reloadToken: this.reloadToken,
          isFull: this.fullNow(), showHud: this.showHud, showBack: this.showBack, title: this.title,
          playRequested: this.playRequested, isPlaying: this.isPlaying, completed: this.completed,
          opening: this.opening, seeking: this.seeking, stalled: this.stalled, errorText: this.errorText,
          currentTime: this.currentTime, duration: this.duration, muted: this.muted || this.volumeIndex <= 0,
          speedLabel: this.speedLabel, scaleLabel: this.actions.scaleCtrl.label(this.state.isPortrait()),
          hasPrev: this.hasPrev, hasNext: this.hasNext, longPressing: this.longPressing,
          feedback: this.feedback, feedbackKind: this.feedbackKind,
          topInset: this.topInset, leftInset: this.leftInset, rightInset: this.rightInset, bottomInset: this.bottomInset,
          edgeHud: this.edgeHud, ready: this.ready, castDeviceName: this.castDeviceName,
          canCast: this.videoUrl.trim().length > 0, events: this.actions.buildSkinEvents(this.skinActionHost())
        })
          .width('100%').height('100%').hitTestBehavior(HitTestMode.Transparent).zIndex(80)
      } else {
        PlayerPipHud({
          poster: this.poster, showBack: this.showBack,
          topInset: this.topInset, leftInset: this.leftInset, rightInset: this.rightInset,
          onBack: () => { if (this.onBack) this.onBack(); },
          onRestore: () => { this.pipCoord.stop(); }
        })
          .width('100%').height('100%').zIndex(85)
      }

      PlayerCastSheet({
        openSeq: this.castOpenSeq, mediaUrl: this.videoUrl, mediaTitle: this.title,
        startPosition: this.castStartSec, startDuration: this.state.duration,
        getStartPosition: () => this.castStartSec > 0 ? this.castStartSec : this.logicalPlayhead(),
        connectedUsn: this.castConnectedUsn, seedDevice: this.castDevice,
        onCasted: (device: DlnaDevice) => { this.castBridge.bindCastDevice(device); this.syncCastUi(); },
        onClosed: () => this.closeCastDialog()
      })
    }
    .width('100%').height('100%').backgroundColor('#000000').clip(true)
    .onAreaChange((_old: Area, area: Area) => {
      this.playerW = Number(area.width); this.playerH = Number(area.height);
      this.scaleLabel = this.actions.scaleCtrl.label(this.state.isPortrait());
    })
  }
}
