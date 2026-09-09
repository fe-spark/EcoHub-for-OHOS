import { media } from '@kit.MediaKit';

const MIN_SEEK_MS = 3 * 60 * 1000;
const MAX_SEEK_MS = 12 * 60 * 1000;
const RATES: number[] = [0.75, 1, 1.25, 1.5, 2, 3];
const LABELS: string[] = ['0.75x', '1.0x', '1.25x', '1.5x', '2.0x', '3.0x'];

export class PlayerSpeed {
  static readonly DEFAULT_INDEX: number = 1;
  static readonly FAST_INDEX: number = 5;

  static labels(): string[] {
    return LABELS;
  }

  static of(index: number): number {
    if (index >= 0 && index < RATES.length) {
      return RATES[index];
    }
    return 1;
  }

  static mediaSpeed(index: number): media.PlaybackSpeed {
    if (index === 0) {
      return media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
    }
    if (index === 2) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_25_X;
    }
    if (index === 3) {
      return media.PlaybackSpeed.SPEED_FORWARD_1_75_X;
    }
    if (index >= 4) {
      return media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
    }
    return media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
  }

  static label(index: number): string {
    if (index >= 0 && index < LABELS.length) {
      return LABELS[index];
    }
    return '1.0x';
  }

  static seekRangeMs(duration: number): number {
    const durationMs = duration * 1000;
    if (durationMs <= 0) {
      return 0;
    }
    const proportional = durationMs * 0.35;
    return Math.min(Math.max(proportional, MIN_SEEK_MS), Math.min(durationMs, MAX_SEEK_MS));
  }
}
