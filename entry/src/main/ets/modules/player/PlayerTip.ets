
import { AppTheme } from '../../common/constants/AppTheme';
import { PlayerSpeed } from './PlayerSpeed';
import { AppIcon } from '../../components/common/AppIcon';
import { PlayerTipKind } from './PlayerPan';
import { PlayerScale, PlayerScaleItem, PlayerScaleMode } from './PlayerScale';

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

  @Prop @Watch('onReloadTokenChange') reloadToken: number = 0;
  @Prop @Watch('onVisibleChange') visible: boolean = false;
  @Prop @Watch('onAllowRetryChange') allowRetry: boolean = false;
  @Prop @Watch('onOpeningChange') opening: boolean = false;
  @Prop seeking: boolean = false;
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

  private onReloadTokenChange(): void {
    this.hideRetry();
    this.clearAllTimers();
    this.showCard = false;
    this.shownAt = 0;
    this.syncGates();
  }

  private onOpeningChange(): void {
    this.hideRetry();
    this.clearAllTimers();
    this.showCard = false;
    this.shownAt = 0;
    this.syncGates();
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

  private handleRetry(): void {
    if (!this.slowNetwork) {
      return;
    }
    this.hideRetry();
    if (this.visible && this.allowRetry) {
      this.armSlowTimer();
    }
    if (this.onRetry) {
      this.onRetry();
    }
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
      const delay = (this.opening || this.seeking) ? 0 : PlayerLoadingCard.DEBOUNCE_DELAY_MS;
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
          Text('加载中...')
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
                  this.handleRetry();
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
      Column() {
        Text('播放异常')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
        Text('视频无法播放，请重试或切换其他播放源')
          .fontSize(13)
          .fontColor(AppTheme.TEXT_SECONDARY)
          .margin({ top: 6 })
        Row({ space: 12 }) {
          Text('重新播放')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .height(36)
            .padding({ left: 18, right: 18 })
            .backgroundColor(AppTheme.ACCENT)
            .borderRadius(18)
            .onClick(() => {
              if (this.onRetry) {
                this.onRetry();
              }
            })
          Text('查看详情')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .height(36)
            .padding({ left: 18, right: 18 })
            .backgroundColor('rgba(255, 255, 255, 0.12)')
            .border({ width: 1, color: 'rgba(255, 255, 255, 0.22)' })
            .borderRadius(18)
            .onClick(() => {
              if (this.onErrorDetail) {
                this.onErrorDetail();
              }
            })
        }
        .margin({ top: 14 })
      }
      .padding({ left: 24, right: 24, top: 18, bottom: 18 })
      .backgroundColor('rgba(20, 22, 26, 0.88)')
      .borderRadius(16)
      .border({ width: 0.5, color: 'rgba(255, 255, 255, 0.12)' })
      .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.5)', offsetX: 0, offsetY: 8 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0, 0, 0, 0.68)')
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
  @StorageLink('SAFE_INSET_BOTTOM') private bottomInset: number = 16;
  @StorageLink('SAFE_INSET_RIGHT') private rightInset: number = 0;
  @StorageLink('SAFE_INSET_TOP') private topInset: number = 0;
  @StorageLink('WINDOW_WIDTH') private windowWidth: number = 360;
  @StorageLink('WINDOW_HEIGHT') private windowHeight: number = 640;

  private isLandscape(): boolean {
    return this.windowWidth > this.windowHeight && this.windowHeight > 0;
  }

  build() {
    if (this.isLandscape()) {
      // 横屏/全屏：移动端最流行的右侧浮层面板 (Right Drawer)
      Column() {
        Row() {
          Text('播放速度')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT_PRIMARY)
          Blank()
          Row() {
            Text(this.speedLabel)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ACCENT)
          }
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(AppTheme.ACCENT_SOFT)
          .borderRadius(AppTheme.RADIUS_PILL)
        }
        .width('100%')
        .padding({ bottom: 16 })

        List({ space: 6 }) {
          ForEach(PlayerSpeed.labels(), (label: string, index: number) => {
            ListItem() {
              Row() {
                Text(label === '1.0x' ? '1.0x (正常)' : label)
                  .fontSize(14)
                  .fontWeight(this.speedLabel === label ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.speedLabel === label ? AppTheme.ACCENT : 'rgba(255, 255, 255, 0.90)')
                Blank()
                if (this.speedLabel === label) {
                  SymbolGlyph($r('sys.symbol.checkmark'))
                    .fontSize(16)
                    .fontColor([AppTheme.ACCENT])
                    .fontWeight(FontWeight.Bold)
                }
              }
              .width('100%')
              .height(44)
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.speedLabel === label ? 'rgba(250, 140, 22, 0.12)' : 'rgba(255, 255, 255, 0.05)')
              .borderRadius(AppTheme.RADIUS_MD)
              .border({
                width: 1,
                color: this.speedLabel === label ? 'rgba(250, 140, 22, 0.36)' : 'rgba(255, 255, 255, 0.06)'
              })
              .onClick(() => {
                this.onPickSpeed(index);
                if (this.controller) {
                  this.controller.close();
                }
              })
            }
          }, (label: string) => `spd_l_${label}`)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width(280)
      .height('100%')
      .padding({
        top: Math.max(16, this.topInset + 12),
        bottom: Math.max(16, this.bottomInset + 12),
        left: 20,
        right: Math.max(20, this.rightInset + 12)
      })
      .backgroundColor('rgba(20, 22, 28, 0.96)')
      .borderRadius({ topLeft: 16, bottomLeft: 16 })
      .border({ width: { left: 0.5 }, color: 'rgba(255, 255, 255, 0.10)' })
    } else {
      // 竖屏/半屏：移动端标准的底部平滑抽屉 (Bottom Sheet)
      Column() {
        Row()
          .width(36)
          .height(4)
          .borderRadius(2)
          .backgroundColor('rgba(255, 255, 255, 0.22)')
          .margin({ top: 8, bottom: 14 })

        Row() {
          Text('播放速度')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT_PRIMARY)
          Blank()
          Row() {
            Text(`当前 ${this.speedLabel}`)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ACCENT)
          }
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(AppTheme.ACCENT_SOFT)
          .borderRadius(AppTheme.RADIUS_PILL)
        }
        .width('100%')
        .margin({ bottom: 16 })

        GridRow({ columns: 4, gutter: { x: 8, y: 8 } }) {
          ForEach(PlayerSpeed.labels(), (label: string, index: number) => {
            GridCol() {
              Row() {
                Text(label)
                  .fontSize(14)
                  .fontWeight(this.speedLabel === label ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.speedLabel === label ? '#FFFFFF' : AppTheme.TEXT_PRIMARY)
              }
              .width('100%')
              .height(40)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(this.speedLabel === label ? AppTheme.ACCENT : 'rgba(255, 255, 255, 0.07)')
              .borderRadius(AppTheme.RADIUS_MD)
              .border({
                width: 1,
                color: this.speedLabel === label ? AppTheme.ACCENT : 'rgba(255, 255, 255, 0.08)'
              })
              .onClick(() => {
                this.onPickSpeed(index);
                if (this.controller) {
                  this.controller.close();
                }
              })
            }
          }, (label: string) => `spd_p_${label}`)
        }
        .width('100%')
      }
      .width('100%')
      .padding({
        left: 20,
        right: 20,
        bottom: Math.max(24, this.bottomInset + 12)
      })
      .backgroundColor('#1A1C23')
      .borderRadius({ topLeft: 24, topRight: 24 })
      .border({ width: { top: 0.5 }, color: 'rgba(255, 255, 255, 0.10)' })
    }
  }
}

@CustomDialog
export struct PlayerScaleDialog {
  controller?: CustomDialogController
  scaleMode: number = PlayerScaleMode.FIT
  isPortrait: boolean = false
  onPickScale: (mode: number) => void = (_mode: number) => {}
  @StorageLink('SAFE_INSET_BOTTOM') private bottomInset: number = 16;
  @StorageLink('SAFE_INSET_RIGHT') private rightInset: number = 0;
  @StorageLink('SAFE_INSET_TOP') private topInset: number = 0;
  @StorageLink('WINDOW_WIDTH') private windowWidth: number = 360;
  @StorageLink('WINDOW_HEIGHT') private windowHeight: number = 640;

  private isLandscape(): boolean {
    return this.windowWidth > this.windowHeight && this.windowHeight > 0;
  }

  build() {
    if (this.isLandscape()) {
      // 横屏/全屏：移动端最流行的右侧浮层面板 (Right Drawer)
      Column() {
        Row() {
          Text('画面填充')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT_PRIMARY)
          Blank()
          Row() {
            Text(PlayerScale.label(this.scaleMode, this.isPortrait))
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ACCENT)
          }
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(AppTheme.ACCENT_SOFT)
          .borderRadius(AppTheme.RADIUS_PILL)
        }
        .width('100%')
        .padding({ bottom: 16 })

        List({ space: 10 }) {
          ForEach(PlayerScale.items(this.isPortrait), (item: PlayerScaleItem) => {
            ListItem() {
              Row() {
                Column({ space: 3 }) {
                  Text(item.label)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.scaleMode === item.mode ? AppTheme.ACCENT : AppTheme.TEXT_PRIMARY)
                  Text(item.desc)
                    .fontSize(11)
                    .fontColor(this.scaleMode === item.mode ? 'rgba(250, 140, 22, 0.85)' : AppTheme.TEXT_MUTED)
                }
                .alignItems(HorizontalAlign.Start)

                Blank()
                if (this.scaleMode === item.mode) {
                  SymbolGlyph($r('sys.symbol.checkmark'))
                    .fontSize(16)
                    .fontColor([AppTheme.ACCENT])
                    .fontWeight(FontWeight.Bold)
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .backgroundColor(this.scaleMode === item.mode ? 'rgba(250, 140, 22, 0.12)' : 'rgba(255, 255, 255, 0.05)')
              .borderRadius(AppTheme.RADIUS_MD)
              .border({
                width: 1,
                color: this.scaleMode === item.mode ? 'rgba(250, 140, 22, 0.36)' : 'rgba(255, 255, 255, 0.06)'
              })
              .onClick(() => {
                this.onPickScale(item.mode);
                if (this.controller) {
                  this.controller.close();
                }
              })
            }
          }, (item: PlayerScaleItem) => `scale_l_${item.mode}`)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width(280)
      .height('100%')
      .padding({
        top: Math.max(16, this.topInset + 12),
        bottom: Math.max(16, this.bottomInset + 12),
        left: 20,
        right: Math.max(20, this.rightInset + 12)
      })
      .backgroundColor('rgba(20, 22, 28, 0.96)')
      .borderRadius({ topLeft: 16, bottomLeft: 16 })
      .border({ width: { left: 0.5 }, color: 'rgba(255, 255, 255, 0.10)' })
    } else {
      // 竖屏/半屏：移动端标准的底部平滑抽屉 (Bottom Sheet)
      Column() {
        Row()
          .width(36)
          .height(4)
          .borderRadius(2)
          .backgroundColor('rgba(255, 255, 255, 0.22)')
          .margin({ top: 8, bottom: 14 })

        Row() {
          Text('画面填充')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT_PRIMARY)
          Blank()
          Row() {
            Text(`当前 ${PlayerScale.label(this.scaleMode, this.isPortrait)}`)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ACCENT)
          }
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(AppTheme.ACCENT_SOFT)
          .borderRadius(AppTheme.RADIUS_PILL)
        }
        .width('100%')
        .margin({ bottom: 16 })

        Row({ space: 10 }) {
          ForEach(PlayerScale.items(this.isPortrait), (item: PlayerScaleItem) => {
            Column({ space: 4 }) {
              Text(item.label)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.scaleMode === item.mode ? AppTheme.ACCENT : AppTheme.TEXT_PRIMARY)
              Text(item.desc)
                .fontSize(11)
                .fontColor(this.scaleMode === item.mode ? 'rgba(250, 140, 22, 0.85)' : AppTheme.TEXT_MUTED)
            }
            .layoutWeight(1)
            .height(56)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor(this.scaleMode === item.mode ? AppTheme.ACCENT_SOFT : 'rgba(255, 255, 255, 0.07)')
            .borderRadius(AppTheme.RADIUS_MD)
            .border({
              width: 1,
              color: this.scaleMode === item.mode ? AppTheme.ACCENT : 'rgba(255, 255, 255, 0.08)'
            })
            .onClick(() => {
              this.onPickScale(item.mode);
              if (this.controller) {
                this.controller.close();
              }
            })
          }, (item: PlayerScaleItem) => `scale_p_${item.mode}`)
        }
        .width('100%')
      }
      .width('100%')
      .padding({
        left: 20,
        right: 20,
        bottom: Math.max(24, this.bottomInset + 12)
      })
      .backgroundColor('#1A1C23')
      .borderRadius({ topLeft: 24, topRight: 24 })
      .border({ width: { top: 0.5 }, color: 'rgba(255, 255, 255, 0.10)' })
    }
  }
}