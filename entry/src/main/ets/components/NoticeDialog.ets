import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from './AppIcon';

@Component
export struct NoticeDialog {
  @Prop title: string = '站点公告';
  @Prop content: string = '';
  onClose: () => void = () => {};

  private handleConfirm(): void {
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
          this.handleConfirm();
        })

      // 居中公告弹窗卡片
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
              src: $r('sys.symbol.bell_fill'),
              iconSize: 16,
              color: AppTheme.ACCENT
            })
          }
          .margin({ right: AppTheme.SPACE_SM })

          Text(this.title || '站点公告')
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
            this.handleConfirm();
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: AppTheme.SPACE_MD })

        // 公告正文（可滚动容器）
        Scroll() {
          Column() {
            Text(this.content)
              .fontSize(14)
              .lineHeight(22)
              .fontColor(AppTheme.TEXT_SECONDARY)
              .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .constraintSize({ maxHeight: 260 })
        .width('100%')
        .padding(AppTheme.SPACE_MD)
        .backgroundColor(AppTheme.BG_CARD)
        .borderRadius(AppTheme.RADIUS_MD)
        .margin({ bottom: AppTheme.SPACE_LG })

        // 底部确认主按钮
        Button('我知道了')
          .width('100%')
          .height(42)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .backgroundColor(AppTheme.ACCENT)
          .borderRadius(AppTheme.RADIUS_PILL)
          .onClick(() => {
            this.handleConfirm();
          })
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
