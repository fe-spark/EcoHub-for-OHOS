import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from './AppIcon';

@Component
export struct ScrollFab {
  @Prop visible: boolean = false;
  @Prop busy: boolean = false;
  @Prop src: Resource = $r('sys.symbol.arrow_up');
  @Prop bottom: number = AppTheme.SPACE_LG;
  onClickFab: () => void = () => {};

  build() {
    Row() {
      if (this.busy) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(AppTheme.TEXT_PRIMARY)
      } else {
        AppIcon({
          src: this.src,
          iconSize: 20,
          color: AppTheme.TEXT_PRIMARY
        })
      }
    }
    .width(44)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.ACCENT)
    .borderRadius(22)
    .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.35)', offsetY: 4 })
    .margin({ right: AppTheme.SPACE_LG, bottom: this.bottom })
    .opacity(this.visible ? 1 : 0)
    .scale({ x: this.visible ? 1 : 0.72, y: this.visible ? 1 : 0.72 })
    .translate({ y: this.visible ? 0 : 12 })
    .animation({ duration: 220, curve: Curve.EaseOut })
    .hitTestBehavior(this.visible && !this.busy ? HitTestMode.Default : HitTestMode.None)
    .onClick(() => {
      if (this.visible && !this.busy) {
        this.onClickFab();
      }
    })
  }
}
