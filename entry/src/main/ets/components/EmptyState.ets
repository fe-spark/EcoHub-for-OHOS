import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from './AppIcon';

@Component
export struct EmptyState {
  @Prop title: string = '暂无内容';
  @Prop subtitle: string = '';
  @Prop icon: Resource = $r('sys.symbol.film');

  build() {
    Column() {
      AppIcon({ src: this.icon, iconSize: 40, color: AppTheme.TEXT_MUTED })
        .margin({ bottom: 16 })
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT_PRIMARY)
      if (this.subtitle) {
        Text(this.subtitle)
          .fontSize(13)
          .fontColor(AppTheme.TEXT_MUTED)
          .margin({ top: 8 })
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: 80, bottom: 80, left: 24, right: 24 })
    .alignItems(HorizontalAlign.Center)
  }
}
