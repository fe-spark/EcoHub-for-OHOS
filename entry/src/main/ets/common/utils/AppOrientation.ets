import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { WindowBar } from './WindowBar';

export class AppOrientation {
  private static context?: common.UIAbilityContext;

  static init(context: common.UIAbilityContext | undefined): void {
    if (context) {
      AppOrientation.context = context;
    }
    AppOrientation.setSystemRotation(context);
  }

  static setSystemRotation(context?: common.UIAbilityContext | undefined): void {
    const ctx = context || AppOrientation.context;
    if (!ctx) {
      return;
    }
    window.getLastWindow(ctx).then((win: window.Window) => {
      win.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED).catch((err: Error) => {
        console.error(`[AppOrientation] 设置自动旋转失败: ${JSON.stringify(err)}`);
      });
    }).catch((err: Error) => {
      console.error(`[AppOrientation] 获取窗口失败: ${JSON.stringify(err)}`);
    });
  }

  static setFullscreenRotation(full: boolean, landscapeVideo: boolean = true): void {
    const ctx = AppOrientation.context;
    if (!ctx) {
      return;
    }
    window.getLastWindow(ctx).then((win: window.Window) => {
      if (full) {
        WindowBar.requestBars(ctx, false);
        const orientation = landscapeVideo ? window.Orientation.LANDSCAPE : window.Orientation.PORTRAIT;
        win.setPreferredOrientation(orientation).catch((err: Error) => {
          console.error(`[AppOrientation] 设置全屏横屏失败: ${JSON.stringify(err)}`);
        });
      } else {
        WindowBar.requestBars(ctx, true);
        win.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED).catch((err: Error) => {
          console.error(`[AppOrientation] 退出全屏恢复系统旋转失败: ${JSON.stringify(err)}`);
        });
      }
    }).catch((err: Error) => {
      console.error(`[AppOrientation] 获取窗口失败: ${JSON.stringify(err)}`);
    });
  }

  static onForeground(context: common.UIAbilityContext | undefined): void {
    if (context) {
      AppOrientation.context = context;
    }
  }

  static onBackground(): void {
  }

  static onDestroy(): void {
  }
}
