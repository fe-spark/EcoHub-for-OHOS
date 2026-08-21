import { FilmApi } from '../api/FilmApi';
import { BannerItem, HomeSection, MovieBasicInfo } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { NavUtil } from '../common/utils/NavUtil';
import { FilmRow } from '../components/FilmRow';
import { LoadingView } from '../components/LoadingView';
import { EmptyState } from '../components/EmptyState';
import { AppIcon } from '../components/AppIcon';
import { SourceGuard } from '../common/utils/SourceGuard';
import { RefreshHint } from '../common/utils/RefreshHint';

@Component
export struct RecommendTab {
  onOpenSearch?: () => void;
  @Prop siteName: string = 'EcoHub';
  @Prop @Watch('onActiveChange') active: boolean = true;
  @State private banners: BannerItem[] = [];
  @State private sections: HomeSection[] = [];
  @State private loading: boolean = true;
  @State private refreshing: boolean = false;
  @State private errorText: string = '';
  @State private headerAlpha: number = 0;
  private scroller: Scroller = new Scroller();

  private hasLoaded: boolean = false;
  private wasActive: boolean = false;
  @State private fetchLock: boolean = false;
  private reconnectCb: () => void = () => {};

  aboutToAppear() {
    this.wasActive = this.active;
    this.reconnectCb = () => {
      this.loadHome(false);
    };
    SourceGuard.onReconnect(this.reconnectCb);
    if (this.hasLoaded) {
      return;
    }
    this.hasLoaded = true;
    this.loadHome(false);
  }

  aboutToDisappear(): void {
    SourceGuard.offReconnect(this.reconnectCb);
  }

  onActiveChange(): void {
    const becameActive = this.active && !this.wasActive;
    this.wasActive = this.active;
    if (!becameActive || !this.hasLoaded || this.fetchLock) {
      return;
    }
    this.refreshing = true;
    this.loadHome(true, false);
  }

  private async loadHome(fromPull: boolean, showHint: boolean = false): Promise<void> {
    if (this.fetchLock) {
      return;
    }
    this.fetchLock = true;
    this.loading = !fromPull && this.banners.length === 0 && this.sections.length === 0;
    this.errorText = '';
    let ok = false;
    try {
      const home = await FilmApi.getHome();
      this.banners = this.buildHeroDeck(home.banners, home.content);
      this.sections = home.content;
      ok = true;
    } catch (err) {
      this.errorText = err instanceof Error ? err.message : '首页加载失败';
    } finally {
      this.fetchLock = false;
      this.loading = false;
      this.refreshing = false;
      if (showHint && ok) {
        RefreshHint.succeed();
      }
    }
  }

  private buildHeroDeck(banners: BannerItem[], content: HomeSection[]): BannerItem[] {
    const seen: string[] = [];
    const deck: BannerItem[] = [];
    const pushBanner = (item: BannerItem) => {
      const id = item.mid > 0 ? `${item.mid}` : item.id;
      if (!id || seen.indexOf(id) >= 0) {
        return;
      }
      if (!item.picture && !item.poster && !item.pictureSlide) {
        return;
      }
      seen.push(id);
      deck.push(item);
    };
    for (let i = 0; i < banners.length; i++) {
      pushBanner(banners[i]);
    }
    for (let s = 0; s < content.length && deck.length < 5; s++) {
      const movies = content[s].hot.concat(content[s].movies);
      for (let i = 0; i < movies.length && deck.length < 5; i++) {
        const film = movies[i];
        const banner: BannerItem = {
          id: `${film.id}`,
          mid: film.id,
          name: film.name,
          year: film.year,
          cName: film.cName,
          poster: film.picture,
          picture: film.picture,
          pictureSlide: film.pictureSlide,
          remark: film.remarks,
          blurb: film.blurb,
          area: film.area
        };
        pushBanner(banner);
      }
    }
    return deck;
  }

  private updateHeaderAlpha(): void {
    const offset = this.scroller.currentOffset();
    const y = offset.yOffset;
    const next = Math.min(1, Math.max(0, y / 180));
    if (Math.abs(next - this.headerAlpha) >= 0.02) {
      this.headerAlpha = next;
    }
  }

  private headerBg(): string {
    return `rgba(10, 11, 16, ${this.headerAlpha.toFixed(2)})`;
  }

  private visibleSections(): HomeSection[] {
    const list: HomeSection[] = [];
    for (let i = 0; i < this.sections.length; i++) {
      if (this.sections[i].nav.show !== false) {
        list.push(this.sections[i]);
      }
    }
    return list;
  }

  @Builder
  categoryEntry(section: HomeSection) {
    Text(section.nav.name)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor('#FFFFFF')
      .maxLines(1)
      .height(36)
      .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG })
      .backgroundColor(FormatUtil.tagBg(section.nav.id, section.nav.name))
      .borderRadius(AppTheme.RADIUS_PILL)
      .border({ width: 1, color: FormatUtil.tagBorder(section.nav.id, section.nav.name) })
      .onClick(() => {
        NavUtil.openFilter(section.nav.id);
      })
  }

  @Builder
  heroItem(item: BannerItem) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(FormatUtil.bannerBackdrop(item))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['rgba(10,11,16,0.08)', 0], ['rgba(10,11,16,0.12)', 0.4], ['rgba(10,11,16,0.92)', 1]]
        })
      Column() {
        if (item.remark) {
          Text(item.remark)
            .fontSize(11)
            .fontColor('#FFFFFF')
            .padding({ left: AppTheme.SPACE_SM, right: AppTheme.SPACE_SM, top: AppTheme.SPACE_XS, bottom: AppTheme.SPACE_XS })
            .backgroundColor(AppTheme.ACCENT)
            .borderRadius(AppTheme.RADIUS_SM)
            .margin({ bottom: AppTheme.SPACE_SM })
        }
        Text(item.name)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .maxLines(2)
        Text(FormatUtil.joinMeta([item.year, item.cName, item.area]))
          .fontSize(12)
          .fontColor(AppTheme.TEXT_SECONDARY)
          .margin({ top: AppTheme.SPACE_SM })
        Row() {
          AppIcon({ src: $r('sys.symbol.play_fill'), iconSize: 14, color: AppTheme.TEXT_PRIMARY })
          Text('立即播放')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .margin({ left: AppTheme.SPACE_SM })
        }
        .height(40)
        .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG })
        .backgroundColor(AppTheme.ACCENT)
        .borderRadius(AppTheme.RADIUS_PILL)
        .margin({ top: AppTheme.SPACE_LG })
        .onClick(() => {
          NavUtil.openPlay(item.mid > 0 ? item.mid : item.id);
        })
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG, bottom: AppTheme.SPACE_XL })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.loading) {
        LoadingView({ label: '正在加载推荐' })
      } else if (this.errorText) {
        EmptyState({
          title: '加载失败',
          subtitle: this.errorText,
          icon: $r('sys.symbol.info_circle')
        })
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          Scroll(this.scroller) {
            Column() {
              if (this.banners.length > 0) {
                Swiper() {
                  ForEach(this.banners, (item: BannerItem) => {
                    this.heroItem(item)
                  }, (item: BannerItem) => item.id)
                }
                .autoPlay(this.banners.length > 1)
                .interval(4800)
                .loop(this.banners.length > 1)
                .indicator(this.banners.length > 1)
                .indicatorStyle({
                  selectedColor: AppTheme.ACCENT,
                  color: '#66FFFFFF'
                })
                .width('100%')
                .height(360)
                .margin({ bottom: AppTheme.SPACE_LG })
              } else {
                Column().height(56)
              }

              if (this.visibleSections().length > 0) {
                Column() {
                  Text('片库分类')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.TEXT_PRIMARY)
                    .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG })
                    .margin({ bottom: AppTheme.SPACE_MD })

                  Scroll() {
                    Row({ space: AppTheme.SPACE_SM }) {
                      ForEach(this.visibleSections(), (section: HomeSection) => {
                        this.categoryEntry(section)
                      }, (section: HomeSection) => `cat_${section.nav.id}`)
                    }
                    .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG })
                    .justifyContent(FlexAlign.Start)
                  }
                  .scrollable(ScrollDirection.Horizontal)
                  .scrollBar(BarState.Off)
                  .align(Alignment.Start)
                  .width('100%')
                  .nestedScroll({
                    scrollForward: NestedScrollMode.SELF_FIRST,
                    scrollBackward: NestedScrollMode.SELF_FIRST
                  })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .margin({ bottom: AppTheme.SPACE_LG })
              }

              ForEach(this.visibleSections(), (section: HomeSection) => {
                FilmRow({
                  title: section.nav.name,
                  films: section.movies.length > 0 ? section.movies : section.hot,
                  pid: section.nav.id,
                  onMore: () => {
                    NavUtil.openFilter(section.nav.id);
                  }
                })
              }, (section: HomeSection) => `${section.nav.id}`)
            }
            .width('100%')
            .padding({ bottom: AppTheme.SPACE_LG })
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .onDidScroll((_x: number, _y: number, _state: ScrollState) => {
            this.updateHeaderAlpha();
          })
        }
        .onRefreshing(() => {
          if (this.fetchLock) {
            return;
          }
          this.loadHome(true, true);
        })
        .pullToRefresh(!this.fetchLock)
        .width('100%')
        .height('100%')
      }

      Row() {
        Text(this.siteName)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ right: AppTheme.SPACE_MD })

        Row() {
          AppIcon({
            src: $r('sys.symbol.magnifyingglass'),
            iconSize: 16,
            color: AppTheme.TEXT_SECONDARY
          })
          Text('搜索')
            .fontSize(13)
            .fontColor(AppTheme.TEXT_SECONDARY)
            .margin({ left: AppTheme.SPACE_SM })
        }
        .height(36)
        .padding({ left: AppTheme.SPACE_MD, right: AppTheme.SPACE_LG })
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.headerAlpha > 0.55 ? AppTheme.BG_CHIP : 'rgba(0,0,0,0.42)')
        .borderRadius(AppTheme.RADIUS_PILL)
        .border({
          width: 1,
          color: this.headerAlpha > 0.55 ? AppTheme.BORDER : 'rgba(255,255,255,0.14)'
        })
        .onClick(() => {
          if (this.onOpenSearch) {
            this.onOpenSearch();
          }
        })
      }
      .width('100%')
      .height(52)
      .padding({
        left: AppTheme.SPACE_LG,
        right: AppTheme.SPACE_LG
      })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.headerBg())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BG)
  }
}
