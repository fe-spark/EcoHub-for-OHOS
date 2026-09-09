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

  public static intercept(uiContext?: UIContext, onContinue?: () => void): void {
    if (SourceGuard.skipCount > 0 || SourceGuard.intercepting) {
      return;
    }
    if (!ServerConfigManager.getInstance().getCachedServerUrl()) {
      return;
    }
    const ctx = uiContext || AppStorage.get<UIContext>('UI_CONTEXT');
    if (!ctx) {
      return;
    }
    const r = ctx.getRouter();
    if (!r) {
      return;
    }
    try {
      const state = r.getState();
      if (state && ((state.path && state.path.indexOf('ServerConfigPage') >= 0) || (state.name && state.name.indexOf('ServerConfigPage') >= 0))) {
        return;
      }
      // 处于播放页面时采用确认弹窗，不直接抢占全屏观影画面
      const p = (state && state.path) || '';
      const n = (state && state.name) || '';
      if (p.indexOf('PlayPage') >= 0 || n.indexOf('PlayPage') >= 0) {
        SourceGuard.intercepting = true;
        ctx.showAlertDialog({
          title: '软件源失联',
          message: '检测到当前软件源连接异常，是否前往重新配置？',
          autoCancel: false,
          cancel: () => {
            SourceGuard.intercepting = false;
            if (onContinue) {
              onContinue();
            }
          },
          primaryButton: {
            value: '更换软件源',
            fontColor: '#FA8C16',
            action: () => {
              SourceGuard.doNavigate(ctx);
            }
          },
          secondaryButton: {
            value: '继续观看',
            action: () => {
              SourceGuard.intercepting = false;
              if (onContinue) {
                onContinue();
              }
            }
          }
        });
        return;
      }
    } catch (_err) {
    }
    SourceGuard.doNavigate(ctx);
  }

  private static doNavigate(ctx: UIContext): void {
    const r = ctx.getRouter();
    if (!r) {
      SourceGuard.intercepting = false;
      return;
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
