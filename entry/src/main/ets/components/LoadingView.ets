import { AppTheme } from '../common/constants/AppTheme';

@Component
export struct LoadingView {
  @Prop label: string = '加载中...';

  build() {
    Column() {
      LoadingProgress()
        .width(36)
        .height(36)
        .color(AppTheme.ACCENT)
      Text(this.label)
        .fontSize(13)
        .fontColor(AppTheme.TEXT_SECONDARY)
        .margin({ top: 12 })
    }
    .width('100%')
    .padding({ top: 80, bottom: 80 })
    .alignItems(HorizontalAlign.Center)
  }
}
