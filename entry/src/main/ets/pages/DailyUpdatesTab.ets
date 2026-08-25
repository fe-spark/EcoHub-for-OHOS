import { FilmApi } from '../api/FilmApi';
import { CategoryItem, MovieBasicInfo } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FilmGrid } from '../components/FilmGrid';
import { LoadingView } from '../components/LoadingView';
import { EmptyState } from '../components/EmptyState';
import { AppIcon } from '../components/AppIcon';
import { NavUtil } from '../common/utils/NavUtil';
import { SourceGuard } from '../common/utils/SourceGuard';
import { RefreshHint } from '../common/utils/RefreshHint';

const FILTER_ALL = 0;
const FILTER_OTHER = -1;

@Component
export struct DailyUpdatesTab {
  @State private films: MovieBasicInfo[] = [];
  @State private nav: CategoryItem[] = [];
  @State private filterPid: number = FILTER_ALL;
  @State private loading: boolean = true;
  @State private refreshing: boolean = false;
  @State private errorText: string = '';

  private hasLoaded: boolean = false;
  @State private fetchLock: boolean = false;
  private reconnectCb: () => void = () => {};

  aboutToAppear() {
    this.reconnectCb = () => {
      this.loadData(false);
    };
    SourceGuard.onReconnect(this.reconnectCb);
    if (this.hasLoaded) {
      return;
    }
    this.hasLoaded = true;
    this.loadData(false);
  }

  aboutToDisappear(): void {
    SourceGuard.offReconnect(this.reconnectCb);
  }

  private async loadData(fromPull: boolean, showHint: boolean = false): Promise<void> {
    if (this.fetchLock) {
      return;
    }
    this.fetchLock = true;
    if (!fromPull) {
      this.loading = this.films.length === 0;
    }
    this.errorText = '';
    let ok = false;
    try {
      const list = await FilmApi.getDailyUpdates();
      const nav = await FilmApi.getNavCategory();
      this.films = list;
      this.nav = nav;
      if (!this.filterStillValid()) {
        this.filterPid = FILTER_ALL;
      }
      ok = true;
    } catch (err) {
      this.errorText = err instanceof Error ? err.message : '每日更新加载失败';
    } finally {
      this.fetchLock = false;
      this.loading = false;
      this.refreshing = false;
      if (showHint && ok) {
        RefreshHint.succeed();
      }
    }
  }

  private isKnownPid(pid: number): boolean {
    for (let i = 0; i < this.nav.length; i++) {
      if (this.nav[i].id === pid) {
        return true;
      }
    }
    return false;
  }

  private countOf(pid: number): number {
    if (pid === FILTER_ALL) {
      return this.films.length;
    }
    let n = 0;
    for (let i = 0; i < this.films.length; i++) {
      const filmPid = this.films[i].pid;
      if (pid === FILTER_OTHER) {
        if (!this.isKnownPid(filmPid)) {
          n++;
        }
      } else if (filmPid === pid) {
        n++;
      }
    }
    return n;
  }

  private visibleNav(): CategoryItem[] {
    const list: CategoryItem[] = [];
    for (let i = 0; i < this.nav.length; i++) {
      const item = this.nav[i];
      if (item.show === false) {
        continue;
      }
      if (this.countOf(item.id) > 0) {
        list.push(item);
      }
    }
    return list;
  }

  private showNavFilter(): boolean {
    const n = this.visibleNav().length + (this.countOf(FILTER_OTHER) > 0 ? 1 : 0);
    return n > 1;
  }

  private filterStillValid(): boolean {
    if (this.filterPid === FILTER_ALL) {
      return true;
    }
    return this.countOf(this.filterPid) > 0;
  }

  private filterLabel(): string {
    if (this.filterPid === FILTER_ALL) {
      return `近 24 小时  ${this.films.length} 部`;
    }
    if (this.filterPid === FILTER_OTHER) {
      return `其他  ${this.countOf(FILTER_OTHER)} 部`;
    }
    for (let i = 0; i < this.nav.length; i++) {
      if (this.nav[i].id === this.filterPid) {
        return `${this.nav[i].name}  ${this.countOf(this.filterPid)} 部`;
      }
    }
    return `近 24 小时  ${this.films.length} 部`;
  }

  private shownFilms(): MovieBasicInfo[] {
    if (this.filterPid === FILTER_ALL) {
      return this.films;
    }
    const list: MovieBasicInfo[] = [];
    for (let i = 0; i < this.films.length; i++) {
      const filmPid = this.films[i].pid;
      if (this.filterPid === FILTER_OTHER) {
        if (!this.isKnownPid(filmPid)) {
          list.push(this.films[i]);
        }
      } else if (filmPid === this.filterPid) {
        list.push(this.films[i]);
      }
    }
    return list;
  }

  @Builder
  filterChip(pid: number, label: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(this.filterPid === pid ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.filterPid === pid ? AppTheme.TEXT_PRIMARY : AppTheme.TEXT_SECONDARY)
      .height(32)
      .padding({ left: AppTheme.SPACE_MD, right: AppTheme.SPACE_MD })
      .backgroundColor(this.filterPid === pid ? AppTheme.ACCENT : AppTheme.BG_CARD)
      .borderRadius(AppTheme.RADIUS_PILL)
      .onClick(() => {
        this.filterPid = pid;
      })
  }

  build() {
    Column() {
      Column() {
        Row() {
          Row() {
            AppIcon({ src: $r('sys.symbol.flame_fill'), iconSize: 22, color: AppTheme.ACCENT })
            Text('每日更新')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT_PRIMARY)
              .margin({ left: AppTheme.SPACE_SM })
          }
          .layoutWeight(1)
          .alignItems(VerticalAlign.Center)

          Row() {
            AppIcon({ src: $r('sys.symbol.magnifyingglass'), iconSize: 18, color: AppTheme.TEXT_SECONDARY })
          }
          .width(36)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppTheme.BG_CARD)
          .borderRadius(18)
          .onClick(() => {
            NavUtil.openSearch();
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.filterLabel())
          .fontSize(12)
          .fontColor(AppTheme.TEXT_MUTED)
          .width('100%')
          .margin({ top: AppTheme.SPACE_SM })
      }
      .width('100%')
      .padding({
        left: AppTheme.SPACE_LG,
        right: AppTheme.SPACE_LG,
        top: AppTheme.SPACE_SM,
        bottom: AppTheme.SPACE_MD
      })

      if (this.showNavFilter()) {
        Scroll() {
          Row({ space: AppTheme.SPACE_SM }) {
            this.filterChip(FILTER_ALL, '全部')
            ForEach(this.visibleNav(), (item: CategoryItem) => {
              this.filterChip(item.id, item.name)
            }, (item: CategoryItem) => `${item.id}`)
            if (this.countOf(FILTER_OTHER) > 0) {
              this.filterChip(FILTER_OTHER, '其他')
            }
          }
          .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG })
          .justifyContent(FlexAlign.Start)
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .align(Alignment.Start)
        .width('100%')
        .margin({ bottom: AppTheme.SPACE_MD })
      }

      if (this.loading) {
        LoadingView({ label: '正在加载今日更新' })
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
          this.loadData(true, true);
        })
        .pullToRefresh(!this.fetchLock)
        .layoutWeight(1)
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          FilmGrid({ films: this.shownFilms(), nestedRefresh: true })
            .width('100%')
            .height('100%')
            .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG })
        }
        .onRefreshing(() => {
          if (this.fetchLock) {
            return;
          }
          this.loadData(true, true);
        })
        .pullToRefresh(!this.fetchLock)
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BG)
  }
}
