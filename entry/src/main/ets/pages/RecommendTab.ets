import { FilmApi } from '../api/FilmApi';
import { BannerItem, HomeSection } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { NavUtil } from '../common/utils/NavUtil';
import { FilmRow } from '../components/FilmRow';
import { LoadingView } from '../components/LoadingView';
import { EmptyState } from '../components/EmptyState';
import { AppIcon } from '../components/AppIcon';
import { HomeBanner } from '../components/HomeBanner';
import { SourceGuard } from '../common/utils/SourceGuard';
import { RefreshHint } from '../common/utils/RefreshHint';
import { Breakpoint } from '../common/utils/Breakpoint';

const CATEGORY_FONT_FAMILY: string = 'CalligraphyFont';
const CATEGORY_ICON_SIZE: number = 17;
const CATEGORY_ICON_RADIUS: number = 8.5;
const CATEGORY_TAG_HEIGHT: number = 32;
const CATEGORY_GLYPH_SIZE: number = 10;
const CATEGORY_LABEL_SIZE: number = 12.5;
const CATEGORY_ICON_BG: string = 'rgba(250, 140, 22, 0.12)';
const CATEGORY_ICON_BORDER: string = 'rgba(250, 140, 22, 0.28)';
const CATEGORY_ICON_BORDER_WIDTH: number = 0.6;
const CATEGORY_CHIP_BG: string = 'rgba(255, 255, 255, 0.05)';
const CATEGORY_CHIP_BORDER: string = 'rgba(255, 255, 255, 0.10)';
const CATEGORY_CHIP_BORDER_WIDTH: number = 0.8;
const CATEGORY_CHIP_BLUR: number = 20;

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
      this.banners = home.banners;
      this.sections = home.content;
      this.reloadToken = Date.now();
      ok = true;
    } catch (err) {
      this.errorText = err instanceof Error ? err.message : '首页加载失败';
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

  private visibleSections(): HomeSection[] {
    const list: HomeSection[] = [];
    for (let i = 0; i < this.sections.length; i++) {
      if (this.sections[i].nav.show !== false) {
        list.push(this.sections[i]);
      }
    }
    return list;
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
    Row({ space: AppTheme.SPACE_SM - 2 }) {
      if (this.categoryGlyph(section.nav.name)) {
        Row() {
          Text(this.categoryGlyph(section.nav.name))
            .fontFamily(CATEGORY_FONT_FAMILY)
            .fontSize(CATEGORY_GLYPH_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ACCENT)
        }
        .width(CATEGORY_ICON_SIZE)
        .height(CATEGORY_ICON_SIZE)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .borderRadius(CATEGORY_ICON_RADIUS)
        .backgroundColor(CATEGORY_ICON_BG)
        .border({ width: CATEGORY_ICON_BORDER_WIDTH, color: CATEGORY_ICON_BORDER })
        .clip(true)
      }
      Text(section.nav.name)
        .fontSize(CATEGORY_LABEL_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT_PRIMARY)
        .maxLines(1)
    }
    .height(CATEGORY_TAG_HEIGHT)
    .padding({ left: AppTheme.SPACE_SM - 2, right: AppTheme.SPACE_MD - 1 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(CATEGORY_CHIP_BG)
    .backdropBlur(CATEGORY_CHIP_BLUR)
    .borderRadius(AppTheme.RADIUS_PILL)
    .clip(true)
    .border({ width: CATEGORY_CHIP_BORDER_WIDTH, color: CATEGORY_CHIP_BORDER })
    .onClick(() => {
      NavUtil.openFilter(section.nav.id);
    })
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
      .backgroundColor(`rgba(${Math.round(22 * this.headerAlpha)}, ${Math.round(23 * this.headerAlpha)}, ${Math.round(31 * this.headerAlpha)}, ${0.36 + 0.64 * this.headerAlpha})`)
      .borderRadius(AppTheme.RADIUS_PILL)
      .border({
        width: 1,
        color: `rgba(255, 255, 255, ${0.16 * (1 - this.headerAlpha) + 0.08 * this.headerAlpha})`
      })
      .onClick(() => {
        if (this.onOpenSearch) {
          this.onOpenSearch();
        } else {
          NavUtil.openSearch();
        }
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
    .backgroundColor(`rgba(10, 11, 16, ${this.headerAlpha})`)
    .border({
      width: { bottom: this.headerAlpha > 0.5 ? 0.5 : 0 },
      color: `rgba(255, 255, 255, ${Math.max(0, (this.headerAlpha - 0.5) * 0.16)})`
    })
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

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 主页面滚动区
      if (this.loading) {
        LoadingView({ label: '正在加载推荐' })
          .width('100%')
          .height('100%')
          .padding({
            top: this.topInset,
            left: this.leftInset,
            right: this.rightInset
          })
      } else if (this.errorText) {
        Scroll() {
          Column() {
            Blank().height(80 + this.topInset)
            EmptyState({
              title: '加载失败',
              subtitle: this.errorText,
              icon: $r('sys.symbol.info_circle'),
              actionText: '重试',
              onAction: () => {
                this.loadHome(true, true);
              }
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({
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
      } else if (this.banners.length === 0 && this.visibleSections().length === 0) {
        Scroll() {
          Column() {
            Blank().height(80 + this.topInset)
            EmptyState({
              title: '暂无影片数据',
              subtitle: '当前软件源内暂无影片或尚未采集，可下拉刷新或更换软件源',
              icon: $r('sys.symbol.film')
            })
            Row({ space: 12 }) {
              Button() {
                Row() {
                  AppIcon({ src: $r('sys.symbol.arrow_counterclockwise'), iconSize: 14, color: AppTheme.TEXT_PRIMARY })
                  Text('刷新')
                    .fontSize(13)
                    .fontColor(AppTheme.TEXT_PRIMARY)
                    .margin({ left: 4 })
                }
              }
              .height(36)
              .padding({ left: 16, right: 16 })
              .backgroundColor(AppTheme.BG_CARD)
              .borderRadius(AppTheme.RADIUS_PILL)
              .onClick(() => {
                this.loadHome(true, true);
              })

              Button() {
                Row() {
                  AppIcon({ src: $r('sys.symbol.link'), iconSize: 14, color: AppTheme.TEXT_PRIMARY })
                  Text('更换软件源')
                    .fontSize(13)
                    .fontColor(AppTheme.TEXT_PRIMARY)
                    .margin({ left: 4 })
                }
              }
              .height(36)
              .padding({ left: 16, right: 16 })
              .backgroundColor(AppTheme.ACCENT)
              .borderRadius(AppTheme.RADIUS_PILL)
              .onClick(() => {
                try {
                  this.getUIContext().getRouter().pushUrl({ url: 'pages/ServerConfigPage' });
                } catch (_e) {
                }
              })
            }
            .margin({ top: 16 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({
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
      } else {
        Scroll(this.scroller) {
          Column() {
            HomeBanner({
              banners: this.banners,
              reloadToken: this.reloadToken
            })

            // 片库分类快捷导航胶囊
            if (this.visibleSections().length > 0) {
              Column() {
                Scroll() {
                  Row({ space: AppTheme.SPACE_SM }) {
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
              .margin({ bottom: AppTheme.SPACE_LG })
            }

            // 各分类影视横向推荐流（通栏无卡片沉浸背景带）
            ForEach(this.visibleSections(), (section: HomeSection) => {
              FilmRow({
                title: section.nav.name,
                films: section.movies.length > 0 ? section.movies : section.hot,
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
