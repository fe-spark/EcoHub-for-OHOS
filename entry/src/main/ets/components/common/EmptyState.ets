import { AppTheme } from '../../common/constants/AppTheme';
import { AppIcon } from './AppIcon';

@Component
export struct EmptyState {
  @Prop title: string = '暂无内容';
  @Prop subtitle: string = '';
  @Prop icon: Resource = $r('sys.symbol.film');
  @Prop actionText: string = '';
  onAction?: () => void;
  @BuilderParam action: () => void = this.emptyAction;

  @Builder
  emptyAction() {}

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
          .lineHeight(19)
          .margin({ top: 8 })
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      if (this.actionText && this.onAction) {
        Button(this.actionText)
          .margin({ top: 16 })
          .backgroundColor(AppTheme.BG_CARD)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .onClick(() => {
            if (this.onAction) {
              this.onAction();
            }
          })
      }
      this.action()
    }
    .width('100%')
    .padding({ top: 24, bottom: 24, left: 24, right: 24 })
    .alignItems(HorizontalAlign.Center)
  }
}
