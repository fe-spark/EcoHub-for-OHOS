import { AppTheme } from '../../common/constants/AppTheme';

@Component
export struct FloatingRefreshIndicator {
  @Prop pullDistance: number = 0;
  @Prop refreshing: boolean = false;
  @Prop topOffset: number = 0;
  @Prop triggerDistance: number = 46;

  build() {
    if (this.pullDistance > 0 || this.refreshing) {
      Row() {
        LoadingProgress()
          .width(22)
          .height(22)
          .color(AppTheme.ACCENT)
      }
      .width(38)
      .height(38)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('rgba(26, 28, 36, 0.75)')
      .backdropBlur(25)
      .borderRadius(19)
      .border({ width: 0.8, color: 'rgba(255, 255, 255, 0.12)' })
      .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.38)', offsetY: 2 })
      .position({
        x: '50%',
        y: this.topOffset + this.pullDistance - 38
      })
      .markAnchor({ x: '50%', y: 0 })
      .opacity(Math.max(0, Math.min(1.0, (this.pullDistance - 4) / 16)))
      .scale({
        x: Math.min(1.0, 0.5 + 0.5 * (this.pullDistance / this.triggerDistance)),
        y: Math.min(1.0, 0.5 + 0.5 * (this.pullDistance / this.triggerDistance))
      })
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }
}
