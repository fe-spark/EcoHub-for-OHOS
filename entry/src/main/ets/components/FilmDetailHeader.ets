import { MovieDescriptor } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from './AppIcon';

@Component
export struct FilmDetailHeader {
  @Prop name: string = '';
  @Prop subTitle: string = '';
  @Prop actor: string = '';
  @Prop @Watch('onDataChange') plot: string = '';
  @Prop @Watch('onDataChange') descriptor: MovieDescriptor | null = null;
  @State private cleanPlot: string = '';
  @State private scoreText: string = '';
  @State private plotOpen: boolean = false;

  aboutToAppear(): void {
    this.syncDerivedState();
  }

  onDataChange(): void {
    this.syncDerivedState();
  }

  private syncDerivedState(): void {
    const raw = this.plot || this.descriptor?.content || this.descriptor?.blurb || '';
    this.cleanPlot = raw
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n')
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/\n{3,}/g, '\n\n')
      .trim();

    const s = this.descriptor?.dbScore ? this.descriptor.dbScore.trim() : '';
    this.scoreText = (!s || s === '0' || s === '0.0') ? '' : s;
  }

  private canExpandPlot(): boolean {
    return this.cleanPlot.length > 56 || this.cleanPlot.indexOf('\n') >= 0;
  }

  private metaTagsList(): string[] {
    const tags: string[] = [];
    if (this.descriptor?.year && this.descriptor.year.trim()) {
      tags.push(this.descriptor.year.trim());
    }
    const cat = this.descriptor?.classTag || this.descriptor?.cName;
    if (cat && cat.trim()) {
      const parts = cat.trim().split(/[,/，\s]+/);
      for (let i = 0; i < parts.length && tags.length < 5; i++) {
        const p = parts[i].trim();
        if (p && tags.indexOf(p) < 0) {
          tags.push(p);
        }
      }
    }
    if (this.descriptor?.area && this.descriptor.area.trim()) {
      const area = this.descriptor.area.trim();
      if (tags.indexOf(area) < 0) {
        tags.push(area);
      }
    }
    if (this.descriptor?.language && this.descriptor.language.trim()) {
      const lang = this.descriptor.language.trim();
      if (tags.indexOf(lang) < 0) {
        tags.push(lang);
      }
    }
    return tags;
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

  build() {
    Column() {
      // 1. 标题与评分徽标行
      Row() {
        Text(this.name)
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        // 评分徽章（有评分展示高亮分值，无评分展示优雅占位）
        if (this.scoreText !== '') {
          Row({ space: 3 }) {
            Text('★')
              .fontSize(12)
              .fontColor(AppTheme.ACCENT)
            Text(this.scoreText)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ACCENT)
            Text('分')
              .fontSize(10)
              .fontColor(AppTheme.ACCENT)
              .margin({ top: 1 })
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(AppTheme.ACCENT_SOFT)
          .borderRadius(AppTheme.RADIUS_SM)
          .margin({ left: 10 })
        } else {
          Row({ space: 3 }) {
            Text('★')
              .fontSize(11)
              .fontColor(AppTheme.TEXT_MUTED)
            Text('暂无评分')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT_MUTED)
          }
          .padding({ left: 7, right: 7, top: 4, bottom: 4 })
          .backgroundColor(AppTheme.BG_CHIP)
          .borderRadius(AppTheme.RADIUS_SM)
          .margin({ left: 10 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 12, right: 12, top: 10 })

      // 2. 元数据小胶囊组
      if (this.metaTagsList().length > 0) {
        Row({ space: 6 }) {
          ForEach(this.metaTagsList(), (tag: string) => {
            Text(tag)
              .fontSize(11)
              .fontColor(AppTheme.TEXT_SECONDARY)
              .padding({ left: 7, right: 7, top: 3, bottom: 3 })
              .backgroundColor(AppTheme.BG_CHIP)
              .borderRadius(AppTheme.RADIUS_SM)
          }, (tag: string) => tag)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8 })
      }

      // 3. 演职员信息板块
      if (this.directorText() !== '' || this.actorText() !== '') {
        Column({ space: 4 }) {
          if (this.directorText() !== '') {
            Row({ space: 6 }) {
              Text('导演')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT_MUTED)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                .backgroundColor(AppTheme.BG_CHIP)
                .borderRadius(3)
              Text(this.directorText())
                .fontSize(12)
                .fontColor(AppTheme.TEXT_SECONDARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }

          if (this.actorText() !== '') {
            Row({ space: 6 }) {
              Text('主演')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT_MUTED)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                .backgroundColor(AppTheme.BG_CHIP)
                .borderRadius(3)
              Text(this.actorText())
                .fontSize(12)
                .fontColor(AppTheme.TEXT_SECONDARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8 })
      }

      // 4. 精美卡片式剧情简介与折叠交互（无简介时直接不显示简介模块）
      if (this.cleanPlot !== '') {
        Row() {
          Column() {
            Row() {
              Row({ space: 4 }) {
                Column()
                  .width(3)
                  .height(11)
                  .backgroundColor(AppTheme.ACCENT)
                  .borderRadius(1.5)
                Text('剧情简介')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.TEXT_PRIMARY)
              }
              .alignItems(VerticalAlign.Center)

              Blank()

              if (this.canExpandPlot()) {
                Row({ space: 2 }) {
                  Text(this.plotOpen ? '收起' : '展开')
                    .fontSize(11)
                    .fontColor(AppTheme.ACCENT)
                  AppIcon({
                    src: this.plotOpen ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'),
                    iconSize: 11,
                    color: AppTheme.ACCENT
                  })
                }
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .onClick(() => {
                  this.plotOpen = !this.plotOpen;
                })
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ bottom: 6 })

            Text(this.cleanPlot)
              .fontSize(12)
              .fontColor(AppTheme.TEXT_SECONDARY)
              .lineHeight(19)
              .width('100%')
              .maxLines(this.plotOpen ? 30 : 2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .animation({ duration: 180, curve: Curve.EaseInOut })
              .onClick(() => {
                if (this.canExpandPlot()) {
                  this.plotOpen = !this.plotOpen;
                }
              })
          }
          .width('100%')
          .padding(10)
          .backgroundColor(AppTheme.BG_CARD)
          .borderRadius(AppTheme.RADIUS_MD)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 4 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ bottom: this.cleanPlot !== '' ? 4 : 10 })
  }
}
