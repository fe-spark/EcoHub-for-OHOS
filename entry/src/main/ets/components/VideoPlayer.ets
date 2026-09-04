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
import { PlayerScale, PlayerScaleMode } from '../common/utils/PlayerScale';
import { PlayerScaleController } from './PlayerScaleController';
import { PlayerScaleSheet } from './PlayerScaleSheet';
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
  @State private scaleOpenSeq: number = 0;

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

  aboutToAppear() {
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
    });
  }

  private setupPlayerAvListener(): void {
    this.playerAv.listener.onPrepared = (dur: number) => {
      if (this.observer) this.observer.handlePrepared(dur);
    };
    this.playerAv.listener.onStart = () => {
      if (this.observer) this.observer.handleStart();
    };
    this.playerAv.listener.onPause = () => {
      if (this.observer) this.observer.handlePause();
    };
    this.playerAv.listener.onTime = (time: number) => {
      if (this.observer) this.observer.handleTime(time);
    };
    this.playerAv.listener.onFinish = () => {
      if (this.observer) this.observer.handleFinish();
    };
    this.playerAv.listener.onError = (detail?: string) => {
      if (this.observer) this.observer.handleError(detail);
    };
    this.playerAv.listener.onSeeked = (timeSec: number, seq: number) => {
      if (this.observer) this.observer.handleSeeked(timeSec, seq);
    };
    this.playerAv.listener.onVideoSize = (w: number, h: number) => {
      if (this.observer) this.observer.handleVideoSize(w, h);
      this.scaleLabel = this.scaleCtrl.label(this.isPortraitVideo());
    };
    this.playerAv.listener.onStalled = (stalled: boolean) => {
      if (this.state.live()) {
        this.state.stalled = stalled;
        this.syncFromState();
      }
    };
  }

  aboutToDisappear() {
    if (this.volumeSub) {
      this.volumeSub();
      this.volumeSub = null;
    }
    this.playerAv.release();
    this.watcher.clearAll();
    this.closeSpeedDialog();
    this.closeScaleDialog();
    this.state.bootGen++;
    if (this.currentTime > 0) this.state.emitProgress(this.onProgress, true);
    const ctx = this.ctx();
    PlayerWindow.resetBrightness(ctx);
    PlayerWindow.setKeepScreenOn(ctx, false);
    if (this.fullNow()) {
      if (this.onFullscreenChange) this.onFullscreenChange(false, false);
      else PlayerWindow.setFullscreen(ctx, false, false);
    }
  }

  onUrlChange(): void {
    this.resetPlayState();
    this.remountPlayer();
  }

  onReloadTokenChange(): void {
    this.resetPlayState();
    this.remountPlayer();
  }

  private observerHost(): PlayerObserverHost {
    return {
      playerAv: this.playerAv,
      state: this.state,
      watcher: this.watcher,
      initialTime: this.initialTime,
      videoUrl: this.videoUrl,
      onProgress: this.onProgress,
      onEnded: this.onEnded,
      syncKeepScreen: () => this.syncKeepScreen(),
      armHide: () => this.armHide(),
      armSeekWatch: () => this.armSeekWatch(),
      revealHud: () => { this.showHud = true; this.watcher.clearHide(); },
      onUIUpdate: () => this.syncFromState()
    };
  }

  private syncFromState(): void {
    this.duration = this.state.duration;
    this.currentTime = this.state.currentTime;
    this.isPlaying = this.state.isPlaying;
    this.playRequested = this.state.playRequested;
    this.completed = this.state.completed;
    this.opening = this.state.opening;
    this.errorText = this.state.errorText;
    this.seeking = this.state.seeking;
    this.stalled = this.state.stalled;
    this.ready = this.state.ready;
    this.videoWidth = this.state.videoWidth;
    this.videoHeight = this.state.videoHeight;
  }

  private resetPlayState(): void {
    this.watcher.clearOpenWatch();
    this.watcher.clearSeekWatch();
    this.state.reset(this.videoUrl);
    this.syncFromState();
    this.showHud = true;
    this.closeSpeedDialog();
    this.closeScaleDialog();
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
      this.closeScaleDialog();
      this.syncFromState();
      if (this.state.currentTime > 0) this.state.emitProgress(this.onProgress, true);
      if (this.state.isPlaying) this.playerAv.pause();
    }
  }

  private ctx(): common.UIAbilityContext | undefined { return this.getUIContext().getHostContext() as common.UIAbilityContext; }

  private fullNow(): boolean {
    return this.isFull || this.innerFull;
  }

  private armHide(): void {
    const canHide = this.state.playRequested && !this.state.completed && !this.state.errorText &&
      !this.state.opening && !this.state.dragging && !this.state.seeking && !this.state.stalled;
    this.watcher.armHide(() => {
      if (this.state.playRequested && !this.state.completed && !this.state.errorText) this.showHud = false;
    }, canHide);
  }

  private pulseHud(): void {
    this.showHud = true;
    this.armHide();
  }

  private togglePlay(): void {
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

  private toggleFull(): void {
    const next = !this.fullNow();
    const isPort = this.state.isPortrait();
    console.info(`[VideoPlayer] 点击全屏 -> targetFull: ${next}, isPortrait: ${isPort}, dimensions: ${this.state.videoWidth}x${this.state.videoHeight}`);
    this.pulseHud();
    if (this.onFullscreenChange) this.onFullscreenChange(next, isPort);
    else { this.innerFull = next; PlayerWindow.setFullscreen(this.ctx(), next, isPort); }
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
    this.watcher.showTip(res.label, PlayerTipKind.VOLUME, (msg, k) => { this.feedback = msg; this.feedbackKind = k; }, () => { this.feedback = ''; this.feedbackKind = PlayerTipKind.NONE; });
    this.pulseHud();
  }

  private retry(): void {
    this.state.prepareRetry();
    this.syncFromState();
    this.showHud = true;
    this.remountPlayer();
  }

  private remountPlayer(): void {
    const gen = ++this.state.bootGen;
    this.state.mountGen = gen;
    this.state.playerOn = !!this.videoUrl;
    if (this.observer) this.observer.updateHost(this.observerHost());
    this.armOpenWatch();
    if (!this.videoUrl) {
      this.watcher.clearOpenWatch();
      this.state.opening = false;
      this.syncFromState();
      this.playerAv.release();
      return;
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
  private openScaleDialog(): void { this.scaleCtrl.setShowing(true); this.scaleOpenSeq += 1; }
  private closeScaleDialog(): void { this.scaleCtrl.setShowing(false); this.scaleOpenSeq = 0; }

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

  private skinEvents(): PlayerSkinEvents {
    return {
      onBack: () => {
        if (this.fullNow()) this.toggleFull();
        else if (this.onBack) this.onBack();
      },
      onPlay: () => this.togglePlay(),
      onFull: () => this.toggleFull(),
      onMute: () => this.toggleMute(),
      onPrev: () => { if (this.onPrev) this.onPrev(); },
      onNext: () => { if (this.onNext) this.onNext(); },
      onSpeed: () => this.openSpeedDialog(),
      onScale: () => this.openScaleDialog(),
      onRetry: () => this.retry(),
      onErrorDetail: () => {
        const rawErr = this.errorText;
        this.getUIContext().showAlertDialog({
          title: '播放异常详情',
          message: rawErr,
          primaryButton: {
            value: '复制',
            fontColor: AppTheme.ACCENT,
            action: () => {
              if (rawErr) {
                try {
                  const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, rawErr);
                  pasteboard.getSystemPasteboard().setDataSync(data);
                  this.getUIContext().getPromptAction().showToast({ message: '已复制报错信息' });
                } catch (_e) {
                }
              }
            }
          },
          secondaryButton: { value: '知道了', action: () => {} }
        });
      },
      onSeekBack: () => { this.seekTo(this.currentTime - VideoPlayer.SEEK_STEP_SEC); this.pulseHud(); },
      onSeekForward: () => { this.seekTo(this.currentTime + VideoPlayer.SEEK_STEP_SEC); this.pulseHud(); },
      onSeekStart: (val) => { this.state.dragging = true; this.currentTime = val; this.state.currentTime = val; this.watcher.clearHide(); this.showHud = true; },
      onSeekUpdate: (val) => { this.currentTime = val; this.state.currentTime = val; },
      onSeekEnd: (val) => { this.currentTime = val; this.state.currentTime = val; this.seekTo(val); this.state.dragging = false; this.pulseHud(); },
      onToggleHud: () => {
        if (this.speedCtrl.showing || this.scaleCtrl.showing || this.gestures.pan.mode > 1 || this.longPressing) return;
        if (this.showHud) {
          if (!this.playRequested || this.completed) return;
          this.showHud = false; this.watcher.clearHide();
        } else {
          this.showHud = true; this.armHide();
        }
      },
      onLongPress: () => {
        if (this.speedCtrl.beginFastForward(this.state.canPlay(), this.isPlaying)) {
          this.longPressing = true; this.speedIndex = this.speedCtrl.index; this.speedLabel = this.speedCtrl.label;
          this.playerAv.setSpeedIndex(this.speedIndex);
          this.feedback = ''; this.feedbackKind = PlayerTipKind.NONE; this.showHud = false;
        }
      },
      onLongPressEnd: () => {
        if (this.speedCtrl.endFastForward()) {
          this.longPressing = false; this.speedIndex = this.speedCtrl.index; this.speedLabel = this.speedCtrl.label;
          this.playerAv.setSpeedIndex(this.speedIndex);
          this.pulseHud();
        }
      },
      onPanStart: (e) => this.gestures.start(e, this.state.canPlay(), this.longPressing, this.currentTime, this.playerW, this.ctx()),
      onPanMove: (e) => this.panMove(e),
      onPanEnd: () => this.finishPanSeek(),
      onPanCancel: () => this.finishPanSeek()
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
        scaleMode: this.fullNow() ? this.scaleMode : PlayerScaleMode.FIT,
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

      PlayerScaleSheet({
        openSeq: this.scaleOpenSeq,
        scaleMode: this.scaleMode,
        isPortrait: this.isPortraitVideo(),
        onPick: (mode: number) => {
          this.scaleCtrl.pick(mode);
          this.scaleMode = mode;
          this.scaleLabel = this.scaleCtrl.label(this.isPortraitVideo());
          this.closeScaleDialog();
          this.pulseHud();
          this.watcher.showTip(`画面：${PlayerScale.label(mode, this.isPortraitVideo())}`, PlayerTipKind.SCALE,
            (msg, k) => { this.feedback = msg; this.feedbackKind = k; },
            () => { this.feedback = ''; this.feedbackKind = PlayerTipKind.NONE; });
        },
        onClosed: () => this.scaleCtrl.setShowing(false)
      })

      PlayerSkinView({
        isFull: this.fullNow(),
        showHud: this.showHud,
        showBack: this.showBack,
        title: this.title,
        playRequested: this.playRequested,
        isPlaying: this.isPlaying,
        completed: this.completed,
        opening: this.opening,
        seeking: this.seeking,
        stalled: this.stalled,
        errorText: this.errorText,
        currentTime: this.currentTime,
        duration: this.duration,
        muted: this.muted || this.volumeIndex <= 0,
        speedLabel: this.speedLabel,
        scaleLabel: this.scaleCtrl.label(this.isPortraitVideo()),
        hasPrev: this.hasPrev,
        hasNext: this.hasNext,
        longPressing: this.longPressing,
        feedback: this.feedback,
        feedbackKind: this.feedbackKind,
        topInset: this.topInset,
        leftInset: this.leftInset,
        rightInset: this.rightInset,
        bottomInset: this.bottomInset,
        ready: this.ready,
        events: this.skinEvents()
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
