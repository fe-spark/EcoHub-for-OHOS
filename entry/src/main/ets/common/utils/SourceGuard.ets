import { UIContext } from '@kit.ArkUI';
import { ServerConfigManager } from './ServerConfigManager';

export interface ServerConfigRouteParams {
  mode: string;
}

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

  public static intercept(uiContext?: UIContext): void {
    if (SourceGuard.skipCount > 0 || SourceGuard.intercepting) {
      return;
    }
    if (!ServerConfigManager.getInstance().getCachedServerUrl()) {
      return;
    }
    const ctx = uiContext || AppStorage.get<UIContext>('UI_CONTEXT');
    const r = ctx ? ctx.getRouter() : undefined;
    if (!r) {
      return;
    }
    try {
      const state = r.getState();
      if (state && state.path.indexOf('ServerConfigPage') >= 0) {
        return;
      }
    } catch (_err) {
    }
    SourceGuard.intercepting = true;
    try {
      const params: ServerConfigRouteParams = { mode: 'reconnect' };
      r.pushUrl({
        url: 'pages/ServerConfigPage',
        params: params
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
