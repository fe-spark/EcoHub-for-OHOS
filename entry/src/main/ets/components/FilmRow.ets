import { MovieBasicInfo } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { Breakpoint } from '../common/utils/Breakpoint';
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
  @StorageLink('WIDTH_BP') private widthBp: string = 'sm';
  @StorageLink('WINDOW_WIDTH') private windowWidth: number = 360;
  @StorageLink('SAFE_INSET_LEFT') private leftInset: number = 0;
  @StorageLink('SAFE_INSET_RIGHT') private rightInset: number = 0;

  private openMore(): void {
    if (this.onMore) {
      this.onMore();
    } else if (this.pid > 0) {
      NavUtil.openFilter(this.pid);
    }
  }

  build() {
    Column() {
      // 标题栏：琥珀色指示条 + 标题 + 查看全部
      Row() {
        Row({ space: 8 }) {
          Row()
            .width(3.5)
            .height(15)
            .backgroundColor(AppTheme.ACCENT)
            .borderRadius(2)

          Text(this.title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .onClick(() => this.openMore())

        Row({ space: 3 }) {
          Text(this.moreText)
            .fontSize(12)
            .fontColor(AppTheme.TEXT_MUTED)
          AppIcon({
            src: $r('sys.symbol.chevron_right'),
            iconSize: 11,
            color: AppTheme.TEXT_MUTED
          })
        }
        .height(28)
        .padding({ left: AppTheme.SPACE_SM })
        .onClick(() => this.openMore())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: AppTheme.SPACE_LG + this.leftInset, right: AppTheme.SPACE_LG + this.rightInset })
      .margin({ bottom: AppTheme.SPACE_MD })

      if (this.films.length === 0) {
        Text('暂无影片')
          .fontSize(12)
          .fontColor(AppTheme.TEXT_MUTED)
          .padding({ left: AppTheme.SPACE_LG + this.leftInset })
      } else {
        Scroll() {
          Row({ space: AppTheme.SPACE_SM }) {
            ForEach(this.films, (film: MovieBasicInfo) => {
              FilmCard({ film: film, cardWidth: Breakpoint.cardWidth(this.widthBp, this.windowWidth) })
            }, (film: MovieBasicInfo) => `${film.id}`)
          }
          .padding({ left: AppTheme.SPACE_LG + this.leftInset, right: AppTheme.SPACE_LG + this.rightInset })
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
    .padding({ top: AppTheme.SPACE_MD, bottom: AppTheme.SPACE_MD })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.BG_CARD)
    .border({
      width: { bottom: 0.5 },
      color: 'rgba(255, 255, 255, 0.05)'
    })
    .margin({ bottom: AppTheme.SPACE_SM })
  }
}



