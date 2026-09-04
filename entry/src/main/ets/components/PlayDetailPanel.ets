import { MovieDescriptor, MovieUrlInfo, PlaySource } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from './AppIcon';
import { FilmDetailHeader } from './FilmDetailHeader';

const GROUP_SIZE = 100;
const EPISODE_MIN_H = 44, EP_COLS_COMPACT = 3, EP_COLS_WIDE = 2, EP_NAME_WIDE_LEN = 6;

@Component
export struct PlayDetailPanel {
  @Prop filmId: string = '';
  @Prop picture: string = '';
  @Prop name: string = '';
  @Prop subTitle: string = '';
  @Prop actor: string = '';
  @Prop plot: string = '';
  @Prop descriptor: MovieDescriptor | null = null;
  @Prop @Watch('onSourcesChange') sources: PlaySource[] = [];
  @Prop @Watch('onPlayIndexChange') playingSourceId: string = '';
  @Prop @Watch('onViewSourceChange') viewingSourceId: string = '';
  @Prop @Watch('onPlayIndexChange') episodeIndex: number = 0;
  onViewSource?: (id: string) => void;
  onSelectEpisode?: (sourceId: string, index: number) => void;
  @State private groupSourceIds: string[] = [];
  @State private groupIndexes: number[] = [];
  @State private headerHeight: number = 148;
  @State private ready: boolean = false;
  private listScroller: Scroller = new Scroller();
  private groupScroller: Scroller = new Scroller();
  private sourceScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.syncGroupFromPlayingEpisode();
    this.checkReadyAndScroll();
    this.syncSourceBar(false);
  }

  private onSourcesChange(): void {
    this.syncGroupFromPlayingEpisode();
    this.checkReadyAndScroll();
    this.syncSourceBar(false);
  }
  private onViewSourceChange(): void {
    this.clampGroup(this.viewingSourceId);
    this.checkReadyAndScroll();
    this.syncSourceBar(true);
  }

  private onPlayIndexChange(): void {
    if (this.viewingSourceId === this.playingSourceId) {
      this.setGroup(this.viewingSourceId, Math.floor(this.episodeIndex / GROUP_SIZE), false);
      Promise.resolve().then(() => {
        this.scrollToFocusedEpisode(true);
      });
    }
  }

  private checkReadyAndScroll(): void {
    const isTop = (this.groupOf(this.viewingSourceId) === 0 && Math.floor((this.episodeIndex % GROUP_SIZE) / this.epCols()) === 0) ||
      !this.needsGrouping();
    if (isTop) {
      this.ready = true;
      this.scrollToFocusedEpisode(false);
    } else {
      this.ready = false;
      this.scrollToFocusedEpisode(false);
      Promise.resolve().then(() => {
        this.ready = true;
      });
    }
  }

  private syncGroupFromPlayingEpisode(): void {
    if (!this.viewingSourceId && this.playingSourceId) {
      this.viewingSourceId = this.playingSourceId;
    }
    if (this.viewingSourceId === this.playingSourceId) {
      const targetGroup = Math.floor(this.episodeIndex / GROUP_SIZE);
      this.setGroup(this.viewingSourceId, targetGroup, false);
    } else {
      this.clampGroup(this.viewingSourceId);
    }
  }

  private syncGroupBar(smooth: boolean): void {
    if (this.needsGrouping()) {
      try {
        const g = this.groupOf(this.viewingSourceId);
        this.groupScroller.scrollToIndex(g, smooth, ScrollAlign.START);
      } catch (_e) {}
    }
  }

  private syncSourceBar(smooth: boolean): void {
    if (this.sources.length === 0) {
      return;
    }
    for (let i = 0; i < this.sources.length; i++) {
      if (this.sources[i].id === this.viewingSourceId) {
        try {
          this.sourceScroller.scrollToIndex(i, smooth, ScrollAlign.START);
        } catch (_err) {}
        break;
      }
    }
  }

  private scrollToFocusedEpisode(smooth: boolean = false): void {
    const list = this.episodeList();
    if (list.length === 0) {
      return;
    }
    const g = this.groupOf(this.viewingSourceId);
    const start = g * GROUP_SIZE;
    const end = start + GROUP_SIZE;
    const inGroup = this.viewingSourceId === this.playingSourceId &&
      this.episodeIndex >= start &&
      this.episodeIndex < end &&
      this.episodeIndex < list.length;

    // 1. 同步横向滚动分组栏与播放源栏，使选中的胶囊进入视野首位
    this.syncGroupBar(smooth);
    this.syncSourceBar(smooth);

    // 2. 纵向列表定位：基于 headerHeight 与行高精确推移，绝不被吸顶栏遮挡
    try {
      if (inGroup) {
        const localIndex = this.episodeIndex - start;
        const targetRow = Math.floor(localIndex / this.epCols());
        const maxRow = Math.max(0, Math.ceil(this.visibleEpisodes().length / this.epCols()) - 1);
        const safeRow = Math.min(targetRow, maxRow);

        // 第一组首行或无分组前1-2行剧集：保持自然置顶（标题+吸顶栏+首行完整可见，绝不遮挡）
        if ((g === 0 && safeRow === 0) || (safeRow <= 1 && !this.needsGrouping())) {
          this.listScroller.scrollToIndex(0, smooth, ScrollAlign.START);
          return;
        }

        const rowH = 54;
        const targetOffset = Math.max(0, this.headerHeight + safeRow * rowH);
        this.listScroller.scrollTo({
          xOffset: 0,
          yOffset: targetOffset,
          animation: smooth ? { duration: 250, curve: Curve.EaseInOut } : undefined
        });
      } else {
        // 目标分组不含当前剧集时，吸顶对齐到 ListItemGroup 顶部（header groupBar 吸顶，首行展示该组第1行）
        this.listScroller.scrollTo({
          xOffset: 0,
          yOffset: this.headerHeight,
          animation: smooth ? { duration: 200, curve: Curve.EaseInOut } : undefined
        });
      }
    } catch (_err) {
      try { this.listScroller.scrollToIndex(0, smooth, ScrollAlign.START); } catch (_e) {}
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

  private setGroup(sourceId: string, groupIndex: number, scrollReset: boolean = true): void {
    if (!sourceId) {
      return;
    }
    const count = this.groupCount();
    const safe = count <= 0 ? 0 : Math.min(Math.max(groupIndex, 0), count - 1);
    const oldGroup = this.groupOf(sourceId);
    if (oldGroup === safe && this.groupSourceIds.indexOf(sourceId) >= 0) {
      if (scrollReset) {
        Promise.resolve().then(() => {
          this.scrollToFocusedEpisode(true);
        });
      }
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
    if (scrollReset) {
      Promise.resolve().then(() => {
        this.scrollToFocusedEpisode(true);
      });
    }
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
    this.setGroup(sourceId, this.groupOf(sourceId), false);
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
    return list.slice(start, start + GROUP_SIZE);
  }

  private groupLabel(index: number): string {
    const total = this.episodeList().length;
    const start = index * GROUP_SIZE + 1;
    const end = Math.min((index + 1) * GROUP_SIZE, total);
    return `${start}-${end}`;
  }

  private groupIndexesOf(): number[] {
    return Array.from({ length: this.groupCount() }, (_v: Object, i: number) => i);
  }

  private usesWideTiles(): boolean {
    const list = this.visibleEpisodes();
    for (let i = 0; i < list.length; i++) {
      if (list[i].episode.length > EP_NAME_WIDE_LEN) {
        return true;
      }
    }
    return false;
  }

  private epCols(): number {
    return this.usesWideTiles() ? EP_COLS_WIDE : EP_COLS_COMPACT;
  }

  private epMaxLines(): number {
    return this.usesWideTiles() ? 2 : 1;
  }

  private colIds(): number[] {
    return Array.from({ length: this.epCols() }, (_v: Object, i: number) => i);
  }

  private epRowIds(): number[] {
    const total = Math.ceil(this.visibleEpisodes().length / this.epCols());
    return Array.from({ length: total }, (_v: Object, i: number) => i);
  }

  private showEpisodeTitle(name: string): void {
    const text = name.trim();
    if (!text) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '剧集名称',
      message: text,
      autoCancel: true,
      confirm: { value: '知道了', action: () => {} }
    });
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
    .margin({ top: 8 })
  }

  @Builder
  groupBar() {
    Column() {
      Divider().color(AppTheme.BORDER).width('100%')

      if (this.sources.length > 0) {
        this.sourceRow()
      }
      if (this.needsGrouping()) {
        Column() {
          List({ space: 4, scroller: this.groupScroller }) {
            ForEach(this.groupIndexesOf(), (index: number) => {
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
          .height(40)
          .contentEndOffset(AppTheme.SPACE_LG)
          .padding({ left: 8, right: 12, top: 4, bottom: 4 })
          .backgroundColor(AppTheme.BG_ELEVATED)
          .borderRadius(AppTheme.RADIUS_MD)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8 })
      }
    }
    .width('100%')
    .padding({ bottom: 8 })
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
      Column().layoutWeight(1).constraintSize({ minWidth: 0 })
    }
  }

  @Builder
  epRow(row: number) {
    Row({ space: AppTheme.SPACE_SM }) {
      ForEach(this.colIds(), (col: number) => {
        this.epCell(row * this.epCols() + col)
      }, (col: number) => `ep_col_${this.viewingSourceId}_${row}_${col}`)
    }
    .width('100%')
    .height(54)
    .padding({ left: 12, right: 12, top: 4, bottom: 6 })
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
        this.setGroup(this.viewingSourceId, index, true);
        this.syncGroupBar(true);
      })
  }

  @Builder
  episodeTile(ep: MovieUrlInfo, index: number) {
    Text(ep.episode)
      .fontSize(13)
      .fontWeight(this.isEpisodeOn(index) ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.isEpisodeOn(index) ? AppTheme.TEXT_PRIMARY : AppTheme.TEXT_SECONDARY)
      .width('100%')
      .constraintSize({ minHeight: EPISODE_MIN_H })
      .padding({ left: AppTheme.SPACE_SM, right: AppTheme.SPACE_SM, top: 10, bottom: 10 })
      .textAlign(TextAlign.Center)
      .maxLines(this.epMaxLines())
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .backgroundColor(this.isEpisodeOn(index) ? AppTheme.ACCENT_SOFT : AppTheme.BG_CARD)
      .borderRadius(AppTheme.RADIUS_MD)
      .border({ width: this.isEpisodeOn(index) ? 2 : 0, color: AppTheme.ACCENT })
      .gesture(LongPressGesture({ repeat: false }).onAction(() => { this.showEpisodeTitle(ep.episode); }))
      .onClick(() => {
        if (this.isEpisodeOn(index) || !this.onSelectEpisode) {
          this.showEpisodeTitle(ep.episode);
          return;
        }
        this.onSelectEpisode(this.viewingSourceId, index);
      })
  }

  build() {
    List({ scroller: this.listScroller }) {
      ListItem() {
        FilmDetailHeader({
          filmId: this.filmId,
          picture: this.picture,
          name: this.name,
          subTitle: this.subTitle,
          actor: this.actor,
          plot: this.plot,
          descriptor: this.descriptor
        })
      }
      .onAreaChange((_oldVal: Area, newVal: Area) => {
        const h = Number(newVal.height);
        if (h > 0 && Math.abs(this.headerHeight - h) > 1) this.headerHeight = h;
      })

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
    }
    .sticky(StickyStyle.Header)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .opacity(this.ready ? 1 : 0)
    .animation({ duration: 150, curve: Curve.EaseOut })
    .onAppear(() => {
      this.scrollToFocusedEpisode(false);
      this.syncSourceBar(false);
    })
  }
}
