import router from '@ohos.router';
import { AppTheme } from '../common/constants/AppTheme';
import { BackIcon } from './BackIcon';

@Component
export struct PageHeader {
  @Prop title: string = '';
  @Prop showBack: boolean = true;
  @Prop rightText: string = '';
  @Prop rightTextColor: string = AppTheme.ACCENT;
  onRight?: () => void;

  build() {
    Row() {
      if (this.showBack) {
        BackIcon({ color: AppTheme.TEXT_PRIMARY })
          .onClick(() => {
            router.back();
          })
      }

      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      if (this.rightText) {
        Text(this.rightText)
          .fontSize(13)
          .fontColor(this.rightTextColor)
          .onClick(() => {
            if (this.onRight) {
              this.onRight();
            }
          })
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 16 })
    .alignItems(VerticalAlign.Center)
  }
}
