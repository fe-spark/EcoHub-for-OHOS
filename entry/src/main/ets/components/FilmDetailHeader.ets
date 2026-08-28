import { MovieDescriptor } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from './AppIcon';

@Component
export struct FilmDetailHeader {
  @Prop name: string = '';
  @Prop actor: string = '';
  @Prop plot: string = '';
  @Prop descriptor: MovieDescriptor | null = null;
  @State private plotOpen: boolean = false;

  private scoreText(): string {
    const s = this.descriptor?.dbScore ? this.descriptor.dbScore.trim() : '';
    if (!s || s === '0' || s === '0.0') {
      return '';
    }
    return s;
  }

  private metaTagsText(): string {
    const tags: string[] = [];
    if (this.descriptor?.year && this.descriptor.year.trim()) {
      tags.push(this.descriptor.year.trim());
    }
    const cat = this.descriptor?.classTag || this.descriptor?.cName;
    if (cat && cat.trim()) {
      tags.push(cat.trim().replace(/\s*[,/，]\s*/g, ' / '));
    }
    if (this.descriptor?.area && this.descriptor.area.trim()) {
      tags.push(this.descriptor.area.trim());
    }
    if (this.descriptor?.remarks && this.descriptor.remarks.trim()) {
      tags.push(this.descriptor.remarks.trim());
    } else if (this.descriptor?.state && this.descriptor.state.trim()) {
      tags.push(this.descriptor.state.trim());
    }
    return tags.join('  ·  ');
  }

  private directorText(): string {
    const raw = this.descriptor?.director ? this.descriptor.director.trim() : '';
    if (!raw) {
      return '';
    }
    return raw.replace(/\s*[，,、]\s*/g, ' / ');
  }

  private actorText(): string {
    const raw = (this.descriptor?.actor || this.actor) ? (this.descriptor?.actor || this.actor).trim() : '';
    if (!raw) {
      return '';
    }
    return raw.replace(/\s*[，,、]\s*/g, ' / ');
  }

  private plotText(): string {
    const raw = this.plot || this.descriptor?.content || this.descriptor?.blurb || '';
    const text = raw
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n')
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
    return text ? text : '暂无介绍';
  }

  build() {
    Column() {
      Row() {
        Text(this.name)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        if (this.scoreText() !== '') {
          Row({ space: 3 }) {
            Text('★')
              .fontSize(11)
              .fontColor(AppTheme.ACCENT)
            Text(this.scoreText())
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ACCENT)
          }
          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .backgroundColor(AppTheme.ACCENT_SOFT)
          .borderRadius(AppTheme.RADIUS_SM)
          .margin({ left: 8 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 12, right: 12, top: 12 })

      if (this.metaTagsText() !== '') {
        Text(this.metaTagsText())
          .fontSize(12)
          .fontColor(AppTheme.TEXT_MUTED)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 12, right: 12, top: 6 })
      }

      if (this.directorText() !== '' || this.actorText() !== '') {
        Row() {
          Text() {
            if (this.directorText() !== '') {
              Span('导演: ')
                .fontColor(AppTheme.TEXT_MUTED)
                .fontSize(12)
              Span(this.directorText() + (this.actorText() !== '' ? '    ' : ''))
                .fontColor(AppTheme.TEXT_SECONDARY)
                .fontSize(12)
            }
            if (this.actorText() !== '') {
              Span('主演: ')
                .fontColor(AppTheme.TEXT_MUTED)
                .fontSize(12)
              Span(this.actorText())
                .fontColor(AppTheme.TEXT_SECONDARY)
                .fontSize(12)
            }
          }
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 6 })
      }

      Row() {
        Text(this.plotText())
          .fontSize(12)
          .fontColor(AppTheme.TEXT_SECONDARY)
          .lineHeight(18)
          .maxLines(this.plotOpen ? 20 : 2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .animation({ duration: 150 })

        Row({ space: 2 }) {
          Text(this.plotOpen ? '收起' : '简介')
            .fontSize(12)
            .fontColor(AppTheme.ACCENT)
          AppIcon({
            src: this.plotOpen ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'),
            iconSize: 12,
            color: AppTheme.ACCENT
          })
        }
        .margin({ left: 8 })
        .alignSelf(this.plotOpen ? ItemAlign.End : ItemAlign.Center)
        .onClick(() => {
          this.plotOpen = !this.plotOpen;
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
