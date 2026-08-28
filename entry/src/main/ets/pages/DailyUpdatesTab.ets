import { FilmApi } from '../api/FilmApi';
import { DailyUpdateCategory, MovieBasicInfo, PageInfo } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from '../components/AppIcon';
import { LoadingView } from '../components/LoadingView';
import { EmptyState } from '../components/EmptyState';
import { SourceGuard } from '../common/utils/SourceGuard';
import { RefreshHint } from '../common/utils/RefreshHint';
import { DailyUpdatePane } from './DailyUpdatePane';

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
      .fontSize(13)
      .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(this.currentIndex === index ? '#FFFFFF' : AppTheme.TEXT_SECONDARY)
      .height(32)
      .padding({ left: 14, right: 14 })
      .backgroundColor(this.currentIndex === index ? AppTheme.ACCENT : 'rgba(255, 255, 255, 0.06)')
      .borderRadius(AppTheme.RADIUS_PILL)
      .border({
        width: 1,
        color: this.currentIndex === index ? AppTheme.ACCENT : 'rgba(255, 255, 255, 0.08)'
      })
      .onClick(() => {
        this.selectIndex(index);
      })
  }

  build() {
    Column() {
      Column() {
        Row() {
          Row() {
            AppIcon({ src: $r('sys.symbol.flame_fill'), iconSize: 18, color: AppTheme.ACCENT })
            Text('每日更新')
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT_PRIMARY)
              .margin({ left: AppTheme.SPACE_SM })
          }
          .layoutWeight(1)

          Row() {
            Text('近 24 小时 ')
              .fontSize(11)
              .fontColor(AppTheme.TEXT_MUTED)
            Text(`${this.currentCategory().count}`)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ACCENT)
            Text(' 部')
              .fontSize(11)
              .fontColor(AppTheme.TEXT_MUTED)
          }
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor('rgba(255, 255, 255, 0.06)')
          .borderRadius(AppTheme.RADIUS_PILL)
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.08)' })
        }
        .width('100%')
        .height(38)
        .alignItems(VerticalAlign.Center)
        .padding({
          left: AppTheme.SPACE_LG,
          right: AppTheme.SPACE_LG
        })

        if (this.categories.length > 1) {
          List({ space: AppTheme.SPACE_SM, scroller: this.chipsScroller }) {
            ForEach(this.categories, (item: DailyUpdateCategory, index: number) => {
              ListItem() {
                this.filterChip(index, item)
              }
            }, (item: DailyUpdateCategory) => `chip_${item.pid}`)
          }
          .listDirection(Axis.Horizontal)
          .width('100%')
          .height(32)
          .contentEndOffset(AppTheme.SPACE_LG)
          .nestedScroll({
            scrollForward: NestedScrollMode.SELF_FIRST,
            scrollBackward: NestedScrollMode.SELF_FIRST
          })
          .scrollBar(BarState.Off)
          .alignListItem(ListItemAlign.Center)
          .margin({ top: AppTheme.SPACE_SM, bottom: AppTheme.SPACE_XS })
          .padding({ left: AppTheme.SPACE_LG })
        }
      }
      .width('100%')
      .padding({ bottom: this.categories.length > 1 ? AppTheme.SPACE_MD : AppTheme.SPACE_XS })

      if (this.loading && !this.ready) {
        LoadingView({ label: '正在加载今日更新' })
          .layoutWeight(1)
      } else if (!this.ready && this.errorText) {
        Refresh({ refreshing: $$this.refreshing }) {
          Scroll() {
            Column() {
              EmptyState({
                title: '加载失败',
                subtitle: this.errorText,
                icon: $r('sys.symbol.info_circle')
              })
              Button('重试')
                .margin({ top: 16 })
                .backgroundColor(AppTheme.BG_CARD)
                .fontColor(AppTheme.TEXT_PRIMARY)
                .onClick(() => {
                  this.loadMeta();
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .scrollBar(BarState.Off)
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
        .layoutWeight(1)
      } else {
        Swiper(this.swiperController) {
          ForEach(this.categories, (item: DailyUpdateCategory, index: number) => {
            DailyUpdatePane({
              pid: item.pid,
              active: Math.abs(this.currentIndex - index) <= 1,
              seedPid: this.seedPid,
              seedList: this.seedList,
              seedPage: this.seedPage,
              reloadToken: this.reloadToken
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
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BG)
  }
}
