import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { FilmApi } from '../api/FilmApi';
import { HistoryItem, MovieBasicInfo, MovieUrlInfo, PlaySource } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { HistoryManager } from '../common/utils/HistoryManager';
import { NavUtil } from '../common/utils/NavUtil';
import { ServerConfigManager } from '../common/utils/ServerConfigManager';
import { WindowBar } from '../common/utils/WindowBar';
import { PlayerWindow } from '../common/utils/PlayerWindow';
import { common } from '@kit.AbilityKit';
import { VideoPlayer } from '../components/VideoPlayer';
import { PlayDetailPanel } from '../components/PlayDetailPanel';
import { FilmGrid } from '../components/FilmGrid';
import { LoadingView } from '../components/LoadingView';
import { EmptyState } from '../components/EmptyState';
import { SourceGuard } from '../common/utils/SourceGuard';

@Entry
@Component
struct PlayPage {
  @State private filmId: string = '';
  @State private loading: boolean = true;
  @State private errorText: string = '';
  @State private name: string = '';
  @State private picture: string = '';
  @State private subTitle: string = '';
  @State private plot: string = '';
  @State private sources: PlaySource[] = [];
  @State private playingSourceId: string = '';
  @State private viewingSourceId: string = '';
  @State private episodeIndex: number = 0;
  @State private playUrl: string = '';
  @State private playToken: number = 0;
  @State private playTitle: string = '';
  @State private initialTime: number = 0;
  @State private related: MovieBasicInfo[] = [];
  @State private relateLoading: boolean = false;
  @State private activeTab: number = 0;
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  @State private leftInset: number = 0;
  @State private rightInset: number = 0;
  @State private viewW: number = 16;
  @State private viewH: number = 9;
  @State private playerFull: boolean = false;
  @State private playerActive: boolean = true;
  private sourceName: string = '';
  private reconnectCb: () => void = () => {};
  private loadToken: number = 0;
  private relateToken: number = 0;
  private historySeq: number = 0;
  private persistEnabled: boolean = true;
  private lastCurrentTime: number = 0;
  private lastDuration: number = 0;

  aboutToAppear() {
    WindowBar.apply(getContext(this) as common.UIAbilityContext, (top: number, bottom: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
    }, (left: number, right: number, width: number, height: number) => {
      this.leftInset = left;
      this.rightInset = right;
      this.viewW = width;
      this.viewH = height;
    });
    const params = router.getParams() as Object;
    this.filmId = NavUtil.param(params, 'id');
    const sourceId = NavUtil.param(params, 'sourceId');
    const hasEpisodeParam = NavUtil.param(params, 'episodeIndex') !== '';
    const hasCurrentTimeParam = NavUtil.param(params, 'currentTime') !== '';
    this.episodeIndex = Number(NavUtil.param(params, 'episodeIndex', '0')) || 0;
    this.initialTime = Number(NavUtil.param(params, 'currentTime', '0')) || 0;
    this.lastCurrentTime = this.initialTime;

    if (!sourceId && !hasEpisodeParam && !hasCurrentTimeParam && this.filmId) {
      HistoryManager.find(this.filmId).then((prev: HistoryItem | null) => {
        let sid = sourceId;
        if (prev) {
          sid = prev.sourceId || '';
          this.episodeIndex = prev.episodeIndex || 0;
          const isEnded = prev.duration > 0 && prev.currentTime >= prev.duration - 3;
          this.initialTime = isEnded ? 0 : (prev.currentTime || 0);
          this.lastCurrentTime = this.initialTime;
          this.lastDuration = prev.duration || 0;
        }
        this.loadPlay(sid);
        this.loadRelate();
      });
    } else {
      this.loadPlay(sourceId);
      this.loadRelate();
    }

    this.reconnectCb = () => {
      this.persistEnabled = false;
      this.historySeq++;
      this.playUrl = '';
      if (!this.filmId) {
        return;
      }
      this.loadPlay(this.playingSourceId);
      this.loadRelate();
    };
    SourceGuard.onReconnect(this.reconnectCb);
  }

  onPageShow(): void {
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

  private setPlayerFull(full: boolean): void {
    if (this.playerFull === full) {
      return;
    }
    this.playerFull = full;
    PlayerWindow.setFullscreen(getContext(this) as common.UIAbilityContext, full);
  }

  private async loadPlay(sourceId: string): Promise<void> {
    if (!this.filmId) {
      this.errorText = '未找到影片参数';
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
      const info = await FilmApi.getPlayInfo(this.filmId, sourceId, this.episodeIndex);
      if (token !== this.loadToken) {
        return;
      }
      const detail = info.detail;
      this.name = detail.name;
      this.picture = detail.picture;
      this.subTitle = detail.descriptor.subTitle;
      this.plot = detail.descriptor.content || detail.descriptor.blurb;
      this.sources = detail.list;
      this.playingSourceId = info.currentPlayFrom || (detail.list.length > 0 ? detail.list[0].id : '');
      this.viewingSourceId = this.playingSourceId;
      this.episodeIndex = info.currentEpisode;
      this.playUrl = info.current.link;
      this.playTitle = `${detail.name} · ${info.current.episode}`;
      this.sourceName = this.findSource(this.playingSourceId)?.name || '默认源';
      this.errorText = '';
      this.persistEnabled = true;
      this.persistHistory();
    } catch (err) {
      if (token !== this.loadToken) {
        return;
      }
      const message = err instanceof Error ? err.message : '播放数据获取失败';
      if (this.name) {
        promptAction.showToast({ message: message });
      } else {
        this.errorText = message;
      }
    } finally {
      if (token === this.loadToken) {
        this.loading = false;
      }
    }
  }

  private async loadRelate(): Promise<void> {
    if (!this.filmId) {
      return;
    }
    const token = ++this.relateToken;
    this.relateLoading = true;
    try {
      const list = await FilmApi.getRelate(this.filmId);
      if (token !== this.relateToken) {
        return;
      }
      this.related = list;
    } catch (err) {
      if (token !== this.relateToken) {
        return;
      }
      this.related = [];
    } finally {
      if (token === this.relateToken) {
        this.relateLoading = false;
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
    if (!source) {
      return false;
    }
    return this.episodeIndex < source.linkList.length - 1;
  }

  private hasPrev(): boolean {
    return this.episodeIndex > 0 && !!this.findSource(this.playingSourceId);
  }

  private playPrev(): void {
    if (!this.hasPrev()) {
      promptAction.showToast({ message: '已经是第一集了' });
      return;
    }
    this.selectEpisode(this.playingSourceId, this.episodeIndex - 1);
  }

  private playNext(): void {
    if (!this.hasNext()) {
      promptAction.showToast({ message: '已经是最后一集了' });
      return;
    }
    this.selectEpisode(this.playingSourceId, this.episodeIndex + 1);
  }

  private currentEpisodeName(): string {
    const source = this.findSource(this.playingSourceId);
    if (!source || this.episodeIndex >= source.linkList.length) {
      return '';
    }
    return source.linkList[this.episodeIndex].episode;
  }

  private persistHistory(currentTime?: number, duration?: number): void {
    if (!this.persistEnabled || !this.filmId || !this.name) {
      return;
    }
    if (!ServerConfigManager.getInstance().storageScope()) {
      return;
    }
    const seq = ++this.historySeq;
    const filmId = this.filmId;
    const name = this.name;
    const picture = this.picture;
    const sourceId = this.playingSourceId;
    const source = this.findSource(sourceId);
    const sourceName = source ? source.name : this.sourceName;
    const episodeIndex = this.episodeIndex;
    const fallback: MovieUrlInfo = { episode: this.playTitle, link: this.playUrl };
    const episode: MovieUrlInfo = source && source.linkList.length > episodeIndex ?
      source.linkList[episodeIndex] : fallback;
    HistoryManager.find(filmId).then((previous: HistoryItem | null) => {
      if (seq !== this.historySeq || !this.persistEnabled) {
        return;
      }
      const cur = currentTime !== undefined ? currentTime : (previous ? previous.currentTime : 0);
      const dur = duration !== undefined ? duration : (previous ? previous.duration : 0);
      const item: HistoryItem = {
        id: filmId,
        name: name,
        picture: picture,
        sourceId: sourceId,
        sourceName: sourceName,
        episodeIndex: episodeIndex,
        episode: episode.episode,
        currentTime: cur,
        duration: dur,
        timeStamp: Date.now()
      };
      HistoryManager.save(item);
    });
  }

  private openRelated(film: MovieBasicInfo): void {
    const id = FormatUtil.filmId(film);
    if (!id || id === this.filmId) {
      return;
    }
    this.filmId = id;
    this.episodeIndex = 0;
    this.initialTime = 0;
    this.lastCurrentTime = 0;
    this.lastDuration = 0;
    this.activeTab = 0;
    this.loadPlay('');
    this.loadRelate();
  }

  @Builder
  playTabItem(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.activeTab === index ? AppTheme.TEXT_PRIMARY : AppTheme.TEXT_MUTED)
      Column()
        .width(18)
        .height(3)
        .backgroundColor(this.activeTab === index ? AppTheme.ACCENT : Color.Transparent)
        .borderRadius(2)
        .margin({ top: 6 })
    }
    .padding({ right: 20 })
    .onClick(() => {
      this.activeTab = index;
    })
  }

  build() {
    Column() {
      if (this.loading && !this.name) {
        LoadingView({ label: '正在打开播放页' })
      } else if (this.errorText && !this.name) {
        EmptyState({
          title: '当前内容无法播放',
          subtitle: this.errorText,
          icon: $r('sys.symbol.play_circle')
        })
      } else {
        VideoPlayer({
          videoUrl: this.playUrl,
          reloadToken: this.playToken,
          title: this.playTitle,
          poster: this.picture,
          initialTime: this.initialTime,
          showBack: true,
          isFull: this.playerFull,
          pageActive: this.playerActive,
          hasPrev: this.hasPrev(),
          hasNext: this.hasNext(),
          topInset: this.playerFull ? this.topInset : 0,
          leftInset: this.playerFull ? this.leftInset : 0,
          rightInset: this.playerFull ? this.rightInset : 0,
          bottomInset: this.playerFull ? this.bottomInset : 0,
          onBack: () => {
            router.back();
          },
          onEnded: () => {
            if (this.hasNext()) {
              this.playNext();
            }
          },
          onPrev: () => this.playPrev(),
          onNext: () => this.playNext(),
          onFullscreenChange: (full: boolean) => this.setPlayerFull(full),
          onProgress: (current: number, duration: number) => {
            this.lastCurrentTime = current;
            this.lastDuration = duration;
            this.persistHistory(current, duration);
          }
        })
          .width('100%')
          .aspectRatio(this.playerFull ? this.viewW / Math.max(this.viewH, 1) : 16 / 9)
          .layoutWeight(this.playerFull ? 1 : 0)
          .constraintSize(this.playerFull ?
            { minWidth: '100%', maxWidth: '100%', minHeight: '100%', maxHeight: '100%' } :
            { minHeight: 0 })

        if (!this.playerFull) {
          Column()
            .width('100%')
            .height(8)
            .backgroundColor(AppTheme.BG_ELEVATED)

          Row() {
            this.playTabItem('详情', 0)
            this.playTabItem('相关推荐', 1)
          }
          .width('100%')
          .height(44)
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Center)
          .padding({ left: 12, right: 12 })

          Stack() {
            Column() {
            PlayDetailPanel({
              name: this.name,
              subTitle: this.subTitle,
              plot: this.plot,
              sources: this.sources,
              playingSourceId: this.playingSourceId,
              viewingSourceId: this.viewingSourceId,
              episodeIndex: this.episodeIndex,
              onViewSource: (id: string) => {
                this.viewingSourceId = id;
              },
              onSelectEpisode: (sourceId: string, index: number) => {
                this.selectEpisode(sourceId, index);
              }
            })
          }
          .width('100%')
          .height('100%')
          .visibility(this.activeTab === 0 ? Visibility.Visible : Visibility.Hidden)

          if (this.activeTab === 1) {
            Column() {
              if (this.relateLoading) {
                LoadingView({ label: '加载相关推荐' })
              } else if (this.related.length === 0) {
                EmptyState({
                  title: '暂无相关推荐',
                  subtitle: '换一部片子再看看',
                  icon: $r('sys.symbol.film')
                })
              } else {
                FilmGrid({
                  films: this.related,
                  columns: 3,
                  onClickFilm: (film: MovieBasicInfo) => this.openRelated(film)
                })
                .padding({ left: 12, right: 12, top: 4, bottom: 12 })
              }
            }
            .width('100%')
            .height('100%')
          }
        }
          .layoutWeight(1)
          .width('100%')
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.playerFull ? 0 : this.topInset,
      bottom: this.playerFull ? 0 : this.bottomInset
    })
    .backgroundColor(this.playerFull ? '#000000' : AppTheme.BG)
  }
}
