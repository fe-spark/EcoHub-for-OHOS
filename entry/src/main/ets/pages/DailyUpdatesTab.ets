import { FilmApi } from '../api/FilmApi';
import { DailyUpdateCategory, MovieBasicInfo, PageInfo } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from '../components/AppIcon';
import { LoadingView } from '../components/LoadingView';
import { EmptyState } from '../components/EmptyState';
import { SourceGuard } from '../common/utils/SourceGuard';
import { RefreshHint } from '../common/utils/RefreshHint';
import { DailyUpdatePane } from './DailyUpdatePane';
import { Breakpoint } from '../common/utils/Breakpoint';

const PAGE_SIZE = 21;

@Component
export struct DailyUpdatesTab {
  @State private categories: DailyUpdateCategory[] = [];
  @State private currentIndex: number = 0;
  @State private loading: boolean = true;
  @State private errorText: string = '';
  @State private ready: boolean = false;
  @State private seedPid: number = 0;
  @State private seedList: MovieBasicInfo[] = [];
  @State private seedPage: PageInfo = { pageSize: PAGE_SIZE, current: 1, pageCount: 1, total: 0 };
  @State private reloadToken: number = 0;
  @State private refreshing: boolean = false;
  private swiperController: SwiperController = new SwiperController();
  private chipsScroller: Scroller = new Scroller();
  private hasLoaded: boolean = false;
  @State private fetchLock: boolean = false;
  private reconnectCb: () => void = () => {};
  @StorageLink('WIDTH_BP') private widthBp: string = 'sm';
  @StorageLink('SAFE_INSET_TOP') private topInset: number = 0;
  @StorageLink('SAFE_INSET_LEFT') private leftInset: number = 0;
  @StorageLink('SAFE_INSET_RIGHT') private rightInset: number = 0;
  @State private headerHeight: number = 0;

  private isWide(): boolean {
    return Breakpoint.isWide(this.widthBp);
  }

  private getHeaderHeight(): number {
    if (this.headerHeight > 0) {
      return this.headerHeight;
    }
    return (this.isWide() ? 38 : 44) + this.topInset + (this.categories.length > 1 ? (this.isWide() ? 40 : 48) : 8);
  }


  aboutToAppear() {
    this.reconnectCb = () => {
      this.loadMeta();
    };
    SourceGuard.onReconnect(this.reconnectCb);
    if (this.hasLoaded) {
      return;
    }
    this.loadMeta();
  }

  aboutToDisappear(): void {
    SourceGuard.offReconnect(this.reconnectCb);
  }

  private currentCategory(): DailyUpdateCategory {
    if (this.currentIndex >= 0 && this.currentIndex < this.categories.length) {
      return this.categories[this.currentIndex];
    }
    const fallback: DailyUpdateCategory = { pid: 0, name: '全部', count: 0 };
    return fallback;
  }

  private async loadMeta(): Promise<void> {
    if (this.fetchLock) {
      return;
    }
    const fromPull = this.refreshing;
    this.fetchLock = true;
    this.loading = true;
    this.errorText = '';
    this.ready = false;
    this.categories = [];
    this.seedList = [];
    this.seedPid = 0;
    this.currentIndex = 0;
    try {
      const result = await FilmApi.getDailyUpdates(0, 1, PAGE_SIZE);
      let cats = result.categories;
      if (cats.length === 0) {
        cats = [{ pid: 0, name: '全部', count: result.page.total }];
      }
      this.categories = cats;
      this.seedPid = 0;
      this.seedList = result.list;
      this.seedPage = result.page;
      this.reloadToken = this.reloadToken + 1;
      this.ready = true;
      this.hasLoaded = true;
    } catch (err) {
      this.errorText = err instanceof Error ? err.message : '每日更新加载失败';
      this.ready = false;
      this.hasLoaded = false;
      this.reloadToken = this.reloadToken + 1;
    } finally {
      this.fetchLock = false;
      this.loading = false;
      this.refreshing = false;
      if (fromPull && this.ready) {
        RefreshHint.succeed();
      }
    }
  }

  private selectIndex(index: number): void {
    if (index < 0 || index >= this.categories.length || index === this.currentIndex) {
      return;
    }
    this.currentIndex = index;
    this.swiperController.changeIndex(index, true);
    this.focusChip(index);
  }

  private focusChip(index: number): void {
    if (index < 0) {
      return;
    }
    try {
      this.chipsScroller.scrollToIndex(index, true, ScrollAlign.START);
    } catch (_err) {
    }
  }

  @Builder
  filterChip(index: number, item: DailyUpdateCategory) {
    Text(item.name)
      .fontSize(this.isWide() ? 13.5 : 13)
      .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(this.currentIndex === index ? '#FFFFFF' : AppTheme.TEXT_SECONDARY)
      .height(this.isWide() ? 35 : 32)
      .padding({
        left: this.isWide() ? 14 : 13,
        right: this.isWide() ? 14 : 13
      })
      .backgroundColor(this.currentIndex === index ? AppTheme.ACCENT : 'rgba(255, 255, 255, 0.06)')
      .borderRadius(AppTheme.RADIUS_PILL)
      .border({
        width: 0.5,
        color: this.currentIndex === index ? AppTheme.ACCENT : 'rgba(255, 255, 255, 0.08)'
      })
      .onClick(() => {
        this.selectIndex(index);
      })
  }

  @Builder
  headerView() {
    Column() {
      Row() {
        Row() {
          AppIcon({ src: $r('sys.symbol.flame_fill'), iconSize: 20, color: AppTheme.ACCENT })
          Text('每日更新')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .margin({ left: 6 })

          if (this.categories.length > 0) {
            Text('·')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT_MUTED)
              .margin({ left: 8, right: 8 })

            Row() {
              Text('近 24 小时 ')
                .fontSize(12)
                .fontColor(AppTheme.TEXT_MUTED)
              Text(`${this.currentCategory().count}`)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ACCENT)
              Text(' 部')
                .fontSize(12)
                .fontColor(AppTheme.TEXT_MUTED)
            }
          }
        }
        .layoutWeight(1)

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          if (this.loading) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(AppTheme.ACCENT)
          } else {
            AppIcon({
              src: $r('sys.symbol.arrow_counterclockwise'),
              iconSize: 16,
              color: AppTheme.TEXT_SECONDARY
            })
          }
        }
        .width(32)
        .height(32)
        .backgroundColor('rgba(255, 255, 255, 0.06)')
        .border({ width: 0.5, color: 'rgba(255, 255, 255, 0.10)' })
        .onClick(() => {
          if (!this.fetchLock) {
            this.loadMeta();
          }
        })
      }
      .width('100%')
      .height(44)
      .alignItems(VerticalAlign.Center)
      .padding({
        left: AppTheme.SPACE_LG + this.leftInset,
        right: AppTheme.SPACE_LG + this.rightInset
      })

      if (this.categories.length > 1) {
        List({ space: this.isWide() ? 8 : AppTheme.SPACE_SM, scroller: this.chipsScroller }) {
          ForEach(this.categories, (item: DailyUpdateCategory, index: number) => {
            ListItem() {
              this.filterChip(index, item)
            }
          }, (item: DailyUpdateCategory) => `chip_${item.pid}`)
        }
        .listDirection(Axis.Horizontal)
        .width('100%')
        .height(this.isWide() ? 40 : 36)
        .contentStartOffset(AppTheme.SPACE_LG + this.leftInset)
        .contentEndOffset(AppTheme.SPACE_LG + this.rightInset)
        .nestedScroll({
          scrollForward: NestedScrollMode.SELF_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST
        })
        .scrollBar(BarState.Off)
        .alignListItem(ListItemAlign.Center)
        .margin({ top: this.isWide() ? 3 : 2, bottom: this.isWide() ? 3 : 4 })
      }
    }
    .width('100%')
    .padding({
      top: this.topInset,
      bottom: this.categories.length > 1 ? 8 : 4
    })
    .backgroundColor('rgba(10, 11, 16, 0.72)')
    .backdropBlur(25)
    .border({
      width: { bottom: 0.5 },
      color: 'rgba(255, 255, 255, 0.08)'
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    .onAreaChange((_oldVal: Area, newVal: Area) => {
      const h = Number(newVal.height);
      if (h > 0 && Math.abs(this.headerHeight - h) > 1) {
        this.headerHeight = h;
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.loading && !this.ready) {
        LoadingView({ label: '正在加载今日更新' })
          .width('100%')
          .height('100%')
          .padding({
            top: this.getHeaderHeight(),
            left: this.leftInset,
            right: this.rightInset
          })
      } else if (!this.ready && this.errorText) {
        Refresh({ refreshing: $$this.refreshing }) {
          Scroll() {
            Column() {
              Blank().height(this.getHeaderHeight() + 20)
              EmptyState({
                title: '加载失败',
                subtitle: this.errorText,
                icon: $r('sys.symbol.info_circle'),
                actionText: '重试',
                onAction: () => {
                  this.loadMeta();
                }
              })
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
        }
        .onRefreshing(() => {
          if (this.fetchLock) {
            this.refreshing = false;
            return;
          }
          this.loadMeta();
        })
        .pullToRefresh(!this.fetchLock)
        .width('100%')
        .height('100%')
      } else {
        Swiper(this.swiperController) {
          ForEach(this.categories, (item: DailyUpdateCategory, index: number) => {
            DailyUpdatePane({
              pid: item.pid,
              active: Math.abs(this.currentIndex - index) <= 1,
              seedPid: this.seedPid,
              seedList: this.seedList,
              seedPage: this.seedPage,
              reloadToken: this.reloadToken,
              headerHeight: this.getHeaderHeight()
            })
              .width('100%')
              .height('100%')
          }, (item: DailyUpdateCategory) => `pane_${item.pid}_${this.reloadToken}`)
        }
        .index(this.currentIndex)
        .indicator(false)
        .loop(false)
        .disableSwipe(this.categories.length <= 1)
        .duration(280)
        .onChange((index: number) => {
          this.currentIndex = index;
          this.focusChip(index);
        })
        .width('100%')
        .height('100%')
      }

      this.headerView()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
