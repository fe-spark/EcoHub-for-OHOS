import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { PlayerTipKind } from '../common/utils/PlayerPan';
import { PlayerBackBtn, PlayerChip, PlayerIconBtn, PlayerLabelBtn, PlayerTextBtn } from './PlayerControl';
import { PlayerGestureLayer } from './PlayerGesture';
import { PlayerErrorPad, PlayerLoadingCard, PlayerTip } from './PlayerTip';

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
  @Prop scaleLabel: string = '适应';
  @Prop hasPrev: boolean = false;
  @Prop hasNext: boolean = false;
  @Prop longPressing: boolean = false;
  @Prop feedback: string = '';
  @Prop feedbackKind: number = PlayerTipKind.NONE;
  @Prop topInset: number = 0;
  @Prop leftInset: number = 0;
  @Prop rightInset: number = 0;
  @Prop bottomInset: number = 0;
  @Prop edgeHud: boolean = false;
  @Prop ready: boolean = false;
  @Prop stalled: boolean = false;
  onBack?: () => void;
  onPlay?: () => void;
  onFull?: () => void;
  onMute?: () => void;
  onPrev?: () => void;
  onNext?: () => void;
  onSpeed?: () => void;
  onScale?: () => void;
  onRetry?: () => void;
  onErrorDetail?: () => void;
  onSeekBack?: () => void;
  onSeekForward?: () => void;
  onSeekStart?: (value: number) => void;
  onSeekUpdate?: (value: number) => void;
  onSeekEnd?: (value: number) => void;
  onToggleHud?: () => void;
  onLongPress?: () => void;
  onLongPressEnd?: () => void;
  onPanStart?: (event: GestureEvent) => void;
  onPanMove?: (event: GestureEvent) => void;
  onPanEnd?: () => void;
  onPanCancel?: () => void;

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

  private canRetryLoad(): boolean {
    if (this.errorText) {
      return false;
    }
    if (this.opening) {
      return true;
    }
    return this.continuing() && this.stalled && !this.seeking;
  }

  private showCenterPlay(): boolean {
    return this.showHud && this.ready && !this.loading() && !this.errorText && !this.continuing();
  }

  private showBottom(): boolean {
    return this.showHud && this.ready && !this.errorText;
  }

  private cinemaHud(): boolean {
    return this.isFull || this.edgeHud;
  }

  private showTopFull(): boolean {
    return this.isFull && (this.showHud || !!this.errorText);
  }

  private timeText(): string {
    return `${FormatUtil.duration(this.currentTime)} / ${FormatUtil.duration(this.duration)}`;
  }

  private edge(base: number, inset: number): number {
    return Math.max(base, inset);
  }

  private handleCast(): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: '正在开发中' });
    } catch (_e) {}
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
        this.currentTime = value;
        if (mode === SliderChangeMode.Begin) {
          if (this.onSeekStart) {
            this.onSeekStart(value);
          }
        } else if (mode === SliderChangeMode.Moving) {
          if (this.onSeekUpdate) {
            this.onSeekUpdate(value);
          }
        } else if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
          if (this.onSeekEnd) {
            this.onSeekEnd(value);
          }
        }
      })
  }

  @Builder
  topBar() {
    if (this.showTopFull()) {
      Row() {
        PlayerBackBtn({ onTap: this.onBack })
          .zIndex(999)
        Text(this.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 4, right: 8 })
        this.skipBtns()
      }
      .width('100%')
      .padding({
        left: this.edge(8, this.leftInset),
        right: this.edge(8, this.rightInset),
        top: this.edge(8, this.topInset),
        bottom: 8
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
  skipBtns() {
    if (this.hasPrev || this.hasNext) {
      PlayerLabelBtn({
        src: $r('sys.symbol.backward_end_fill'),
        label: '上集',
        canTap: this.hasPrev,
        onTap: this.onPrev
      })
      PlayerLabelBtn({
        src: $r('sys.symbol.forward_end_fill'),
        label: '下集',
        canTap: this.hasNext,
        onTap: this.onNext
      })
    }
  }

  @Builder
  bottomBar() {
    if (this.showBottom()) {
      if (this.cinemaHud()) {
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
            PlayerChip({ label: this.scaleLabel, canTap: this.ready, onTap: this.onScale })
            PlayerChip({ label: this.speedLabel, canTap: this.ready, onTap: this.onSpeed })
            PlayerIconBtn({
              src: this.muted ? $r('sys.symbol.speaker_slash') : $r('sys.symbol.speaker_wave_2'),
              iconSize: 20,
              boxSize: 44,
              onTap: this.onMute
            })
            PlayerIconBtn({
              src: this.isFull ? $r('sys.symbol.arrow_down_right_and_arrow_up_left') :
                $r('sys.symbol.arrow_up_left_and_arrow_down_right'),
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
        PlayerTip({ message: this.speedLabel, kind: PlayerTipKind.SPEED })
      } else if (this.feedback) {
        PlayerTip({ message: this.feedback, kind: this.feedbackKind })
      }
      PlayerLoadingCard({
        visible: this.loading(),
        opening: this.opening,
        allowRetry: this.canRetryLoad(),
        onRetry: this.onRetry
      })
      if (this.showCenterPlay()) {
        this.centerPlay()
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
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

      Column() {
        this.centerGroup()
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .hitTestBehavior(HitTestMode.Transparent)
      .zIndex(10)

      Column() {
        this.topBar()
        Blank().hitTestBehavior(HitTestMode.None)
        this.bottomBar()
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .hitTestBehavior(HitTestMode.Transparent)
      .zIndex(11)

      if (!this.isFull) {
        Row() {
          if (this.showBack) {
            PlayerBackBtn({ onTap: this.onBack })
          }
          Blank().hitTestBehavior(HitTestMode.None)
          PlayerIconBtn({
            src: $r('sys.symbol.wireless_projection'),
            iconSize: 20,
            boxSize: 40,
            onTap: () => this.handleCast()
          })
        }
        .width('100%')
        .padding({
          left: this.edge(4, this.leftInset),
          right: this.edge(4, this.rightInset),
          top: this.edge(4, this.topInset)
        })
        .hitTestBehavior(HitTestMode.Transparent)
        .zIndex(999)
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}
