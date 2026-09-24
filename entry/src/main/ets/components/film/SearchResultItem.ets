import { MovieBasicInfo } from '../../types/FilmModels';
import { AppTheme } from '../../common/constants/AppTheme';
import { FormatUtil } from '../../common/utils/FormatUtil';
import { NavUtil } from '../../common/utils/NavUtil';
import { AppIcon } from '../common/AppIcon';
import { FavoriteManager } from '../../services/FavoriteManager';

@Component
export struct SearchResultItem {
  @Prop @Watch('onFilmChange') film: MovieBasicInfo;
  @StorageProp('FAVORITE_VERSION') @Watch('onFavVersionChange') private favVersion: number = 0;
  @State private isFav: boolean = false;
  onSelect?: (film: MovieBasicInfo) => void;
  private favChangeCb: () => void = () => {};

  aboutToAppear(): void {
    this.updateFavState();
    this.favChangeCb = () => {
      this.updateFavState();
    };
    FavoriteManager.onFavoriteChange(this.favChangeCb);
  }

  aboutToDisappear(): void {
    FavoriteManager.offFavoriteChange(this.favChangeCb);
  }

  private onFilmChange(): void {
    this.updateFavState();
  }

  private onFavVersionChange(): void {
    this.updateFavState();
  }

  private updateFavState(): void {
    this.isFav = FavoriteManager.isFavoriteFilmSync(this.film);
  }

  private handleClick(): void {
    if (this.onSelect) {
      this.onSelect(this.film);
      return;
    }
    NavUtil.openPlay(
      FormatUtil.filmId(this.film),
      this.film.sourceId,
      undefined,
      undefined,
      this.film.sourceMid > 0 ? `${this.film.sourceMid}` : '',
      undefined,
      this.film.name
    );
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

        if (this.isFav) {
          Row() {
            this.favoriteTag()
          }
          .position({ x: 4, y: 4 })
          .hitTestBehavior(HitTestMode.Transparent)
        }
      }

      Column() {
        Text(this.film.name)
          .fontSize(AppTheme.FONT_LG)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .lineHeight(22)
          .maxLines(2)
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
