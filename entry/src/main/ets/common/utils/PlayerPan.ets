import { FormatUtil } from './FormatUtil';
import { PlayerSpeed } from './PlayerSpeed';

const SEEK_LOCK = 10;
const VERT_LOCK = 18;
const DIR_BIAS = 1.08;
const VERT_SENS = 1.75;
const LONG_PRESS_TOLERANCE = 18;

export class PlayerTipKind {
  static readonly NONE: number = 0;
  static readonly SEEK_FWD: number = 1;
  static readonly SEEK_BACK: number = 2;
  static readonly BRIGHT: number = 3;
  static readonly SPEED: number = 4;
  static readonly VOLUME: number = 5;
  static readonly SCALE: number = 6;
}

export class PlayerPanResult {
  mode: number = 0;
  time: number = 0;
  bright: number = -1;
  volume: number = -1;
  feedback: string = '';
  kind: number = PlayerTipKind.NONE;
}

export class PlayerPan {
  mode: number = 0;
  startX: number = 0;
  startY: number = 0;
  startSeek: number = 0;
  startBright: number = 0.5;
  startVolume: number = 0.8;
  leftSide: boolean = false;
  lastBright: number = 0.5;
  lastVolume: number = 0.8;

  reset(): void {
    this.mode = 0;
  }

  begin(x: number, y: number, currentTime: number, playerW: number): void {
    this.startX = x;
    this.startY = y;
    this.startSeek = currentTime;
    this.startBright = this.lastBright;
    this.startVolume = this.lastVolume;
    this.leftSide = x <= playerW / 2;
    this.mode = 1;
  }

  primeBright(value: number): void {
    const next = Math.min(1, Math.max(0, value));
    this.lastBright = next;
    if (this.mode === 1) {
      this.startBright = next;
    }
  }

  primeVolume(value: number): void {
    const next = Math.min(1, Math.max(0, value));
    this.lastVolume = next;
    if (this.mode === 1) {
      this.startVolume = next;
    }
  }

  move(x: number, y: number, full: boolean, duration: number, playerW: number, playerH: number): PlayerPanResult | null {
    const result = new PlayerPanResult();
    const dx = Math.abs(x - this.startX);
    const dy = Math.abs(y - this.startY);
    if (this.mode === 1) {
      if (Math.max(dx, dy) < SEEK_LOCK) {
        return null;
      }
      if (dx > LONG_PRESS_TOLERANCE && dx > dy * DIR_BIAS && duration > 0) {
        this.mode = 2;
      } else if (full && dy >= VERT_LOCK && dy > dx * DIR_BIAS) {
        this.mode = this.leftSide ? 3 : 4;
      } else {
        return null;
      }
    }
    result.mode = this.mode;
    if (this.mode === 2) {
      const width = Math.max(playerW, 1);
      const targetMs = this.startSeek * 1000 + (x - this.startX) / width * PlayerSpeed.seekRangeMs(duration);
      const next = Math.min(duration, Math.max(0, targetMs / 1000));
      const delta = Math.round(next - this.startSeek);
      const sign = delta === 0 ? '0s' : `${delta > 0 ? '+' : '-'}${Math.abs(delta)}s`;
      result.time = next;
      result.kind = delta >= 0 ? PlayerTipKind.SEEK_FWD : PlayerTipKind.SEEK_BACK;
      result.feedback = `${FormatUtil.duration(next)} / ${FormatUtil.duration(duration)}  ${sign}`;
      return result;
    }
    if (this.mode === 3) {
      const height = Math.max(playerH, 1);
      const next = Math.min(1, Math.max(0, this.startBright - (y - this.startY) / height * VERT_SENS));
      this.startBright = next;
      this.startY = y;
      this.lastBright = next;
      result.bright = next;
      result.kind = PlayerTipKind.BRIGHT;
      result.feedback = `${Math.round(next * 100)}%`;
      return result;
    }
    if (this.mode === 4) {
      const height = Math.max(playerH, 1);
      const next = Math.min(1, Math.max(0, this.startVolume - (y - this.startY) / height * VERT_SENS));
      this.startVolume = next;
      this.startY = y;
      this.lastVolume = next;
      result.volume = next;
      result.kind = PlayerTipKind.VOLUME;
      result.feedback = `${Math.round(next * 100)}%`;
      return result;
    }
    return result;
  }
}
