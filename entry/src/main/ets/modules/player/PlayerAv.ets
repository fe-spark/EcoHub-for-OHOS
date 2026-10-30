import {
  IjkMediaPlayer,
  OnPreparedListener,
  OnCompletionListener,
  OnErrorListener,
  OnVideoSizeChangedListener,
  OnBufferingUpdateListener,
  OnSeekCompleteListener,
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

  setXComponentContext(context: object, surfaceId: string): void {
    console.info(`[PlayerAv] setXComponentContext: ${surfaceId}`);
    this.xContext = context;
    this.surfaceId = surfaceId;
    if (this.ijk && context && surfaceId) {
      try {
        this.ijk.setContext(context, surfaceId);
        this.ijk.native_setup();
      } catch (err) {
        console.error(`[PlayerAv] setXComponentContext 异常: ${JSON.stringify(err)}`);
      }
    }
  }

  setSurface(id: string): void {
    console.info(`[PlayerAv] setSurface: ${id}`);
    this.surfaceId = id;
    if (this.ijk && this.xContext && id) {
      try {
        this.ijk.setContext(this.xContext, id);
        this.ijk.native_setup();
      } catch (err) {
        console.error(`[PlayerAv] setSurface 异常: ${JSON.stringify(err)}`);
      }
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

    try {
      const ijk = IjkMediaPlayer.getInstance();
      this.ijk = ijk;

      if (this.xContext && this.surfaceId) {
        ijk.setContext(this.xContext, this.surfaceId);
        ijk.native_setup();
      }

      // 1. 配置 FFmpeg / ijkplayer 网络流与解码选项
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec", "1"); // 优先硬件加速
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "opensles", "1");   // 底层音频驱动
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "soundtouch", "1"); // 倍速变调补偿
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "framedrop", "1");  // 弱网平滑丢帧防音画脱节
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "reconnect", "1");  // 网络断线自愈
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "timeout", "15000000"); // 15s 超时
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "dns_cache_clear", "1");
      ijk.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "user_agent", "EcoHub-OHOS");

      // 2. 绑定事件监听
      this.bindListeners(ijk, gen);

      // 3. 设置播放源并预加载
      ijk.setDataSource(playable);
      ijk.prepareAsync();
    } catch (err) {
      console.error(`[PlayerAv] 创建 ijkplayer 异常: ${JSON.stringify(err)}`);
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
    // ijkplayer 内部维护精准 seek 队列
  }

  async release(): Promise<void> {
    this.gen++;
    this.url = '';
    this.stopProgressTimer();
    await this.resetPlayer();
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

  private async resetPlayer(): Promise<void> {
    const ijk = this.ijk;
    this.ijk = undefined;
    if (!ijk) return;
    try {
      ijk.stop();
      ijk.reset();
      ijk.release();
    } catch (_err) {}
  }
}
