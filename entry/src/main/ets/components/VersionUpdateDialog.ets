import { curves } from '@kit.ArkUI';
import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from './AppIcon';
import { AppUpdateInfo } from '../common/utils/AppVersionUtil';
import { NavUtil } from '../common/utils/NavUtil';
import { WindowBar } from '../common/utils/WindowBar';
import { common } from '@kit.AbilityKit';

@Component
export struct VersionUpdateDialog {
  @Prop updateInfo: AppUpdateInfo = {
    currentVersion: '',
    latestVersion: '',
    hasUpdate: false,
    releaseName: '',
    releaseNotes: '',
    releaseUrl: '',
    downloadUrl: ''
  };
  onClose: () => void = () => {};

  @State private maskOpacity: number = 0;
  @State private cardScale: number = 0.72;
  @State private cardOpacity: number = 0;
  private isClosing: boolean = false;

  @StorageLink('SAFE_INSET_TOP') private topInset: number = 0;
  @StorageLink('SAFE_INSET_BOTTOM') private bottomInset: number = 16;
  @StorageLink('SAFE_INSET_LEFT') private leftInset: number = 0;
  @StorageLink('SAFE_INSET_RIGHT') private rightInset: number = 0;
  @StorageLink('WINDOW_WIDTH') private windowWidth: number = 360;
  @StorageLink('WINDOW_HEIGHT') private windowHeight: number = 640;

  private isLandscape(): boolean {
    return this.windowWidth > this.windowHeight && this.windowHeight > 0;
  }

  aboutToAppear(): void {
    WindowBar.setImmersiveOverlay(true);
    setTimeout(() => {
      this.maskOpacity = 1;
      this.cardScale = 1;
      this.cardOpacity = 1;
    }, 16);
  }

  aboutToDisappear(): void {
    WindowBar.setImmersiveOverlay(false);
  }

  private handleClose(): void {
    if (this.isClosing) {
      return;
    }
    this.isClosing = true;
    this.maskOpacity = 0;
    this.cardScale = 0.85;
    this.cardOpacity = 0;
    setTimeout(() => {
      this.onClose();
    }, 200);
  }

  private handleUpdate(): void {
    const url = this.updateInfo.downloadUrl || this.updateInfo.releaseUrl;
    if (url) {
      NavUtil.openBrowser(this.getUIContext().getHostContext() as common.UIAbilityContext, url);
    }
    this.handleClose();
  }

  private notesMaxHeight(): number {
    const reserved = this.isLandscape() ? 200 : 280;
    const available = this.windowHeight - this.topInset - this.bottomInset - reserved;
    return Math.max(60, Math.min(this.isLandscape() ? 140 : 240, available));
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 全屏遮罩：不吃安全区 padding，避免底部露出导航条/底栏形成第二层蒙版
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.72)')
        .opacity(this.maskOpacity)
        .animation({ duration: 200, curve: Curve.EaseOut })
        .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
        .onClick(() => {
          this.handleClose();
        })

      // 卡片放在安全区内居中，横屏避开刘海与手势条
      Column() {
        Column() {
          Row() {
            Stack({ alignContent: Alignment.Center }) {
              Column()
                .width(32)
                .height(32)
                .borderRadius(16)
                .backgroundColor(AppTheme.ACCENT_SOFT)
              AppIcon({
                src: $r('sys.symbol.arrow_counterclockwise'),
                iconSize: 16,
                color: AppTheme.ACCENT
              })
            }
            .margin({ right: AppTheme.SPACE_SM })

            Text('发现新版本')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT_PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            Row() {
              AppIcon({
                src: $r('sys.symbol.xmark'),
                iconSize: 14,
                color: AppTheme.TEXT_MUTED
              })
            }
            .width(28)
            .height(28)
            .justifyContent(FlexAlign.Center)
            .borderRadius(14)
            .onClick(() => {
              this.handleClose();
            })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: this.isLandscape() ? 6 : AppTheme.SPACE_MD })

          Row() {
            Text(`当前 v${this.updateInfo.currentVersion}`)
              .fontSize(12)
              .fontColor(AppTheme.TEXT_MUTED)

            AppIcon({
              src: $r('sys.symbol.chevron_right'),
              iconSize: 10,
              color: AppTheme.TEXT_MUTED
            })
            .margin({ left: 4, right: 4 })

            Text(`最新 v${this.updateInfo.latestVersion}`)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ACCENT)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: this.isLandscape() ? 6 : AppTheme.SPACE_SM })

          Scroll() {
            Column() {
              if (this.updateInfo.releaseName && this.updateInfo.releaseName !== `v${this.updateInfo.latestVersion}`) {
                Text(this.updateInfo.releaseName)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.TEXT_PRIMARY)
                  .margin({ bottom: AppTheme.SPACE_XS })
              }
              Text(this.updateInfo.releaseNotes ? this.updateInfo.releaseNotes.trim() : '包含稳定性优化与功能增强。')
                .fontSize(13)
                .lineHeight(20)
                .fontColor(AppTheme.TEXT_SECONDARY)
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)
          .constraintSize({ minHeight: 60, maxHeight: this.notesMaxHeight() })
          .width('100%')
          .padding(AppTheme.SPACE_MD)
          .backgroundColor(AppTheme.BG_CARD)
          .borderRadius(AppTheme.RADIUS_MD)
          .margin({ bottom: this.isLandscape() ? 6 : AppTheme.SPACE_MD })

          Row() {
            AppIcon({
              src: $r('sys.symbol.info_circle'),
              iconSize: 14,
              color: AppTheme.ACCENT
            })
            Text('下载完成后，需进行侧载安装')
              .fontSize(11)
              .lineHeight(16)
              .fontColor(AppTheme.TEXT_SECONDARY)
              .margin({ left: 6 })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: AppTheme.SPACE_MD, right: AppTheme.SPACE_MD, top: 6, bottom: 6 })
          .backgroundColor(AppTheme.ACCENT_SOFT)
          .borderRadius(AppTheme.RADIUS_MD)
          .margin({ bottom: this.isLandscape() ? 8 : AppTheme.SPACE_MD })
          .alignItems(VerticalAlign.Center)

          if (this.isLandscape()) {
            Row({ space: 10 }) {
              Button('稍后再说')
                .layoutWeight(1)
                .height(36)
                .fontSize(13)
                .fontColor(AppTheme.TEXT_MUTED)
                .backgroundColor('rgba(255, 255, 255, 0.08)')
                .borderRadius(AppTheme.RADIUS_PILL)
                .onClick(() => {
                  this.handleClose();
                })

              Button('前往更新')
                .layoutWeight(1)
                .height(36)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.TEXT_PRIMARY)
                .backgroundColor(AppTheme.ACCENT)
                .borderRadius(AppTheme.RADIUS_PILL)
                .onClick(() => {
                  this.handleUpdate();
                })
            }
            .width('100%')
          } else {
            Column({ space: 8 }) {
              Button('前往更新')
                .width('100%')
                .height(42)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.TEXT_PRIMARY)
                .backgroundColor(AppTheme.ACCENT)
                .borderRadius(AppTheme.RADIUS_PILL)
                .onClick(() => {
                  this.handleUpdate();
                })

              Button('稍后再说')
                .width('100%')
                .height(36)
                .fontSize(13)
                .fontColor(AppTheme.TEXT_MUTED)
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  this.handleClose();
                })
            }
            .width('100%')
          }
        }
        .width('86%')
        .constraintSize({ maxWidth: 420, maxHeight: '100%' })
        .padding(this.isLandscape() ? 12 : AppTheme.SPACE_LG)
        .backgroundColor(AppTheme.BG_ELEVATED)
        .borderRadius(AppTheme.RADIUS_LG)
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.08)' })
        .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.5)', offsetY: 8 })
        .scale({ x: this.cardScale, y: this.cardScale })
        .opacity(this.cardOpacity)
        .animation({
          curve: curves.springMotion(0.38, 0.65, 0)
        })
        .onClick(() => {})
      }
      .width('100%')
      .height('100%')
      .padding({
        top: Math.max(8, this.topInset),
        bottom: Math.max(8, this.bottomInset),
        left: Math.max(16, this.leftInset),
        right: Math.max(16, this.rightInset)
      })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT],
      [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
    .zIndex(999)
  }
}
