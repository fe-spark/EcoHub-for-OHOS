import { PlayerScale, PlayerScaleMode } from '../common/utils/PlayerScale';

export class PlayerScaleController {
  private scaleMode: PlayerScaleMode = PlayerScaleMode.FIT;
  private isShowingScale: boolean = false;

  get mode(): PlayerScaleMode {
    return this.scaleMode;
  }

  set mode(val: PlayerScaleMode) {
    this.scaleMode = val;
  }

  label(isPortrait: boolean = false): string {
    return PlayerScale.label(this.scaleMode, isPortrait);
  }

  desc(isPortrait: boolean = false): string {
    return PlayerScale.desc(this.scaleMode, isPortrait);
  }

  get showing(): boolean {
    return this.isShowingScale;
  }

  reset(): void {
    this.isShowingScale = false;
  }

  setShowing(showing: boolean): void {
    this.isShowingScale = showing;
  }

  pick(mode: PlayerScaleMode): void {
    this.scaleMode = mode;
    this.isShowingScale = false;
  }
}
