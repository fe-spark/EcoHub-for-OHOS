import { MovieBasicInfo } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { NavUtil } from '../common/utils/NavUtil';

@Component
export struct FilmCard {
  @Prop film: MovieBasicInfo;
  @Prop cardWidth: number = 0;
  @Prop showMeta: boolean = true;
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

  @Builder
  posterTag(text: string) {
    Text(text)
      .fontSize(9)
      .fontWeight(FontWeight.Medium)
      .fontColor('#FFFFFF')
      .maxLines(1)
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .backgroundColor('rgba(10, 11, 16, 0.78)')
      .borderRadius(4)
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        if (!this.broken && this.posterUrl()) {
          Image(this.posterUrl())
            .width('100%')
            .aspectRatio(2 / 3)
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
          .aspectRatio(2 / 3)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppTheme.BG_CARD)
          .borderRadius(AppTheme.RADIUS_MD)
        }

        Column()
          .width('100%')
          .aspectRatio(2 / 3)
          .borderRadius(AppTheme.RADIUS_MD)
          .linearGradient({
            angle: 180,
            colors: [['rgba(0,0,0,0)', 0.65], ['rgba(10,11,16,0.60)', 1]]
          })

        if (this.film.remarks || this.film.cName) {
          Row() {
            this.posterTag(this.film.remarks || this.film.cName)
          }
          .padding(6)
        }
      }
      .width('100%')
      .clip(true)
      .borderRadius(AppTheme.RADIUS_MD)
      .border({ width: 0.5, color: 'rgba(255, 255, 255, 0.08)' })

      if (this.showMeta) {
        Text(this.film.name)
          .width('100%')
          .height(18)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })

        Text(this.film.subTitle || FormatUtil.joinMeta([this.film.year, this.film.cName]))
          .width('100%')
          .height(15)
          .fontSize(11)
          .fontColor(AppTheme.TEXT_MUTED)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
    }
    .width(this.cardSize())
    .alignItems(HorizontalAlign.Start)
    .scale({ x: this.pressed ? 0.96 : 1, y: this.pressed ? 0.96 : 1 })
    .animation({ duration: 120, curve: Curve.EaseOut })
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
