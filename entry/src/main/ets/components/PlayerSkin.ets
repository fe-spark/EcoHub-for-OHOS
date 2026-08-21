import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { PlayerTipKind } from '../common/utils/PlayerPan';
import { PlayerBackBtn, PlayerChip, PlayerIconBtn, PlayerTextBtn } from './PlayerControl';
import { PlayerGestureLayer } from './PlayerGesture';
import { PlayerErrorPad, PlayerLoadingCard, PlayerSpeedSheet, PlayerTip } from './PlayerTip';

@Component
export struct PlayerSkin {
  @Prop isFull: boolean = false;
  @Prop showHud: boolean = true;
  @Prop showBack: boolean = false;
  @Prop title: string = '';
  @Prop playRequested: boolean = false;
  @Prop isPlaying: boolean = false;
  @Prop completed: boolean = false;
  @Prop opening: boolean = false;
  @Prop seeking: boolean = false;
  @Prop errorText: string = '';
  @Prop currentTime: number = 0;
  @Prop duration: number = 0;
  @Prop muted: boolean = false;
  @Prop speedLabel: string = '1.0x';
  @Prop hasPrev: boolean = false;
  @Prop hasNext: boolean = false;
  @Prop @Watch('onLongPressWatch') longPressing: boolean = false;
  @Prop feedback: string = '';
  @Prop feedbackKind: number = PlayerTipKind.NONE;
  @Prop showSpeed: boolean = false;
  @Prop topInset: number = 0;
  @Prop leftInset: number = 0;
  @Prop rightInset: number = 0;
  @Prop bottomInset: number = 0;
  @Prop ready: boolean = false;
  @Prop stalled: boolean = false;
  onBack?: () => void;
  onPlay?: () => void;
  onFull?: () => void;
  onMute?: () => void;
  onPrev?: () => void;
  onNext?: () => void;
  onSpeed?: () => void;
  onPickSpeed?: (index: number) => void;
  onRetry?: () => void;
  onErrorDetail?: () => void;
  onSeekBack?: () => void;
  onSeekForward?: () => void;
  onSeekStart?: (value: number) => void;
  onSeekUpdate?: (value: number) => void;
  onSeekEnd?: (value: number) => void;
  onCloseSpeed?: () => void;
  onToggleHud?: () => void;
  onLongPress?: () => void;
  onLongPressEnd?: () => void;
  onPanStart?: (event: GestureEvent) => void;
  onPanMove?: (event: GestureEvent) => void;
  onPanEnd?: () => void;
  onPanCancel?: () => void;
  @State private speedTick: number = 0;
  private speedTimer: number = -1;

  aboutToDisappear(): void {
    this.clearSpeedTimer();
  }

  onLongPressWatch(): void {
    this.clearSpeedTimer();
    if (!this.longPressing) {
      this.speedTick = 0;
      return;
    }
    this.speedTimer = setInterval(() => {
      this.speedTick = (this.speedTick + 1) % 3;
    }, 180);
  }

  private clearSpeedTimer(): void {
    if (this.speedTimer >= 0) {
      clearInterval(this.speedTimer);
      this.speedTimer = -1;
    }
  }

  private continuing(): boolean {
    return this.playRequested && !this.completed && !this.errorText;
  }

  private loading(): boolean {
    if (this.errorText) {
      return false;
    }
    if (this.opening) {
      return true;
    }
    if (!this.continuing()) {
      return false;
    }
    return this.seeking || this.stalled;
  }

  private showCenterPlay(): boolean {
    return this.showHud && this.ready && !this.loading() && !this.errorText && !this.continuing();
  }

  private showBottom(): boolean {
    return this.showHud && this.ready && !this.errorText;
  }

  private showTopFull(): boolean {
    return this.isFull && this.showHud && !this.errorText;
  }

  private timeText(): string {
    return `${FormatUtil.duration(this.currentTime)} / ${FormatUtil.duration(this.duration)}`;
  }

  private edge(base: number, inset: number): number {
    return Math.max(base, inset);
  }

  private progressPercent(): number {
    if (this.duration <= 0) {
      return 0;
    }
    return Math.min(100, Math.max(0, this.currentTime / this.duration * 100));
  }

  @Builder
  sliderBar() {
    Slider({
      value: this.currentTime,
      min: 0,
      max: this.duration > 0 ? this.duration : 1,
      step: 0.2,
      style: SliderStyle.OutSet
    })
      .width('100%')
      .height(20)
      .trackThickness(2)
      .blockSize({ width: 12, height: 12 })
      .blockColor('#FFFFFF')
      .trackColor('rgba(255,255,255,0.28)')
      .selectedColor(AppTheme.ACCENT)
      .enabled(this.duration > 0 && this.ready)
      .onChange((value: number, mode: SliderChangeMode) => {
        if (mode === SliderChangeMode.Begin && this.onSeekStart) {
          this.onSeekStart(value);
        } else if (mode === SliderChangeMode.Moving && this.onSeekUpdate) {
          this.onSeekUpdate(value);
        } else if (this.onSeekEnd) {
          this.onSeekEnd(value);
        }
      })
  }

  @Builder
  topBar() {
    if (this.showTopFull()) {
      Row() {
        PlayerBackBtn({ onTap: this.onBack })
        Text(this.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 4, right: 8 })
        if (this.hasPrev) {
          PlayerChip({ label: '上集', canTap: true, onTap: this.onPrev })
        }
        if (this.hasNext) {
          PlayerChip({ label: '下集', canTap: true, onTap: this.onNext })
        }
      }
      .width('100%')
      .height(44)
      .padding({
        left: this.edge(8, this.leftInset),
        right: this.edge(8, this.rightInset),
        top: this.edge(4, this.topInset)
      })
      .alignItems(VerticalAlign.Center)
      .linearGradient({
        angle: 180,
        colors: [['rgba(0,0,0,0.68)', 0], ['rgba(0,0,0,0.34)', 0.5], ['rgba(0,0,0,0)', 1]]
      })
    }
  }

  @Builder
  playToggle() {
    PlayerIconBtn({
      src: this.continuing() ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'),
      iconSize: 22,
      boxSize: 44,
      onTap: this.onPlay
    })
  }

  @Builder
  bottomBar() {
    if (this.showBottom()) {
      if (this.isFull) {
        Column({ space: 2 }) {
          this.sliderBar()
          Row() {
            this.playToggle()
            Text(this.timeText())
              .fontSize(12)
              .fontColor('rgba(255,255,255,0.92)')
              .margin({ left: 4 })
              .maxLines(1)
            Blank()
            PlayerChip({ label: this.speedLabel, canTap: this.ready, onTap: this.onSpeed })
            PlayerIconBtn({
              src: this.muted ? $r('sys.symbol.speaker_slash') : $r('sys.symbol.speaker_wave_2'),
              iconSize: 20,
              boxSize: 44,
              onTap: this.onMute
            })
            PlayerIconBtn({
              src: $r('sys.symbol.arrow_down_right_and_arrow_up_left'),
              iconSize: 18,
              boxSize: 44,
              onTap: this.onFull
            })
          }
          .width('100%')
          .height(44)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .padding({
          left: this.edge(4, this.leftInset),
          right: this.edge(4, this.rightInset),
          bottom: this.edge(8, this.bottomInset),
          top: 4
        })
        .linearGradient({
          angle: 180,
          colors: [['rgba(0,0,0,0)', 0], ['rgba(0,0,0,0.72)', 1]]
        })
      } else {
        Row() {
          this.playToggle()
          Column() {
            this.sliderBar()
          }
          .layoutWeight(1)
          .margin({ left: 2, right: 8 })
          Text(this.timeText())
            .fontSize(11)
            .fontColor('rgba(255,255,255,0.88)')
            .maxLines(1)
          PlayerChip({ label: this.speedLabel, canTap: this.ready, onTap: this.onSpeed })
          PlayerIconBtn({
            src: $r('sys.symbol.arrow_up_left_and_arrow_down_right'),
            iconSize: 18,
            boxSize: 44,
            onTap: this.onFull
          })
        }
        .width('100%')
        .height(44)
        .padding({ left: 2, right: 2 })
        .alignItems(VerticalAlign.Center)
        .linearGradient({
          angle: 180,
          colors: [['rgba(0,0,0,0)', 0], ['rgba(0,0,0,0.72)', 1]]
        })
      }
    } else if (!this.errorText && this.ready) {
      Row() {
        Row()
          .width(`${this.progressPercent()}%`)
          .height(2)
          .backgroundColor(AppTheme.ACCENT)
      }
      .width('100%')
      .height(2)
      .backgroundColor('rgba(255,255,255,0.18)')
      .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  centerPlay() {
    if (this.showCenterPlay()) {
      Row({ space: 28 }) {
        if (this.isFull) {
          PlayerTextBtn({ label: '-10', boxSize: 48, onTap: this.onSeekBack })
        }
        PlayerIconBtn({
          src: this.completed ? $r('sys.symbol.arrow_counterclockwise') : $r('sys.symbol.play_fill'),
          iconSize: 36,
          boxSize: 64,
          circle: true,
          prominent: true,
          onTap: this.onPlay
        })
        if (this.isFull) {
          PlayerTextBtn({ label: '+10', boxSize: 48, onTap: this.onSeekForward })
        }
      }
    }
  }

  @Builder
  centerGroup() {
    Column({ space: 12 }) {
      if (this.longPressing) {
        PlayerTip({ message: '2.0x', kind: PlayerTipKind.SPEED, speedTick: this.speedTick })
      } else if (this.feedback) {
        PlayerTip({ message: this.feedback, kind: this.feedbackKind })
      }
      if (this.loading()) {
        PlayerLoadingCard({ opening: this.opening })
      }
      if (this.showCenterPlay()) {
        this.centerPlay()
      }
    }
  }

  build() {
    Stack() {
      PlayerGestureLayer({
        onPlay: this.onPlay,
        onToggleHud: this.onToggleHud,
        onLongPress: this.onLongPress,
        onLongPressEnd: this.onLongPressEnd,
        onPanStart: this.onPanStart,
        onPanMove: this.onPanMove,
        onPanEnd: this.onPanEnd,
        onPanCancel: this.onPanCancel
      })
        .width('100%')
        .height('100%')

      if (this.showCenterPlay()) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.isFull ? 'rgba(0,0,0,0.20)' : 'rgba(0,0,0,0.24)')
          .hitTestBehavior(HitTestMode.None)
      }

      Column() {
        this.topBar()
        Column() {
          this.centerGroup()
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
        this.bottomBar()
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)

      if (!this.isFull && this.showBack) {
        PlayerBackBtn({ onTap: this.onBack })
          .position({ x: 4, y: 4 })
      }

      if (this.errorText) {
        PlayerErrorPad({
          onRetry: () => {
            if (this.onRetry) {
              this.onRetry();
            }
          },
          onErrorDetail: () => {
            if (this.onErrorDetail) {
              this.onErrorDetail();
            }
          }
        })
      }
      if (this.showSpeed) {
        PlayerSpeedSheet({
          speedLabel: this.speedLabel,
          onCloseSpeed: () => {
            if (this.onCloseSpeed) {
              this.onCloseSpeed();
            }
          },
          onPickSpeed: (index: number) => {
            if (this.onPickSpeed) {
              this.onPickSpeed(index);
            }
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}
