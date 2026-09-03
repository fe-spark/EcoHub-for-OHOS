import { PlayerAv } from '../common/utils/PlayerAv';

export type ProgressCallback = (current: number, duration: number) => void;

export class PlayerPlaybackState {
  static readonly MIN_RESUME_THRESHOLD_SEC: number = 2;
  static readonly PROGRESS_PERSIST_INTERVAL_MS: number = 3000;
  static readonly END_PROGRESS_THRESHOLD_SEC: number = 1;
  static readonly SEEK_DEBOUNCE_DELTA_SEC: number = 0.3;

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
  public seekSeq: number = 0;
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
    return this.currentTime >= PlayerPlaybackState.MIN_RESUME_THRESHOLD_SEC ? this.currentTime : initialTime;
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
    this.seekSeq = 0;
    this.lastToggleAt = 0;
    this.videoWidth = 0;
    this.videoHeight = 0;
  }

  public emitProgress(cb?: ProgressCallback, force: boolean = false): void {
    if (!cb) {
      return;
    }
    const now = Date.now();
    if (!force && now - this.lastPersist < PlayerPlaybackState.PROGRESS_PERSIST_INTERVAL_MS &&
      this.currentTime < this.duration - PlayerPlaybackState.END_PROGRESS_THRESHOLD_SEC) {
      return;
    }
    this.lastPersist = now;
    cb(this.currentTime, this.duration);
  }

  public applyTime(time: number): boolean {
    if (this.dragging) {
      return false;
    }
    if (this.seeking || this.seekTarget >= 0) {
      return false;
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
    this.seekAt = 0;
    this.seekSeq = 0;
  }

  public failOpen(url: string): void {
    this.opening = false;
    this.playRequested = false;
    this.seeking = false;
    this.seekTarget = -1;
    this.seekAt = 0;
    this.seekSeq = 0;
    this.errorText = this.formatError(false, url);
  }

  public seek(time: number, playerAv: PlayerAv): void {
    if (!this.canPlay() || this.duration <= 0) {
      return;
    }
    const next = Math.min(this.duration, Math.max(0, time));
    if (this.seeking && Math.abs(next - this.seekTarget) < PlayerPlaybackState.SEEK_DEBOUNCE_DELTA_SEC) {
      return;
    }
    const seq = playerAv.seek(next);
    this.currentTime = next;
    if (seq <= 0) {
      this.seeking = false;
      this.seekTarget = -1;
      this.seekAt = 0;
      this.seekSeq = 0;
      return;
    }
    this.seekSeq = seq;
    this.seeking = true;
    this.seekTarget = next;
    this.seekAt = Date.now();
    if (this.playRequested) {
      playerAv.play();
    }
  }
}
