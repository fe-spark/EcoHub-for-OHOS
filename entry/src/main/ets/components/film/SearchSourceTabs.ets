import { SearchSourceTab } from '../../types/FilmModels';
import { AppTheme } from '../../common/constants/AppTheme';

@Component
export struct SearchSourceTabs {
  @Prop sources: SearchSourceTab[] = [];
  @Prop @Watch('onActiveChange') activeId: string = '';
  onChange: (id: string) => void = () => {};
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.scrollToActive(false);
  }

  onActiveChange(): void {
    this.scrollToActive(true);
  }

  private scrollToActive(smooth: boolean): void {
    let targetIndex = -1;
    for (let i = 0; i < this.sources.length; i++) {
      if (this.sources[i].id === this.activeId) {
        targetIndex = i;
        break;
      }
    }
    if (targetIndex >= 0) {
      try {
        this.scroller.scrollToIndex(targetIndex, smooth, ScrollAlign.CENTER);
      } catch (_err) {
      }
    }
  }

  build() {
    Column() {
      if (this.sources.length > 1) {
        List({ space: 8, scroller: this.scroller }) {
          ForEach(this.sources, (tab: SearchSourceTab) => {
            ListItem() {
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
            }
          }, (tab: SearchSourceTab) => `src_${tab.id}_${tab.loading ? '1' : '0'}_${tab.count}`)
        }
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
        .width('100%')
        .height(44)
        .onAppear(() => {
          this.scrollToActive(false);
        })
      }
    }
    .width('100%')
    .height(this.sources.length > 1 ? 44 : 0)
  }
}
