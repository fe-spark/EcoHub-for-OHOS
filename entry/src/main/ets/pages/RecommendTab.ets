import { FilmApi } from '../api/FilmApi';
import { BannerItem, HomeSection } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { NavUtil } from '../common/utils/NavUtil';
import { FilmRow } from '../components/FilmRow';
import { LoadingView } from '../components/LoadingView';
import { EmptyState } from '../components/EmptyState';
import { AppIcon } from '../components/AppIcon';
import { SourceGuard } from '../common/utils/SourceGuard';
import { RefreshHint } from '../common/utils/RefreshHint';

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
  private swiperController: SwiperController = new SwiperController();
  @State private currentBannerIndex: number = 0;
  @State private reloadToken: number = 0;
  @State private headerAlpha: number = 0;

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
      if (fromPull && this.banners.length > 0) {
        this.currentBannerIndex = 0;
        try {
          this.swiperController.changeIndex(0, false);
        } catch (_err) {
        }
      }
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

  private displayBanners(): BannerItem[] {
    if (this.banners.length === 2) {
      // 扩充为 4 张循环副本，解决仅有 2 张时 Swiper 左右两翼无法同时渲染出上一张/下一张露出卡片的问题
      return [this.banners[0], this.banners[1], this.banners[0], this.banners[1]];
    }
    return this.banners;
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
  heroBannerItem(item: BannerItem) {
    Stack({ alignContent: Alignment.Bottom }) {
      // 1. 海报大图（多张时为圆角卡片，单张时满铺全屏直角无留白）
      Image(FormatUtil.bannerBackdrop(item))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .borderRadius(this.banners.length > 1 ? AppTheme.RADIUS_LG : 0)

      // 2. 顶部微暗角遮罩（保障 Header 纯净可读）
      Column()
        .width('100%')
        .height(110)
        .position({ x: 0, y: 0 })
        .borderRadius(this.banners.length > 1 ? AppTheme.RADIUS_LG : 0)
        .linearGradient({
          angle: 180,
          colors: [
            ['rgba(10, 11, 16, 0.70)', 0],
            ['rgba(10, 11, 16, 0.20)', 0.55],
            ['rgba(10, 11, 16, 0.0)', 1.0]
          ]
        })

      // 3. 底部 5 阶指数羽化遮罩（海报与页面黑位融合）
      Column()
        .width('100%')
        .height('100%')
        .borderRadius(this.banners.length > 1 ? AppTheme.RADIUS_LG : 0)
        .linearGradient({
          angle: 180,
          colors: [
            ['rgba(10, 11, 16, 0.0)', 0.0],
            ['rgba(10, 11, 16, 0.20)', 0.40],
            ['rgba(10, 11, 16, 0.70)', 0.70],
            ['rgba(10, 11, 16, 0.95)', 0.90],
            ['#0A0B10', 1.0]
          ]
        })

      // 4. Apple TV+ 居中对称排版层
      Column() {
        // 极简大片标 (24vp 特粗纯白 + 居中对齐 + 电影级文字阴影)
        Text(item.name)
          .fontSize(23)
          .fontWeight(FontWeight.Bolder)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textShadow({
            radius: 10,
            color: 'rgba(0, 0, 0, 0.90)',
            offsetY: 2
          })

        // 极细元数据副标 (居中对齐)
        Row({ space: 6 }) {
          if (item.remark) {
            Text(item.remark)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FA8C16')
          }
          Text(FormatUtil.joinMeta([item.year, item.cName, item.area]))
            .fontSize(12)
            .fontColor('rgba(255, 255, 255, 0.75)')
        }
        .justifyContent(FlexAlign.Center)
        .margin({ top: 6, bottom: 14 })

        // 主操作：主题琥珀金流光播放胶囊（居中）
        Row({ space: 6 }) {
          AppIcon({ src: $r('sys.symbol.play_fill'), iconSize: 13, color: '#FFFFFF' })
          Text('立即播放')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .height(36)
        .padding({ left: 22, right: 24 })
        .linearGradient({
          angle: 90,
          colors: [['#FA8C16', 0], ['#FFA940', 1]]
        })
        .borderRadius(AppTheme.RADIUS_PILL)
        .shadow({
          radius: 12,
          color: 'rgba(250, 140, 22, 0.38)',
          offsetY: 4
        })
        .onClick(() => {
          NavUtil.openPlay(item.mid > 0 ? item.mid : item.id);
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({
        left: AppTheme.SPACE_MD,
        right: AppTheme.SPACE_MD,
        bottom: AppTheme.SPACE_LG
      })
    }
    .width('100%')
    .height('100%')
    .borderRadius(this.banners.length > 1 ? AppTheme.RADIUS_LG : 0)
    .clip(true)
    .shadow(this.banners.length > 1 ? {
      radius: 12,
      color: 'rgba(0, 0, 0, 0.50)',
      offsetY: 4
    } : undefined)
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
    .height(48)
    .padding({
      left: AppTheme.SPACE_LG,
      right: AppTheme.SPACE_LG
    })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(`rgba(10, 11, 16, ${this.headerAlpha})`)
    .border({
      width: { bottom: this.headerAlpha > 0.5 ? 0.5 : 0 },
      color: `rgba(255, 255, 255, ${Math.max(0, (this.headerAlpha - 0.5) * 0.16)})`
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 主页面滚动区
      if (this.loading) {
        LoadingView({ label: '正在加载推荐' })
          .width('100%')
          .height('100%')
      } else if (this.errorText) {
        Refresh({ refreshing: $$this.refreshing }) {
          Scroll() {
            Column() {
              Blank().height(80)
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
          this.loadHome(true, true);
        })
        .pullToRefresh(!this.fetchLock)
        .width('100%')
        .height('100%')
      } else if (this.banners.length === 0 && this.visibleSections().length === 0) {
        Refresh({ refreshing: $$this.refreshing }) {
          Scroll() {
            Column() {
              Blank().height(80)
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
          this.loadHome(true, true);
        })
        .pullToRefresh(!this.fetchLock)
        .width('100%')
        .height('100%')
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          Scroll(this.scroller) {
            Column() {
              if (this.banners.length > 0) {
                Column() {
                  Swiper(this.swiperController) {
                    ForEach(this.displayBanners(), (item: BannerItem, index: number) => {
                      this.heroBannerItem(item)
                    }, (item: BannerItem, index: number) => `banner_${item.id}_${index}_${this.reloadToken}`)
                  }
                  .autoPlay(this.banners.length > 1)
                  .interval(4800)
                  .loop(this.banners.length > 1)
                  .indicator(false)
                  .prevMargin(this.banners.length > 1 ? 20 : 0)
                  .nextMargin(this.banners.length > 1 ? 20 : 0)
                  .itemSpace(this.banners.length > 1 ? 10 : 0)
                  .onChange((index: number) => {
                    this.currentBannerIndex = index % this.banners.length;
                  })
                  .width('100%')
                  .height(this.banners.length > 1 ? 430 : 450)

                  // 居中指示条（置于首尾露出轮播图下方，按真实数据数量显示点数）
                  if (this.banners.length > 1) {
                    Row({ space: 4 }) {
                      ForEach(this.banners, (_b: BannerItem, bIdx: number) => {
                        Row()
                          .width(bIdx === (this.currentBannerIndex % this.banners.length) ? 18 : 5)
                          .height(3.5)
                          .borderRadius(2)
                          .backgroundColor(bIdx === (this.currentBannerIndex % this.banners.length) ? '#FA8C16' : 'rgba(255, 255, 255, 0.25)')
                          .animation({ duration: 250, curve: Curve.EaseInOut })
                      }, (_b: BannerItem, bIdx: number) => `ind_${bIdx}`)
                    }
                    .margin({ top: 12 })
                    .justifyContent(FlexAlign.Center)
                  }
                }
                .width('100%')
                .margin({ bottom: this.banners.length > 1 ? AppTheme.SPACE_XL : AppTheme.SPACE_LG })
              } else {
                Blank().height(48)
              }

              // 片库分类快捷导航胶囊
              if (this.visibleSections().length > 0) {
                Column() {
                  Scroll() {
                    Row({ space: AppTheme.SPACE_SM }) {
                      ForEach(this.visibleSections(), (section: HomeSection) => {
                        this.categoryEntry(section)
                      }, (section: HomeSection) => `cat_${section.nav.id}_${this.reloadToken}`)
                    }
                    .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG })
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
        }
        .onRefreshing(() => {
          if (this.fetchLock) {
            this.refreshing = false;
            return;
          }
          this.loadHome(true, true);
        })
        .pullToRefresh(!this.fetchLock)
        .width('100%')
        .height('100%')
      }

      // 2. 连续 60fps 渐变 Header（位于顶层，背景随滚动深度无缝过渡 0.0 -> 1.0）
      this.headerRow()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BG)
  }
}


