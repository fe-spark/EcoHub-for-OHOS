import { FilmApi } from '../api/FilmApi';
import { FilterResult, MovieBasicInfo } from '../types/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { NavUtil } from '../common/utils/NavUtil';
import { WindowBar } from '../common/utils/WindowBar';
import { common } from '@kit.AbilityKit';
import { QueryParams } from '../common/utils/QueryParams';
import { LoadingView } from '../components/common/LoadingView';
import { EmptyState } from '../components/common/EmptyState';
import { BackIcon } from '../components/common/BackIcon';
import { FilterTagRow } from '../components/film/FilterTagRow';
import { ScrollFab } from '../components/common/ScrollFab';
import { FilmCard } from '../components/film/FilmCard';
import { SourceGuard } from '../services/SourceGuard';
import { HttpClient } from '../common/network/HttpClient';
import { RefreshHint } from '../common/utils/RefreshHint';
import { Breakpoint } from '../common/utils/Breakpoint';
import { FloatingRefreshIndicator } from '../components/common/FloatingRefreshIndicator';
import { FilterNavHeader, FilterSelectedTag } from '../components/film/FilterNavHeader';

@Entry
@Component
struct FilterPage {
  @State private pid: string = '';
  @State private titleName: string = '片库';
  @State private films: MovieBasicInfo[] = [];
  @State private total: number = 0;
  @State private current: number = 1;
  @State private pageCount: number = 1;
  @State private loading: boolean = true;
  @State private listLoading: boolean = false;
  @State private loadingMore: boolean = false;
  @State private refreshing: boolean = false;
  @State private pullDistance: number = 0;
  @State private isPulling: boolean = false;
  private touchStartY: number = 0;
  private touchStartX: number = 0;
  @State private errorText: string = '';
  @State private sortList: string[] = [];
  @State private titleKeys: string[] = [];
  @State private titles: string[] = [];
  @State private tagKeys: string[] = [];
  @State private tagNames: string[][] = [];
  @State private tagValues: string[][] = [];
  @State private selectedKeys: string[] = [];
  @State private selectedValues: string[] = [];
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  @State private leftInset: number = 0;
  @State private rightInset: number = 0;
  @State private fetchLock: boolean = false;
  @State private listHeight: number = 0;
  @State private showTopFab: boolean = false;
  @StorageLink('WIDTH_BP') private widthBp: string = 'sm';
  @StorageLink('WINDOW_WIDTH') private windowWidth: number = 360;
  private reconnectCb: () => void = () => {};
  private scroller: Scroller = new Scroller();

  private gridCols(): number { return Breakpoint.gridCols(this.widthBp, this.windowWidth); }

  private applyWindowBar(): void {
    WindowBar.apply(this.getUIContext().getHostContext() as common.UIAbilityContext, (top: number, bottom: number, left: number, right: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
      this.leftInset = left;
      this.rightInset = right;
    });
  }

  aboutToAppear() {
    this.applyWindowBar();
    const params = this.getUIContext().getRouter().getParams() as Object;
    this.pid = NavUtil.param(params, 'Pid');
    HttpClient.getInstance().trackView('classify', this.pid, 'FilterPage');
    const category = NavUtil.param(params, 'Category');
    const sort = NavUtil.param(params, 'Sort');
    if (category) this.setSelected('Category', category);
    if (sort) this.setSelected('Sort', sort);
    this.loadData(true, false);
    this.reconnectCb = () => { this.loadData(true, false); };
    SourceGuard.onReconnect(this.reconnectCb);
  }

  onPageShow(): void { this.applyWindowBar(); }
  aboutToDisappear(): void { SourceGuard.offReconnect(this.reconnectCb); }

  private selectedOf(key: string): string {
    const index = this.selectedKeys.indexOf(key);
    return index >= 0 ? this.selectedValues[index] : '';
  }

  private isChipOn(key: string, value: string): boolean {
    const current = this.selectedOf(key);
    return (key === 'Sort' && !current ? 'update_stamp' : current) === value;
  }

  private setSelected(key: string, value: string): void {
    const nextKeys = this.selectedKeys.slice();
    const nextValues = this.selectedValues.slice();
    const index = nextKeys.indexOf(key);
    if (index >= 0) {
      nextValues[index] = value;
    } else {
      nextKeys.push(key);
      nextValues.push(value);
    }
    this.selectedKeys = nextKeys;
    this.selectedValues = nextValues;
  }

  private pick(key: string, value: string): void {
    if (this.isChipOn(key, value) || this.fetchLock) return;
    this.setSelected(key, value);
    this.loadData(true, false);
    this.scrollToTop();
  }

  private buildQuery(page: number): QueryParams {
    const query = new QueryParams().set('Pid', this.pid).set('current', page).set('pageSize', 21);
    for (let i = 0; i < this.selectedKeys.length; i++) {
      query.set(this.selectedKeys[i], this.selectedValues[i]);
    }
    return query;
  }

  private applyResult(result: FilterResult, reset: boolean): void {
    this.titleName = result.titleName || '片库';
    this.total = result.page.total;
    this.current = result.page.current;
    this.pageCount = result.page.pageCount;
    this.films = reset ? result.list : this.films.concat(result.list);
    this.sortList = result.search.sortList;
    this.titleKeys = result.search.titleKeys;
    this.titles = result.search.titles;
    this.tagKeys = result.search.tagKeys;
    this.tagNames = result.search.tagNames;
    this.tagValues = result.search.tagValues;
    if (reset) {
      this.applyParams(result.paramKeys, result.params);
    }
  }

  private applyParams(keys: string[], values: string[]): void {
    const nextKeys = this.selectedKeys.slice();
    const nextValues = this.selectedValues.slice();
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = values[i] || '';
      if (!value) {
        continue;
      }
      const index = nextKeys.indexOf(key);
      if (index >= 0) {
        nextValues[index] = value;
      } else {
        nextKeys.push(key);
        nextValues.push(value);
      }
    }
    this.selectedKeys = nextKeys;
    this.selectedValues = nextValues;
  }

  private selectedFor(key: string): string {
    const value = this.selectedOf(key);
    return (key === 'Sort' && !value) ? 'update_stamp' : value;
  }

  private async loadData(reset: boolean, fromPull: boolean = false): Promise<void> {
    if (!this.pid) {
      this.errorText = '缺少分类信息';
      this.loading = false;
      this.listLoading = false;
      this.refreshing = false;
      this.pullDistance = 0;
      return;
    }
    const page = reset ? 1 : this.current + 1;
    if ((!reset && (this.loadingMore || page > this.pageCount)) || this.fetchLock) {
      return;
    }
    this.fetchLock = true;
    if (reset) {
      if (fromPull) {
        this.listLoading = false;
      } else if (this.sortList.length === 0) {
        this.loading = true;
      } else {
        this.listLoading = true;
      }
    } else {
      this.loadingMore = true;
    }
    let ok = false;
    const minDelay = fromPull ? new Promise<void>((resolve) => setTimeout(resolve, 450)) : Promise.resolve();
    try {
      const result = await FilmApi.getFilter(this.buildQuery(page));
      if (fromPull) await minDelay;
      this.applyResult(result, reset);
      this.errorText = this.titleName ? '' : '当前分类已失效';
      ok = !this.errorText;
    } catch (err) {
      if (reset) {
        this.errorText = err instanceof Error ? err.message : '筛选失败';
      }
    } finally {
      this.fetchLock = false;
      this.loading = false;
      this.listLoading = false;
      this.loadingMore = false;
      this.getUIContext()?.animateTo({ duration: 240, curve: Curve.EaseIn }, () => {
        this.pullDistance = 0;
      });
      setTimeout(() => {
        this.refreshing = false;
      }, 240);
      if (fromPull && ok) {
        RefreshHint.succeed();
      }
    }
  }

  private titleOf(key: string): string {
    const index = this.titleKeys.indexOf(key);
    return index >= 0 ? this.titles[index] : key;
  }

  private namesOf(key: string): string[] {
    const index = this.tagKeys.indexOf(key);
    return index >= 0 ? this.tagNames[index] : [];
  }

  private valuesOf(key: string): string[] {
    const index = this.tagKeys.indexOf(key);
    return index >= 0 ? this.tagValues[index] : [];
  }

  private labelOf(key: string, value: string): string {
    if (!value) return '';
    const values = this.valuesOf(key);
    const names = this.namesOf(key);
    for (let i = 0; i < values.length; i++) {
      if (values[i] === value) return names[i] || value;
    }
    return value;
  }

  private selectedTags(): FilterSelectedTag[] {
    const keys: FilterSelectedTag[] = [];
    for (let i = 0; i < this.sortList.length; i++) {
      const key = this.sortList[i];
      const label = this.labelOf(key, this.selectedFor(key));
      if (label && label !== '全部') {
        keys.push({ key: key, label: label });
      }
    }
    return keys;
  }

  private rowIds(): number[] {
    return Breakpoint.rowIds(this.films.length, this.gridCols());
  }

  private scrollToTop(): void {
    this.showTopFab = false;
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
  }

  private syncTopFab(y: number): void {
    const show = this.listHeight > 0 && y > this.listHeight;
    if (show !== this.showTopFab) {
      this.showTopFab = show;
    }
  }

  private handleTouch(event: TouchEvent): void {
    if (this.refreshing || this.fetchLock || this.loading) {
      return;
    }
    if (event.type === TouchType.Down) {
      this.touchStartY = event.touches[0].y;
      this.touchStartX = event.touches[0].x;
      this.isPulling = false;
    } else if (event.type === TouchType.Move) {
      let scrollY: number = 0;
      try {
        scrollY = this.scroller.currentOffset().yOffset;
      } catch (_e) {
        scrollY = 0;
      }

      const currentY = event.touches[0].y;
      const currentX = event.touches[0].x;

      if (scrollY > 0) {
        this.touchStartY = currentY;
        this.touchStartX = currentX;
        if (this.isPulling) {
          this.isPulling = false;
          this.pullDistance = 0;
        }
        return;
      }

      const deltaY = currentY - this.touchStartY;
      const deltaX = Math.abs(currentX - this.touchStartX);

      if (scrollY <= 0 && deltaY > 0 && deltaY > deltaX) {
        this.isPulling = true;
        const damping = 0.42;
        this.pullDistance = Math.min(68, deltaY * damping);
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
            this.pullDistance = 46;
          });
          this.loadData(true, true);
        } else {
          this.getUIContext()?.animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
            this.pullDistance = 0;
          });
        }
      }
    }
  }

  @Builder
  filmCell(index: number) {
    if (index < this.films.length) {
      FilmCard({ film: this.films[index] })
        .layoutWeight(1)
        .constraintSize({ minWidth: 0 })
    } else {
      Column().layoutWeight(1).constraintSize({ minWidth: 0 })
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
    .padding({ left: AppTheme.SPACE_MD, right: AppTheme.SPACE_MD, bottom: AppTheme.SPACE_MD })
  }

  @Builder
  navHeader() {
    FilterNavHeader({
      total: this.total,
      tags: this.selectedTags(),
      onBack: () => {
        try {
          this.getUIContext().getRouter().back();
        } catch (_e) {}
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        if (this.loading) {
          FilterNavHeader({
            total: 0,
            tags: [],
            onBack: () => {
              try {
                this.getUIContext().getRouter().back();
              } catch (_e) {}
            }
          })
          LoadingView({ label: '加载中' })
        } else {
          List({ scroller: this.scroller }) {
            ListItem() {
              Column() {
                ForEach(this.sortList, (key: string) => {
                  FilterTagRow({
                    filterKey: key,
                    title: this.titleOf(key),
                    names: this.namesOf(key),
                    values: this.valuesOf(key),
                    selected: this.selectedFor(key),
                    onPick: (k: string, v: string) => {
                      this.pick(k, v);
                    }
                  })
                }, (key: string) => `row_${key}`)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ top: AppTheme.SPACE_SM, bottom: AppTheme.SPACE_SM })
              .backgroundColor(AppTheme.BG_ELEVATED)
            }

            ListItemGroup({ header: this.navHeader }) {
              if (this.listLoading) {
                ListItem() {
                  LoadingView({ label: '列表加载中' })
                }
              } else if (this.errorText) {
                ListItem() {
                  EmptyState({
                    title: '加载失败',
                    subtitle: this.errorText,
                    icon: $r('sys.symbol.info_circle')
                  })
                }
              } else if (this.films.length === 0) {
                ListItem() {
                  EmptyState({ title: '没有符合条件的影片', icon: $r('sys.symbol.film') })
                }
              } else {
                ForEach(this.rowIds(), (row: number) => {
                  ListItem() {
                    this.filmRow(row)
                  }
                }, (row: number) => `film_row_${this.gridCols()}_${row}_${this.films[row * this.gridCols()].id}`)
              }

              ListItem() {
                Text(this.loadingMore ? '加载中...' : (this.current >= this.pageCount ? '没有更多了' : ''))
                  .fontSize(12)
                  .fontColor(AppTheme.TEXT_MUTED)
                  .width('100%')
                  .height(40)
                  .textAlign(TextAlign.Center)
              }
            }
          }
          .sticky(StickyStyle.Header)
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
          .nestedScroll({
            scrollForward: NestedScrollMode.SELF_FIRST,
            scrollBackward: NestedScrollMode.SELF_FIRST
          })
          .onAreaChange((_oldValue: Area, newValue: Area) => {
            const h = Number(newValue.height);
            if (h > 0) {
              this.listHeight = h;
            }
          })
          .onDidScroll((_offset: number, _state: ScrollState) => {
            this.syncTopFab(this.scroller.currentOffset().yOffset);
          })
          .onReachEnd(() => {
            this.loadData(false);
          })
        }
      }
      .width('100%')
      .height('100%')
      .padding({
        top: this.topInset,
        bottom: this.bottomInset,
        left: this.leftInset,
        right: this.rightInset
      })
      .backgroundColor(AppTheme.BG)

      FloatingRefreshIndicator({
        pullDistance: this.pullDistance,
        refreshing: this.refreshing,
        topOffset: this.topInset + 16
      })

      if (!this.loading) {
        ScrollFab({
          visible: this.showTopFab,
          src: $r('sys.symbol.arrow_up'),
          bottom: this.bottomInset + AppTheme.SPACE_LG,
          right: this.rightInset + AppTheme.SPACE_LG,
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
