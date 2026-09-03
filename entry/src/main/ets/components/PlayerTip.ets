import { AppTheme } from '../common/constants/AppTheme';
import { PlayerSpeed } from '../common/utils/PlayerSpeed';
import { AppIcon } from './AppIcon';
import { PlayerTipKind } from '../common/utils/PlayerPan';
import { PlayerScale, PlayerScaleItem, PlayerScaleMode } from '../common/utils/PlayerScale';

@Component
export struct PlayerTip {
  @Prop message: string = '';
  @Prop kind: number = PlayerTipKind.NONE;

  private iconSrc(): Resource {
    if (this.kind === PlayerTipKind.SEEK_BACK) {
      return $r('sys.symbol.chevron_left');
    }
    if (this.kind === PlayerTipKind.SEEK_FWD) {
      return $r('sys.symbol.chevron_right');
    }
    if (this.kind === PlayerTipKind.BRIGHT) {
      return $r('sys.symbol.sun_max');
    }
    if (this.kind === PlayerTipKind.VOLUME) {
      return this.message === '0%' ? $r('sys.symbol.speaker_slash') : $r('sys.symbol.speaker_wave_2');
    }
    if (this.kind === PlayerTipKind.SCALE) {
      return $r('sys.symbol.arrow_up_left_and_arrow_down_right');
    }
    return $r('sys.symbol.play_fill');
  }

  @Builder
  speedIcons() {
    Row({ space: 1 }) {
      AppIcon({ src: $r('sys.symbol.play_fill'), iconSize: 15, color: '#FFFFFF' })
      AppIcon({ src: $r('sys.symbol.play_fill'), iconSize: 15, color: '#FFFFFF' })
    }
  }

  build() {
    Row({ space: 8 }) {
      if (this.kind === PlayerTipKind.SPEED) {
        this.speedIcons()
      } else if (this.kind !== PlayerTipKind.NONE) {
        AppIcon({ src: this.iconSrc(), iconSize: 18, color: 'rgba(255,255,255,0.9)' })
          .id(`${this.kind}_${this.message}`)
      }
      Text(this.message)
        .fontSize(this.kind === PlayerTipKind.SPEED ? 13 : 16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
    }
    .constraintSize({ minHeight: 38 })
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor('rgba(0,0,0,0.74)')
    .borderRadius(999)
    .shadow({
      radius: 14,
      color: 'rgba(0,0,0,0.22)',
      offsetX: 0,
      offsetY: 8
    })
    .hitTestBehavior(HitTestMode.None)
  }
}

@Component
export struct PlayerLoadingCard {
  private static readonly DEBOUNCE_DELAY_MS: number = 200;
  private static readonly MIN_DISPLAY_MS: number = 350;
  private static readonly SLOW_NETWORK_MS: number = 6000;
  private static readonly PROGRESS_SIZE: number = 20;
  private static readonly CARD_RADIUS: number = 16;
  private static readonly CARD_PADDING_H: number = 18;
  private static readonly CARD_PADDING_V: number = 14;

  @Prop @Watch('onVisibleChange') visible: boolean = false;
  @Prop @Watch('onAllowRetryChange') allowRetry: boolean = false;
  @Prop opening: boolean = false;
  onRetry?: () => void;

  @State private showCard: boolean = false;
  @State private slowNetwork: boolean = false;
  private showTimer: number = -1;
  private hideTimer: number = -1;
  private slowTimer: number = -1;
  private shownAt: number = 0;

  aboutToAppear(): void {
    this.syncGates();
  }

  aboutToDisappear(): void {
    this.clearAllTimers();
  }

  private clearShowTimer(): void {
    if (this.showTimer >= 0) {
      clearTimeout(this.showTimer);
      this.showTimer = -1;
    }
  }

  private clearHideTimer(): void {
    if (this.hideTimer >= 0) {
      clearTimeout(this.hideTimer);
      this.hideTimer = -1;
    }
  }

  private clearSlowTimer(): void {
    if (this.slowTimer >= 0) {
      clearTimeout(this.slowTimer);
      this.slowTimer = -1;
    }
  }

  private clearAllTimers(): void {
    this.clearShowTimer();
    this.clearHideTimer();
    this.clearSlowTimer();
  }

  private armSlowTimer(): void {
    if (this.slowNetwork || this.slowTimer >= 0) {
      return;
    }
    this.slowTimer = setTimeout(() => {
      this.slowTimer = -1;
      if (this.visible && this.allowRetry) {
        this.slowNetwork = true;
      }
    }, PlayerLoadingCard.SLOW_NETWORK_MS);
  }

  private hideRetry(): void {
    this.clearSlowTimer();
    this.slowNetwork = false;
  }

  private onVisibleChange(): void {
    this.syncGates();
  }

  private onAllowRetryChange(): void {
    this.syncGates();
  }

  private syncGates(): void {
    if (this.visible && this.allowRetry) {
      this.armSlowTimer();
    } else {
      this.hideRetry();
    }
    this.syncCardVisibility();
  }

  private syncCardVisibility(): void {
    if (this.visible) {
      this.clearHideTimer();
      if (this.showCard) {
        return;
      }
      const delay = this.opening ? 0 : PlayerLoadingCard.DEBOUNCE_DELAY_MS;
      if (delay === 0) {
        this.doShow();
        return;
      }
      this.clearShowTimer();
      this.showTimer = setTimeout(() => {
        this.showTimer = -1;
        this.doShow();
      }, delay);
      return;
    }
    this.clearShowTimer();
    if (!this.showCard) {
      return;
    }
    const elapsed = Date.now() - this.shownAt;
    if (elapsed >= PlayerLoadingCard.MIN_DISPLAY_MS) {
      this.showCard = false;
      return;
    }
    this.clearHideTimer();
    this.hideTimer = setTimeout(() => {
      this.hideTimer = -1;
      this.showCard = false;
    }, PlayerLoadingCard.MIN_DISPLAY_MS - elapsed);
  }

  private doShow(): void {
    this.showCard = true;
    this.shownAt = Date.now();
  }

  build() {
    if (this.showCard) {
      Column({ space: 8 }) {
        Row({ space: 12 }) {
          LoadingProgress()
            .width(PlayerLoadingCard.PROGRESS_SIZE)
            .height(PlayerLoadingCard.PROGRESS_SIZE)
            .color(AppTheme.TEXT_PRIMARY)
          Text(this.opening ? '正在打开...' : '加载中...')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT_PRIMARY)
        }
        if (this.slowNetwork) {
          Row({ space: 8 }) {
            Text('网络较慢')
              .fontSize(12)
              .fontColor(AppTheme.TEXT_SECONDARY)
            if (this.onRetry) {
              Text('点击重试')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ACCENT)
                .onClick(() => {
                  if (this.onRetry) {
                    this.onRetry();
                  }
                })
            }
          }
          .margin({ top: 2 })
        }
      }
      .padding({
        left: PlayerLoadingCard.CARD_PADDING_H,
        right: PlayerLoadingCard.CARD_PADDING_H,
        top: PlayerLoadingCard.CARD_PADDING_V,
        bottom: PlayerLoadingCard.CARD_PADDING_V
      })
      .backgroundColor('rgba(0,0,0,0.78)')
      .borderRadius(PlayerLoadingCard.CARD_RADIUS)
      .animation({ duration: 200, curve: Curve.EaseInOut })
    }
  }
}

@Component
export struct PlayerErrorPad {
  onRetry?: () => void;
  onErrorDetail?: () => void;

  build() {
    Column() {
      Text('播放异常')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
      Text('视频无法播放，请重试！')
        .fontSize(13)
        .fontColor('rgba(255,255,255,0.82)')
        .margin({ top: 8 })
      Row({ space: 10 }) {
        Text('重新播放')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .height(36)
          .padding({ left: 16, right: 16 })
          .backgroundColor(AppTheme.ACCENT)
          .borderRadius(18)
          .onClick(() => {
            if (this.onRetry) {
              this.onRetry();
            }
          })
        Text('查看详情')
          .fontSize(13)
          .fontColor('#FFFFFF')
          .height(36)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: 'rgba(255,255,255,0.16)' })
          .borderRadius(18)
          .onClick(() => {
            if (this.onErrorDetail) {
              this.onErrorDetail();
            }
          })
      }
      .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(20)
  }
}

@CustomDialog
export struct PlayerSpeedDialog {
  controller?: CustomDialogController
  speedLabel: string = '1.0x'
  onPickSpeed: (index: number) => void = (_index: number) => {}

  build() {
    Column() {
      Row() {
        Text('播放速度')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        Blank()
        Text(`当前 ${this.speedLabel}`)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.ACCENT)
      }
      .width('100%')
      Text('点击后立即生效')
        .fontSize(12)
        .fontColor('rgba(255,255,255,0.55)')
        .margin({ top: 6, bottom: 12 })
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(PlayerSpeed.labels(), (label: string, index: number) => {
          Text(label)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .width(80)
            .height(40)
            .textAlign(TextAlign.Center)
            .margin({ right: 8, bottom: 8 })
            .backgroundColor(this.speedLabel === label ? AppTheme.ACCENT : 'rgba(255,255,255,0.08)')
            .borderRadius(12)
            .onClick(() => {
              this.onPickSpeed(index)
              if (this.controller) {
                this.controller.close()
              }
            })
        }, (label: string) => `spd_${label}`)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 24 })
    .backgroundColor('#191B20')
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}

@CustomDialog
export struct PlayerScaleDialog {
  private static readonly ITEM_WIDTH: number = 96;
  private static readonly ITEM_HEIGHT: number = 48;
  private static readonly ITEM_SPACE: number = 2;
  private static readonly TITLE_SIZE: number = 16;
  private static readonly SUBTITLE_SIZE: number = 12;
  private static readonly LABEL_SIZE: number = 14;
  private static readonly DESC_SIZE: number = 11;
  private static readonly CURRENT_LABEL_SIZE: number = 13;
  private static readonly DIALOG_RADIUS_TOP: number = 20;
  private static readonly DIALOG_BG_COLOR: string = '#191B20';
  private static readonly DESC_COLOR_ACTIVE: string = 'rgba(255, 255, 255, 0.85)';
  private static readonly DESC_COLOR_INACTIVE: string = 'rgba(255, 255, 255, 0.45)';
  private static readonly ITEM_BG_INACTIVE: string = 'rgba(255, 255, 255, 0.08)';

  controller?: CustomDialogController
  scaleMode: number = PlayerScaleMode.FIT
  isPortrait: boolean = false
  onPickScale: (mode: number) => void = (_mode: number) => {}

  build() {
    Column() {
      Row() {
        Text('画面填充')
          .fontSize(PlayerScaleDialog.TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
        Blank()
        Text(`当前 ${PlayerScale.label(this.scaleMode, this.isPortrait)}`)
          .fontSize(PlayerScaleDialog.CURRENT_LABEL_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.ACCENT)
      }
      .width('100%')
      Text('全屏播放时画面适应与拉伸方式')
        .fontSize(PlayerScaleDialog.SUBTITLE_SIZE)
        .fontColor(AppTheme.TEXT_SECONDARY)
        .margin({ top: AppTheme.SPACE_XS, bottom: AppTheme.SPACE_MD })
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(PlayerScale.items(this.isPortrait), (item: PlayerScaleItem) => {
          Column({ space: PlayerScaleDialog.ITEM_SPACE }) {
            Text(item.label)
              .fontSize(PlayerScaleDialog.LABEL_SIZE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT_PRIMARY)
            Text(item.desc)
              .fontSize(PlayerScaleDialog.DESC_SIZE)
              .fontColor(this.scaleMode === item.mode ? PlayerScaleDialog.DESC_COLOR_ACTIVE : PlayerScaleDialog.DESC_COLOR_INACTIVE)
          }
          .width(PlayerScaleDialog.ITEM_WIDTH)
          .height(PlayerScaleDialog.ITEM_HEIGHT)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .margin({ right: AppTheme.SPACE_SM, bottom: AppTheme.SPACE_SM })
          .backgroundColor(this.scaleMode === item.mode ? AppTheme.ACCENT : PlayerScaleDialog.ITEM_BG_INACTIVE)
          .borderRadius(AppTheme.RADIUS_LG)
          .onClick(() => {
            this.onPickScale(item.mode);
            if (this.controller) {
              this.controller.close();
            }
          })
        }, (item: PlayerScaleItem) => `scale_${item.mode}_${item.label}_${this.scaleMode === item.mode ? '1' : '0'}`)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG, top: AppTheme.SPACE_LG, bottom: AppTheme.SPACE_XL })
    .backgroundColor(PlayerScaleDialog.DIALOG_BG_COLOR)
    .borderRadius({ topLeft: PlayerScaleDialog.DIALOG_RADIUS_TOP, topRight: PlayerScaleDialog.DIALOG_RADIUS_TOP })
  }
}