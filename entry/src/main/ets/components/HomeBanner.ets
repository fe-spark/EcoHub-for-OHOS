import { BannerItem } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { NavUtil } from '../common/utils/NavUtil';
import { Breakpoint } from '../common/utils/Breakpoint';
import { AppIcon } from './AppIcon';

@Component
export struct HomeBanner {
  @Prop banners: BannerItem[] = [];
  @Prop @Watch('onReloadChange') reloadToken: number = 0;
  @StorageLink('WIDTH_BP') private widthBp: string = 'sm';
  @StorageLink('WINDOW_WIDTH') private windowWidth: number = 360;
  @StorageLink('WINDOW_HEIGHT') private windowHeight: number = 640;
  @State private currentIndex: number = 0;
  private swiperController: SwiperController = new SwiperController();

  private onReloadChange(): void {
    this.currentIndex = 0;
    try {
      this.swiperController.changeIndex(0, false);
    } catch (_err) {
    }
  }

  private displayBanners(): BannerItem[] {
    if (this.banners.length === 2) {
      return [this.banners[0], this.banners[1], this.banners[0], this.banners[1]];
    }
    return this.banners;
  }

  @Builder
  heroBannerItemWide(item: BannerItem) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(FormatUtil.bannerBackdrop(item))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .borderRadius(this.banners.length > 1 ? AppTheme.RADIUS_LG : 0)

      Column()
        .width('100%')
        .height('100%')
        .borderRadius(this.banners.length > 1 ? AppTheme.RADIUS_LG : 0)
        .linearGradient({
          angle: 90,
          colors: [
            ['#0A0B10', 0.0],
            ['rgba(10, 11, 16, 0.94)', 0.38],
            ['rgba(10, 11, 16, 0.60)', 0.68],
            ['rgba(10, 11, 16, 0.15)', 1.0]
          ]
        })

      Column()
        .width('100%')
        .height('100%')
        .borderRadius(this.banners.length > 1 ? AppTheme.RADIUS_LG : 0)
        .linearGradient({
          angle: 180,
          colors: [
            ['rgba(10, 11, 16, 0.0)', 0.65],
            ['rgba(10, 11, 16, 0.75)', 1.0]
          ]
        })

      Column() {
        Row({ space: 8 }) {
          Row({ space: 4 }) {
            AppIcon({
              src: $r('sys.symbol.star_fill'),
              iconSize: 11,
              color: AppTheme.ACCENT
            })
            Text('精选推荐')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.ACCENT)
          }
          .height(24)
          .padding({ left: 8, right: 8 })
          .backgroundColor('rgba(250, 140, 22, 0.12)')
          .borderRadius(AppTheme.RADIUS_PILL)
          .border({ width: 0.5, color: 'rgba(250, 140, 22, 0.35)' })

          if (item.cName) {
            Text(item.cName)
              .fontSize(11)
              .fontColor('rgba(255, 255, 255, 0.85)')
              .height(24)
              .padding({ left: 8, right: 8 })
              .backgroundColor('rgba(255, 255, 255, 0.08)')
              .borderRadius(AppTheme.RADIUS_PILL)
          }

          if (item.remark) {
            Text(item.remark)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFA940')
              .height(24)
              .padding({ left: 8, right: 8 })
              .backgroundColor('rgba(255, 169, 64, 0.12)')
              .borderRadius(AppTheme.RADIUS_PILL)
          }
        }

        Text(item.name)
          .fontSize(this.windowHeight < 500 ? 20 : 28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: this.windowHeight < 500 ? 8 : 12, bottom: this.windowHeight < 500 ? 4 : 6 })
          .textShadow({
            radius: 8,
            color: 'rgba(0, 0, 0, 0.85)',
            offsetY: 2
          })

        Text(FormatUtil.joinMeta([item.year, item.cName, item.area]))
          .fontSize(this.windowHeight < 500 ? 11 : 12)
          .fontColor(AppTheme.TEXT_SECONDARY)
          .margin({ bottom: this.windowHeight < 500 ? 6 : 10 })

        if (item.blurb) {
          Text(item.blurb.trim())
            .fontSize(this.windowHeight < 500 ? 11 : 12)
            .fontColor(AppTheme.TEXT_MUTED)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .lineHeight(this.windowHeight < 500 ? 16 : 18)
            .margin({ bottom: this.windowHeight < 500 ? 12 : 18 })
        } else {
          Blank().height(this.windowHeight < 500 ? 6 : 10)
        }

        Row({ space: 6 }) {
          AppIcon({ src: $r('sys.symbol.play_fill'), iconSize: this.windowHeight < 500 ? 12 : 13, color: '#FFFFFF' })
          Text('立即播放')
            .fontSize(this.windowHeight < 500 ? 12 : 13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .height(this.windowHeight < 500 ? 34 : 38)
        .padding({ left: this.windowHeight < 500 ? 18 : 22, right: this.windowHeight < 500 ? 20 : 24 })
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
      .width('55%')
      .constraintSize({ maxWidth: 480 })
      .height('100%')
      .padding({
        left: this.windowHeight < 500 ? 28 : 36,
        right: 16,
        top: this.windowHeight < 500 ? 14 : 24,
        bottom: this.windowHeight < 500 ? 14 : 24
      })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .borderRadius(this.banners.length > 1 ? AppTheme.RADIUS_LG : 0)
    .border({ width: 0.5, color: 'rgba(255, 255, 255, 0.08)' })
    .clip(true)
    .shadow(this.banners.length > 1 ? {
      radius: 14,
      color: 'rgba(0, 0, 0, 0.50)',
      offsetY: 4
    } : undefined)
    .onClick(() => {
      NavUtil.openPlay(item.mid > 0 ? item.mid : item.id);
    })
  }

  @Builder
  heroBannerItemMobile(item: BannerItem) {
    Stack({ alignContent: Alignment.Bottom }) {
      Image(FormatUtil.bannerBackdrop(item))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .borderRadius(this.banners.length > 1 ? AppTheme.RADIUS_LG : 0)

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

      Column() {
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

  build() {
    Column() {
      if (this.banners.length > 0) {
        Column() {
          Swiper(this.swiperController) {
            ForEach(this.displayBanners(), (item: BannerItem, index: number) => {
              if (Breakpoint.isWide(this.widthBp)) {
                this.heroBannerItemWide(item)
              } else {
                this.heroBannerItemMobile(item)
              }
            }, (item: BannerItem, index: number) => `banner_${item.id}_${index}_${this.reloadToken}`)
          }
          .autoPlay(this.banners.length > 1)
          .interval(4800)
          .loop(this.banners.length > 1)
          .indicator(false)
          .prevMargin(this.banners.length > 1 ? Breakpoint.bannerPeek(this.widthBp, this.windowWidth) : 0)
          .nextMargin(this.banners.length > 1 ? Breakpoint.bannerPeek(this.widthBp, this.windowWidth) : 0)
          .itemSpace(this.banners.length > 1 ? (Breakpoint.isWide(this.widthBp) ? 14 : 10) : 0)
          .onChange((index: number) => {
            this.currentIndex = index % this.banners.length;
          })
          .width('100%')
          .height(Breakpoint.bannerHeight(this.widthBp, this.banners.length > 1, this.windowHeight))

          if (this.banners.length > 1) {
            Row({ space: 4 }) {
              ForEach(this.banners, (_b: BannerItem, bIdx: number) => {
                Row()
                  .width(bIdx === (this.currentIndex % this.banners.length) ? 18 : 5)
                  .height(3.5)
                  .borderRadius(2)
                  .backgroundColor(bIdx === (this.currentIndex % this.banners.length) ? '#FA8C16' : 'rgba(255, 255, 255, 0.25)')
                  .animation({ duration: 250, curve: Curve.EaseInOut })
              }, (_b: BannerItem, bIdx: number) => `ind_${bIdx}`)
            }
            .margin({ top: this.windowHeight < 500 ? 8 : 12 })
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('100%')
        .margin({ bottom: this.banners.length > 1 ? (Breakpoint.isWide(this.widthBp) && this.windowHeight < 500 ? 14 : AppTheme.SPACE_XL) : AppTheme.SPACE_LG })
      } else {
        Blank().height(48)
      }
    }
    .width('100%')
  }
}
