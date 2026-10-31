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
        // 全屏：进入全屏那一刻就锁定目标朝向！
        // 横屏视频锁定横屏（LANDSCAPE），手机物理旋转绝不改变全屏窗口，更不会被压扁或挤成横线
        // 竖屏视频锁定竖屏（PORTRAIT）
        const targetOrientation = landscapeVideo
          ? window.Orientation.LANDSCAPE
          : window.Orientation.PORTRAIT;

        win.setPreferredOrientation(targetOrientation).catch((err: Error) => {
          console.error(`[AppOrientation] 设置全屏朝向失败: ${JSON.stringify(err)}`);
        });
      } else {
        // 退出全屏：恢复系统自动旋转策略，随重力感应自然回落
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
