import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from './AppIcon';
import { EmptyState } from './EmptyState';

@Component
export struct SearchSuggestPane {
  @Prop searchHistory: string[] = [];
  @Prop hotKeywords: string[] = [];
  onSelectKeyword: (keyword: string) => void = () => {};
  onClearHistory: () => void = () => {};
  onRemoveHistory: (item: string) => void = () => {};

  build() {
    Scroll() {
      Column() {
        if (this.searchHistory.length > 0) {
          Column() {
            Row() {
              Text('搜索历史')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT_PRIMARY)

              Row() {
                AppIcon({
                  src: $r('sys.symbol.trash'),
                  iconSize: 14,
                  color: AppTheme.TEXT_MUTED
                })
                Text('清空')
                  .fontSize(12)
                  .fontColor(AppTheme.TEXT_MUTED)
                  .margin({ left: 4 })
              }
              .onClick(() => {
                this.onClearHistory();
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .padding({ left: 16, right: 16, top: 8, bottom: 12 })

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.searchHistory, (item: string) => {
                Row() {
                  Row() {
                    Text(item)
                      .fontSize(13)
                      .fontColor(AppTheme.TEXT_SECONDARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .constraintSize({ maxWidth: 200 })
                  }
                  .padding({ left: 12, right: 4, top: 6, bottom: 6 })
                  .onClick(() => {
                    this.onSelectKeyword(item);
                  })

                  Row() {
                    AppIcon({
                      src: $r('sys.symbol.xmark'),
                      iconSize: 10,
                      color: AppTheme.TEXT_MUTED
                    })
                  }
                  .width(22)
                  .height(28)
                  .justifyContent(FlexAlign.Center)
                  .padding({ right: 6 })
                  .onClick(() => {
                    this.onRemoveHistory(item);
                  })
                }
                .margin({ right: 8, bottom: 8 })
                .backgroundColor(AppTheme.BG_CARD)
                .borderRadius(AppTheme.RADIUS_PILL)
              }, (item: string) => item)
            }
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 16 })
        }

        if (this.hotKeywords.length > 0) {
          Column() {
            Row() {
              AppIcon({
                src: $r('sys.symbol.flame_fill'),
                iconSize: 15,
                color: AppTheme.ACCENT
              })
              Text('热门搜索')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT_PRIMARY)
                .margin({ left: 6 })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 12 })

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.hotKeywords, (item: string, index: number) => {
                Row() {
                  Text(`${index + 1}`)
                    .fontSize(11)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(index < 3 ? AppTheme.ACCENT : AppTheme.TEXT_MUTED)
                    .margin({ right: 6 })
                  Text(item)
                    .fontSize(13)
                    .fontColor(AppTheme.TEXT_PRIMARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: 200 })
                }
                .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                .margin({ right: 8, bottom: 8 })
                .backgroundColor(index < 3 ? AppTheme.BG_CHIP : AppTheme.BG_CARD)
                .border({
                  width: 1,
                  color: index < 3 ? AppTheme.ACCENT_SOFT : AppTheme.BORDER
                })
                .borderRadius(AppTheme.RADIUS_PILL)
                .onClick(() => {
                  this.onSelectKeyword(item);
                })
              }, (item: string) => item)
            }
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        if (this.searchHistory.length === 0 && this.hotKeywords.length === 0) {
          EmptyState({
            title: '搜索影片',
            subtitle: '输入片名、演员或关键词',
            icon: $r('sys.symbol.magnifyingglass')
          })
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: AppTheme.CONTENT_MAX_WIDTH })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
    .layoutWeight(1)
  }
}
