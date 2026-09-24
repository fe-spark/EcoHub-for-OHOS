import { FilmApi } from '../api/FilmApi';
import { HistoryItem, MovieBasicInfo, MovieDescriptor, MovieUrlInfo, PlaySource } from '../types/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { HistoryManager } from '../services/HistoryManager';
import { FavoriteManager } from '../services/FavoriteManager';
import { NavUtil } from '../common/utils/NavUtil';
import { PlayNavigation } from '../common/utils/PlayNavigation';
import { ServerConfigManager } from '../services/ServerConfigManager';
import { WindowBar } from '../common/utils/WindowBar';
import { PlayerWindow } from '../modules/player/PlayerWindow';
import { common } from '@kit.AbilityKit';
import { VideoPlayer } from '../modules/player/VideoPlayer';
import { PlayDetailPanel } from '../components/film/PlayDetailPanel';
import { LivePlayRelatedView } from '../components/film/LivePlayRelatedView';
import { LoadingView } from '../components/common/LoadingView';
import { SourceGuard } from '../services/SourceGuard';
import { HttpClient } from '../common/network/HttpClient';
import { Breakpoint } from '../common/utils/Breakpoint';
import { LivePlayErrorView } from '../components/player/LivePlayErrorView';

@Entry
@Component
struct LivePlayPage {
  @State private sourceId: string = '';
  @State private sourceMid: string = '';
  @State private errorText: string = '';
  @State private name: string = '';
  @State private subTitle: string = '';
  @State private actor: string = '';
  @State private picture: string = '';
  @State private plot: string = '';
  @State private descriptor: MovieDescriptor | null = null;
  @State private loading: boolean = true;
  @State private sources: PlaySource[] = [];
  @State private playingSourceId: string = '';
  @State private viewingSourceId: string = '';
  @State private episodeIndex: number = 0;
  @State private playUrl: string = '';
  @State private playToken: number = 0;
  @State private playTitle: string = '';
  @State private initialTime: number = 0;
  @State private activeTab: number = 0;
  @State private related: MovieBasicInfo[] = [];
  @State private relateLoading: boolean = false;
  @State private pageW: number = 0;
  @State private pageH: number = 0;
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  @State private leftInset: number = 0;
  @State private rightInset: number = 0;
  @State private playerFull: boolean = false;
  @State private playerActive: boolean = true;
  @State private isFav: boolean = false;
  @StorageLink('WIDTH_BP') private widthBp: string = 'sm';
  @StorageLink('SETTING_AUTO_PLAY_NEXT') private settingAutoPlayNext: boolean = true;
  private sourceName: string = '采集源';
  private reconnectCb: () => void = () => {};
  private favChangeCb: () => void = () => {};
  private loadToken: number = 0;
  private historySeq: number = 0;
  private persistEnabled: boolean = true;
  private lastCurrentTime: number = 0;
  private lastDuration: number = 0;

  private historyId(): string {
    return PlayNavigation.livePlayHistoryId(this.sourceId, this.sourceMid);
  }

  private applyWindowBar(): void {
    WindowBar.apply(this.getUIContext().getHostContext() as common.UIAbilityContext,
      (top: number, bottom: number, left: number, right: number) => {
        this.topInset = top; this.bottomInset = bottom; this.leftInset = left; this.rightInset = right;
      }, (left: number, right: number) => { this.leftInset = left; this.rightInset = right; });
  }

  private async syncFavoriteState(): Promise<void> {
    const key = this.historyId();
    this.isFav = key ? await FavoriteManager.isFavorite(key) : false;
  }

  async aboutToAppear(): Promise<void> {
    this.applyWindowBar();
    const params = this.getUIContext().getRouter().getParams() as Object;
    this.sourceId = NavUtil.param(params, 'sourceId');
    this.sourceMid = NavUtil.param(params, 'sourceMid');
    const paramTitle = NavUtil.param(params, 'title');
    if (paramTitle) this.name = paramTitle;
    const historyKey = this.historyId();
    if (historyKey) {
      HttpClient.getInstance().trackView('play', historyKey, 'LivePlayPage');
      this.syncFavoriteState();
      try {
        const fav = await FavoriteManager.find(historyKey);
        if (fav?.name && !this.name) this.name = fav.name;
      } catch (_e) {}
    }
    this.favChangeCb = () => { this.syncFavoriteState(); };
    FavoriteManager.onFavoriteChange(this.favChangeCb);
    const paramEp = NavUtil.param(params, 'episodeIndex');
    const paramTime = NavUtil.param(params, 'currentTime');
    let targetEpIndex = paramEp !== '' ? Number(paramEp) : -1;
    let targetTime = paramTime !== '' ? Number(paramTime) : -1;
    if (historyKey && targetEpIndex < 0 && targetTime < 0) {
      try {
        const prev = await HistoryManager.find(historyKey);
        if (prev) {
          if (!this.name && prev.name) this.name = prev.name;
          if (prev.episodeIndex !== undefined && prev.episodeIndex !== null) targetEpIndex = prev.episodeIndex;
          targetTime = (prev.duration > 0 && prev.currentTime >= prev.duration - 3) ? 0 : (prev.currentTime || 0);
          this.lastDuration = prev.duration || 0;
        }
      } catch (_e) {}
    }
    this.episodeIndex = Math.max(0, targetEpIndex >= 0 ? targetEpIndex : 0);
    this.initialTime = Math.max(0, targetTime >= 0 ? targetTime : 0);
    this.lastCurrentTime = this.initialTime;
    this.loadPlay();
    this.reconnectCb = () => {
      this.persistEnabled = false;
      this.historySeq++;
      this.playUrl = '';
      if (this.sourceId && this.sourceMid) this.loadPlay();
    };
    SourceGuard.onReconnect(this.reconnectCb);
  }

  onPageShow(): void {
    this.applyWindowBar();
    this.playerActive = true;
    this.syncFavoriteState();
  }

  onPageHide(): void {
    this.playerActive = false;
    if (this.lastCurrentTime > 0) this.persistHistory(this.lastCurrentTime, this.lastDuration);
  }

  onBackPress(): boolean {
    if (this.playerFull) {
      this.setPlayerFull(false);
      return true;
    }
    return false;
  }

  aboutToDisappear(): void {
    if (this.playerFull) this.setPlayerFull(false);
    if (this.lastCurrentTime > 0) this.persistHistory(this.lastCurrentTime, this.lastDuration);
    SourceGuard.offReconnect(this.reconnectCb);
    FavoriteManager.offFavoriteChange(this.favChangeCb);
  }

  private setPlayerFull(full: boolean, isPortrait: boolean = false): void {
    if (this.playerFull === full) return;
    this.playerFull = full;
    PlayerWindow.setFullscreen(this.getUIContext().getHostContext() as common.UIAbilityContext, full, isPortrait);
  }

  private async loadPlay(): Promise<void> {
    if (!this.sourceId || !this.sourceMid) {
      this.errorText = '缺少采集源播放参数'; this.loading = false; return;
    }
    const token = ++this.loadToken;
    this.loading = true;
    this.playUrl = '';
    try {
      const info = await FilmApi.getLivePlayInfo(this.sourceId, this.sourceMid, this.episodeIndex);
      if (token !== this.loadToken) return;
      const detail = info.detail;
      this.name = detail.name;
      this.subTitle = detail.descriptor.remarks || '';
      this.actor = detail.descriptor.actor || '';
      this.picture = detail.picture;
      this.plot = detail.descriptor.content || detail.descriptor.blurb;
      this.descriptor = detail.descriptor;
      this.sources = detail.list;
      this.playingSourceId = info.currentPlayFrom || (detail.list.length > 0 ? detail.list[0].id : '');
      this.viewingSourceId = this.playingSourceId;
      this.episodeIndex = info.currentEpisode;
      this.playUrl = info.current.link;
      this.playTitle = `${detail.name} · ${info.current.episode}`;
      this.sourceName = this.findSource(this.playingSourceId)?.name || '采集源';
      this.errorText = '';
      this.persistEnabled = true;
      this.persistHistory();
      this.loadRelate(detail.rawCid || detail.cid);
    } catch (err) {
      if (token !== this.loadToken) return;
      this.errorText = err instanceof Error ? err.message : '现场播放数据获取失败';
    } finally {
      if (token === this.loadToken) this.loading = false;
    }
  }

  private async removeFavorite(): Promise<void> {
    const key = this.historyId();
    if (!key) return;
    try {
      await FavoriteManager.remove(key);
      this.isFav = false;
      this.getUIContext().getPromptAction().showToast({ message: '已从收藏中移出' });
    } catch (_e) {
      this.getUIContext().getPromptAction().showToast({ message: '移出收藏失败' });
    }
  }

  private async loadRelate(cid: number): Promise<void> {
    this.relateLoading = true;
    try {
      this.related = await FilmApi.getLiveRelate(this.sourceId, cid, this.sourceMid);
    } catch (_e) {
      this.related = [];
    } finally {
      this.relateLoading = false;
    }
  }

  private findSource(id: string): PlaySource | null {
    for (let i = 0; i < this.sources.length; i++) {
      if (this.sources[i].id === id) return this.sources[i];
    }
    return this.sources.length > 0 ? this.sources[0] : null;
  }

  private selectEpisode(sourceId: string, index: number): void {
    const source = this.findSource(sourceId);
    if (!source || index < 0 || index >= source.linkList.length) return;
    const episode: MovieUrlInfo = source.linkList[index];
    this.playingSourceId = sourceId;
    this.viewingSourceId = sourceId;
    this.episodeIndex = index;
    this.initialTime = 0;
    this.lastCurrentTime = 0;
    this.lastDuration = 0;
    this.playUrl = episode.link;
    this.playToken += 1;
    this.playTitle = `${this.name} · ${episode.episode}`;
    this.sourceName = source.name;
    this.persistHistory(0, 0);
  }

  private hasNext(): boolean {
    const source = this.findSource(this.playingSourceId);
    return !!source && this.episodeIndex < source.linkList.length - 1;
  }

  private hasPrev(): boolean {
    return this.episodeIndex > 0 && !!this.findSource(this.playingSourceId);
  }

  private playPrev(): void {
    if (!this.hasPrev()) {
      try { this.getUIContext().getPromptAction().showToast({ message: '已经是第一集了' }); } catch (_e) {}
      return;
    }
    this.selectEpisode(this.playingSourceId, this.episodeIndex - 1);
  }

  private playNext(): void {
    if (!this.hasNext()) {
      try { this.getUIContext().getPromptAction().showToast({ message: '已经是最后一集了' }); } catch (_e) {}
      return;
    }
    this.selectEpisode(this.playingSourceId, this.episodeIndex + 1);
  }

  private async openRelated(film: MovieBasicInfo): Promise<void> {
    const newSid = film.sourceMid > 0 ? `${film.sourceMid}` : `${film.id}`;
    if (!newSid || newSid === this.sourceMid) return;
    this.sourceMid = newSid;
    const historyKey = this.historyId();
    if (historyKey) HttpClient.getInstance().trackView('play', historyKey, 'LivePlayPage');
    this.name = film.name || '';
    this.sources = [];
    this.playUrl = '';
    this.activeTab = 0;
    this.loading = true;
    this.syncFavoriteState();

    let targetEpisodeIndex = 0, targetTime = 0;
    if (historyKey) {
      try {
        const prev = await HistoryManager.find(historyKey);
        if (prev) {
          if (!this.name && prev.name) this.name = prev.name;
          if (prev.episodeIndex !== undefined && prev.episodeIndex !== null && prev.episodeIndex >= 0) {
            targetEpisodeIndex = prev.episodeIndex;
          }
          const isEnded = prev.duration > 0 && prev.currentTime >= prev.duration - 3;
          targetTime = isEnded ? 0 : (prev.currentTime || 0);
          this.lastDuration = prev.duration || 0;
        }
      } catch (_e) {}
    }
    this.episodeIndex = targetEpisodeIndex;
    this.initialTime = targetTime;
    this.lastCurrentTime = targetTime;
    this.loadPlay();
  }

  private persistHistory(currentTime?: number, duration?: number): void {
    const filmId = this.historyId();
    if (!this.persistEnabled || !filmId || !this.name || !ServerConfigManager.getInstance().storageScope()) return;
    const seq = ++this.historySeq;
    const source = this.findSource(this.playingSourceId);
    const fallback: MovieUrlInfo = { episode: this.playTitle, link: this.playUrl };
    const ep: MovieUrlInfo = source && source.linkList.length > this.episodeIndex ? source.linkList[this.episodeIndex] : fallback;
    HistoryManager.find(filmId).then((prev: HistoryItem | null) => {
      if (seq !== this.historySeq || !this.persistEnabled) return;
      HistoryManager.save({
        id: filmId, name: this.name, picture: this.picture, sourceId: this.sourceId,
        sourceName: source ? source.name : this.sourceName, episodeIndex: this.episodeIndex, episode: ep.episode,
        currentTime: currentTime !== undefined ? currentTime : (prev ? prev.currentTime : 0),
        duration: duration !== undefined ? duration : (prev ? prev.duration : 0),
        timeStamp: Date.now()
      });
    });
  }

  private isWideScreen(): boolean {
    if (this.pageW > 0 && this.pageH > 0) return this.pageW >= 600 && this.pageW > this.pageH;
    return Breakpoint.isWide(this.widthBp) && Breakpoint.windowWidth() > Breakpoint.windowHeight();
  }

  private splitPlay(): boolean { return !this.playerFull && this.isWideScreen(); }
  private hudLeftInset(): number { return (this.playerFull || this.splitPlay()) ? Math.max(this.leftInset, AppTheme.SAFE_EDGE) : 0; }
  private hudRightInset(): number { return this.playerFull ? Math.max(this.rightInset, AppTheme.SAFE_EDGE) : AppTheme.SAFE_EDGE; }
  private hudTopInset(): number { return (this.playerFull || this.splitPlay()) ? this.topInset : 0; }
  private hudBottomInset(): number { return (this.playerFull || this.splitPlay()) ? this.bottomInset : 0; }

  @Builder
  playTabItem(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(16).fontWeight(FontWeight.Bold)
        .fontColor(this.activeTab === index ? AppTheme.TEXT_PRIMARY : AppTheme.TEXT_MUTED)
      Column()
        .width(18).height(3).borderRadius(2).margin({ top: 6 })
        .backgroundColor(this.activeTab === index ? AppTheme.ACCENT : Color.Transparent)
    }
    .padding({ right: 20 })
    .onClick(() => { this.activeTab = index; })
  }

  @Builder
  playVideo() {
    VideoPlayer({
      videoUrl: this.playUrl,
      reloadToken: this.playToken,
      title: this.playTitle,
      poster: this.picture,
      initialTime: this.initialTime,
      showBack: true,
      isFull: this.playerFull,
      edgeHud: this.splitPlay(),
      pageActive: this.playerActive,
      hasPrev: this.hasPrev(),
      hasNext: this.hasNext(),
      topInset: this.hudTopInset(),
      leftInset: this.hudLeftInset(),
      rightInset: this.hudRightInset(),
      bottomInset: this.hudBottomInset(),
      onBack: () => {
        if (this.playerFull) this.setPlayerFull(false);
        else try { this.getUIContext().getRouter().back(); } catch (_e) {}
      },
      onEnded: () => { if (this.settingAutoPlayNext && this.hasNext()) this.playNext(); },
      onPrev: () => this.playPrev(),
      onNext: () => this.playNext(),
      onFullscreenChange: (full: boolean, isPortrait?: boolean) => this.setPlayerFull(full, isPortrait),
      onProgress: (cur: number, dur: number) => {
        this.lastCurrentTime = cur; this.lastDuration = dur; this.persistHistory(cur, dur);
      }
    })
      .width('100%')
      .height((this.playerFull || this.splitPlay()) ? '100%' : undefined)
      .aspectRatio((this.playerFull || this.splitPlay()) ? undefined : 16 / 9)
      .constraintSize({ maxHeight: '100%' })
  }

  @Builder
  playDetail() {
    PlayDetailPanel({
      filmId: this.historyId(),
      picture: this.picture,
      name: this.name,
      subTitle: this.subTitle,
      actor: this.actor,
      sourceName: this.sourceName,
      plot: this.plot,
      descriptor: this.descriptor,
      sources: this.sources,
      playingSourceId: this.playingSourceId,
      viewingSourceId: this.viewingSourceId,
      episodeIndex: this.episodeIndex,
      onViewSource: (id: string) => { this.viewingSourceId = id; },
      onSelectEpisode: (sourceId: string, index: number) => { this.selectEpisode(sourceId, index); }
    })
  }

  @Builder
  sideTabs() {
    Row() {
      this.playTabItem('详情', 0)
      this.playTabItem('同类推荐', 1)
    }
    .width('100%')
    .height(44)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 12 })

    Stack() {
      Column() { this.playDetail() }.width('100%').height('100%')
        .visibility(this.activeTab === 0 ? Visibility.Visible : Visibility.Hidden)
      if (this.activeTab === 1) {
        Column() {
          LivePlayRelatedView({
            relateLoading: this.relateLoading,
            related: this.related,
            columns: this.splitPlay() ? 3 : Breakpoint.gridCols(this.widthBp),
            onOpenRelated: (film: MovieBasicInfo) => this.openRelated(film)
          })
        }.width('100%').height('100%')
      }
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  playBody() {
    Row() {
      Column() { this.playVideo() }
        .layoutWeight(this.splitPlay() ? 7 : 1)
        .width(this.splitPlay() ? undefined : '100%')
        .height(this.splitPlay() || this.playerFull ? '100%' : 'auto')
        .backgroundColor(this.playerFull ? '#000000' : AppTheme.BG)

      if (this.splitPlay()) {
        Column() {
          Column().width(1).height('100%').backgroundColor('rgba(255, 255, 255, 0.14)')
        }
        .height('100%').padding({ top: this.topInset, bottom: this.bottomInset })

        Column() { this.sideTabs() }
          .layoutWeight(5)
          .height('100%')
          .padding({ top: this.topInset, bottom: this.bottomInset })
          .backgroundColor(AppTheme.BG_ELEVATED)
      }
    }
    .width('100%')
    .layoutWeight(this.splitPlay() || this.playerFull ? 1 : 0)

    if (!this.playerFull && !this.splitPlay()) {
      Column().width('100%').height(8).backgroundColor(AppTheme.BG_ELEVATED)
      this.sideTabs()
    }
  }

  build() {
    Column() {
      if (this.loading && !this.sources.length) {
        LoadingView({ label: '正在打开播放页' })
      } else if (this.errorText && !this.sources.length) {
        LivePlayErrorView({
          filmName: this.name,
          errorText: this.errorText,
          isFavorite: this.isFav,
          onBack: () => {
            try { this.getUIContext().getRouter().back(); } catch (_e) {}
          },
          onRetry: () => { this.loadPlay(); },
          onRemoveFavorite: () => { this.removeFavorite(); }
        })
      } else {
        this.playBody()
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_old: Area, newArea: Area) => {
      const w = Number(newArea.width);
      const h = Number(newArea.height);
      if (w > 0 && h > 0) {
        this.pageW = w;
        this.pageH = h;
      }
    })
    .padding({
      top: (this.playerFull || this.splitPlay()) ? 0 : this.topInset,
      bottom: (this.playerFull || this.splitPlay()) ? 0 : this.bottomInset,
      left: (this.playerFull || this.splitPlay()) ? 0 : this.leftInset,
      right: (this.playerFull || this.splitPlay()) ? 0 : this.rightInset
    })
    .backgroundColor(this.playerFull ? '#000000' : AppTheme.BG)
  }
}
