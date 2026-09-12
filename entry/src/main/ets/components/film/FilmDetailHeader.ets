import { FavoriteItem, MovieDescriptor } from '../../types/FilmModels';
import { AppTheme } from '../../common/constants/AppTheme';
import { AppIcon } from '../common/AppIcon';
import { FilmDetailDialog } from '../dialogs/FilmDetailDialog';
import { FavoriteManager } from '../../services/FavoriteManager';
import { FormatUtil } from '../../common/utils/FormatUtil';

@Component
export struct FilmDetailHeader {
  @Prop @Watch('syncFavState') filmId: string = '';
  @Prop picture: string = '';
  @Prop name: string = '';
  @Prop subTitle: string = '';
  @Prop actor: string = '';
  @Prop @Watch('onDataChange') plot: string = '';
  @Prop @Watch('onDataChange') descriptor: MovieDescriptor | null = null;
  @State private isFav: boolean = false;
  @State private cleanPlot: string = '';
  @State private scoreText: string = '';
  private detailDialog: CustomDialogController | null = null;
  private favChangeCb: () => void = () => {};

  aboutToAppear(): void {
    this.syncDerivedState();
    this.syncFavState();
    this.favChangeCb = () => { this.syncFavState(); };
    FavoriteManager.onFavoriteChange(this.favChangeCb);
  }

  aboutToDisappear(): void {
    if (this.detailDialog) {
      this.detailDialog.close();
      this.detailDialog = null;
    }
    FavoriteManager.offFavoriteChange(this.favChangeCb);
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
    this.cleanPlot = FormatUtil.cleanPlot(raw);

    const s = this.descriptor?.dbScore ? this.descriptor.dbScore.trim() : '';
    this.scoreText = (!s || s === '0' || s === '0.0') ? '' : s;
  }

  private hasDetailInfo(): boolean {
    return this.directorText() !== '' || this.actorText() !== '' || this.cleanPlot !== '';
  }

  private briefMetaText(): string {
    const parts: string[] = [];
    if (this.descriptor?.year && this.descriptor.year.trim()) {
      parts.push(this.descriptor.year.trim());
    }
    const cat = this.descriptor?.classTag || this.descriptor?.cName;
    if (cat && cat.trim()) {
      const firstCat = cat.trim().split(/[,/，\s]+/)[0].trim();
      if (firstCat) {
        parts.push(firstCat);
      }
    }
    const rawArea = this.descriptor?.area || this.descriptor?.language;
    if (rawArea && rawArea.trim()) {
      const firstArea = rawArea.trim().split(/[,/，\s]+/)[0].trim();
      if (firstArea) {
        parts.push(firstArea);
      }
    }
    if (parts.length === 0) {
      return '';
    }
    return parts.join(' · ');
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

  private async syncFavState(): Promise<void> {
    const targetId = this.filmId;
    if (!targetId) {
      this.isFav = false;
      return;
    }
    const fav = await FavoriteManager.isFavorite(targetId);
    if (this.filmId === targetId) {
      this.isFav = fav;
    }
  }

  private async handleToggleFavorite(): Promise<void> {
    if (!this.filmId || !this.name) return;
    const item: FavoriteItem = {
      id: this.filmId, name: this.name, picture: this.picture,
      cName: this.descriptor?.cName || '', remarks: this.descriptor?.remarks || '',
      year: this.descriptor?.year || '', area: this.descriptor?.area || '',
      subTitle: this.subTitle, actor: this.actor, director: this.descriptor?.director || '',
      createdAt: Date.now()
    };
    const next: boolean = await FavoriteManager.toggleFavorite(item);
    this.isFav = next;
    try {
      this.getUIContext().getPromptAction().showToast({ message: next ? '已加入收藏' : '已取消收藏' });
    } catch (_e) {}
  }

  build() {
    Column() {
      // 1. 片名与收藏行（左侧片名最多2行后省略；右上角常驻唯一收藏胶囊，平衡短片名与长片名的视觉重心）
      Row() {
        Text(this.name)
          .fontSize(AppTheme.FONT_XL)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(24)
          .layoutWeight(1)

        // 收藏按钮（右上角唯一的实体胶囊，26vp 精致尺寸，顶部对齐）
        Row({ space: 3 }) {
          AppIcon({
            src: this.isFav ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'),
            iconSize: 13,
            color: this.isFav ? '#FA8C16' : AppTheme.TEXT_SECONDARY
          })
          Text(this.isFav ? '已收藏' : '收藏')
            .fontSize(AppTheme.FONT_SM)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isFav ? '#FA8C16' : AppTheme.TEXT_SECONDARY)
        }
        .height(26)
        .padding({ left: 9, right: 9 })
        .backgroundColor(this.isFav ? 'rgba(250, 140, 22, 0.14)' : AppTheme.BG_CARD)
        .borderRadius(AppTheme.RADIUS_PILL)
        .border({ width: 0.5, color: this.isFav ? 'rgba(250, 140, 22, 0.35)' : AppTheme.BORDER })
        .margin({ left: 10 })
        .onClick(() => {
          this.handleToggleFavorite();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 12, right: 12, top: 8, bottom: 4 })

      // 2. 元数据与简介行（纯信息展示，全靠左自然流式排布，整行点击直达详情弹窗）
      Row({ space: 6 }) {
        // 评分微标（如有）
        if (this.scoreText !== '') {
          Row({ space: 2 }) {
            Text('★')
              .fontSize(AppTheme.FONT_XS)
              .fontColor(AppTheme.ACCENT)
            Text(this.scoreText)
              .fontSize(AppTheme.FONT_SM)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.ACCENT)
            Text('分')
              .fontSize(AppTheme.FONT_2XS)
              .fontColor(AppTheme.ACCENT)
          }
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(AppTheme.ACCENT_SOFT)
          .borderRadius(AppTheme.RADIUS_SM)
        }

        // 核心信息摘要（年份 · 分类 · 地区）
        if (this.briefMetaText() !== '') {
          Text(this.briefMetaText())
            .fontSize(AppTheme.FONT_SM)
            .fontColor(AppTheme.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: '65%' })
        }

        // 紧贴左侧的纯文字更多入口（主题高亮色链接，无按钮底色）
        Row({ space: 1 }) {
          if (this.briefMetaText() !== '') {
            Text('· ')
              .fontSize(AppTheme.FONT_SM)
              .fontColor(AppTheme.TEXT_MUTED)
          }
          Text('更多')
            .fontSize(AppTheme.FONT_SM)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.ACCENT)
          AppIcon({
            src: $r('sys.symbol.chevron_right'),
            iconSize: 10,
            color: AppTheme.ACCENT
          })
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 12, right: 12, top: 2, bottom: 8 })
      .onClick(() => {
        this.openDetailDialog();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
