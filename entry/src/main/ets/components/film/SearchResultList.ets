import { MovieBasicInfo, PageInfo } from '../../types/FilmModels';
import { AppTheme } from '../../common/constants/AppTheme';
import { Breakpoint } from '../../common/utils/Breakpoint';
import { SearchResultItem } from './SearchResultItem';

@Component
export struct SearchResultList {
  @Link list: MovieBasicInfo[];
  @Link page: PageInfo;
  @Prop loadingMore: boolean;
  @StorageLink('WIDTH_BP') private widthBp: string = 'sm';
  onSelect: (film: MovieBasicInfo) => void = () => {};
  onLoadMore: () => void = () => {};
  onScrollFrame: () => void = () => {};

  private listCols(): number {
    return Breakpoint.listLanes(this.widthBp);
  }

  private rowIds(): number[] {
    const cols = this.listCols();
    const rows = Math.ceil(this.list.length / cols);
    const ids: number[] = [];
    for (let i = 0; i < rows; i++) {
      ids.push(i);
    }
    return ids;
  }

  private rowFilms(row: number): MovieBasicInfo[] {
    const cols = this.listCols();
    return this.list.slice(row * cols, row * cols + cols);
  }

  private rowFillers(row: number): number[] {
    const missing = Math.max(0, this.listCols() - this.rowFilms(row).length);
    const fillers: number[] = [];
    for (let i = 0; i < missing; i++) {
      fillers.push(i);
    }
    return fillers;
  }

  @Builder
  filmRow(row: number) {
    Row({ space: AppTheme.SPACE_LG }) {
      ForEach(this.rowFilms(row), (film: MovieBasicInfo) => {
        SearchResultItem({
          film: film,
          onSelect: (selected: MovieBasicInfo) => {
            this.onSelect(selected);
          }
        })
          .layoutWeight(1)
      }, (film: MovieBasicInfo, idx: number) => `${film.sourceId}_${film.id}_${film.sourceMid}_${film.name}_${idx}`)

      ForEach(this.rowFillers(row), (idx: number) => {
        Blank()
          .layoutWeight(1)
      }, (idx: number) => `filler_${row}_${idx}`)
    }
    .width('100%')
  }

  build() {
    List({ space: 12 }) {
      ForEach(this.rowIds(), (row: number) => {
        ListItem() {
          this.filmRow(row)
        }
      }, (row: number) => {
        const first = this.list[row * this.listCols()];
        return `row_${this.listCols()}_${row}_${first?.sourceId || ''}_${first?.id || 0}_${first?.sourceMid || ''}_${first?.name || ''}`;
      })

      ListItem() {
        Text(this.loadingMore ? '加载中...' : (this.page.current >= this.page.pageCount ? '没有更多了' : ''))
          .fontSize(12)
          .fontColor(AppTheme.TEXT_MUTED)
          .width('100%')
          .height(60)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: AppTheme.CONTENT_MAX_WIDTH })
    .padding({ left: 16, right: 16, top: 8 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .nestedScroll({
      scrollForward: NestedScrollMode.SELF_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
    .onScrollFrameBegin((offset: number, _state: ScrollState) => {
      this.onScrollFrame();
      return { offsetRemain: offset };
    })
    .onReachEnd(() => {
      this.onLoadMore();
    })
  }
}
