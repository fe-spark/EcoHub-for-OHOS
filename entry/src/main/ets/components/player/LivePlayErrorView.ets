import { AppTheme } from '../../common/constants/AppTheme';
import { NavUtil } from '../../common/utils/NavUtil';
import { BackIcon } from '../common/BackIcon';
import { AppIcon } from '../common/AppIcon';

@Component
export struct LivePlayErrorView {
  @Prop filmName: string = '';
  @Prop errorText: string = '';
  @Prop isFavorite: boolean = false;
  onBack?: () => void;
  onRetry?: () => void;
  onRemoveFavorite?: () => void;

  private searchKeyword(): string {
    return this.filmName ? this.filmName.trim() : '';
  }

  private searchButtonText(): string {
    const kw = this.searchKeyword();
    return kw.length > 0 ? `全网搜索「${kw}」` : '全网重新搜索';
  }

  build() {
    Column() {
      // 顶部返回导航栏
      Row() {
        BackIcon({ color: AppTheme.TEXT_PRIMARY })
          .onClick(() => {
            if (this.onBack) {
              this.onBack();
            } else {
              try {
                this.getUIContext().getRouter().back();
              } catch (_e) {}
            }
          })
        Text('现场播放')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(48)
      .padding({ left: 12, right: 16 })
      .alignItems(VerticalAlign.Center)

      // 错误信息与操作引导
      Scroll() {
        Column() {
          Stack() {
            AppIcon({
              src: $r('sys.symbol.play_circle'),
              iconSize: 36,
              color: AppTheme.ACCENT
            })
          }
          .width(72)
          .height(72)
          .borderRadius(36)
          .backgroundColor(AppTheme.ACCENT_SOFT)
          .alignContent(Alignment.Center)
          .margin({ bottom: 16 })

          Text('采集源已失效或下线')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .margin({ bottom: 8 })
            .textAlign(TextAlign.Center)

          Text(this.errorText ? `错误原因：${this.errorText}\n该采集源可能已被管理员下线或源站响应超时，建议全网重搜其他片源。` : '该采集源可能已被管理员下线或源站响应超时，建议全网重搜其他片源。')
            .fontSize(13)
            .lineHeight(20)
            .fontColor(AppTheme.TEXT_SECONDARY)
            .textAlign(TextAlign.Center)
            .margin({ bottom: 24 })

          // 全网搜索按钮
          Button(this.searchButtonText())
            .width('100%')
            .height(44)
            .backgroundColor(AppTheme.ACCENT)
            .fontColor(Color.White)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .borderRadius(AppTheme.RADIUS_LG)
            .margin({ bottom: 12 })
            .onClick(() => {
              NavUtil.openSearch(this.searchKeyword(), this.getUIContext());
            })

          // 移出收藏按钮（仅已收藏时展示）
          if (this.isFavorite) {
            Button('移出收藏')
              .width('100%')
              .height(44)
              .backgroundColor(AppTheme.DANGER_SOFT)
              .fontColor(AppTheme.DANGER)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .borderRadius(AppTheme.RADIUS_LG)
              .border({ width: 1, color: 'rgba(255, 77, 79, 0.3)' })
              .margin({ bottom: 12 })
              .onClick(() => {
                if (this.onRemoveFavorite) {
                  this.onRemoveFavorite();
                }
              })
          }

          // 重新尝试按钮
          Row() {
            AppIcon({
              src: $r('sys.symbol.arrow_counterclockwise'),
              iconSize: 14,
              color: AppTheme.TEXT_MUTED
            })
            Text('重新尝试')
              .fontSize(13)
              .fontColor(AppTheme.TEXT_MUTED)
              .margin({ left: 4 })
          }
          .padding({ top: 8, bottom: 8, left: 16, right: 16 })
          .onClick(() => {
            if (this.onRetry) {
              this.onRetry();
            }
          })
        }
        .width('100%')
        .constraintSize({ maxWidth: 420 })
        .padding({ left: 24, right: 24, top: 40, bottom: 40 })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .height('100%')
  }
}
