import { MovieBasicInfo } from '../../types/FilmModels';
import { AppTheme } from '../../common/constants/AppTheme';
import { FormatUtil } from '../../common/utils/FormatUtil';
import { NavUtil } from '../../common/utils/NavUtil';
import { AppIcon } from '../common/AppIcon';

@Component
export struct SearchResultItem {
  @Prop film: MovieBasicInfo;
  onSelect?: (film: MovieBasicInfo) => void;

  private handleClick(): void {
    if (this.onSelect) {
      this.onSelect(this.film);
      return;
    }
    NavUtil.openPlay(this.film.id, this.film.sourceId, undefined, undefined,
      this.film.sourceMid > 0 ? `${this.film.sourceMid}` : '');
  }

  build() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Image(FormatUtil.poster(this.film))
          .width(96)
          .height(142)
          .objectFit(ImageFit.Cover)
          .borderRadius(AppTheme.RADIUS_LG)
          .backgroundColor(AppTheme.BG_CARD)
        Row() {
          AppIcon({
            src: $r('sys.symbol.play_fill'),
            iconSize: 14,
            color: AppTheme.TEXT_PRIMARY
          })
        }
        .width(30)
        .height(30)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.55)')
        .borderRadius(15)
      }

      Column() {
        Text(this.film.name)
          .fontSize(AppTheme.FONT_LG)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .lineHeight(22)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(FormatUtil.joinMeta([this.film.cName, this.film.year, this.film.area, this.film.remarks]))
          .fontSize(AppTheme.FONT_SM)
          .fontColor(AppTheme.TEXT_SECONDARY)
          .margin({ top: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`导演 ${this.film.director || '未知'}`)
          .fontSize(AppTheme.FONT_SM)
          .fontColor(AppTheme.TEXT_MUTED)
          .margin({ top: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`主演 ${this.film.actor || '未知'}`)
          .fontSize(AppTheme.FONT_SM)
          .fontColor(AppTheme.TEXT_MUTED)
          .margin({ top: 6 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.film.blurb || '暂无简介')
          .fontSize(AppTheme.FONT_SM)
          .fontColor(AppTheme.TEXT_SECONDARY)
          .margin({ top: 10 })
          .lineHeight(18)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: AppTheme.SPACE_LG })
      .constraintSize({ minHeight: 142 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .onClick(() => {
      this.handleClick();
    })
  }
}
