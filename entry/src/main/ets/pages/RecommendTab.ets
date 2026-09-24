import { FilmApi } from '../api/FilmApi';
import { BannerItem, HomeSection, MovieBasicInfo } from '../types/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { NavUtil } from '../common/utils/NavUtil';
import { FilmRow } from '../components/film/FilmRow';
import { LoadingView } from '../components/common/LoadingView';
import { EmptyState } from '../components/common/EmptyState';
import { AppIcon } from '../components/common/AppIcon';
import { HomeBanner } from '../components/film/HomeBanner';
import { SourceGuard } from '../services/SourceGuard';
import { FavoriteManager } from '../services/FavoriteManager';
import { RefreshHint } from '../common/utils/RefreshHint';
import { Breakpoint } from '../common/utils/Breakpoint';

const CAT_FONT: string = 'CalligraphyFont';
const CAT_ICON_BG: string = 'rgba(250, 140, 22, 0.12)';
const CAT_ICON_BORDER: string = 'rgba(250, 140, 22, 0.28)';
const CAT_CHIP_BG: string = 'rgba(255, 255, 255, 0.05)';
const CAT_CHIP_BORDER: string = 'rgba(255, 255, 255, 0.10)';

@Component
export struct RecommendTab {
  onOpenSearch?: () => void;
  @Prop siteName: string = 'EcoHub';
  @State private banners: BannerItem[] = [];
  @State private sections: HomeSection[] = [];
  @State private loading: boolean = true;
  @State private refreshing: boolean = false;
  @State private errorText: string = '';
  private scroller: Scroller = new Scroller();
  @State private reloadToken: number = 0;
  @State private headerAlpha: number = 0;
  @StorageLink('WIDTH_BP') private widthBp: string = 'sm';
  @StorageLink('SAFE_INSET_TOP') private topInset: number = 0;
  @StorageLink('SAFE_INSET_LEFT') private leftInset: number = 0;
  @StorageLink('SAFE_INSET_RIGHT') private rightInset: number = 0;
  @State private pullDistance: number = 0;
  @State private isPulling: boolean = false;
  private touchStartY: number = 0;
  private touchStartX: number = 0;
  private hasLoaded: boolean = false;
  @State private fetchLock: boolean = false;
  private reconnectCb: () => void = () => {};

  aboutToAppear() {
    FavoriteManager.preload();
    this.reconnectCb = () => {
      FavoriteManager.preload();
      this.loadHome(false);
    };
    SourceGuard.onReconnect(this.reconnectCb);
    if (this.hasLoaded) return;
    this.hasLoaded = true;
    this.loadHome(false);
  }

  aboutToDisappear(): void {
    SourceGuard.offReconnect(this.reconnectCb);
  }

  private async loadHome(fromPull: boolean, showHint: boolean = false): Promise<void> {
    if (this.fetchLock) {
      return;
    }
    this.fetchLock = true;
    if (!fromPull) {
      this.banners = [];
      this.sections = [];
      this.loading = true;
      this.errorText = '';
    }
    let ok = false;
    try {
      const home = await FilmApi.getHome();
      this.banners = home.banners;
      this.sections = home.content;
      this.reloadToken = Date.now();
      this.errorText = '';
      ok = true;
    } catch (err) {
      this.errorText = err instanceof Error ? err.message : `${err}`;
    } finally {
      this.fetchLock = false;
      this.loading = false;
      this.getUIContext()?.animateTo({ duration: 240, curve: Curve.EaseIn }, () => {
        this.pullDistance = 0;
      });
      setTimeout(() => {
        this.refreshing = false;
      }, 240);
      if (showHint && ok) {
        RefreshHint.succeed();
      }
    }
  }

  private sectionFilms(sec: HomeSection): MovieBasicInfo[] {
    return (sec.movies && sec.movies.length > 0) ? sec.movies : ((sec.hot && sec.hot.length > 0) ? sec.hot : []);
  }

  private visibleSections(): HomeSection[] {
    return this.sections.filter((s: HomeSection) => s.nav.show !== false && this.sectionFilms(s).length > 0);
  }

  private categoryGlyph(name: string): string {
    const text = (name || '').trim();
    if (!text) {
      return '';
    }
    const chars = Array.from(text);
    return chars.length > 0 ? chars[0] : '';
  }

  @Builder
  categoryEntry(section: HomeSection) {
    Row({ space: this.isWide() ? 6 : (AppTheme.SPACE_SM - 2) }) {
      if (this.categoryGlyph(section.nav.name)) {
        Row() {
          Text(this.categoryGlyph(section.nav.name))
            .fontFamily(CAT_FONT)
            .fontSize(this.isWide() ? 11 : 10)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ACCENT)
        }
        .width(this.isWide() ? 19 : 17).height(this.isWide() ? 19 : 17)
        .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
        .borderRadius(this.isWide() ? 9.5 : 8.5)
        .backgroundColor(this.isWide() ? 'rgba(250, 140, 22, 0.14)' : CAT_ICON_BG)
        .border({ width: this.isWide() ? 0.7 : 0.6, color: this.isWide() ? 'rgba(250, 140, 22, 0.32)' : CAT_ICON_BORDER })
        .clip(true)
      }
      Text(section.nav.name)
        .fontSize(this.isWide() ? 13.5 : 13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT_PRIMARY)
        .maxLines(1)
    }
    .height(this.isWide() ? 35 : 32)
    .padding({ left: this.isWide() ? 8 : (AppTheme.SPACE_SM - 2), right: this.isWide() ? 13 : (AppTheme.SPACE_MD - 1) })
    .justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
    .backgroundColor(this.isWide() ? 'rgba(255, 255, 255, 0.06)' : CAT_CHIP_BG)
    .backdropBlur(20)
    .borderRadius(AppTheme.RADIUS_PILL).clip(true)
    .border({ width: this.isWide() ? 0.8 : 0.8, color: this.isWide() ? 'rgba(255, 255, 255, 0.12)' : CAT_CHIP_BORDER })
    .onClick(() => { NavUtil.openFilter(section.nav.id); })
  }

  private isWide(): boolean {
    return Breakpoint.isWide(this.widthBp);
  }

  private effectiveHeaderAlpha(): number {
    if (this.banners.length === 0) {
      return 1.0;
    }
    return Breakpoint.isWide(this.widthBp) ? Math.min(0.92, 0.76 + 0.16 * this.headerAlpha) : this.headerAlpha;
  }

  @Builder
  headerRow() {
    Row() {
      // 站点 Logo + 名称
      Row({ space: 6 }) {
        AppIcon({
          src: $r('sys.symbol.play_square_stack_fill'),
          iconSize: 20,
          color: AppTheme.ACCENT
        })
        Text(this.siteName)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textShadow({
            radius: 8,
            color: 'rgba(0, 0, 0, 0.85)',
            offsetY: 1
          })
      }
      .layoutWeight(1)

      // 搜索胶囊（背景与边框随滚动深度平滑变色）
      Row({ space: 6 }) {
        AppIcon({
          src: $r('sys.symbol.magnifyingglass'),
          iconSize: 14,
          color: 'rgba(255, 255, 255, 0.75)'
        })
        Text('搜索')
          .fontSize(12)
          .fontColor('rgba(255, 255, 255, 0.55)')
      }
      .height(34)
      .padding({ left: 12, right: 14 })
      .backgroundColor(`rgba(${Math.round(22 * this.effectiveHeaderAlpha())}, ${Math.round(23 * this.effectiveHeaderAlpha())}, ${Math.round(31 * this.effectiveHeaderAlpha())}, ${0.36 + 0.64 * this.effectiveHeaderAlpha()})`)
      .borderRadius(AppTheme.RADIUS_PILL)
      .border({
        width: 1,
        color: `rgba(255, 255, 255, ${0.16 * (1 - this.effectiveHeaderAlpha()) + 0.08 * this.effectiveHeaderAlpha()})`
      })
      .onClick(() => {
        if (this.onOpenSearch) this.onOpenSearch(); else NavUtil.openSearch();
      })
    }
    .width('100%')
    .height(48 + this.topInset)
    .padding({
      top: this.topInset,
      left: AppTheme.SPACE_LG + this.leftInset,
      right: AppTheme.SPACE_LG + this.rightInset
    })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(`rgba(10, 11, 16, ${this.effectiveHeaderAlpha()})`)
    .backdropBlur(this.isWide() || this.headerAlpha > 0 ? 25 : 0)
    .border({
      width: { bottom: (this.isWide() || this.headerAlpha > 0.5) ? 0.5 : 0 },
      color: `rgba(255, 255, 255, ${this.isWide() ? 0.08 : Math.max(0, (this.headerAlpha - 0.5) * 0.16)})`
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  private handleTouch(event: TouchEvent): void {
    if (this.refreshing || this.fetchLock || this.errorText) return;
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
          this.loadHome(true, true);
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
          .width(22)
          .height(22)
          .color(AppTheme.ACCENT)
      }
      .width(38)
      .height(38)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('rgba(26, 28, 36, 0.75)')
      .backdropBlur(25)
      .borderRadius(19)
      .border({ width: 0.8, color: 'rgba(255, 255, 255, 0.12)' })
      .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.38)', offsetY: 2 })
      .position({
        x: '50%',
        y: this.topInset + 48 + this.pullDistance - 38
      })
      .markAnchor({ x: '50%', y: 0 })
      .opacity(Math.max(0, Math.min(1.0, (this.pullDistance - 4) / 16)))
      .scale({
        x: Math.min(1.0, 0.5 + 0.5 * (this.pullDistance / 46)),
        y: Math.min(1.0, 0.5 + 0.5 * (this.pullDistance / 46))
      })
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  @Builder
  centeredState(title: string, subtitle: string, icon: Resource, retryText: string, onRetry: () => void) {
    Scroll() {
      Column() {
        EmptyState({ title: title, subtitle: subtitle, icon: icon }) {
          this.stateActions(retryText, onRetry)
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({
        top: 48 + this.topInset,
        left: this.leftInset,
        right: this.rightInset
      })
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

  @Builder
  stateActions(retryText: string, onRetry: () => void) {
    Column({ space: 12 }) {
      Button() {
        Row() {
          AppIcon({ src: $r('sys.symbol.link'), iconSize: 15, color: AppTheme.TEXT_PRIMARY })
          Text('更换软件源').fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT_PRIMARY).margin({ left: 6 })
        }
      }
      .width(148).height(38).backgroundColor(AppTheme.ACCENT).borderRadius(AppTheme.RADIUS_PILL)
      .onClick(() => {
        try { this.getUIContext().getRouter().pushUrl({ url: 'pages/ServerConfigPage' }); } catch (_e) {}
      })

      Button() {
        Row() {
          AppIcon({ src: $r('sys.symbol.arrow_counterclockwise'), iconSize: 15, color: AppTheme.TEXT_PRIMARY })
          Text(retryText).fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT_PRIMARY).margin({ left: 6 })
        }
      }
      .width(148).height(38).backgroundColor(AppTheme.BG_CARD).borderRadius(AppTheme.RADIUS_PILL)
      .onClick(onRetry)
    }.margin({ top: 16 }).width('100%').alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 主页面滚动区
      if (this.loading) {
        LoadingView({ label: '正在加载推荐' })
          .width('100%')
          .height('100%')
          .padding({
            top: 48 + this.topInset,
            left: this.leftInset,
            right: this.rightInset
          })
      } else if (this.errorText) {
        this.centeredState('加载失败', this.errorText, $r('sys.symbol.info_circle'), '刷新', () => { this.loadHome(false, true); })
      } else if (this.banners.length === 0 && this.visibleSections().length === 0) {
        this.centeredState('暂无影片数据', '当前软件源内暂无影片或尚未采集，可下拉刷新或更换软件源', $r('sys.symbol.film'), '刷新', () => { this.loadHome(true, true); })
      } else {
        Scroll(this.scroller) {
          Column() {
            Blank().height(
              Breakpoint.isWide(this.widthBp)
                ? (48 + this.topInset + 8)
                : (this.banners.length === 0 ? (48 + this.topInset + 12) : 0)
            )

            HomeBanner({
              banners: this.banners,
              reloadToken: this.reloadToken
            })

            // 片库分类快捷导航胶囊
            if (this.visibleSections().length > 0) {
              Column() {
                Scroll() {
                  Row({ space: this.isWide() ? 8 : AppTheme.SPACE_SM }) {
                    ForEach(this.visibleSections(), (section: HomeSection) => {
                      this.categoryEntry(section)
                    }, (section: HomeSection) => `cat_${section.nav.id}_${this.reloadToken}`)
                  }
                  .padding({
                    left: AppTheme.SPACE_LG + this.leftInset,
                    right: AppTheme.SPACE_LG + this.rightInset
                  })
                  .justifyContent(FlexAlign.Start)
                }
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
                .align(Alignment.Start)
                .width('100%')
                .nestedScroll({
                  scrollForward: NestedScrollMode.SELF_FIRST,
                  scrollBackward: NestedScrollMode.SELF_FIRST
                })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .margin({ bottom: this.isWide() ? 14 : AppTheme.SPACE_LG })
            }

            // 各分类影视横向推荐流（通栏无卡片沉浸背景带）
            ForEach(this.visibleSections(), (section: HomeSection) => {
              FilmRow({
                title: section.nav.name,
                films: this.sectionFilms(section),
                pid: section.nav.id,
                onMore: () => {
                  NavUtil.openFilter(section.nav.id);
                }
              })
            }, (section: HomeSection) => `sec_${section.nav.id}_${this.reloadToken}`)
          }
          .width('100%')
          .padding({ bottom: 0 })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .nestedScroll({
          scrollForward: NestedScrollMode.SELF_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST
        })
        .onDidScroll((_x: number, _y: number, _state: ScrollState) => {
          const y = this.scroller.currentOffset().yOffset;
          if (y <= 0) {
            if (this.headerAlpha !== 0) {
              this.headerAlpha = 0;
            }
          } else {
            const alpha = Math.min(1.0, y / 160.0);
            if (Math.abs(this.headerAlpha - alpha) > 0.01 || alpha === 1.0 || alpha === 0.0) {
              this.headerAlpha = alpha;
            }
          }
        })
        .width('100%')
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      }

      // 2. 状态栏安全区悬浮刷新指示器（位于内容之上，Header 之下）
      this.floatingRefreshIndicator()

      // 3. 连续 60fps 渐变 Header（位于顶层，背景随滚动深度无缝过渡 0.0 -> 1.0）
      this.headerRow()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    .onTouch((event: TouchEvent) => {
      this.handleTouch(event);
    })
  }
}
