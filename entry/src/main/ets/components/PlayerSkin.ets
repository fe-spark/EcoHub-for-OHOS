import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { PlayerTipKind } from '../common/utils/PlayerPan';
import { AppIcon } from './AppIcon';
import { BackIcon } from './BackIcon';
import { PlayerGestureLayer } from './PlayerGesture';
import { PlayerErrorPad, PlayerLoadingCard, PlayerMuteBtn, PlayerSpeedSheet, PlayerTip } from './PlayerTip';

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
  iconBtn(src: Resource, size: number, glyphKey: string, onTap: () => void) {
    Row() {
      AppIcon({ src: src, iconSize: size, color: '#FFFFFF' })
        .key(glyphKey)
    }
    .key(glyphKey)
    .width(36)
    .height(36)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.Transparent)
    .hitTestBehavior(HitTestMode.Block)
    .onClick(() => onTap())
  }

  @Builder
  textChip(label: string, enabled: boolean, onTap: () => void) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(enabled ? '#FFFFFF' : 'rgba(255,255,255,0.45)')
      .height(32)
      .padding({ left: 10, right: 10 })
      .textAlign(TextAlign.Center)
      .backgroundColor('rgba(0,0,0,0.42)')
      .borderRadius(16)
      .border({ width: 1, color: 'rgba(255,255,255,0.14)' })
      .onClick(() => {
        if (enabled) {
          onTap();
        }
      })
  }

  @Builder
  sliderBar() {
    Slider({
      value: this.currentTime,
      min: 0,
      max: this.duration > 0 ? this.duration : 1,
      step: 0.2,
      style: SliderStyle.InSet
    })
      .width('100%')
      .height(16)
      .trackThickness(3)
      .blockSize({ width: 10, height: 10 })
      .blockColor(AppTheme.ACCENT)
      .trackColor('rgba(255,255,255,0.22)')
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
  circleBtn(src: Resource, size: number, iconSize: number, glyphKey: string, onTap: () => void, prominent: boolean) {
    Row() {
      AppIcon({ src: src, iconSize: iconSize, color: '#FFFFFF' })
        .key(glyphKey)
    }
    .key(glyphKey)
    .width(size)
    .height(size)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(prominent ? 'rgba(0,0,0,0.34)' : 'rgba(0,0,0,0.20)')
    .borderRadius(size / 2)
    .border({ width: 1, color: prominent ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.12)' })
    .hitTestBehavior(HitTestMode.Block)
    .onClick(() => onTap())
  }

  @Builder
  textCircleBtn(label: string, size: number, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
    }
    .width(size)
    .height(size)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('rgba(0,0,0,0.20)')
    .borderRadius(size / 2)
    .border({ width: 1, color: 'rgba(255,255,255,0.12)' })
    .hitTestBehavior(HitTestMode.Block)
    .onClick(() => onTap())
  }

  @Builder
  topBar() {
    if (this.showTopFull()) {
      Row({ space: 8 }) {
        Row() {
          BackIcon({ color: '#FFFFFF' })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          if (this.onBack) {
            this.onBack();
          }
        })
        Text(this.title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.hasPrev) {
          this.textChip('上集', true, () => {
            if (this.onPrev) {
              this.onPrev();
            }
          })
        }
        if (this.hasNext) {
          this.textChip('下集', true, () => {
            if (this.onNext) {
              this.onNext();
            }
          })
        }
        this.textChip(this.speedLabel, this.ready, () => {
          if (this.onSpeed) {
            this.onSpeed();
          }
        })
      }
      .width('100%')
      .height(52)
      .padding({
        left: this.edge(8, this.leftInset),
        right: this.edge(8, this.rightInset),
        top: this.edge(4, this.topInset)
      })
      .alignItems(VerticalAlign.Center)
      .hitTestBehavior(HitTestMode.Block)
      .linearGradient({
        angle: 180,
        colors: [['rgba(0,0,0,0.68)', 0], ['rgba(0,0,0,0.34)', 0.5], ['rgba(0,0,0,0)', 1]]
      })
    }
  }

  @Builder
  bottomBar() {
    if (this.showBottom()) {
      if (this.isFull) {
        Column({ space: 6 }) {
          this.sliderBar()
          Row() {
            if (this.continuing()) {
              this.iconBtn($r('sys.symbol.pause_fill'), 22, 'pause', () => {
                if (this.onPlay) {
                  this.onPlay();
                }
              })
            } else {
              this.iconBtn($r('sys.symbol.play_fill'), 22, 'play', () => {
                if (this.onPlay) {
                  this.onPlay();
                }
              })
            }
            Text(this.timeText())
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .margin({ left: 8 })
              .maxLines(1)
            Blank()
            PlayerMuteBtn({
              muted: this.muted,
              iconSize: 18,
              onMute: this.onMute
            })
            this.iconBtn($r('sys.symbol.arrow_down_right_and_arrow_up_left'), 18, 'exit_full', () => {
              if (this.onFull) {
                this.onFull();
              }
            })
          }
          .width('100%')
          .height(36)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .padding({
          left: this.edge(8, this.leftInset),
          right: this.edge(8, this.rightInset),
          bottom: this.edge(6, this.bottomInset),
          top: 4
        })
        .hitTestBehavior(HitTestMode.Block)
        .linearGradient({
          angle: 180,
          colors: [['rgba(0,0,0,0)', 0], ['rgba(0,0,0,0.82)', 1]]
        })
      } else {
        Row() {
          if (this.continuing()) {
            this.iconBtn($r('sys.symbol.pause_fill'), 20, 'pause', () => {
              if (this.onPlay) {
                this.onPlay();
              }
            })
          } else {
            this.iconBtn($r('sys.symbol.play_fill'), 20, 'play', () => {
              if (this.onPlay) {
                this.onPlay();
              }
            })
          }
          Column() {
            this.sliderBar()
          }
          .layoutWeight(1)
          .margin({ left: 4, right: 8 })
          Text(this.timeText())
            .fontSize(11)
            .fontColor('rgba(255,255,255,0.9)')
            .width(78)
            .maxLines(1)
            .textAlign(TextAlign.End)
          PlayerMuteBtn({
            muted: this.muted,
            iconSize: 16,
            onMute: this.onMute
          })
          this.iconBtn($r('sys.symbol.arrow_up_left_and_arrow_down_right'), 16, 'enter_full', () => {
            if (this.onFull) {
              this.onFull();
            }
          })
        }
        .width('100%')
        .height(40)
        .padding({ left: 4, right: 4 })
        .alignItems(VerticalAlign.Center)
        .hitTestBehavior(HitTestMode.Block)
        .linearGradient({
          angle: 180,
          colors: [['rgba(0,0,0,0)', 0], ['rgba(0,0,0,0.82)', 1]]
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
    }
  }

  @Builder
  centerPlay() {
    if (this.showCenterPlay()) {
      Row({ space: 24 }) {
        if (this.isFull) {
          this.textCircleBtn('-10', 52, () => {
            if (this.onSeekBack) {
              this.onSeekBack();
            }
          })
        }
        this.circleBtn(
          this.completed ? $r('sys.symbol.arrow_counterclockwise') : $r('sys.symbol.play_fill'),
          76, 42, this.completed ? 'replay' : 'cplay', () => {
            if (this.onPlay) {
              this.onPlay();
            }
          }, true)
        if (this.isFull) {
          this.textCircleBtn('+10', 52, () => {
            if (this.onSeekForward) {
              this.onSeekForward();
            }
          })
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
      .alignItems(HorizontalAlign.Start)
      .hitTestBehavior(HitTestMode.Transparent)

      if (!this.isFull && this.showBack) {
        Row() {
          BackIcon({ color: '#FFFFFF' })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Block)
        .position({ x: 4, y: 4 })
        .onClick(() => {
          if (this.onBack) {
            this.onBack();
          }
        })
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
    .hitTestBehavior(HitTestMode.Default)
  }
}
