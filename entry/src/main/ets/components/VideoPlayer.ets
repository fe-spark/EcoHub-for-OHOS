import { common } from '@kit.AbilityKit';
import { AVVolumePanel } from '@kit.AudioKit';
import { PlayerVolumeInfo, PlayerWindow } from '../common/utils/PlayerWindow';
import { PlayerSpeed } from '../common/utils/PlayerSpeed';
import { PlayerPan, PlayerPanResult, PlayerTipKind } from '../common/utils/PlayerPan';
import { PlayerSkin } from './PlayerSkin';
import { PlayerSpeedDialog } from './PlayerTip';

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
  onFullscreenChange?: (full: boolean) => void;
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
  @State private longPressing: boolean = false;
  @State private feedback: string = '';
  @State private feedbackKind: number = PlayerTipKind.NONE;
  @State private showSpeed: boolean = false;
  @State private speedIndex: number = 1;
  @State private speedLabel: string = '1.0x';
  @State private playSrc: string = '';
  @State private playerOn: boolean = false;
  private controller: VideoController = new VideoController();
  private lastPersist: number = 0;
  private hideTimer: number = -1;
  private stallTimer: number = -1;
  private tipTimer: number = -1;
  private openTimer: number = -1;
  private bootGen: number = 0;
  private mountGen: number = 0;
  private pageWasHidden: boolean = false;
  private lastUpdateAt: number = 0;
  private lastProgressTime: number = -1;
  private playerW: number = 1;
  private playerH: number = 1;
  private savedSpeedIndex: number = 1;
  private volumeMax: number = 15;
  private lastVolumeIndex: number = 8;
  private dragging: boolean = false;
  private seekTarget: number = -1;
  private seekAt: number = 0;
  private lastToggleAt: number = 0;
  private pan: PlayerPan = new PlayerPan();
  private speedDialog: CustomDialogController | null = null;

  aboutToAppear() {
    this.nonce = 1;
    this.bootGen = 1;
    this.mountGen = 1;
    this.opening = !!this.videoUrl;
    this.playSrc = this.videoUrl;
    this.playerOn = !!this.videoUrl;
    this.armOpenWatch();
    this.armHide();
    this.syncVolume();
  }

  aboutToDisappear() {
    this.clearHide();
    this.clearStallWatch();
    this.clearTip();
    this.clearOpenWatch();
    this.closeSpeedDialog();
    this.bootGen++;
    const ctx = this.ctx();
    PlayerWindow.resetBrightness(ctx);
    PlayerWindow.setKeepScreenOn(ctx, false);
    if (this.fullNow()) {
      if (this.onFullscreenChange) {
        this.onFullscreenChange(false);
      } else {
        PlayerWindow.setFullscreen(ctx, false);
      }
    }
  }

  onUrlChange(): void {
    this.duration = 0;
    this.currentTime = 0;
    this.isPlaying = false;
    this.playRequested = true;
    this.completed = false;
    this.showHud = true;
    this.lastPersist = 0;
    this.opening = !!this.videoUrl;
    this.errorText = '';
    this.seeking = false;
    this.resetStallWatch();
    this.ready = false;
    if (this.longPressing) {
      this.speedIndex = this.savedSpeedIndex;
      this.speedLabel = PlayerSpeed.label(this.savedSpeedIndex);
    }
    this.longPressing = false;
    this.feedback = '';
    this.feedbackKind = PlayerTipKind.NONE;
    this.clearTip();
    this.closeSpeedDialog();
    this.dragging = false;
    this.seekTarget = -1;
    this.seekAt = 0;
    this.lastToggleAt = 0;
    this.pan.reset();
    this.armHide();
    this.remountPlayer();
  }

  onReloadTokenChange(): void {
    this.duration = 0;
    this.currentTime = 0;
    this.isPlaying = false;
    this.playRequested = true;
    this.completed = false;
    this.showHud = true;
    this.lastPersist = 0;
    this.opening = !!this.videoUrl;
    this.errorText = '';
    this.seeking = false;
    this.resetStallWatch();
    this.ready = false;
    this.closeSpeedDialog();
    this.dragging = false;
    this.seekTarget = -1;
    this.seekAt = 0;
    this.lastToggleAt = 0;
    this.pan.reset();
    this.armHide();
    this.remountPlayer();
  }

  onPageActiveChange(): void {
    if (!this.pageActive) {
      this.enterBackground();
      return;
    }
    this.enterForeground();
  }

  private ctx(): common.UIAbilityContext | undefined {
    return getContext(this) as common.UIAbilityContext;
  }

  private fullNow(): boolean { return this.isFull || this.innerFull; }

  private resumeTime(): number {
    if (this.currentTime >= 2) {
      return this.currentTime;
    }
    return this.initialTime;
  }

  private enterBackground(): void {
    this.pageWasHidden = true;
    this.resetStallWatch();
    this.seeking = false;
    this.seekTarget = -1;
    if (this.longPressing) {
      this.endSpeed();
    }
    if (this.dragging) {
      this.dragging = false;
      this.pan.reset();
      this.feedback = '';
      this.feedbackKind = PlayerTipKind.NONE;
    }
    this.showSpeed = false;
    PlayerWindow.setKeepScreenOn(this.ctx(), false);
    if (this.ready) {
      this.controller.pause();
    }
  }

  private enterForeground(): void {
    if (!this.pageWasHidden || !this.videoUrl || this.completed || this.errorText) {
      return;
    }
    this.pageWasHidden = false;
    this.resetStallWatch();
    if (!this.playRequested) {
      return;
    }
    this.controller.start();
  }

  private canPlay(): boolean { return this.ready && !this.opening && !this.errorText; }

  private emitProgress(current: number, duration: number): void {
    if (!this.onProgress) {
      return;
    }
    const now = Date.now();
    if (now - this.lastPersist < 5000 && current < duration - 1) {
      return;
    }
    this.lastPersist = now;
    this.onProgress(current, duration);
  }

  private armHide(): void {
    this.clearHide();
    if (!this.playRequested || this.completed || this.errorText || this.opening ||
      this.dragging || this.seeking || this.stalled) {
      return;
    }
    this.hideTimer = setTimeout(() => {
      if (this.playRequested && !this.completed && !this.errorText) {
        this.showHud = false;
      }
    }, 3000);
  }

  private clearHide(): void {
    if (this.hideTimer >= 0) {
      clearTimeout(this.hideTimer);
      this.hideTimer = -1;
    }
  }

  private clearTip(): void {
    if (this.tipTimer >= 0) {
      clearTimeout(this.tipTimer);
      this.tipTimer = -1;
    }
  }

  private showTip(message: string, kind: number): void {
    this.clearTip();
    this.feedback = message;
    this.feedbackKind = kind;
    this.tipTimer = setTimeout(() => {
      this.tipTimer = -1;
      this.feedback = '';
      this.feedbackKind = PlayerTipKind.NONE;
    }, 1000);
  }

  private clearStallWatch(): void {
    if (this.stallTimer >= 0) {
      clearTimeout(this.stallTimer);
      this.stallTimer = -1;
    }
  }

  private resetStallWatch(): void {
    this.clearStallWatch();
    this.stalled = false;
    this.lastProgressTime = -1;
  }

  private noteProgress(time: number = -1): void {
    if (time >= 0) {
      const moved = this.lastProgressTime < 0 || Math.abs(time - this.lastProgressTime) > 0.001;
      this.lastProgressTime = time;
      if (!moved) {
        return;
      }
    }
    this.lastUpdateAt = Date.now();
    if (this.stalled) {
      this.stalled = false;
    }
    this.clearStallWatch();
    if (!this.playRequested || !this.isPlaying || this.completed || this.errorText) {
      return;
    }
    // Video.onUpdate 正常播放也可能约 1s 一次；短暂停顿不弹「加载中」
    this.stallTimer = setTimeout(() => {
      this.stallTimer = -1;
      if (this.playRequested && this.isPlaying && !this.completed && !this.errorText &&
        !this.dragging && this.seekTarget < 0) {
        this.stalled = true;
      }
    }, 2500);
  }

  private toggleHud(): void {
    if (this.showSpeed || this.pan.mode > 1 || this.longPressing) {
      return;
    }
    if (this.showHud) {
      if (!this.playRequested || this.completed) {
        return;
      }
      this.showHud = false;
      this.clearHide();
    } else {
      this.showHud = true;
      this.armHide();
    }
  }

  private togglePlay(): void {
    const now = Date.now();
    if (now - this.lastToggleAt < 280) {
      return;
    }
    this.lastToggleAt = now;
    if (!this.canPlay() && !this.completed) {
      return;
    }
    if (this.completed) {
      this.playRequested = true;
      this.completed = false;
      this.currentTime = 0;
      this.seeking = true;
      this.seekTarget = 0;
      this.seekAt = Date.now();
      this.controller.setCurrentTime(0, SeekMode.Accurate);
      this.controller.start();
      this.showHud = true;
      this.armHide();
      return;
    }
    if (this.playRequested) {
      this.playRequested = false;
      this.isPlaying = false;
      this.controller.pause();
      this.syncKeepScreen();
      this.showHud = true;
      this.clearHide();
    } else {
      this.playRequested = true;
      this.controller.start();
      this.showHud = true;
      this.armHide();
    }
  }

  private toggleFull(): void {
    const next = !this.fullNow();
    this.showHud = true;
    this.armHide();
    if (this.onFullscreenChange) {
      this.onFullscreenChange(next);
    } else {
      this.innerFull = next;
      PlayerWindow.setFullscreen(this.ctx(), next);
    }
    this.syncKeepScreen();
  }

  private syncKeepScreen(): void {
    const on = this.pageActive && this.playRequested && this.isPlaying && !this.completed && !this.errorText;
    PlayerWindow.setKeepScreenOn(this.ctx(), on);
  }

  private formatPlayError(wasReady: boolean): string {
    const stage = wasReady ? '播放过程中失败' : '打开视频失败';
    const url = this.videoUrl.trim();
    if (!url) {
      return `${stage}\n未提供播放地址`;
    }
    return `${stage}\n${url}`;
  }

  private syncVolume(): void {
    PlayerWindow.getVolume().then((info: PlayerVolumeInfo) => {
      this.volumeMax = info.max;
      this.volumeIndex = info.current;
      this.muted = info.current <= 0;
      if (info.current > 0) {
        this.lastVolumeIndex = info.current;
      }
      this.pan.primeVolume(info.max > 0 ? info.current / info.max : 0);
    });
  }

  private applyVolume(ratio: number): void {
    const max = Math.max(1, this.volumeMax);
    const next = Math.round(Math.min(1, Math.max(0, ratio)) * max);
    this.volumeIndex = next;
    this.muted = next <= 0;
    if (next > 0) {
      this.lastVolumeIndex = next;
    }
  }

  private toggleMute(): void {
    if (this.volumeIndex <= 0 || this.muted) {
      const restore = this.lastVolumeIndex > 0 ? this.lastVolumeIndex : Math.ceil(this.volumeMax / 2);
      this.volumeIndex = restore;
      this.muted = false;
      this.pan.primeVolume(this.volumeMax > 0 ? restore / this.volumeMax : 0.5);
      this.showTip(`${Math.round(restore / Math.max(1, this.volumeMax) * 100)}%`, PlayerTipKind.VOLUME);
    } else {
      this.lastVolumeIndex = this.volumeIndex;
      this.volumeIndex = 0;
      this.muted = true;
      this.pan.primeVolume(0);
      this.showTip('静音', PlayerTipKind.VOLUME);
    }
    this.showHud = true;
    this.armHide();
  }

  private handleBack(): void {
    if (this.fullNow()) {
      this.toggleFull();
      return;
    }
    if (this.onBack) {
      this.onBack();
    }
  }

  private retry(): void {
    this.errorText = '';
    this.opening = true;
    this.ready = false;
    this.completed = false;
    this.playRequested = true;
    this.isPlaying = false;
    this.resetStallWatch();
    this.seeking = false;
    this.seekTarget = -1;
    this.showHud = true;
    this.remountPlayer();
  }

  private live(): boolean {
    return this.playerOn && this.bootGen === this.mountGen;
  }

  private remountPlayer(): void {
    const gen = ++this.bootGen;
    this.playerOn = false;
    this.playSrc = '';
    this.controller = new VideoController();
    this.nonce += 1;
    this.armOpenWatch();
    if (!this.videoUrl) {
      this.clearOpenWatch();
      this.opening = false;
      return;
    }
    setTimeout(() => {
      if (gen !== this.bootGen) {
        return;
      }
      this.mountGen = gen;
      this.playSrc = this.videoUrl;
      this.playerOn = true;
    }, 80);
  }

  private armOpenWatch(): void {
    this.clearOpenWatch();
    if (!this.opening) {
      return;
    }
    this.openTimer = setTimeout(() => {
      this.openTimer = -1;
      if (this.live() && this.opening && !this.ready && !this.errorText) {
        this.opening = false;
        this.playRequested = false;
        this.errorText = this.formatPlayError(false);
        this.syncKeepScreen();
      }
    }, 12000);
  }

  private clearOpenWatch(): void {
    if (this.openTimer >= 0) {
      clearTimeout(this.openTimer);
      this.openTimer = -1;
    }
  }

  private showErrorDetail(): void {
    AlertDialog.show({
      title: '报错详情',
      message: this.errorText,
      confirm: { value: '知道了', action: () => {} }
    });
  }

  private pickSpeed(index: number): void {
    this.speedIndex = index;
    this.speedLabel = PlayerSpeed.label(index);
    this.showSpeed = false;
    this.closeSpeedDialog();
    this.showHud = true;
    this.armHide();
  }

  private openSpeedDialog(): void {
    this.closeSpeedDialog();
    this.showSpeed = true;
    this.speedDialog = new CustomDialogController({
      builder: PlayerSpeedDialog({
        speedLabel: this.speedLabel,
        onPickSpeed: (index: number) => this.pickSpeed(index)
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      backgroundColor: Color.Transparent,
      maskColor: 'rgba(0,0,0,0.52)',
      cancel: () => {
        this.showSpeed = false;
        this.speedDialog = null;
      }
    });
    this.speedDialog.open();
  }

  private closeSpeedDialog(): void {
    this.showSpeed = false;
    if (this.speedDialog) {
      this.speedDialog.close();
      this.speedDialog = null;
    }
  }

  private seekTo(time: number): void {
    if (!this.canPlay() || this.duration <= 0) {
      return;
    }
    const next = Math.min(this.duration, Math.max(0, time));
    this.seeking = true;
    this.currentTime = next;
    this.seekTarget = next;
    this.seekAt = Date.now();
    this.controller.setCurrentTime(next, SeekMode.Accurate);
    if (this.playRequested) {
      this.controller.start();
    }
  }

  private applyPlaybackTime(time: number): void {
    if (this.dragging || this.pan.mode === 2) {
      return;
    }
    if (this.seekTarget >= 0) {
      const delta = Math.abs(time - this.seekTarget);
      const elapsed = Date.now() - this.seekAt;
      const settled = delta <= 1.2 || elapsed > 1800;
      if (!settled) {
        return;
      }
      this.seekTarget = -1;
      this.seeking = false;
      this.armHide();
    }
    this.currentTime = time;
  }

  private seekBy(delta: number): void {
    this.seekTo(this.currentTime + delta);
    this.showHud = true;
    this.armHide();
  }

  private beginSpeed(): void {
    if (!this.canPlay() || !this.isPlaying) {
      return;
    }
    this.savedSpeedIndex = this.speedIndex;
    this.longPressing = true;
    this.speedIndex = PlayerSpeed.FAST_INDEX;
    this.speedLabel = PlayerSpeed.label(PlayerSpeed.FAST_INDEX);
    this.feedback = '';
    this.feedbackKind = PlayerTipKind.NONE;
    this.showHud = false;
  }

  private endSpeed(): void {
    if (!this.longPressing) {
      return;
    }
    this.longPressing = false;
    this.speedIndex = this.savedSpeedIndex;
    this.speedLabel = PlayerSpeed.label(this.savedSpeedIndex);
    this.showHud = true;
    this.armHide();
  }

  private panStart(event: GestureEvent): void {
    if (!this.canPlay() || this.longPressing) {
      this.pan.reset();
      return;
    }
    if (!event.fingerList || event.fingerList.length === 0) {
      return;
    }
    const finger = event.fingerList[0];
    this.pan.begin(finger.localX, finger.localY, this.currentTime, this.playerW);
    PlayerWindow.getBrightness(this.ctx()).then((value: number) => {
      this.pan.primeBright(value);
    });
    PlayerWindow.getVolume().then((info: PlayerVolumeInfo) => {
      this.volumeMax = info.max;
      this.pan.primeVolume(info.max > 0 ? info.current / info.max : 0);
    });
  }

  private panMove(event: GestureEvent): void {
    if (this.pan.mode === 0 || this.longPressing) {
      return;
    }
    if (!event.fingerList || event.fingerList.length === 0) {
      return;
    }
    const finger = event.fingerList[0];
    const result: PlayerPanResult | null =
      this.pan.move(finger.localX, finger.localY, this.fullNow(), this.duration, this.playerW, this.playerH);
    if (!result) {
      return;
    }
    if (result.mode === 2) {
      this.dragging = true;
      this.currentTime = result.time;
      this.feedback = result.feedback;
      this.feedbackKind = result.kind;
      this.clearHide();
    } else if (result.mode === 3 && result.bright >= 0) {
      PlayerWindow.setBrightness(this.ctx(), result.bright);
      this.feedback = result.feedback;
      this.feedbackKind = result.kind;
    } else if (result.mode === 4 && result.volume >= 0) {
      this.applyVolume(result.volume);
      this.feedback = result.feedback;
      this.feedbackKind = result.kind;
    }
  }

  private finishPanSeek(): void {
    const shouldSeek = this.pan.mode === 2;
    const target = this.currentTime;
    this.pan.reset();
    this.clearTip();
    this.feedback = '';
    this.feedbackKind = PlayerTipKind.NONE;
    if (shouldSeek) {
      this.seekTo(target);
    }
    this.dragging = false;
    this.showHud = true;
    this.armHide();
  }

  private panEnd(): void {
    this.finishPanSeek();
  }

  private panCancel(): void {
    this.finishPanSeek();
  }

  @Builder
  skin() {
    PlayerSkin({
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
      muted: this.muted,
      speedLabel: this.speedLabel,
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
      onBack: () => this.handleBack(),
      onPlay: () => this.togglePlay(),
      onFull: () => this.toggleFull(),
      onMute: () => this.toggleMute(),
      onPrev: () => {
        if (this.onPrev) {
          this.onPrev();
        }
      },
      onNext: () => {
        if (this.onNext) {
          this.onNext();
        }
      },
      onSpeed: () => this.openSpeedDialog(),
      onRetry: () => this.retry(),
      onErrorDetail: () => this.showErrorDetail(),
      onSeekBack: () => this.seekBy(-10),
      onSeekForward: () => this.seekBy(10),
      onSeekStart: (value: number) => {
        this.dragging = true;
        this.currentTime = value;
        this.clearHide();
        this.showHud = true;
      },
      onSeekUpdate: (value: number) => {
        this.currentTime = value;
      },
      onSeekEnd: (value: number) => {
        this.seekTo(value);
        this.dragging = false;
        this.showHud = true;
        this.armHide();
      },
      onToggleHud: () => this.toggleHud(),
      onLongPress: () => this.beginSpeed(),
      onLongPressEnd: () => this.endSpeed(),
      onPanStart: (event: GestureEvent) => this.panStart(event),
      onPanMove: (event: GestureEvent) => this.panMove(event),
      onPanEnd: () => this.panEnd(),
      onPanCancel: () => this.panCancel()
    })
      .width('100%')
      .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AVVolumePanel({ volumeLevel: this.volumeIndex })
        .width(1)
        .height(1)
        .hitTestBehavior(HitTestMode.None)
        .opacity(0)

      if (this.playerOn && this.playSrc) {
        Video({
          src: this.playSrc,
          previewUri: this.poster,
          controller: this.controller,
          currentProgressRate: PlayerSpeed.of(this.speedIndex)
        })
          .id(`eco_player_${this.nonce}`)
          .width('100%')
          .height('100%')
          .autoPlay(this.playRequested)
          .controls(false)
          .muted(this.muted || this.volumeIndex <= 0)
          .objectFit(ImageFit.Contain)
          .backgroundColor('#000000')
          .hitTestBehavior(HitTestMode.None)
          .onPrepared((info: PreparedInfo) => {
            if (!this.live()) {
              return;
            }
            this.duration = info.duration;
            this.ready = true;
            this.opening = false;
            this.clearOpenWatch();
            this.errorText = '';
            const resumeAt = this.resumeTime();
            if (resumeAt >= 2) {
              this.currentTime = resumeAt;
              this.seeking = true;
              this.seekTarget = resumeAt;
              this.seekAt = Date.now();
              this.controller.setCurrentTime(resumeAt, SeekMode.Accurate);
            }
            if (this.playRequested) {
              this.controller.start();
            }
          })
          .onStart(() => {
            if (!this.live()) {
              return;
            }
            if (!this.playRequested) {
              this.controller.pause();
              this.isPlaying = false;
              return;
            }
            this.isPlaying = true;
            this.opening = false;
            this.clearOpenWatch();
            this.completed = false;
            if (this.seekTarget < 0) {
              this.seeking = false;
            }
            this.noteProgress();
            this.syncKeepScreen();
            this.armHide();
          })
          .onPause(() => {
            if (!this.live()) {
              return;
            }
            this.isPlaying = false;
            this.stalled = false;
            this.clearStallWatch();
            this.syncKeepScreen();
            if (!this.playRequested) {
              this.showHud = true;
              this.clearHide();
            }
            this.emitProgress(this.currentTime, this.duration);
          })
          .onUpdate((info: PlaybackInfo) => {
            if (!this.live()) {
              return;
            }
            this.opening = false;
            if (info.time > 0) {
              this.isPlaying = this.playRequested;
            }
            this.noteProgress(info.time);
            this.applyPlaybackTime(info.time);
            this.emitProgress(this.currentTime, this.duration);
          })
          .onSeeking(() => {
            if (!this.live()) {
              return;
            }
            if (this.seekTarget >= 0 || this.dragging) {
              this.seeking = true;
            }
          })
          .onSeeked(() => {
            if (!this.live()) {
              return;
            }
            if (this.seekTarget < 0) {
              this.seeking = false;
            }
          })
          .onFinish(() => {
            if (!this.live()) {
              return;
            }
            this.isPlaying = false;
            this.playRequested = false;
            this.completed = true;
            this.stalled = false;
            this.clearStallWatch();
            this.showHud = true;
            this.syncKeepScreen();
            this.lastPersist = 0;
            this.emitProgress(this.duration > 0 ? this.duration : this.currentTime, this.duration);
            if (this.onEnded) {
              this.onEnded();
            }
          })
          .onError(() => {
            if (!this.live()) {
              return;
            }
            const wasReady = this.ready;
            this.isPlaying = false;
            this.playRequested = false;
            this.opening = false;
            this.clearOpenWatch();
            this.ready = false;
            this.showHud = true;
            this.errorText = this.formatPlayError(wasReady);
            this.syncKeepScreen();
          })
      } else if (this.poster) {
        Image(this.poster)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(0.35)
      } else {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
      }

      this.skin()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .clip(true)
    .onAreaChange((_old: Area, area: Area) => {
      this.playerW = Number(area.width);
      this.playerH = Number(area.height);
    })
  }
}
