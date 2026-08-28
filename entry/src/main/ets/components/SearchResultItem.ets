import { MovieBasicInfo } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { NavUtil } from '../common/utils/NavUtil';
import { AppIcon } from './AppIcon';

@Component
export struct SearchResultItem {
  @Prop film: MovieBasicInfo;
  onSelect?: (film: MovieBasicInfo) => void;

  private handleClick(): void {
    if (this.onSelect) {
      this.onSelect(this.film);
      return;
    }
    NavUtil.openPlay(this.film.id);
  }

  build() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Image(FormatUtil.poster(this.film))
          .width(86)
          .height(128)
          .objectFit(ImageFit.Cover)
          .borderRadius(AppTheme.RADIUS_MD)
          .backgroundColor(AppTheme.BG_CARD)
        Row() {
          AppIcon({
            src: $r('sys.symbol.play_fill'),
            iconSize: 12,
            color: AppTheme.TEXT_PRIMARY
          })
        }
        .width(28)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.55)')
        .borderRadius(14)
      }
      Column() {
        Text(this.film.name)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(FormatUtil.joinMeta([this.film.cName, this.film.year, this.film.area, this.film.remarks]))
          .fontSize(12)
          .fontColor(AppTheme.TEXT_SECONDARY)
          .margin({ top: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`导演 ${this.film.director || '未知'}`)
          .fontSize(12)
          .fontColor(AppTheme.TEXT_MUTED)
          .margin({ top: 6 })
          .maxLines(1)
        Text(`主演 ${this.film.actor || '未知'}`)
          .fontSize(12)
          .fontColor(AppTheme.TEXT_MUTED)
          .margin({ top: 4 })
          .maxLines(1)
        Text(this.film.blurb || '暂无简介')
          .fontSize(12)
          .fontColor(AppTheme.TEXT_SECONDARY)
          .margin({ top: 8 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
    }
    .width('100%')
    .onClick(() => {
      this.handleClick();
    })
  }
}
