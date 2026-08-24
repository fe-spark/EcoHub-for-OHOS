import { MovieBasicInfo } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { NavUtil } from '../common/utils/NavUtil';
import { FilmCard } from './FilmCard';
import { AppIcon } from './AppIcon';

@Component
export struct FilmRow {
  @Prop title: string = '';
  @Prop films: MovieBasicInfo[] = [];
  @Prop moreText: string = '查看全部';
  @Prop pid: number = 0;
  onMore?: () => void;

  private openMore(): void {
    if (this.onMore) {
      this.onMore();
    } else if (this.pid > 0) {
      NavUtil.openFilter(this.pid);
    }
  }

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .onClick(() => this.openMore())

        Row() {
          Text(this.moreText)
            .fontSize(12)
            .fontColor(AppTheme.ACCENT)
          AppIcon({
            src: $r('sys.symbol.chevron_right'),
            iconSize: 12,
            color: AppTheme.ACCENT
          })
        }
        .height(28)
        .padding({ left: AppTheme.SPACE_SM })
        .onClick(() => this.openMore())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG })
      .margin({ bottom: AppTheme.SPACE_MD })

      if (this.films.length === 0) {
        Text('暂无影片')
          .fontSize(12)
          .fontColor(AppTheme.TEXT_MUTED)
          .padding({ left: AppTheme.SPACE_LG })
      } else {
        Scroll() {
          Row({ space: AppTheme.SPACE_SM }) {
            ForEach(this.films, (film: MovieBasicInfo) => {
              FilmCard({ film: film, cardWidth: 108 })
            }, (film: MovieBasicInfo) => `${film.id}`)
          }
          .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .nestedScroll({
          scrollForward: NestedScrollMode.SELF_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST
        })
      }
    }
    .width('100%')
    .padding({ top: AppTheme.SPACE_LG, bottom: AppTheme.SPACE_LG })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.BG_ELEVATED)
    .borderRadius(AppTheme.RADIUS_LG)
    .clip(true)
    .margin({
      left: AppTheme.SPACE_LG,
      right: AppTheme.SPACE_LG,
      bottom: AppTheme.SPACE_LG
    })
  }
}



