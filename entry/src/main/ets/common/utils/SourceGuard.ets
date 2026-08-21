import router from '@ohos.router';
import { ServerConfigManager } from './ServerConfigManager';

export class SourceGuard {
  private static intercepting: boolean = false;
  private static skipCount: number = 0;
  private static listeners: Array<() => void> = [];

  public static beginSkip(): void {
    SourceGuard.skipCount++;
  }

  public static endSkip(): void {
    if (SourceGuard.skipCount > 0) {
      SourceGuard.skipCount--;
    }
  }

  public static onReconnect(listener: () => void): void {
    if (SourceGuard.listeners.indexOf(listener) < 0) {
      SourceGuard.listeners.push(listener);
    }
  }

  public static offReconnect(listener: () => void): void {
    const next: Array<() => void> = [];
    for (let i = 0; i < SourceGuard.listeners.length; i++) {
      if (SourceGuard.listeners[i] !== listener) {
        next.push(SourceGuard.listeners[i]);
      }
    }
    SourceGuard.listeners = next;
  }

  public static intercept(): void {
    if (SourceGuard.skipCount > 0 || SourceGuard.intercepting) {
      return;
    }
    if (!ServerConfigManager.getInstance().getCachedServerUrl()) {
      return;
    }
    try {
      const state = router.getState();
      if (state && state.path.indexOf('ServerConfigPage') >= 0) {
        return;
      }
    } catch (_err) {
    }
    SourceGuard.intercepting = true;
    try {
      router.pushUrl({
        url: 'pages/ServerConfigPage',
        params: { mode: 'reconnect' }
      }, (err: Error) => {
        if (err) {
          SourceGuard.intercepting = false;
        }
      });
    } catch (_err) {
      SourceGuard.intercepting = false;
    }
  }

  public static markClosed(): void {
    SourceGuard.intercepting = false;
  }

  public static notifyReconnected(): void {
    SourceGuard.intercepting = false;
    const list = SourceGuard.listeners.slice();
    for (let i = 0; i < list.length; i++) {
      list[i]();
    }
  }
}
