import { media } from '@kit.MediaKit';
import { PlayerSpeed } from './PlayerSpeed';

export class PlayerAvListener {
  onPrepared: (duration: number) => void = (_duration: number) => {};
  onStart: () => void = () => {};
  onPause: () => void = () => {};
  onTime: (time: number) => void = (_time: number) => {};
  onFinish: () => void = () => {};
  onError: () => void = () => {};
  onSeeked: () => void = () => {};
  onBuffer: (buffered: number) => void = (_buffered: number) => {};
  onStalled: (stalled: boolean) => void = (_stalled: boolean) => {};
  onVideoSize: (width: number, height: number) => void = (_width: number, _height: number) => {};
}

export class PlayerAv {
  readonly listener: PlayerAvListener = new PlayerAvListener();
  private player: media.AVPlayer | undefined = undefined;
  private surfaceId: string = '';
  private url: string = '';
  private gen: number = 0;
  private speedIndex: number = 1;
  private muted: boolean = false;
  private pendingPrepare: boolean = false;

  setSurface(id: string): void {
    console.info(`[PlayerAv] setSurface id: ${id}, hasPlayer: ${!!this.player}, pending: ${this.pendingPrepare}`);
    this.surfaceId = id;
    if (this.player && this.pendingPrepare && id) {
      this.pendingPrepare = false;
      this.prepareWithSurface(this.player, id);
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

  async open(url: string): Promise<void> {
    const gen = ++this.gen;
    console.info(`[PlayerAv] open 启动 (gen: ${gen}), url: ${url}`);
    await this.resetPlayer();
    if (gen !== this.gen) {
      console.info(`[PlayerAv] open 时序被覆盖，丢弃: gen=${gen}, curGen=${this.gen}`);
      return;
    }
    this.url = url;
    if (!url) {
      return;
    }
    try {
      console.info(`[PlayerAv] 创建 media.createAVPlayer() ...`);
      const player = await media.createAVPlayer();
      if (gen !== this.gen) {
        console.info(`[PlayerAv] 创建后已过期，释放`);
        player.release();
        return;
      }
      this.player = player;
      this.bind(player, gen);
      console.info(`[PlayerAv] 设置 player.url: ${url}`);
      player.url = url;
    } catch (err) {
      console.error(`[PlayerAv] 创建 AVPlayer 异常: ${JSON.stringify(err)}`);
      if (gen === this.gen) {
        this.listener.onError();
      }
    }
  }

  play(): void {
    const player = this.player;
    if (player && (player.state === 'prepared' || player.state === 'paused' || player.state === 'completed')) {
      console.info(`[PlayerAv] 调用 player.play()`);
      player.play();
    }
  }

  pause(): void {
    const player = this.player;
    if (player && player.state === 'playing') {
      console.info(`[PlayerAv] 调用 player.pause()`);
      player.pause();
    }
  }

  seek(timeSec: number): void {
    const player = this.player;
    if (!player) {
      return;
    }
    if (player.state === 'prepared' || player.state === 'playing' || player.state === 'paused' ||
      player.state === 'completed') {
      console.info(`[PlayerAv] 调用 player.seek(${timeSec}s)`);
      player.seek(Math.floor(Math.max(0, timeSec) * 1000), media.SeekMode.SEEK_CLOSEST);
    }
  }

  async release(): Promise<void> {
    this.gen++;
    this.url = '';
    await this.resetPlayer();
  }

  private bind(player: media.AVPlayer, gen: number): void {
    player.on('stateChange', (state: string) => {
      console.info(`[PlayerAv] stateChange 回调 -> ${state}, gen: ${gen}/${this.gen}, surfaceId: ${this.surfaceId}`);
      if (gen !== this.gen || this.player !== player) {
        return;
      }
      if (state === 'initialized') {
        if (this.surfaceId) {
          this.prepareWithSurface(player, this.surfaceId);
        } else {
          console.info(`[PlayerAv] state=initialized 但 surfaceId 为空，进入 pendingPrepare 等待 setSurface`);
          this.pendingPrepare = true;
        }
      } else if (state === 'prepared') {
        const durationMs = player.duration;
        const duration = durationMs > 0 ? durationMs / 1000 : 0;
        console.info(`[PlayerAv] prepared 完成! duration: ${duration}s, size: ${player.width}x${player.height}`);
        this.applyVolume();
        this.applySpeed();
        try {
          player.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT;
        } catch (_e) {
        }
        if (player.width > 0 && player.height > 0) {
          this.listener.onVideoSize(player.width, player.height);
        }
        this.listener.onPrepared(duration);
      } else if (state === 'playing') {
        console.info(`[PlayerAv] playing 状态开始`);
        this.listener.onStart();
      } else if (state === 'paused') {
        console.info(`[PlayerAv] paused 状态暂停`);
        this.listener.onPause();
      } else if (state === 'completed') {
        console.info(`[PlayerAv] completed 播放完成`);
        this.listener.onFinish();
      } else if (state === 'error') {
        console.error(`[PlayerAv] error 状态错误`);
        this.listener.onError();
      }
    });
    player.on('videoSizeChange', (width: number, height: number) => {
      if (gen !== this.gen) {
        return;
      }
      if (width > 0 && height > 0) {
        console.info(`[PlayerAv] videoSizeChange 原生尺寸回调: ${width}x${height}`);
        this.listener.onVideoSize(width, height);
      }
    });
    player.on('timeUpdate', (time: number) => {
      if (gen !== this.gen) {
        return;
      }
      this.listener.onTime(time / 1000);
    });
    player.on('seekDone', (_time: number) => {
      if (gen !== this.gen) {
        return;
      }
      this.listener.onSeeked();
    });
    player.on('bufferingUpdate', (infoType: media.BufferingInfoType, value: number) => {
      if (gen !== this.gen) {
        return;
      }
      if (infoType === media.BufferingInfoType.CACHED_DURATION) {
        this.listener.onBuffer(value / 1000);
      } else if (infoType === media.BufferingInfoType.BUFFERING_START) {
        this.listener.onStalled(true);
      } else if (infoType === media.BufferingInfoType.BUFFERING_END) {
        this.listener.onStalled(false);
      }
    });
    player.on('error', (err) => {
      if (gen !== this.gen) {
        return;
      }
      console.error(`[PlayerAv] player error: ${JSON.stringify(err)}`);
      this.listener.onError();
    });
  }

  private prepareWithSurface(player: media.AVPlayer, surfaceId: string): void {
    try {
      player.surfaceId = surfaceId;
      player.prepare();
    } catch (err) {
      console.error(`[PlayerAv] prepareWithSurface 异常: ${JSON.stringify(err)}`);
      this.listener.onError();
    }
  }

  private applySpeed(): void {
    const player = this.player;
    if (!player) {
      return;
    }
    if (player.state === 'prepared' || player.state === 'playing' || player.state === 'paused') {
      player.setSpeed(PlayerSpeed.mediaSpeed(this.speedIndex));
    }
  }

  private applyVolume(): void {
    const player = this.player;
    if (!player) {
      return;
    }
    if (player.state === 'prepared' || player.state === 'playing' || player.state === 'paused' ||
      player.state === 'completed') {
      player.setVolume(this.muted ? 0 : 1);
    }
  }

  private async resetPlayer(): Promise<void> {
    const player = this.player;
    this.player = undefined;
    this.pendingPrepare = false;
    if (!player) {
      return;
    }
    try {
      player.off('stateChange');
      player.off('videoSizeChange');
      player.off('timeUpdate');
      player.off('seekDone');
      player.off('bufferingUpdate');
      player.off('error');
      await player.release();
    } catch (err) {
    }
  }
}
