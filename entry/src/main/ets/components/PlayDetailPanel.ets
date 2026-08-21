import { MovieUrlInfo, PlaySource } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from './AppIcon';

const GROUP_SIZE = 100;
const EPISODE_MIN_H = 44;
const EP_COLS = 4;

@Component
export struct PlayDetailPanel {
  @Prop name: string = '';
  @Prop subTitle: string = '';
  @Prop plot: string = '';
  @Prop sources: PlaySource[] = [];
  @Prop @Watch('onPlayIndexChange') playingSourceId: string = '';
  @Prop @Watch('onViewSourceChange') viewingSourceId: string = '';
  @Prop @Watch('onPlayIndexChange') episodeIndex: number = 0;
  onViewSource?: (id: string) => void;
  onSelectEpisode?: (sourceId: string, index: number) => void;
  @State private plotOpen: boolean = false;
  @State private groupSourceIds: string[] = [];
  @State private groupIndexes: number[] = [];

  private onViewSourceChange(): void {
    this.clampGroup(this.viewingSourceId);
  }

  private onPlayIndexChange(): void {
    if (this.viewingSourceId === this.playingSourceId) {
      this.setGroup(this.viewingSourceId, Math.floor(this.episodeIndex / GROUP_SIZE));
    }
  }

  private findSource(id: string): PlaySource | null {
    for (let i = 0; i < this.sources.length; i++) {
      if (this.sources[i].id === id) {
        return this.sources[i];
      }
    }
    return this.sources.length > 0 ? this.sources[0] : null;
  }

  private episodeList(): MovieUrlInfo[] {
    const source = this.findSource(this.viewingSourceId);
    return source ? source.linkList : [];
  }

  private groupOf(sourceId: string): number {
    const index = this.groupSourceIds.indexOf(sourceId);
    return index >= 0 ? this.groupIndexes[index] : 0;
  }

  private setGroup(sourceId: string, groupIndex: number): void {
    if (!sourceId) {
      return;
    }
    const count = this.groupCount();
    const safe = count <= 0 ? 0 : Math.min(Math.max(groupIndex, 0), count - 1);
    if (this.groupOf(sourceId) === safe && this.groupSourceIds.indexOf(sourceId) >= 0) {
      return;
    }
    const ids = this.groupSourceIds.slice();
    const values = this.groupIndexes.slice();
    const index = ids.indexOf(sourceId);
    if (index >= 0) {
      values[index] = safe;
    } else {
      ids.push(sourceId);
      values.push(safe);
    }
    this.groupSourceIds = ids;
    this.groupIndexes = values;
  }

  private groupCount(): number {
    const total = this.episodeList().length;
    if (total <= 0) {
      return 0;
    }
    return Math.ceil(total / GROUP_SIZE);
  }

  private needsGrouping(): boolean {
    return this.episodeList().length > GROUP_SIZE;
  }

  private clampGroup(sourceId: string): void {
    this.setGroup(sourceId, this.groupOf(sourceId));
  }

  private groupStart(): number {
    return this.groupOf(this.viewingSourceId) * GROUP_SIZE;
  }

  private visibleEpisodes(): MovieUrlInfo[] {
    const list = this.episodeList();
    if (!this.needsGrouping()) {
      return list;
    }
    const start = this.groupStart();
    const end = Math.min(start + GROUP_SIZE, list.length);
    const result: MovieUrlInfo[] = [];
    for (let i = start; i < end; i++) {
      result.push(list[i]);
    }
    return result;
  }

  private groupLabel(index: number): string {
    const total = this.episodeList().length;
    const start = index * GROUP_SIZE + 1;
    const end = Math.min((index + 1) * GROUP_SIZE, total);
    return `${start}-${end}`;
  }

  private groupIndexesOf(): number[] {
    const count = this.groupCount();
    const result: number[] = [];
    for (let i = 0; i < count; i++) {
      result.push(i);
    }
    return result;
  }

  private epRowIds(): number[] {
    const n = Math.ceil(this.visibleEpisodes().length / EP_COLS);
    const ids: number[] = [];
    for (let i = 0; i < n; i++) {
      ids.push(i);
    }
    return ids;
  }

  private subtitleText(): string {
    const text = this.subTitle ? this.subTitle.trim() : '';
    return text ? text : '暂无数据';
  }

  private plotText(): string {
    const raw = this.plot ? this.plot : '';
    const text = raw
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n')
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
    return text ? text : '暂无介绍';
  }

  private isEpisodeOn(index: number): boolean {
    return this.viewingSourceId === this.playingSourceId && this.episodeIndex === index;
  }

  @Builder
  sourceChip(source: PlaySource) {
    Row({ space: 4 }) {
      if (this.viewingSourceId === source.id) {
        AppIcon({
          src: $r('sys.symbol.checkmark'),
          iconSize: 12,
          color: AppTheme.TEXT_PRIMARY
        })
      }
      Text(source.name)
        .fontSize(13)
        .fontWeight(this.viewingSourceId === source.id ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.viewingSourceId === source.id ? AppTheme.TEXT_PRIMARY : AppTheme.TEXT_SECONDARY)
        .maxLines(1)
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
  sourceRow() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.sources, (source: PlaySource) => {
          this.sourceChip(source)
        }, (source: PlaySource) => source.id)
      }
      .justifyContent(FlexAlign.Start)
      .padding({ left: 12, right: 16 })
      .constraintSize({ minHeight: 32 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.Start)
    .nestedScroll({
      scrollForward: NestedScrollMode.SELF_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
    .width('100%')
    .height(36)
  }

  @Builder
  groupBar() {
    Column() {
      if (this.sources.length > 0) {
        this.sourceRow()
      }
      if (this.needsGrouping()) {
        Scroll() {
          Row({ space: 4 }) {
            ForEach(this.groupIndexesOf(), (index: number) => {
              this.groupChip(index)
            }, (index: number) => `group_${this.viewingSourceId}_${index}`)
          }
          .justifyContent(FlexAlign.Start)
          .padding({ left: 8, right: 12 })
          .constraintSize({ minHeight: 32 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .align(Alignment.Start)
        .nestedScroll({
          scrollForward: NestedScrollMode.SELF_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST
        })
        .width('100%')
        .height(40)
        .margin({ left: 12, right: 12, top: 8 })
        .backgroundColor(AppTheme.BG_ELEVATED)
        .borderRadius(AppTheme.RADIUS_MD)
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .backgroundColor(AppTheme.BG)
  }

  @Builder
  epCell(index: number) {
    if (index < this.visibleEpisodes().length) {
      Column() {
        this.episodeTile(this.visibleEpisodes()[index], this.groupStart() + index)
      }
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })
    } else {
      Column()
        .layoutWeight(1)
        .constraintSize({ minWidth: 0 })
    }
  }

  @Builder
  epRow(row: number) {
    Row({ space: 10 }) {
      this.epCell(row * EP_COLS)
      this.epCell(row * EP_COLS + 1)
      this.epCell(row * EP_COLS + 2)
      this.epCell(row * EP_COLS + 3)
    }
    .width('100%')
    .padding({ left: 12, right: 12, bottom: 10 })
  }

  @Builder
  groupChip(index: number) {
    Text(this.groupLabel(index))
      .fontSize(13)
      .fontWeight(this.groupOf(this.viewingSourceId) === index ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(this.groupOf(this.viewingSourceId) === index ? AppTheme.TEXT_PRIMARY : AppTheme.TEXT_SECONDARY)
      .height(32)
      .padding({ left: 16, right: 16 })
      .textAlign(TextAlign.Center)
      .backgroundColor(this.groupOf(this.viewingSourceId) === index ? AppTheme.ACCENT : Color.Transparent)
      .borderRadius(6)
      .onClick(() => {
        this.setGroup(this.viewingSourceId, index);
      })
  }

  @Builder
  episodeTile(ep: MovieUrlInfo, index: number) {
    Text(ep.episode)
      .fontSize(14)
      .fontWeight(this.isEpisodeOn(index) ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.isEpisodeOn(index) ? AppTheme.TEXT_PRIMARY : AppTheme.TEXT_SECONDARY)
      .width('100%')
      .constraintSize({ minHeight: EPISODE_MIN_H })
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .textAlign(TextAlign.Center)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .backgroundColor(this.isEpisodeOn(index) ? AppTheme.ACCENT_SOFT : AppTheme.BG_CARD)
      .borderRadius(AppTheme.RADIUS_MD)
      .border({
        width: this.isEpisodeOn(index) ? 2 : 0,
        color: AppTheme.ACCENT
      })
      .onClick(() => {
        if (this.isEpisodeOn(index) || !this.onSelectEpisode) {
          return;
        }
        this.onSelectEpisode(this.viewingSourceId, index);
      })
  }

  build() {
    List() {
      ListItem() {
        Column() {
          Row() {
            Column() {
              Text(this.name)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.TEXT_PRIMARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              Text(this.subtitleText())
                .fontSize(13)
                .fontColor(AppTheme.TEXT_MUTED)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 4 })
                .width('100%')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            AppIcon({
              src: this.plotOpen ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'),
              iconSize: 18,
              color: AppTheme.TEXT_MUTED
            })
          }
          .width('100%')
          .padding({ left: 12, right: 4, top: 12 })
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.plotOpen = !this.plotOpen;
          })

          if (this.plotOpen) {
            Text(this.plotText())
              .fontSize(13)
              .fontColor(AppTheme.TEXT_SECONDARY)
              .lineHeight(22)
              .width('100%')
              .margin({ left: 12, right: 12, top: 12 })
              .padding(12)
              .backgroundColor(AppTheme.BG_CARD)
              .borderRadius(AppTheme.RADIUS_MD)
          }

          Divider()
            .color(AppTheme.BORDER)
            .margin({ top: 12, bottom: 4 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      if (this.needsGrouping() || this.sources.length > 0) {
        ListItemGroup({ header: this.groupBar }) {
          if (this.episodeList().length === 0) {
            ListItem() {
              Text('暂无数据')
                .fontSize(13)
                .fontColor(AppTheme.TEXT_MUTED)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 32, bottom: 32 })
            }
          } else {
            ForEach(this.epRowIds(), (row: number) => {
              ListItem() {
                this.epRow(row)
              }
            }, (row: number) => `ep_row_${this.viewingSourceId}_${this.groupStart()}_${row}`)
          }
        }
      } else {
        if (this.episodeList().length === 0) {
          ListItem() {
            Text('暂无数据')
              .fontSize(13)
              .fontColor(AppTheme.TEXT_MUTED)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 32, bottom: 32 })
          }
        } else {
          ForEach(this.epRowIds(), (row: number) => {
            ListItem() {
              this.epRow(row)
            }
          }, (row: number) => `ep_row_${this.viewingSourceId}_${row}`)
        }
      }
    }
    .sticky(StickyStyle.Header)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
