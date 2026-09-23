import { SearchSourceTab } from '../../types/FilmModels';
import { AppTheme } from '../../common/constants/AppTheme';

@Component
export struct SearchSourceTabs {
  @Prop sources: SearchSourceTab[] = [];
  @Prop activeId: string = '';
  onChange: (id: string) => void = () => {};

  build() {
    Column() {
      if (this.sources.length > 1) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.sources, (tab: SearchSourceTab) => {
              Row({ space: 4 }) {
                Text(tab.name)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(tab.id === this.activeId ? Color.White : AppTheme.TEXT_SECONDARY)
                if (tab.loading) {
                  LoadingProgress()
                    .width(12)
                    .height(12)
                    .color(tab.id === this.activeId ? Color.White : AppTheme.TEXT_MUTED)
                } else {
                  Text(`${tab.count}`)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(tab.id === this.activeId ? Color.White : AppTheme.TEXT_SECONDARY)
                }
              }
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(16)
              .backgroundColor(tab.id === this.activeId ? AppTheme.ACCENT : AppTheme.BG_CARD)
              .onClick(() => {
                this.onChange(tab.id);
              })
            }, (tab: SearchSourceTab) => `src_${tab.id}_${tab.loading ? '1' : '0'}_${tab.count}`)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
      }
    }
  }
}
