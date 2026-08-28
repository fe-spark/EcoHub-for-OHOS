import { PlayerVolumeInfo, PlayerWindow } from '../common/utils/PlayerWindow';

export interface AudioMuteResult {
  volume: number;
  muted: boolean;
  label: string;
}

export class PlayerAudioBridge {
  private volumeMax: number = 15;
  private currentVolume: number = 8;
  private lastVolume: number = 8;
  private isMuted: boolean = false;

  get volumeIndex(): number {
    return this.currentVolume;
  }

  get muted(): boolean {
    return this.isMuted;
  }

  get max(): number {
    return this.volumeMax;
  }

  sync(onSync?: (volume: number, max: number, muted: boolean) => void): void {
    PlayerWindow.getVolume().then((info: PlayerVolumeInfo) => {
      this.volumeMax = info.max;
      this.currentVolume = info.current;
      this.isMuted = info.current <= 0;
      if (info.current > 0) {
        this.lastVolume = info.current;
      }
      if (onSync) {
        onSync(this.currentVolume, this.volumeMax, this.isMuted);
      }
    });
  }

  applyRatio(ratio: number): number {
    const max = Math.max(1, this.volumeMax);
    const next = Math.round(Math.min(1, Math.max(0, ratio)) * max);
    this.currentVolume = next;
    this.isMuted = next <= 0;
    if (next > 0) {
      this.lastVolume = next;
    }
    return next;
  }

  toggleMute(): AudioMuteResult {
    if (this.currentVolume <= 0 || this.isMuted) {
      const restore = this.lastVolume > 0 ? this.lastVolume : Math.ceil(this.volumeMax / 2);
      this.currentVolume = restore;
      this.isMuted = false;
      const pct = Math.round(restore / Math.max(1, this.volumeMax) * 100);
      const res: AudioMuteResult = { volume: restore, muted: false, label: `${pct}%` };
      return res;
    } else {
      this.lastVolume = this.currentVolume;
      this.currentVolume = 0;
      this.isMuted = true;
      const res: AudioMuteResult = { volume: 0, muted: true, label: '静音' };
      return res;
    }
  }
}
