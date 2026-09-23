import { MovieBasicInfo } from '../../types/FilmModels';
import { AppTheme } from '../../common/constants/AppTheme';
import { FormatUtil } from '../../common/utils/FormatUtil';
import { NavUtil } from '../../common/utils/NavUtil';
import { AppIcon } from '../common/AppIcon';
import { FavoriteManager } from '../../services/FavoriteManager';

@Component
export struct SearchResultItem {
  @Prop film: MovieBasicInfo;
  @StorageProp('FAVORITE_VERSION') private favVersion: number = 0;
  onSelect?: (film: MovieBasicInfo) => void;

  private handleClick(): void {
    if (this.onSelect) {
      this.onSelect(this.film);
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
        iconSize: 9,
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

        if (this.isFavorited()) {
          Row() {
            this.favoriteTag()
          }
          .position({ x: 4, y: 4 })
          .hitTestBehavior(HitTestMode.Transparent)
        }
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
