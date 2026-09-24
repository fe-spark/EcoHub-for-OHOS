import { PlaySource } from '../../types/FilmModels';
import { AppTheme } from '../../common/constants/AppTheme';

@Component
export struct PlayGroupBar {
  @Prop sources: PlaySource[] = [];
  @Prop viewingSourceId: string = '';
  @Prop needsGrouping: boolean = false;
  @Prop groupIndexes: number[] = [];
  @Prop currentGroup: number = 0;
  sourceScroller?: Scroller;
  groupScroller?: Scroller;
  onViewSource?: (sourceId: string) => void;
  onSelectGroup?: (index: number) => void;
  groupLabel?: (index: number) => string;

  @Builder
  sourceChip(source: PlaySource) {
    Row() {
      if (this.viewingSourceId === source.id) {
        Row()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor('#FFFFFF')
          .margin({ right: 6 })
      }
      Text(source.name)
        .fontSize(13)
        .fontWeight(this.viewingSourceId === source.id ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.viewingSourceId === source.id ? '#FFFFFF' : AppTheme.TEXT_SECONDARY)
    }
    .height(32)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.viewingSourceId === source.id ? AppTheme.ACCENT : AppTheme.BG_CHIP)
    .borderRadius(AppTheme.RADIUS_PILL)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (this.onViewSource) {
        this.onViewSource(source.id);
      }
    })
  }

  @Builder
  groupChip(index: number) {
    Text(this.groupLabel ? this.groupLabel(index) : `${index + 1}`)
      .fontSize(13)
      .fontWeight(this.currentGroup === index ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(this.currentGroup === index ? '#FFFFFF' : AppTheme.TEXT_SECONDARY)
      .height(30)
      .padding({ left: 14, right: 14 })
      .backgroundColor(this.currentGroup === index ? AppTheme.ACCENT : AppTheme.BG_CHIP)
      .borderRadius(AppTheme.RADIUS_PILL)
      .onClick(() => {
        if (this.onSelectGroup) {
          this.onSelectGroup(index);
        }
      })
  }

  build() {
    Column() {
      // 实色不透明白线：保留视觉分区层次，同时 100% 阻断下层滚动内容透光
      Row()
        .width('100%')
        .height(1)
        .backgroundColor(AppTheme.BORDER_SOLID)

      if (this.sources.length > 1) {
        List({ space: 8, scroller: this.sourceScroller }) {
          ForEach(this.sources, (source: PlaySource) => {
            ListItem() {
              this.sourceChip(source)
            }
          }, (source: PlaySource) => source.id)
        }
        .listDirection(Axis.Horizontal)
        .alignListItem(ListItemAlign.Center)
        .scrollBar(BarState.Off)
        .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
        .width('100%')
        .height(32)
        .contentEndOffset(AppTheme.SPACE_LG)
        .padding({ left: 12, right: 16 })
        .margin({ top: 10 })
      }

      if (this.needsGrouping) {
        List({ space: 8, scroller: this.groupScroller }) {
          ForEach(this.groupIndexes, (index: number) => {
            ListItem() {
              this.groupChip(index)
            }
          }, (index: number) => `group_${this.viewingSourceId}_${index}`)
        }
        .listDirection(Axis.Horizontal)
        .alignListItem(ListItemAlign.Center)
        .scrollBar(BarState.Off)
        .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
        .width('100%')
        .height(30)
        .contentEndOffset(AppTheme.SPACE_LG)
        .padding({ left: 12, right: 16 })
        .margin({ top: 10 })
      }
    }
    .width('100%')
    .padding({ bottom: this.needsGrouping ? 12 : 10 })
    .backgroundColor(AppTheme.BG)
  }
}
