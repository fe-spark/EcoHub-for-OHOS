import { MovieDescriptor } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from './AppIcon';
import { FilmDetailDialog } from './FilmDetailDialog';

@Component
export struct FilmDetailHeader {
  @Prop name: string = '';
  @Prop subTitle: string = '';
  @Prop actor: string = '';
  @Prop @Watch('onDataChange') plot: string = '';
  @Prop @Watch('onDataChange') descriptor: MovieDescriptor | null = null;
  @State private cleanPlot: string = '';
  @State private scoreText: string = '';
  private detailDialog: CustomDialogController | null = null;

  aboutToAppear(): void {
    this.syncDerivedState();
  }

  aboutToDisappear(): void {
    if (this.detailDialog) {
      this.detailDialog.close();
      this.detailDialog = null;
    }
  }

  private openDetailDialog(): void {
    if (this.detailDialog) {
      this.detailDialog.close();
      this.detailDialog = null;
    }
    this.detailDialog = new CustomDialogController({
      builder: FilmDetailDialog({
        name: this.name,
        scoreText: this.scoreText,
        tags: this.metaTagsList(),
        director: this.directorText(),
        actor: this.actorText(),
        plot: this.cleanPlot
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      backgroundColor: Color.Transparent,
      maskColor: 'rgba(0, 0, 0, 0.65)',
      cancel: () => {
        this.detailDialog = null;
      }
    });
    this.detailDialog.open();
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

  private hasDetailInfo(): boolean {
    return this.directorText() !== '' || this.actorText() !== '' || this.cleanPlot !== '';
  }

  private detailSnippetText(): string {
    if (this.actorText() !== '') {
      return `主演：${this.actorText()}`;
    }
    if (this.directorText() !== '') {
      return `导演：${this.directorText()}`;
    }
    if (this.cleanPlot !== '') {
      return `简介：${this.cleanPlot.replace(/\n+/g, ' ')}`;
    }
    return '查看简介 / 主演 / 导演';
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

        // 评分徽章
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
        Scroll() {
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
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .align(Alignment.Start)
        .padding({ left: 12, right: 12, top: 8 })
      }

      // 3. 详细信息卡片导引条（独立整行大热区，带摘要与高亮详情入口）
      if (this.hasDetailInfo()) {
        Row() {
          Row() {
            Row({ space: 6 }) {
              AppIcon({
                src: $r('sys.symbol.doc_plaintext'),
                iconSize: 14,
                color: AppTheme.ACCENT
              })
              Text(this.detailSnippetText())
                .fontSize(12)
                .fontColor(AppTheme.TEXT_SECONDARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .layoutWeight(1)
            .alignItems(VerticalAlign.Center)

            Row({ space: 2 }) {
              Text('详情')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ACCENT)
              AppIcon({
                src: $r('sys.symbol.chevron_right'),
                iconSize: 12,
                color: AppTheme.ACCENT
              })
            }
            .padding({ left: 6, right: 4, top: 3, bottom: 3 })
            .backgroundColor(AppTheme.ACCENT_SOFT)
            .borderRadius(AppTheme.RADIUS_SM)
            .alignItems(VerticalAlign.Center)
            .margin({ left: 8 })
          }
          .width('100%')
          .padding({ left: 10, right: 8, top: 8, bottom: 8 })
          .backgroundColor(AppTheme.BG_CARD)
          .borderRadius(AppTheme.RADIUS_MD)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.openDetailDialog();
          })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ bottom: 4 })
  }
}
