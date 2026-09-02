import { PlayerAv } from '../common/utils/PlayerAv';

export type ProgressCallback = (current: number, duration: number) => void;

export class PlayerPlaybackState {
  public duration: number = 0;
  public currentTime: number = 0;
  public isPlaying: boolean = false;
  public playRequested: boolean = true;
  public completed: boolean = false;
  public opening: boolean = true;
  public errorText: string = '';
  public seeking: boolean = false;
  public stalled: boolean = false;
  public ready: boolean = false;
  public playSrc: string = '';
  public playerOn: boolean = false;
  public nonce: number = 0;
  public bootGen: number = 0;
  public mountGen: number = 0;
  public lastPersist: number = 0;
  public seekTarget: number = -1;
  public seekAt: number = 0;
  public lastToggleAt: number = 0;
  public dragging: boolean = false;
  public videoWidth: number = 0;
  public videoHeight: number = 0;

  public live(): boolean {
    return this.playerOn && this.bootGen === this.mountGen;
  }

  public canPlay(): boolean {
    return this.ready && !this.opening && !this.errorText;
  }

  public isPortrait(): boolean {
    return this.videoHeight > 0 && this.videoWidth > 0 && this.videoHeight > this.videoWidth;
  }

  public resumeTime(initialTime: number): number {
    return this.currentTime >= 2 ? this.currentTime : initialTime;
  }

  public formatError(wasReady: boolean, url: string): string {
    const stage = wasReady ? '播放过程中失败' : '打开视频失败';
    const trimmed = url.trim();
    return trimmed ? `${stage}\n${trimmed}` : `${stage}\n未提供播放地址`;
  }

  public reset(videoUrl: string): void {
    this.duration = 0;
    this.currentTime = 0;
    this.isPlaying = false;
    this.playRequested = true;
    this.completed = false;
    this.lastPersist = 0;
    this.opening = !!videoUrl;
    this.errorText = '';
    this.seeking = false;
    this.stalled = false;
    this.ready = false;
    this.dragging = false;
    this.seekTarget = -1;
    this.seekAt = 0;
    this.lastToggleAt = 0;
    this.videoWidth = 0;
    this.videoHeight = 0;
  }

  public emitProgress(cb?: ProgressCallback, force: boolean = false): void {
    if (!cb) {
      return;
    }
    const now = Date.now();
    if (!force && now - this.lastPersist < 3000 && this.currentTime < this.duration - 1) {
      return;
    }
    this.lastPersist = now;
    cb(this.currentTime, this.duration);
  }

  public applyTime(time: number): boolean {
    if (this.dragging) {
      return false;
    }
    if (this.seekTarget >= 0) {
      const delta = Math.abs(time - this.seekTarget);
      const elapsed = Date.now() - this.seekAt;
      const settled = delta <= 1.2 || elapsed > 1800;
      if (!settled) {
        return false;
      }
      this.seekTarget = -1;
      this.seeking = false;
    }
    this.currentTime = time;
    return true;
  }

  public prepareRetry(): void {
    this.errorText = '';
    this.opening = true;
    this.ready = false;
    this.completed = false;
    this.playRequested = true;
    this.isPlaying = false;
    this.stalled = false;
    this.seeking = false;
    this.seekTarget = -1;
  }

  public failOpen(url: string): void {
    this.opening = false;
    this.playRequested = false;
    this.errorText = this.formatError(false, url);
  }

  public seek(time: number, playerAv: PlayerAv): void {
    if (!this.canPlay() || this.duration <= 0) {
      return;
    }
    const next = Math.min(this.duration, Math.max(0, time));
    this.seeking = true;
    this.currentTime = next;
    this.seekTarget = next;
    this.seekAt = Date.now();
    playerAv.seek(next);
    if (this.playRequested) {
      playerAv.play();
    }
  }
}
