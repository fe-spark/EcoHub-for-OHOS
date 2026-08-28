import { PlayerSpeed } from '../common/utils/PlayerSpeed';

export class PlayerSpeedController {
  private speedIdx: number = 1;
  private savedSpeedIdx: number = 1;
  private isLongPressing: boolean = false;
  private isShowingSpeed: boolean = false;

  get index(): number {
    return this.speedIdx;
  }

  set index(val: number) {
    this.speedIdx = val;
  }

  get label(): string {
    return PlayerSpeed.label(this.speedIdx);
  }

  get longPressing(): boolean {
    return this.isLongPressing;
  }

  get showing(): boolean {
    return this.isShowingSpeed;
  }

  reset(): void {
    if (this.isLongPressing) {
      this.speedIdx = this.savedSpeedIdx;
    }
    this.isLongPressing = false;
    this.isShowingSpeed = false;
  }

  setShowing(showing: boolean): void {
    this.isShowingSpeed = showing;
  }

  beginFastForward(canPlay: boolean, isPlaying: boolean): boolean {
    if (!canPlay || !isPlaying) {
      return false;
    }
    this.savedSpeedIdx = this.speedIdx;
    this.isLongPressing = true;
    this.speedIdx = PlayerSpeed.FAST_INDEX;
    return true;
  }

  endFastForward(): boolean {
    if (!this.isLongPressing) {
      return false;
    }
    this.isLongPressing = false;
    this.speedIdx = this.savedSpeedIdx;
    return true;
  }

  pick(index: number): void {
    this.speedIdx = index;
    this.isShowingSpeed = false;
  }
}
