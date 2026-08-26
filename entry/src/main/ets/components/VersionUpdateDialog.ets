import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from './AppIcon';
import { AppUpdateInfo } from '../common/utils/AppVersionUtil';
import { NavUtil } from '../common/utils/NavUtil';
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

  private handleUpdate(): void {
    const url = this.updateInfo.downloadUrl || this.updateInfo.releaseUrl;
    if (url) {
      NavUtil.openBrowser(getContext(this) as common.UIAbilityContext, url);
    }
    this.onClose();
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 半透明黑色遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.72)')
        .onClick(() => {
          this.onClose();
        })

      // 居中卡片
      Column() {
        // 头部：图标 + 标题 + 关闭小叉
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
            this.onClose();
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: AppTheme.SPACE_MD })

        // 版本号信息对比胶囊
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
        .margin({ bottom: AppTheme.SPACE_SM })

        // 更新日志（可滚动容器）
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
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .constraintSize({ maxHeight: 240 })
        .width('100%')
        .padding(AppTheme.SPACE_MD)
        .backgroundColor(AppTheme.BG_CARD)
        .borderRadius(AppTheme.RADIUS_MD)
        .margin({ bottom: AppTheme.SPACE_LG })

        // 底部操作区：主按钮「前往更新」+ 次按钮「稍后再说」
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
              this.onClose();
            })
        }
        .width('100%')
      }
      .width('86%')
      .constraintSize({ maxWidth: 360 })
      .padding(AppTheme.SPACE_LG)
      .backgroundColor(AppTheme.BG_ELEVATED)
      .borderRadius(AppTheme.RADIUS_LG)
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.08)' })
      .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.5)', offsetY: 8 })
      .onClick(() => {}) // 阻止点击卡片内部冒泡关闭
    }
    .width('100%')
    .height('100%')
    .zIndex(999)
  }
}
