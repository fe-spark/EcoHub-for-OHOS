import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { WindowBar } from './WindowBar';
import { Breakpoint } from './Breakpoint';

export class AppOrientation {
  private static context?: common.UIAbilityContext;

  static getContext(): common.UIAbilityContext | undefined {
    return AppOrientation.context;
  }
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
        // 先看手机当前的物理/窗口实际朝向，绝不逆势反转
        const rect = win.getWindowProperties().windowRect;
        const isCurrentLandscape = (rect && rect.width > 0 && rect.height > 0)
          ? (rect.width > rect.height)
          : (Breakpoint.windowWidth() > Breakpoint.windowHeight());

        let targetOrientation: window.Orientation;
        if (isCurrentLandscape) {
          // 手机当前本来就是横屏，全屏直接保持横屏全屏，绝不转回竖屏
          targetOrientation = window.Orientation.USER_ROTATION_LANDSCAPE;
        } else {
          // 手机当前是竖屏：横屏视频转横屏，竖屏视频直接留在竖屏全屏
          targetOrientation = landscapeVideo
            ? window.Orientation.USER_ROTATION_LANDSCAPE
            : window.Orientation.USER_ROTATION_PORTRAIT;
        }

        win.setPreferredOrientation(targetOrientation).catch((err: Error) => {
          console.error(`[AppOrientation] 设置全屏朝向失败: ${JSON.stringify(err)}`);
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
