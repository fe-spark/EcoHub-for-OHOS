import { AppTheme } from '../common/constants/AppTheme';

@Component
export struct FilterTagRow {
  @Prop filterKey: string = '';
  @Prop title: string = '';
  @Prop names: string[] = [];
  @Prop @Watch('onSelectChange') values: string[] = [];
  @Prop @Watch('onSelectChange') selected: string = '';
  onPick?: (key: string, value: string) => void;
  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    this.jumpSelected(false);
  }

  onSelectChange(): void {
    this.jumpSelected(true);
  }

  private jumpSelected(smooth: boolean): void {
    let idx = -1;
    for (let i = 0; i < this.values.length; i++) {
      if (this.values[i] === this.selected) {
        idx = i;
        break;
      }
    }
    if (idx < 0) {
      return;
    }
    try {
      this.scroller.scrollToIndex(idx, smooth, ScrollAlign.START);
    } catch (_err) {
    }
  }

  build() {
    Row() {
      Text(this.title)
        .width(40)
        .fontSize(13)
        .fontColor(AppTheme.TEXT_SECONDARY)
        .textAlign(TextAlign.Start)
      List({ space: 8, scroller: this.scroller }) {
        ForEach(this.names, (name: string, index: number) => {
          ListItem() {
            Text(name)
              .fontSize(13)
              .fontColor(this.values[index] === this.selected ? AppTheme.TEXT_PRIMARY : AppTheme.TEXT_SECONDARY)
              .height(32)
              .padding({ left: 12, right: 12 })
              .backgroundColor(this.values[index] === this.selected ? AppTheme.ACCENT : AppTheme.BG_CARD)
              .borderRadius(AppTheme.RADIUS_PILL)
              .onClick(() => {
                if (this.onPick) {
                  this.onPick(this.filterKey, this.values[index] || '');
                }
              })
          }
        }, (name: string, index: number) => `${this.filterKey}_${index}_${name}`)
      }
      .listDirection(Axis.Horizontal)
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })
      .height(32)
      .contentEndOffset(AppTheme.SPACE_LG)
      .nestedScroll({
        scrollForward: NestedScrollMode.SELF_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })
      .scrollBar(BarState.Off)
      .alignListItem(ListItemAlign.Center)
      .onAppear(() => {
        this.jumpSelected(false);
      })
    }
    .width('100%')
    .height(44)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .padding({ left: AppTheme.SPACE_LG })
  }
}
