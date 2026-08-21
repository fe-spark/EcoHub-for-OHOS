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
    await this.resetPlayer();
    if (gen !== this.gen) {
      return;
    }
    this.url = url;
    if (!url) {
      return;
    }
    try {
      const player = await media.createAVPlayer();
      if (gen !== this.gen) {
        player.release();
        return;
      }
      this.player = player;
      this.bind(player, gen);
      player.url = url;
    } catch (err) {
      if (gen === this.gen) {
        this.listener.onError();
      }
    }
  }

  play(): void {
    const player = this.player;
    if (player && (player.state === 'prepared' || player.state === 'paused' || player.state === 'completed')) {
      player.play();
    }
  }

  pause(): void {
    const player = this.player;
    if (player && player.state === 'playing') {
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
      if (gen !== this.gen || this.player !== player) {
        return;
      }
      if (state === 'initialized') {
        if (this.surfaceId) {
          this.prepareWithSurface(player, this.surfaceId);
        } else {
          this.pendingPrepare = true;
        }
      } else if (state === 'prepared') {
        const durationMs = player.duration;
        const duration = durationMs > 0 ? durationMs / 1000 : 0;
        this.applyVolume();
        this.applySpeed();
        this.listener.onPrepared(duration);
      } else if (state === 'playing') {
        this.listener.onStart();
      } else if (state === 'paused') {
        this.listener.onPause();
      } else if (state === 'completed') {
        this.listener.onFinish();
      } else if (state === 'error') {
        this.listener.onError();
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
    player.on('error', () => {
      if (gen !== this.gen) {
        return;
      }
      this.listener.onError();
    });
  }

  private prepareWithSurface(player: media.AVPlayer, surfaceId: string): void {
    player.surfaceId = surfaceId;
    player.prepare();
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
      player.off('timeUpdate');
      player.off('seekDone');
      player.off('bufferingUpdate');
      player.off('error');
      await player.release();
    } catch (err) {
    }
  }
}
