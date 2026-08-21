import { media } from '@kit.MediaKit';

const MIN_SEEK_MS = 3 * 60 * 1000;
const MAX_SEEK_MS = 12 * 60 * 1000;

export class PlayerSpeed {
  static of(index: number): PlaybackSpeed {
    if (index === 0) {
      return PlaybackSpeed.Speed_Forward_0_75_X;
    }
    if (index === 2) {
      return PlaybackSpeed.Speed_Forward_1_25_X;
    }
    if (index === 3) {
      return PlaybackSpeed.Speed_Forward_1_75_X;
    }
    if (index === 4) {
      return PlaybackSpeed.Speed_Forward_2_00_X;
    }
    return PlaybackSpeed.Speed_Forward_1_00_X;
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
    if (index === 4) {
      return media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
    }
    return media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
  }

  static label(index: number): string {
    const labels: string[] = ['0.75x', '1.0x', '1.25x', '1.75x', '2.0x'];
    return labels[index] || '1.0x';
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
