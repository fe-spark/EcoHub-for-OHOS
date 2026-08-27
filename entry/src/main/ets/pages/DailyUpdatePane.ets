import { FilmApi } from '../api/FilmApi';
import { MovieBasicInfo, PageInfo } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FilmCard } from '../components/FilmCard';
import { LoadingView } from '../components/LoadingView';
import { EmptyState } from '../components/EmptyState';
import { RefreshHint } from '../common/utils/RefreshHint';

const PAGE_SIZE = 21;
const GRID_COLS = 3;

@Component
export struct DailyUpdatePane {
  @Prop pid: number = 0;
  @Prop @Watch('onActiveChange') active: boolean = false;
  @Prop seedPid: number = 0;
  @Prop seedList: MovieBasicInfo[] = [];
  @Prop seedPage: PageInfo = { pageSize: PAGE_SIZE, current: 1, pageCount: 1, total: 0 };
  @Prop @Watch('onReloadToken') reloadToken: number = 0;

  @State private films: MovieBasicInfo[] = [];
  @State private page: PageInfo = { pageSize: PAGE_SIZE, current: 1, pageCount: 1, total: 0 };
  @State private loading: boolean = true;
  @State private refreshing: boolean = false;
  @State private loadingMore: boolean = false;
  @State private errorText: string = '';
  @State private fetchLock: boolean = false;
  private hasLoaded: boolean = false;

  aboutToAppear(): void {
    this.boot();
  }

  onReloadToken(): void {
    this.hasLoaded = false;
    this.boot();
  }

  onActiveChange(): void {
    if (this.active && !this.hasLoaded) {
      this.load(true, false);
    }
  }

  private boot(): void {
    if (this.consumeSeed()) {
      return;
    }
    this.films = [];
    this.page = { pageSize: PAGE_SIZE, current: 1, pageCount: 1, total: 0 };
    this.errorText = '';
    if (this.active) {
      this.load(true, false);
    } else {
      this.loading = true;
    }
  }

  private consumeSeed(): boolean {
    if (this.pid !== this.seedPid) {
      return false;
    }
    this.films = this.seedList.slice();
    this.page = {
      pageSize: this.seedPage.pageSize || PAGE_SIZE,
      current: this.seedPage.current || 1,
      pageCount: this.seedPage.pageCount || 1,
      total: this.seedPage.total
    };
    this.hasLoaded = true;
    this.loading = false;
    this.errorText = '';
    return true;
  }

  private async load(reset: boolean, fromPull: boolean): Promise<void> {
    if (this.fetchLock) {
      return;
    }
    const nextPage = reset ? 1 : this.page.current + 1;
    if (!reset && (this.loadingMore || nextPage > this.page.pageCount)) {
      return;
    }
    this.fetchLock = true;
    if (reset) {
      if (!fromPull && this.films.length === 0) {
        this.loading = true;
      }
    } else {
      this.loadingMore = true;
    }
    this.errorText = '';
    let ok = false;
    try {
      const result = await FilmApi.getDailyUpdates(this.pid, nextPage, PAGE_SIZE);
      this.page = result.page;
      this.films = reset ? result.list : this.films.concat(result.list);
      this.hasLoaded = true;
      ok = true;
    } catch (err) {
      if (reset) {
        this.errorText = err instanceof Error ? err.message : '每日更新加载失败';
      }
    } finally {
      this.fetchLock = false;
      this.loading = false;
      this.loadingMore = false;
      this.refreshing = false;
      if (fromPull && ok) {
        RefreshHint.succeed();
      }
    }
  }

  private hasMore(): boolean {
    return this.page.current < this.page.pageCount;
  }

  private footerText(): string {
    if (this.loadingMore) {
      return '加载中...';
    }
    if (!this.hasMore()) {
      return '没有更多了';
    }
    return '上拉加载更多';
  }

  private rowIds(): number[] {
    const n = Math.ceil(this.films.length / GRID_COLS);
    const ids: number[] = [];
    for (let i = 0; i < n; i++) {
      ids.push(i);
    }
    return ids;
  }

  @Builder
  filmCell(index: number) {
    if (index < this.films.length) {
      FilmCard({ film: this.films[index] })
        .layoutWeight(1)
        .constraintSize({ minWidth: 0 })
    } else {
      Column()
        .layoutWeight(1)
        .constraintSize({ minWidth: 0 })
    }
  }

  @Builder
  filmRow(row: number) {
    Row({ space: AppTheme.SPACE_SM }) {
      this.filmCell(row * GRID_COLS)
      this.filmCell(row * GRID_COLS + 1)
      this.filmCell(row * GRID_COLS + 2)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ bottom: AppTheme.SPACE_MD })
  }

  @Builder
  loadFooter() {
    Row({ space: AppTheme.SPACE_SM }) {
      if (this.loadingMore) {
        LoadingProgress()
          .width(16)
          .height(16)
          .color(AppTheme.ACCENT)
      }
      Text(this.footerText())
        .fontSize(12)
        .fontColor(AppTheme.TEXT_MUTED)
    }
    .width('100%')
    .height(48)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      if (this.loading && this.films.length === 0) {
        LoadingView({ label: '正在加载今日更新' })
          .layoutWeight(1)
      } else if (this.films.length === 0) {
        Refresh({ refreshing: $$this.refreshing }) {
          Scroll() {
            if (this.errorText) {
              EmptyState({
                title: '加载失败',
                subtitle: this.errorText,
                icon: $r('sys.symbol.info_circle')
              })
            } else {
              EmptyState({
                title: '暂无更新',
                subtitle: '近 24 小时还没有新片入库',
                icon: $r('sys.symbol.flame')
              })
            }
          }
          .scrollBar(BarState.Off)
          .width('100%')
          .height('100%')
        }
        .onRefreshing(() => {
          if (this.fetchLock) {
            return;
          }
          this.load(true, true);
        })
        .pullToRefresh(!this.fetchLock)
        .width('100%')
        .layoutWeight(1)
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List() {
            ForEach(this.rowIds(), (row: number) => {
              ListItem() {
                this.filmRow(row)
              }
            }, (row: number) => `film_row_${row}_${this.films[row * GRID_COLS].id}`)

            ListItem() {
              this.loadFooter()
            }
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .nestedScroll({
            scrollForward: NestedScrollMode.SELF_FIRST,
            scrollBackward: NestedScrollMode.SELF_FIRST
          })
          .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG })
          .onReachEnd(() => {
            this.load(false, false);
          })
        }
        .onRefreshing(() => {
          if (this.fetchLock) {
            return;
          }
          this.load(true, true);
        })
        .pullToRefresh(!this.fetchLock)
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
  }
}
