import { MovieUrlInfo, PlaySource } from '../../types/FilmModels';
import { AppTheme } from '../../common/constants/AppTheme';

@Component
export struct LivePlayPanel {
  @Prop sources: PlaySource[] = [];
  @Prop playingSourceId: string = '';
  @Prop episodeIndex: number = 0;
  @Prop plot: string = '';
  onSelectEpisode?: (sourceId: string, index: number) => void;

  private playingSource(): PlaySource | null {
    for (let i = 0; i < this.sources.length; i++) {
      if (this.sources[i].id === this.playingSourceId) {
        return this.sources[i];
      }
    }
    return this.sources.length > 0 ? this.sources[0] : null;
  }

  private episodes(): MovieUrlInfo[] {
    const source = this.playingSource();
    return source ? source.linkList : [];
  }

  private select(sourceId: string, index: number): void {
    if (this.onSelectEpisode) {
      this.onSelectEpisode(sourceId, index);
    }
  }

  private chipColor(active: boolean): string {
    return active ? AppTheme.ACCENT : AppTheme.TEXT_PRIMARY;
  }

  private chipBg(active: boolean): string {
    return active ? AppTheme.ACCENT_SOFT : AppTheme.BG_CHIP;
  }

  build() {
    Column() {
      if (this.sources.length > 1) {
        Text('线路')
          .fontSize(AppTheme.FONT_LG)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .margin({ bottom: 10 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.sources, (item: PlaySource) => {
            Text(item.name)
              .fontSize(AppTheme.FONT_BASE)
              .fontWeight(item.id === this.playingSourceId ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.chipColor(item.id === this.playingSourceId))
              .constraintSize({ minWidth: 64, minHeight: 36 })
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .borderRadius(AppTheme.RADIUS_MD)
              .backgroundColor(this.chipBg(item.id === this.playingSourceId))
              .border({
                width: 1,
                color: item.id === this.playingSourceId ? AppTheme.ACCENT : Color.Transparent
              })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => this.select(item.id, 0))
          }, (item: PlaySource) => item.id)
        }
        .width('100%')
        .margin({ bottom: AppTheme.SPACE_LG })
      }

      Text('选集')
        .fontSize(AppTheme.FONT_LG)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT_PRIMARY)
        .margin({ bottom: 10 })

      if (this.episodes().length === 0) {
        Text('暂无剧集')
          .fontSize(AppTheme.FONT_BASE)
          .fontColor(AppTheme.TEXT_MUTED)
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.episodes(), (item: MovieUrlInfo, index: number) => {
            Text(item.episode || `第${index + 1}集`)
              .fontSize(AppTheme.FONT_BASE)
              .fontWeight(index === this.episodeIndex ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.chipColor(index === this.episodeIndex))
              .constraintSize({ minWidth: 64, minHeight: 36 })
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .borderRadius(AppTheme.RADIUS_MD)
              .backgroundColor(this.chipBg(index === this.episodeIndex))
              .border({
                width: 1,
                color: index === this.episodeIndex ? AppTheme.ACCENT : Color.Transparent
              })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                const source = this.playingSource();
                if (source) {
                  this.select(source.id, index);
                }
              })
          }, (item: MovieUrlInfo, index: number) => `${index}_${item.episode}`)
        }
        .width('100%')
      }

      if (this.plot.trim()) {
        Text('剧情简介')
          .fontSize(AppTheme.FONT_LG)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .margin({ top: AppTheme.SPACE_LG, bottom: 10 })
        Text(this.plot.trim())
          .fontSize(AppTheme.FONT_BASE)
          .lineHeight(20)
          .fontColor(AppTheme.TEXT_SECONDARY)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: AppTheme.SPACE_LG,
      right: AppTheme.SPACE_LG,
      bottom: AppTheme.SPACE_LG
    })
  }
}
