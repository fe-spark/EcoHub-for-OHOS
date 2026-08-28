import { router } from '@kit.ArkUI';
import { FilmApi } from '../api/FilmApi';
import { FilterResult, MovieBasicInfo } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { NavUtil } from '../common/utils/NavUtil';
import { WindowBar } from '../common/utils/WindowBar';
import { common } from '@kit.AbilityKit';
import { QueryParams } from '../common/utils/QueryParams';
import { LoadingView } from '../components/LoadingView';
import { EmptyState } from '../components/EmptyState';
import { BackIcon } from '../components/BackIcon';
import { FilterTagRow } from '../components/FilterTagRow';
import { ScrollFab } from '../components/ScrollFab';
import { FilmCard } from '../components/FilmCard';
import { SourceGuard } from '../common/utils/SourceGuard';
import { HttpClient } from '../common/network/HttpClient';
import { RefreshHint } from '../common/utils/RefreshHint';

const GRID_COLS = 3;

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
  @State private fetchLock: boolean = false;
  @State private listHeight: number = 0;
  @State private showTopFab: boolean = false;
  private reconnectCb: () => void = () => {};
  private scroller: Scroller = new Scroller();

  private applyWindowBar(): void {
    WindowBar.apply(getContext(this) as common.UIAbilityContext, (top: number, bottom: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
    });
  }

  aboutToAppear() {
    this.applyWindowBar();
    const params = router.getParams() as Object;
    this.pid = NavUtil.param(params, 'Pid');
    HttpClient.getInstance().trackView('classify', this.pid);
    const category = NavUtil.param(params, 'Category');
    const sort = NavUtil.param(params, 'Sort');
    if (category) {
      this.setSelected('Category', category);
    }
    if (sort) {
      this.setSelected('Sort', sort);
    }
    this.loadData(true, false);
    this.reconnectCb = () => {
      this.loadData(true, false);
    };
    SourceGuard.onReconnect(this.reconnectCb);
  }

  onPageShow(): void {
    this.applyWindowBar();
  }

  aboutToDisappear(): void {
    SourceGuard.offReconnect(this.reconnectCb);
  }

  private selectedOf(key: string): string {
    const index = this.selectedKeys.indexOf(key);
    return index >= 0 ? this.selectedValues[index] : '';
  }

  private isChipOn(key: string, value: string): boolean {
    let current = this.selectedOf(key);
    if (key === 'Sort' && !current) {
      current = 'update_stamp';
    }
    return current === value;
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
    if (this.isChipOn(key, value) || this.fetchLock) {
      return;
    }
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
    let value = this.selectedOf(key);
    if (key === 'Sort' && !value) {
      return 'update_stamp';
    }
    return value;
  }

  private async loadData(reset: boolean, fromPull: boolean = false): Promise<void> {
    if (!this.pid) {
      this.errorText = '缺少分类信息';
      this.loading = false;
      this.listLoading = false;
      this.refreshing = false;
      return;
    }
    const page = reset ? 1 : this.current + 1;
    if (!reset && (this.loadingMore || page > this.pageCount)) {
      return;
    }
    if (this.fetchLock) {
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
    try {
      const result = await FilmApi.getFilter(this.buildQuery(page));
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
      this.refreshing = false;
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
    if (!value) {
      return '';
    }
    const values = this.valuesOf(key);
    const names = this.namesOf(key);
    for (let i = 0; i < values.length; i++) {
      if (values[i] === value) {
        return names[i] || value;
      }
    }
    return value;
  }

  private selectedTagKeys(): string[] {
    const keys: string[] = [];
    for (let i = 0; i < this.sortList.length; i++) {
      const key = this.sortList[i];
      const label = this.labelOf(key, this.selectedFor(key));
      if (label && label !== '全部') {
        keys.push(key);
      }
    }
    return keys;
  }

  private rowIds(): number[] {
    const n = Math.ceil(this.films.length / GRID_COLS);
    const ids: number[] = [];
    for (let i = 0; i < n; i++) {
      ids.push(i);
    }
    return ids;
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
    .padding({
      left: AppTheme.SPACE_MD,
      right: AppTheme.SPACE_MD,
      bottom: AppTheme.SPACE_MD
    })
  }

  @Builder
  navHeader() {
    Row() {
      Row() {
        BackIcon({ color: AppTheme.TEXT_PRIMARY, iconSize: 24 })
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        router.back();
      })

      List({ space: AppTheme.SPACE_SM }) {
        ForEach(this.selectedTagKeys(), (key: string) => {
          ListItem() {
            Text(this.labelOf(key, this.selectedFor(key)))
              .fontSize(12)
              .fontColor(AppTheme.ACCENT)
              .height(28)
              .padding({ left: AppTheme.SPACE_MD, right: AppTheme.SPACE_MD })
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: AppTheme.ACCENT })
              .borderRadius(AppTheme.RADIUS_PILL)
          }
        }, (key: string) => `nav_tag_${key}`)
      }
      .listDirection(Axis.Horizontal)
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })
      .height(28)
      .contentEndOffset(AppTheme.SPACE_SM)
      .scrollBar(BarState.Off)
      .nestedScroll({
        scrollForward: NestedScrollMode.SELF_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })
      .alignListItem(ListItemAlign.Center)
      .margin({ left: AppTheme.SPACE_XS })

      if (this.total > 0) {
        Text(`共 ${this.total} 部`)
          .fontSize(12)
          .fontColor(AppTheme.TEXT_MUTED)
          .margin({ left: AppTheme.SPACE_SM })
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: AppTheme.SPACE_SM, right: AppTheme.SPACE_LG })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.BG)
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        if (this.loading) {
          Row() {
            Row() {
              BackIcon({ color: AppTheme.TEXT_PRIMARY, iconSize: 24 })
            }
            .width(32)
            .height(32)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              router.back();
            })
          }
          .width('100%')
          .height(48)
          .padding({ left: AppTheme.SPACE_SM })
          .alignItems(VerticalAlign.Center)
          LoadingView({ label: '加载中' })
        } else {
          Refresh({ refreshing: $$this.refreshing }) {
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
                  }, (row: number) => `film_row_${row}_${this.films[row * GRID_COLS].id}`)
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
            .height('100%')
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
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
          .onRefreshing(() => {
            if (this.fetchLock) {
              this.refreshing = false;
              return;
            }
            this.loadData(true, true);
          })
          .pullToRefresh(!this.fetchLock)
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.topInset, bottom: this.bottomInset })
      .backgroundColor(AppTheme.BG)

      if (!this.loading) {
        ScrollFab({
          visible: this.showTopFab,
          src: $r('sys.symbol.arrow_up'),
          bottom: this.bottomInset + AppTheme.SPACE_LG,
          onClickFab: () => {
            this.scrollToTop();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
