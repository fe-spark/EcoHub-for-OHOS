export class PlayerStallWatcher {
  private static readonly HIDE_DELAY_MS: number = 3000;
  private static readonly TIP_DURATION_MS: number = 1000;
  private static readonly OPEN_TIMEOUT_MS: number = 12000;
  private static readonly SEEK_TIMEOUT_MS: number = 8000;

  private hideTimer: number = -1;
  private tipTimer: number = -1;
  private openTimer: number = -1;
  private seekTimer: number = -1;

  public armHide(callback: () => void, canHide: boolean): void {
    this.clearHide();
    if (!canHide) {
      return;
    }
    this.hideTimer = setTimeout(() => {
      this.hideTimer = -1;
      callback();
    }, PlayerStallWatcher.HIDE_DELAY_MS);
  }

  public clearHide(): void {
    if (this.hideTimer >= 0) {
      clearTimeout(this.hideTimer);
      this.hideTimer = -1;
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
    }, PlayerStallWatcher.OPEN_TIMEOUT_MS);
  }

  public clearOpenWatch(): void {
    if (this.openTimer >= 0) {
      clearTimeout(this.openTimer);
      this.openTimer = -1;
    }
  }

  public armSeekWatch(callback: () => void, isSeeking: boolean): void {
    this.clearSeekWatch();
    if (!isSeeking) {
      return;
    }
    this.seekTimer = setTimeout(() => {
      this.seekTimer = -1;
      callback();
    }, PlayerStallWatcher.SEEK_TIMEOUT_MS);
  }

  public clearSeekWatch(): void {
    if (this.seekTimer >= 0) {
      clearTimeout(this.seekTimer);
      this.seekTimer = -1;
    }
  }

  public showTip(message: string, kind: number, onUpdate: (msg: string, k: number) => void, onClear: () => void): void {
    this.clearTip();
    onUpdate(message, kind);
    this.tipTimer = setTimeout(() => {
      this.tipTimer = -1;
      onClear();
    }, PlayerStallWatcher.TIP_DURATION_MS);
  }

  public clearTip(): void {
    if (this.tipTimer >= 0) {
      clearTimeout(this.tipTimer);
      this.tipTimer = -1;
    }
  }

  public clearAll(): void {
    this.clearHide();
    this.clearTip();
    this.clearOpenWatch();
    this.clearSeekWatch();
  }
}
