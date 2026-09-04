import { FilmApi } from '../api/FilmApi';
import { MovieBasicInfo, PageInfo } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FilmCard } from '../components/FilmCard';
import { ScrollFab } from '../components/ScrollFab';
import { LoadingView } from '../components/LoadingView';
import { EmptyState } from '../components/EmptyState';
import { RefreshHint } from '../common/utils/RefreshHint';
import { Breakpoint } from '../common/utils/Breakpoint';

const PAGE_SIZE = 21;

@Component
export struct DailyUpdatePane {
  @Prop pid: number = 0;
  @Prop @Watch('onActiveChange') active: boolean = false;
  @Prop seedPid: number = 0;
  @Prop seedList: MovieBasicInfo[] = [];
  @Prop seedPage: PageInfo = { pageSize: PAGE_SIZE, current: 1, pageCount: 1, total: 0 };
  @Prop @Watch('onReloadToken') reloadToken: number = 0;
  @Prop headerHeight: number = 0;
  @StorageLink('SAFE_INSET_LEFT') private leftInset: number = 0;
  @StorageLink('SAFE_INSET_RIGHT') private rightInset: number = 0;

  @State private films: MovieBasicInfo[] = [];
  @State private page: PageInfo = { pageSize: PAGE_SIZE, current: 1, pageCount: 1, total: 0 };
  @State private loading: boolean = true;
  @State private refreshing: boolean = false;
  @State private loadingMore: boolean = false;
  @State private errorText: string = '';
  @State private fetchLock: boolean = false;
  @State private listHeight: number = 0;
  @State private showTopFab: boolean = false;
  @StorageLink('WIDTH_BP') private widthBp: string = 'sm';
  @StorageLink('WINDOW_WIDTH') private windowWidth: number = 360;
  private hasLoaded: boolean = false;
  private listScroller: Scroller = new Scroller();
  private touchStartY: number = 0;
  private touchStartX: number = 0;
  private isPulling: boolean = false;
  @State private pullDistance: number = 0;

  private gridCols(): number {
    return Breakpoint.gridCols(this.widthBp, this.windowWidth);
  }

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
      const msg = err instanceof Error ? err.message : '每日更新加载失败';
      if (reset) {
        this.errorText = msg;
      } else {
        RefreshHint.fail(msg);
      }
    } finally {
      this.fetchLock = false;
      this.loading = false;
      this.loadingMore = false;
      this.refreshing = false;
      this.getUIContext()?.animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.pullDistance = 0;
      });
      if (fromPull) {
        if (ok) {
          RefreshHint.succeed();
        } else {
          RefreshHint.fail(this.errorText || '刷新失败');
        }
      }
    }
  }

  private hasMore(): boolean {
    return this.page.current < this.page.pageCount;
  }

  private onPullRefreshing(): void {
    if (this.fetchLock) {
      return;
    }
    this.load(true, true);
  }

  private scrollToTop(): void {
    this.showTopFab = false;
    this.listScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
  }

  private syncTopFab(y: number): void {
    const show = this.listHeight > 0 && y > this.listHeight;
    if (show !== this.showTopFab) {
      this.showTopFab = show;
    }
  }

  private rowIds(): number[] {
    return Breakpoint.rowIds(this.films.length, this.gridCols());
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
      ForEach(Breakpoint.colIds(this.gridCols()), (col: number) => {
        this.filmCell(row * this.gridCols() + col)
      }, (col: number) => `film_col_${this.gridCols()}_${row}_${col}`)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ bottom: AppTheme.SPACE_MD })
  }

  private handleTouch(event: TouchEvent): void {
    if (this.refreshing || this.fetchLock) {
      return;
    }
    if (event.type === TouchType.Down) {
      this.touchStartY = event.touches[0].y;
      this.touchStartX = event.touches[0].x;
      this.isPulling = false;
    } else if (event.type === TouchType.Move) {
      let scrollY: number = 0;
      try {
        scrollY = this.listScroller.currentOffset().yOffset;
      } catch (_e) {
        scrollY = 0;
      }
      const currentY = event.touches[0].y;
      const currentX = event.touches[0].x;

      if (scrollY > 0) {
        if (this.isPulling) {
          this.isPulling = false;
          this.pullDistance = 0;
        }
        return;
      }

      const deltaY = currentY - this.touchStartY;
      const deltaX = Math.abs(currentX - this.touchStartX);

      if (scrollY <= 0 && deltaY > 0 && deltaY > deltaX * 1.2) {
        this.isPulling = true;
        const damping = 0.42;
        this.pullDistance = Math.min(84, deltaY * damping);
      } else if (this.isPulling && deltaY <= 0) {
        this.isPulling = false;
        this.pullDistance = 0;
      }
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      if (this.isPulling) {
        this.isPulling = false;
        if (this.pullDistance >= 46 && !this.fetchLock) {
          this.refreshing = true;
          this.getUIContext()?.animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
            this.pullDistance = 60;
          });
          this.load(true, true);
        } else {
          this.getUIContext()?.animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
            this.pullDistance = 0;
          });
        }
      }
    }
  }

  @Builder
  floatingRefreshIndicator() {
    if (this.pullDistance > 0 || this.refreshing) {
      Row() {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(AppTheme.ACCENT)
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('rgba(26, 28, 36, 0.85)')
      .backdropBlur(25)
      .borderRadius(18)
      .border({ width: 0.8, color: 'rgba(255, 255, 255, 0.12)' })
      .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.38)', offsetY: 2 })
      .position({
        x: '50%',
        y: this.headerHeight - 36 + this.pullDistance * 0.84
      })
      .markAnchor({ x: '50%', y: 0 })
      .opacity(Math.max(0, Math.min(1.0, (this.pullDistance - 6) / 16)))
      .scale({
        x: Math.min(1.0, 0.5 + 0.5 * (this.pullDistance / 46)),
        y: Math.min(1.0, 0.5 + 0.5 * (this.pullDistance / 46))
      })
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.loading && this.films.length === 0) {
        LoadingView({ label: '正在加载今日更新' })
          .width('100%')
          .height('100%')
          .padding({ top: this.headerHeight })
      } else if (this.films.length === 0) {
        Scroll() {
          Column() {
            Blank().height(this.headerHeight + 24)
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
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .nestedScroll({
          scrollForward: NestedScrollMode.SELF_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST
        })
        .width('100%')
        .height('100%')
        .translate({ y: this.pullDistance })
      } else {
        List({ scroller: this.listScroller }) {
          ListItem() {
            Row()
              .width('100%')
              .height(this.headerHeight + 8)
          }
          .hitTestBehavior(HitTestMode.Transparent)

          ForEach(this.rowIds(), (row: number) => {
            ListItem() {
              this.filmRow(row)
            }
          }, (row: number) => `film_row_${this.gridCols()}_${row}_${this.films[row * this.gridCols()].id}`)

          ListItem() {
            Text(this.loadingMore ? '加载中...' : (this.hasMore() ? '' : '没有更多了'))
              .fontSize(12)
              .fontColor(AppTheme.TEXT_MUTED)
              .width('100%')
              .height(72)
              .textAlign(TextAlign.Center)
          }
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          const h = Number(newValue.height);
          if (h > 0) {
            this.listHeight = h;
          }
        })
        .onDidScroll((_offset: number, _state: ScrollState) => {
          this.syncTopFab(this.listScroller.currentOffset().yOffset);
        })
        .nestedScroll({
          scrollForward: NestedScrollMode.SELF_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST
        })
        .padding({
          left: AppTheme.SPACE_LG + this.leftInset,
          right: AppTheme.SPACE_LG + this.rightInset
        })
        .translate({ y: this.pullDistance })
        .onReachEnd(() => {
          this.load(false, false);
        })
      }

      this.floatingRefreshIndicator()

      if (!this.loading && this.films.length > 0) {
        ScrollFab({
          visible: this.showTopFab,
          src: $r('sys.symbol.arrow_up'),
          bottom: AppTheme.SPACE_LG,
          onClickFab: () => {
            this.scrollToTop();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .onTouch((event: TouchEvent) => {
      this.handleTouch(event);
    })
  }
}
