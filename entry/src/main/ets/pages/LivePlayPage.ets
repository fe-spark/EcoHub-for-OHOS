import { FilmApi } from '../api/FilmApi';
import { HistoryItem, MovieUrlInfo, PlaySource } from '../types/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { HistoryManager } from '../services/HistoryManager';
import { NavUtil } from '../common/utils/NavUtil';
import { PlayNavigation } from '../common/utils/PlayNavigation';
import { ServerConfigManager } from '../services/ServerConfigManager';
import { WindowBar } from '../common/utils/WindowBar';
import { PlayerWindow } from '../modules/player/PlayerWindow';
import { common } from '@kit.AbilityKit';
import { VideoPlayer } from '../modules/player/VideoPlayer';
import { PageHeader } from '../components/common/PageHeader';
import { LivePlayPanel } from '../components/film/LivePlayPanel';
import { LoadingView } from '../components/common/LoadingView';
import { EmptyState } from '../components/common/EmptyState';
import { SourceGuard } from '../services/SourceGuard';
import { HttpClient } from '../common/network/HttpClient';
import { Breakpoint } from '../common/utils/Breakpoint';

@Entry
@Component
struct LivePlayPage {
  @State private sourceId: string = '';
  @State private sourceMid: string = '';
  @State private errorText: string = '';
  @State private name: string = '';
  @State private picture: string = '';
  @State private plot: string = '';
  @State private loading: boolean = true;
  @State private sources: PlaySource[] = [];
  @State private playingSourceId: string = '';
  @State private episodeIndex: number = 0;
  @State private playUrl: string = '';
  @State private playToken: number = 0;
  @State private playTitle: string = '';
  @State private initialTime: number = 0;
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  @State private leftInset: number = 0;
  @State private rightInset: number = 0;
  @State private playerFull: boolean = false;
  @State private playerActive: boolean = true;
  @StorageLink('WIDTH_BP') private widthBp: string = 'sm';
  @StorageLink('SETTING_AUTO_PLAY_NEXT') private settingAutoPlayNext: boolean = true;
  private sourceName: string = '采集源';
  private reconnectCb: () => void = () => {};
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
        this.topInset = top;
        this.bottomInset = bottom;
        this.leftInset = left;
        this.rightInset = right;
      }, (left: number, right: number, _width: number, _height: number) => {
        this.leftInset = left;
        this.rightInset = right;
      });
  }

  async aboutToAppear(): Promise<void> {
    this.applyWindowBar();
    const params = this.getUIContext().getRouter().getParams() as Object;
    this.sourceId = NavUtil.param(params, 'sourceId');
    this.sourceMid = NavUtil.param(params, 'sourceMid');
    const historyKey = this.historyId();
    if (historyKey) {
      HttpClient.getInstance().trackView('play', historyKey, 'LivePlayPage');
    }
    const paramEp = NavUtil.param(params, 'episodeIndex');
    const paramTime = NavUtil.param(params, 'currentTime');
    let targetEpIndex = paramEp !== '' ? Number(paramEp) : -1;
    let targetTime = paramTime !== '' ? Number(paramTime) : -1;

    if (historyKey && targetEpIndex < 0 && targetTime < 0) {
      try {
        const prev = await HistoryManager.find(historyKey);
        if (prev) {
          if (prev.episodeIndex !== undefined && prev.episodeIndex !== null) {
            targetEpIndex = prev.episodeIndex;
          }
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
      if (!this.sourceId || !this.sourceMid) {
        return;
      }
      this.loadPlay();
    };
    SourceGuard.onReconnect(this.reconnectCb);
  }

  onPageShow(): void {
    this.applyWindowBar();
    this.playerActive = true;
  }

  onPageHide(): void {
    this.playerActive = false;
    if (this.lastCurrentTime > 0) {
      this.persistHistory(this.lastCurrentTime, this.lastDuration);
    }
  }

  onBackPress(): boolean {
    if (this.playerFull) {
      this.setPlayerFull(false);
      return true;
    }
    return false;
  }

  aboutToDisappear(): void {
    if (this.playerFull) {
      this.setPlayerFull(false);
    }
    if (this.lastCurrentTime > 0) {
      this.persistHistory(this.lastCurrentTime, this.lastDuration);
    }
    SourceGuard.offReconnect(this.reconnectCb);
  }

  private setPlayerFull(full: boolean, isPortrait: boolean = false): void {
    if (this.playerFull === full) {
      return;
    }
    this.playerFull = full;
    PlayerWindow.setFullscreen(this.getUIContext().getHostContext() as common.UIAbilityContext, full, isPortrait);
  }

  private async loadPlay(): Promise<void> {
    if (!this.sourceId || !this.sourceMid) {
      this.errorText = '缺少采集源播放参数';
      this.loading = false;
      return;
    }
    const token = ++this.loadToken;
    const firstOpen = !this.name;
    if (firstOpen) {
      this.loading = true;
    }
    this.playUrl = '';
    try {
      const info = await FilmApi.getPlayInfo('', this.sourceId, this.episodeIndex, this.sourceMid);
      if (token !== this.loadToken) {
        return;
      }
      const detail = info.detail;
      this.name = detail.name;
      this.picture = detail.picture;
      this.plot = detail.descriptor.content || detail.descriptor.blurb;
      this.sources = detail.list;
      this.playingSourceId = info.currentPlayFrom || (detail.list.length > 0 ? detail.list[0].id : '');
      this.episodeIndex = info.currentEpisode;
      this.playUrl = info.current.link;
      this.playTitle = `${detail.name} · ${info.current.episode}`;
      this.sourceName = this.findSource(this.playingSourceId)?.name || '采集源';
      this.errorText = '';
      this.persistEnabled = true;
      this.persistHistory();
    } catch (err) {
      if (token !== this.loadToken) {
        return;
      }
      const msg = err instanceof Error ? err.message : '播放数据获取失败';
      if (this.name) {
        try {
          this.getUIContext().getPromptAction().showToast({ message: msg });
        } catch (_e) {}
      } else {
        this.errorText = msg;
      }
    } finally {
      if (token === this.loadToken) {
        this.loading = false;
      }
    }
  }

  private findSource(id: string): PlaySource | null {
    for (let i = 0; i < this.sources.length; i++) {
      if (this.sources[i].id === id) {
        return this.sources[i];
      }
    }
    return this.sources.length > 0 ? this.sources[0] : null;
  }

  private selectEpisode(sourceId: string, index: number): void {
    const source = this.findSource(sourceId);
    if (!source || index < 0 || index >= source.linkList.length) {
      return;
    }
    const episode: MovieUrlInfo = source.linkList[index];
    this.playingSourceId = sourceId;
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
      try {
        this.getUIContext().getPromptAction().showToast({ message: '已经是第一集了' });
      } catch (_e) {}
      return;
    }
    this.selectEpisode(this.playingSourceId, this.episodeIndex - 1);
  }

  private playNext(): void {
    if (!this.hasNext()) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '已经是最后一集了' });
      } catch (_e) {}
      return;
    }
    this.selectEpisode(this.playingSourceId, this.episodeIndex + 1);
  }

  private persistHistory(currentTime?: number, duration?: number): void {
    const filmId = this.historyId();
    if (!this.persistEnabled || !filmId || !this.name || !ServerConfigManager.getInstance().storageScope()) {
      return;
    }
    const seq = ++this.historySeq;
    const source = this.findSource(this.playingSourceId);
    const fallback: MovieUrlInfo = { episode: this.playTitle, link: this.playUrl };
    const episode: MovieUrlInfo = source && source.linkList.length > this.episodeIndex
      ? source.linkList[this.episodeIndex] : fallback;

    HistoryManager.find(filmId).then((previous: HistoryItem | null) => {
      if (seq !== this.historySeq || !this.persistEnabled) {
        return;
      }
      HistoryManager.save({
        id: filmId,
        name: this.name,
        picture: this.picture,
        sourceId: this.sourceId,
        sourceName: source ? source.name : this.sourceName,
        episodeIndex: this.episodeIndex,
        episode: episode.episode,
        currentTime: currentTime !== undefined ? currentTime : (previous ? previous.currentTime : 0),
        duration: duration !== undefined ? duration : (previous ? previous.duration : 0),
        timeStamp: Date.now()
      });
    });
  }

  build() {
    Column() {
      if (!this.playerFull) {
        PageHeader({ title: this.name || '现场播放' })
      }

      if (this.loading && !this.name) {
        LoadingView({ label: '正在打开播放页' })
          .layoutWeight(1)
      } else if (this.errorText && !this.name) {
        EmptyState({ title: '当前内容无法播放', subtitle: this.errorText, icon: $r('sys.symbol.play_circle') })
          .layoutWeight(1)
      } else {
        if (this.playUrl) {
          VideoPlayer({
            videoUrl: this.playUrl,
            reloadToken: this.playToken,
            title: this.playTitle,
            poster: this.picture,
            initialTime: this.initialTime,
            showBack: this.playerFull,
            isFull: this.playerFull,
            pageActive: this.playerActive,
            hasPrev: this.hasPrev(),
            hasNext: this.hasNext(),
            topInset: this.playerFull ? this.topInset : 0,
            leftInset: this.playerFull ? this.leftInset : 0,
            rightInset: this.playerFull ? this.rightInset : 0,
            bottomInset: this.playerFull ? this.bottomInset : 0,
            onBack: () => this.setPlayerFull(false),
            onEnded: () => {
              if (this.settingAutoPlayNext && this.hasNext()) {
                this.playNext();
              }
            },
            onPrev: () => this.playPrev(),
            onNext: () => this.playNext(),
            onFullscreenChange: (full: boolean, isPortrait?: boolean) => this.setPlayerFull(full, isPortrait),
            onProgress: (current: number, duration: number) => {
              this.lastCurrentTime = current;
              this.lastDuration = duration;
              this.persistHistory(current, duration);
            }
          })
            .width('100%')
            .height(this.playerFull ? '100%' : undefined)
            .aspectRatio(this.playerFull ? undefined : 16 / 9)
            .layoutWeight(this.playerFull || Breakpoint.isWide(this.widthBp) ? 1 : 0)
        }

        if (!this.playerFull) {
          Scroll() {
            LivePlayPanel({
              sources: this.sources,
              playingSourceId: this.playingSourceId,
              episodeIndex: this.episodeIndex,
              plot: this.plot,
              onSelectEpisode: (sourceId: string, index: number) => this.selectEpisode(sourceId, index)
            })
          }
          .width('100%')
          .layoutWeight(1)
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.playerFull ? 0 : this.topInset,
      bottom: this.playerFull ? 0 : this.bottomInset,
      left: this.playerFull ? 0 : this.leftInset,
      right: this.playerFull ? 0 : this.rightInset
    })
    .backgroundColor(this.playerFull ? '#000000' : AppTheme.BG)
  }
}
