import {
  IjkMediaPlayer,
  OnPreparedListener,
  OnCompletionListener,
  OnErrorListener,
  OnVideoSizeChangedListener,
  OnBufferingUpdateListener,
  OnSeekCompleteListener,
  VideoCodecMode,
} from '@ohos/ijkplayer';
import { PlayerSpeed } from './PlayerSpeed';
import { PlayerPlayableUrl } from './PlayerPlayableUrl';

export class PlayerAvListener {
  onPrepared: (duration: number) => void = (_duration: number) => {};
  onStart: () => void = () => {};
  onPause: () => void = () => {};
  onTime: (time: number) => void = (_time: number) => {};
  onFinish: () => void = () => {};
  onError: (detail?: string) => void = (_detail?: string) => {};
  onSeeked: (timeSec: number, seq: number) => void = (_timeSec: number, _seq: number) => {};
  onBuffer: (buffered: number) => void = (_buffered: number) => {};
  onStalled: (stalled: boolean) => void = (_stalled: boolean) => {};
  onVideoSize: (width: number, height: number) => void = (_width: number, _height: number) => {};
}

/**
 * 基于 ijkplayer (FFmpeg 内核) 的高性能音视频播放驱动
 */
export class PlayerAv {
  static readonly MS_PER_SEC: number = 1000;

  readonly listener: PlayerAvListener = new PlayerAvListener();
  private ijk: IjkMediaPlayer | undefined = undefined;
  private xContext: object | undefined = undefined;
  private surfaceId: string = '';
  private url: string = '';
  private gen: number = 0;
  private speedIndex: number = PlayerSpeed.DEFAULT_INDEX;
  private muted: boolean = false;
  private seekGen: number = 0;
  private progressTimer: number = -1;
  private pendingUrl: string = '';
  private pendingGen: number = 0;

  setXComponentContext(context: object, surfaceId: string): void {
    console.info(`[PlayerAv] setXComponentContext: ${surfaceId}`);
    this.xContext = context;
    this.surfaceId = surfaceId;
    if (this.pendingUrl) {
      const url = this.pendingUrl;
      const gen = this.pendingGen;
      this.pendingUrl = '';
      this.pendingGen = 0;
      this.startPlayInternal(url, gen);
    }
  }

  setSpeedIndex(index: number): void {
    this.speedIndex = index;
    this.applySpeed();
  }

  setMuted(muted: boolean): void {
    this.muted = muted;
    this.applyVolume();
  }

  setScaleMode(_mode: number): void {
    // 画面比例由 PlayerVideoLayer 外层容器与 XComponent 布局自适应控制
  }

  async open(url: string): Promise<void> {
    const gen = ++this.gen;
    console.info(`[PlayerAv] ijkplayer 开始打开: ${url}`);
    this.stopProgressTimer();
    this.pendingUrl = '';
    this.pendingGen = 0;
    await this.resetPlayer();
    if (gen !== this.gen || !url) {
      return;
    }

    let playable = url;
    try {
      playable = await PlayerPlayableUrl.normalize(url);
    } catch (_normErr) {}

    if (gen !== this.gen) {
      return;
    }
    this.url = playable;

    // 若 XComponent 尚未完成 onLoad，暂存等待 onLoad 触发
    if (!this.xContext || !this.surfaceId) {
      console.info(`[PlayerAv] xComponentContext 尚未就绪，暂存播放地址等待加载: ${playable}`);
      this.pendingUrl = playable;
      this.pendingGen = gen;
      return;
    }

    await this.startPlayInternal(playable, gen);
  }

  private async startPlayInternal(playable: string, gen: number): Promise<void> {
    if (gen !== this.gen || !playable || !this.xContext || !this.surfaceId) {
      return;
    }
    try {
      console.info(`[PlayerAv] startPlayInternal: ${playable}, surfaceId: ${this.surfaceId}`);
      const ijk = IjkMediaPlayer.getInstance();
      this.ijk = ijk;
      ijk.setDebug(true);

      // 1. 绑定 XComponent 上下文并指定 SURFACE 硬件渲染模式（核心！必须为 SURFACE 才能渲染画面）
      ijk.setContext(this.xContext, this.surfaceId);
      ijk.native_setup(VideoCodecMode.SURFACE);
      // 2. 配置 FFmpeg / ijkplayer 选项
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec", "1"); // 硬件解码
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "opensles", "1");   // 音频驱动
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "soundtouch", "1"); // 倍速变调补偿
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "framedrop", "1");  // 丢帧保同步
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "reconnect", "1");  // 网络断线重连
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "timeout", "15000000"); // 15s 超时
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "dns_cache_clear", "1");
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "user_agent", "EcoHub-OHOS");

      // 3. 绑定事件监听
      this.bindListeners(ijk, gen);

      // 4. 设置播放源并预加载
      ijk.setDataSource(playable);
      ijk.setMessageListener();
      ijk.prepareAsync();
    } catch (err) {
      console.error(`[PlayerAv] startPlayInternal 异常: ${JSON.stringify(err)}`);
      if (gen === this.gen) {
        const msg = err instanceof Error ? (err.message || String(err)) : String(err);
        this.listener.onError(msg || 'ijkplayer open error');
      }
    }
  }

  play(): void {
    const ijk = this.ijk;
    if (ijk) {
      console.info(`[PlayerAv] ijkplayer.start()`);
      try {
        ijk.start();
        this.startProgressTimer();
        this.listener.onStart();
      } catch (err) {
        console.error(`[PlayerAv] ijk.start 失败: ${JSON.stringify(err)}`);
      }
    }
  }

  pause(): void {
    const ijk = this.ijk;
    if (ijk) {
      console.info(`[PlayerAv] ijkplayer.pause()`);
      try {
        ijk.pause();
        this.stopProgressTimer();
        this.listener.onPause();
      } catch (err) {
        console.error(`[PlayerAv] ijk.pause 失败: ${JSON.stringify(err)}`);
      }
    }
  }

  seek(timeSec: number): number {
    const ijk = this.ijk;
    if (!ijk) {
      return 0;
    }
    const targetMs = Math.max(0, Math.floor(timeSec * PlayerAv.MS_PER_SEC));
    const seq = ++this.seekGen;
    console.info(`[PlayerAv] ijkplayer.seekTo(${timeSec}s / ${targetMs}ms) seq=${seq}`);
    try {
      ijk.seekTo(targetMs.toString());
      return seq;
    } catch (e) {
      console.error(`[PlayerAv] ijkplayer.seekTo 异常: ${JSON.stringify(e)}`);
      return 0;
    }
  }

  abandonSeeksUpTo(_seq: number): void {
  }

  async release(): Promise<void> {
    this.gen++;
    this.url = '';
    this.pendingUrl = '';
    this.stopProgressTimer();
    await this.resetPlayer(true);
  }

  private bindListeners(ijk: IjkMediaPlayer, gen: number): void {
    const onPrepared: OnPreparedListener = {
      onPrepared: () => {
        if (gen !== this.gen || this.ijk !== ijk) return;
        const durMs = ijk.getDuration();
        const duration = durMs > 0 ? durMs / PlayerAv.MS_PER_SEC : 0;
        console.info(`[PlayerAv] ijkplayer prepared! duration: ${duration}s`);
        this.applyVolume();
        this.applySpeed();
        const w = ijk.getVideoWidth();
        const h = ijk.getVideoHeight();
        if (w > 0 && h > 0) {
          this.listener.onVideoSize(w, h);
        }
        this.listener.onPrepared(duration);
      }
    };
    ijk.setOnPreparedListener(onPrepared);

    const onCompletion: OnCompletionListener = {
      onCompletion: () => {
        if (gen !== this.gen || this.ijk !== ijk) return;
        console.info(`[PlayerAv] ijkplayer 播放完成`);
        this.stopProgressTimer();
        this.listener.onFinish();
      }
    };
    ijk.setOnCompletionListener(onCompletion);

    const onError: OnErrorListener = {
      onError: (what: number, extra: number) => {
        if (gen !== this.gen || this.ijk !== ijk) return;
        console.error(`[PlayerAv] ijkplayer onError: what=${what}, extra=${extra}`);
        this.stopProgressTimer();
        this.listener.onError(`播放异常 (${what}, ${extra})`);
      }
    };
    ijk.setOnErrorListener(onError);

    const onVideoSize: OnVideoSizeChangedListener = {
      onVideoSizeChanged: (width: number, height: number) => {
        if (gen !== this.gen || this.ijk !== ijk) return;
        if (width > 0 && height > 0) {
          this.listener.onVideoSize(width, height);
        }
      }
    };
    ijk.setOnVideoSizeChangedListener(onVideoSize);

    const onBuffer: OnBufferingUpdateListener = {
      onBufferingUpdate: (percent: number) => {
        if (gen !== this.gen || this.ijk !== ijk) return;
        this.listener.onBuffer(percent);
      }
    };
    ijk.setOnBufferingUpdateListener(onBuffer);

    const onSeek: OnSeekCompleteListener = {
      onSeekComplete: () => {
        if (gen !== this.gen || this.ijk !== ijk) return;
        const curMs = ijk.getCurrentPosition();
        const curSec = curMs > 0 ? curMs / PlayerAv.MS_PER_SEC : 0;
        this.listener.onSeeked(curSec, this.seekGen);
      }
    };
    ijk.setOnSeekCompleteListener(onSeek);

    ijk.setMessageListener();
  }

  private startProgressTimer(): void {
    this.stopProgressTimer();
    this.progressTimer = setInterval(() => {
      const ijk = this.ijk;
      if (ijk && ijk.isPlaying()) {
        const curMs = ijk.getCurrentPosition();
        const curSec = curMs > 0 ? curMs / PlayerAv.MS_PER_SEC : 0;
        this.listener.onTime(curSec);
      }
    }, 250);
  }

  private stopProgressTimer(): void {
    if (this.progressTimer !== -1) {
      clearInterval(this.progressTimer);
      this.progressTimer = -1;
    }
  }

  private applySpeed(): void {
    const ijk = this.ijk;
    if (!ijk) return;
    try {
      const rate = PlayerSpeed.of(this.speedIndex);
      ijk.setSpeed(rate.toString());
    } catch (_e) {}
  }

  private applyVolume(): void {
    const ijk = this.ijk;
    if (!ijk) return;
    try {
      const vol = this.muted ? "0" : "1";
      ijk.setVolume(vol, vol);
    } catch (_e) {}
  }

  private async resetPlayer(fullRelease: boolean = false): Promise<void> {
    const ijk = this.ijk;
    this.ijk = undefined;
    if (!ijk) return;
    try {
      ijk.stop();
      ijk.reset();
      if (fullRelease) {
        ijk.release();
      }
    } catch (_err) {}
  }
}
