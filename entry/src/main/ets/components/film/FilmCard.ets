import { MovieBasicInfo } from '../../types/FilmModels';
import { AppTheme } from '../../common/constants/AppTheme';
import { FormatUtil } from '../../common/utils/FormatUtil';
import { NavUtil } from '../../common/utils/NavUtil';
import { AppIcon } from '../common/AppIcon';
import { FavoriteManager } from '../../services/FavoriteManager';

@Component
export struct FilmCard {
  @Prop film: MovieBasicInfo;
  @Prop cardWidth: number = 0;
  @Prop showMeta: boolean = true;
  @StorageProp('FAVORITE_VERSION') private favVersion: number = 0;
  onClickCard?: (film: MovieBasicInfo) => void;
  @State private broken: boolean = false;
  @State private pressed: boolean = false;

  private posterUrl(): string {
    return FormatUtil.poster(this.film);
  }

  private cardSize(): Length {
    return this.cardWidth > 0 ? this.cardWidth : '100%';
  }

  private handleClick(): void {
    if (this.onClickCard) {
      this.onClickCard(this.film);
      return;
    }
    NavUtil.openPlay(FormatUtil.filmId(this.film));
  }

  private isFavorited(): boolean {
    if (this.favVersion < 0) {
      return false;
    }
    return FavoriteManager.isFavoriteSync(FormatUtil.filmId(this.film));
  }

  @Builder
  favoriteTag() {
    Row({ space: 2 }) {
      AppIcon({
        src: $r('sys.symbol.star_fill'),
        iconSize: 10,
        color: '#FA8C16'
      })
      Text('已收藏')
        .fontSize(9)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FA8C16')
    }
    .padding({ left: 4, right: 5, top: 2, bottom: 2 })
    .backgroundColor('rgba(10, 11, 16, 0.85)')
    .borderRadius(4)
    .border({ width: 0.5, color: 'rgba(250, 140, 22, 0.4)' })
  }

  @Builder
  posterTag(text: string) {
    Text(text)
      .fontSize(AppTheme.FONT_2XS)
      .fontWeight(FontWeight.Medium)
      .fontColor('#FFFFFF')
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .constraintSize({ maxWidth: '90%' })
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .backgroundColor('rgba(10, 11, 16, 0.78)')
      .borderRadius(4)
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        if (!this.broken && this.posterUrl()) {
          Image(this.posterUrl())
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .borderRadius(AppTheme.RADIUS_MD)
            .backgroundColor(AppTheme.BG_CARD)
            .onError(() => {
              this.broken = true;
            })
        } else {
          Column() {
            Text(this.film.name ? this.film.name.substring(0, 1) : '影')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT_SECONDARY)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppTheme.BG_CARD)
          .borderRadius(AppTheme.RADIUS_MD)
        }

        Column()
          .width('100%')
          .height('100%')
          .borderRadius(AppTheme.RADIUS_MD)
          .linearGradient({
            angle: 180,
            colors: [['rgba(0,0,0,0)', 0.65], ['rgba(10,11,16,0.60)', 1]]
          })

        if (this.isFavorited()) {
          Row() {
            this.favoriteTag()
          }
          .position({ x: 6, y: 6 })
          .hitTestBehavior(HitTestMode.Transparent)
        }

        if (this.film.remarks || this.film.cName) {
          Row() {
            this.posterTag(this.film.remarks || this.film.cName)
          }
          .padding(6)
          .hitTestBehavior(HitTestMode.Transparent)
        }
      }
      .width('100%')
      .aspectRatio(2 / 3)
      .clip(true)
      .borderRadius(AppTheme.RADIUS_MD)
      .border({ width: 0.5, color: 'rgba(255, 255, 255, 0.08)' })

      if (this.showMeta) {
        Text(this.film.name)
          .width('100%')
          .height(18)
          .fontSize(AppTheme.FONT_BASE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })

        Text(this.film.subTitle || FormatUtil.joinMeta([this.film.year, this.film.cName]))
          .width('100%')
          .height(15)
          .fontSize(AppTheme.FONT_SM)
          .fontColor(AppTheme.TEXT_MUTED)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .scale({ x: this.pressed ? 0.96 : 1, y: this.pressed ? 0.96 : 1 })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .width(this.cardSize())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick(() => this.handleClick())
  }
}
