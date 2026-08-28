export class PlayerStallWatcher {
  private hideTimer: number = -1;
  private stallTimer: number = -1;
  private tipTimer: number = -1;
  private openTimer: number = -1;
  private lastProgressTime: number = -1;
  private isStalled: boolean = false;

  public get stalled(): boolean {
    return this.isStalled;
  }

  public set stalled(val: boolean) {
    this.isStalled = val;
  }

  public armHide(callback: () => void, canHide: boolean): void {
    this.clearHide();
    if (!canHide) {
      return;
    }
    this.hideTimer = setTimeout(() => {
      this.hideTimer = -1;
      callback();
    }, 3000);
  }

  public clearHide(): void {
    if (this.hideTimer >= 0) {
      clearTimeout(this.hideTimer);
      this.hideTimer = -1;
    }
  }

  public showTip(message: string, kind: number, onUpdate: (msg: string, k: number) => void, onClear: () => void): void {
    this.clearTip();
    onUpdate(message, kind);
    this.tipTimer = setTimeout(() => {
      this.tipTimer = -1;
      onClear();
    }, 1000);
  }

  public clearTip(): void {
    if (this.tipTimer >= 0) {
      clearTimeout(this.tipTimer);
      this.tipTimer = -1;
    }
  }

  public armOpenWatch(callback: () => void, isOpening: boolean): void {
    this.clearOpenWatch();
    if (!isOpening) {
      return;
    }
    this.openTimer = setTimeout(() => {
      this.openTimer = -1;
      callback();
    }, 12000);
  }

  public clearOpenWatch(): void {
    if (this.openTimer >= 0) {
      clearTimeout(this.openTimer);
      this.openTimer = -1;
    }
  }

  public resetStallWatch(): void {
    this.clearStallWatch();
    this.isStalled = false;
    this.lastProgressTime = -1;
  }

  public clearStallWatch(): void {
    if (this.stallTimer >= 0) {
      clearTimeout(this.stallTimer);
      this.stallTimer = -1;
    }
  }

  public noteProgress(time: number, canStall: boolean, onStallChanged: (stalled: boolean) => void,
    stillValid: () => boolean): void {
    if (time >= 0) {
      const moved = this.lastProgressTime < 0 || Math.abs(time - this.lastProgressTime) > 0.001;
      this.lastProgressTime = time;
      if (!moved) {
        return;
      }
    }
    if (this.isStalled) {
      this.isStalled = false;
      onStallChanged(false);
    }
    this.clearStallWatch();
    if (!canStall) {
      return;
    }
    this.stallTimer = setTimeout(() => {
      this.stallTimer = -1;
      if (!stillValid()) {
        return;
      }
      this.isStalled = true;
      onStallChanged(true);
    }, 2500);
  }

  public clearAll(): void {
    this.clearHide();
    this.clearStallWatch();
    this.clearTip();
    this.clearOpenWatch();
  }
}
