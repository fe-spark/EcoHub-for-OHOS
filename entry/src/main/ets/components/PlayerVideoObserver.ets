import { PlayerAv } from '../common/utils/PlayerAv';
import { PlayerPlaybackState, ProgressCallback } from './PlayerPlaybackState';
import { PlayerStallWatcher } from './PlayerStallWatcher';

export interface PlayerObserverHost {
  playerAv: PlayerAv;
  state: PlayerPlaybackState;
  watcher: PlayerStallWatcher;
  initialTime: number;
  videoUrl: string;
  onProgress?: ProgressCallback;
  onEnded?: () => void;
  syncKeepScreen: () => void;
  armHide: () => void;
  revealHud: () => void;
  onUIUpdate: () => void;
}

export class PlayerVideoObserver {
  private host: PlayerObserverHost;

  constructor(host: PlayerObserverHost) {
    this.host = host;
  }

  updateHost(host: PlayerObserverHost): void {
    this.host = host;
  }

  handlePrepared(duration: number): void {
    if (!this.host.state.live()) {
      return;
    }
    this.host.state.duration = duration;
    this.host.state.ready = true;
    this.host.state.opening = false;
    this.host.watcher.clearOpenWatch();
    this.host.state.errorText = '';
    const resumeAt = this.host.state.resumeTime(this.host.initialTime);
    if (resumeAt >= 2) {
      this.host.state.seek(resumeAt, this.host.playerAv);
    }
    if (this.host.state.playRequested) {
      this.host.playerAv.play();
    }
    this.host.onUIUpdate();
  }

  handleVideoSize(width: number, height: number): void {
    if (!this.host.state.live() || width <= 0 || height <= 0) {
      return;
    }
    console.info(`[PlayerVideoObserver] 原生视频分辨率更新: ${width}x${height}, isPortrait: ${height > width}`);
    this.host.state.videoWidth = width;
    this.host.state.videoHeight = height;
    this.host.onUIUpdate();
  }

  handleStart(): void {
    if (!this.host.state.live()) {
      return;
    }
    if (!this.host.state.playRequested) {
      this.host.playerAv.pause();
      this.host.state.isPlaying = false;
      this.host.onUIUpdate();
      return;
    }
    this.host.state.isPlaying = true;
    this.host.state.opening = false;
    this.host.watcher.clearOpenWatch();
    this.host.state.completed = false;
    if (this.host.state.seekTarget < 0) {
      this.host.state.seeking = false;
    }
    this.host.watcher.noteProgress(-1, this.canStall(), (stalled: boolean) => {
      this.host.state.stalled = stalled;
      this.host.onUIUpdate();
    }, () => this.canStall());
    this.host.syncKeepScreen();
    this.host.armHide();
    this.host.onUIUpdate();
  }

  handlePause(): void {
    if (!this.host.state.live()) {
      return;
    }
    this.host.state.isPlaying = false;
    this.host.state.stalled = false;
    this.host.watcher.clearStallWatch();
    this.host.syncKeepScreen();
    if (!this.host.state.playRequested) {
      this.host.revealHud();
    }
    this.host.state.emitProgress(this.host.onProgress, true);
    this.host.onUIUpdate();
  }

  handleTime(time: number): void {
    if (!this.host.state.live()) {
      return;
    }
    this.host.state.opening = false;
    if (time > 0) {
      this.host.state.isPlaying = this.host.state.playRequested;
    }
    this.host.watcher.noteProgress(time, this.canStall(), (stalled: boolean) => {
      this.host.state.stalled = stalled;
      this.host.onUIUpdate();
    }, () => this.canStall());
    const hadSeek = this.host.state.seekTarget >= 0;
    if (this.host.state.applyTime(time)) {
      if (hadSeek && this.host.state.seekTarget < 0) {
        this.host.state.seeking = false;
        this.host.armHide();
      }
    }
    this.host.state.emitProgress(this.host.onProgress);
    this.host.onUIUpdate();
  }

  handleFinish(): void {
    if (!this.host.state.live()) {
      return;
    }
    this.host.state.isPlaying = false;
    this.host.state.playRequested = false;
    this.host.state.completed = true;
    this.host.state.stalled = false;
    this.host.watcher.clearStallWatch();
    if (this.host.state.duration > 0) {
      this.host.state.currentTime = this.host.state.duration;
    }
    this.host.revealHud();
    this.host.syncKeepScreen();
    this.host.state.lastPersist = 0;
    this.host.state.emitProgress(this.host.onProgress, true);
    if (this.host.onEnded) {
      this.host.onEnded();
    }
    this.host.onUIUpdate();
  }

  handleError(): void {
    if (!this.host.state.live()) {
      return;
    }
    const wasReady = this.host.state.ready;
    this.host.state.isPlaying = false;
    this.host.state.playRequested = false;
    this.host.state.opening = false;
    this.host.watcher.clearOpenWatch();
    this.host.state.ready = false;
    this.host.state.errorText = this.host.state.formatError(wasReady, this.host.videoUrl);
    this.host.revealHud();
    this.host.syncKeepScreen();
    this.host.onUIUpdate();
  }

  private canStall(): boolean {
    const s = this.host.state;
    return s.playRequested && s.isPlaying && !s.completed && !s.errorText && !s.dragging && s.seekTarget < 0;
  }
}
