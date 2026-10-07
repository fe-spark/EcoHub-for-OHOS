import { common } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
import { sensor } from '@kit.SensorServiceKit';
import { settings } from '@kit.BasicServicesKit';
import { WindowBar } from './WindowBar';

export class AppOrientation {
  static readonly ANGLE_KEY: string = 'APP_DEVICE_ANGLE';
  static readonly HELD_KEY: string = 'APP_ROTATION_HELD';
  static readonly FROZEN_KEY: string = 'APP_FROZEN_ANGLE';
  private static started: boolean = false;
  private static gravityOn: boolean = false;
  private static barsHeld: boolean = false;
  private static lockedDegrees: number = 0;
  private static lastDeviceDegrees: number = 0;
  private static pageAngle: number = 0;
  private static rotateAllowed: boolean = true;
  private static rotateAllowedUntil: number = 0;
  private static context: common.UIAbilityContext | undefined = undefined;

  static angle(): number {
    return AppOrientation.pageAngle;
  }

  static setBarsHeld(held: boolean): void {
    AppOrientation.barsHeld = held;
  }

  /**
   * 全屏时窗口改成视频自己的方向，系统状态栏贴在画面顶部并隐藏。页面不再另转 90°。
   */
  static setFullscreenRotation(full: boolean, landscapeVideo: boolean): void {
    AppOrientation.barsHeld = full;
    AppOrientation.putBool(AppOrientation.HELD_KEY, false);
    AppOrientation.putNumber(AppOrientation.FROZEN_KEY, 0);
    AppOrientation.syncBars();
    WindowBar.refresh();
    const orientation = !full ? window.Orientation.AUTO_ROTATION_RESTRICTED
      : (landscapeVideo ? window.Orientation.LANDSCAPE : window.Orientation.PORTRAIT);
    AppOrientation.prefer(orientation);
  }

  private static prefer(orientation: window.Orientation): void {
    const ctx = AppOrientation.context;
    if (!ctx) {
      return;
    }
    window.getLastWindow(ctx).then((win: window.Window) => {
      let current = window.Orientation.UNSPECIFIED;
      try {
        current = win.getPreferredOrientation();
      } catch (_err) {
      }
      if (current === orientation) {
        return;
      }
      console.info(`[AppOrientation] 窗口方向 ${current} -> ${orientation}`);
      win.setPreferredOrientation(orientation).catch((err: Error) => {
        console.error(`[AppOrientation] 设置窗口方向失败: ${JSON.stringify(err)}`);
      });
    }).catch((err: Error) => {
      console.error(`[AppOrientation] 获取窗口失败: ${JSON.stringify(err)}`);
    });
  }

  private static putBool(key: string, value: boolean): void {
    AppStorage.setOrCreate<boolean>(key, value);
    AppStorage.set<boolean>(key, value);
  }

  private static putNumber(key: string, value: number): void {
    AppStorage.setOrCreate<number>(key, value);
    AppStorage.set<number>(key, value);
  }

  static onForeground(context: common.UIAbilityContext | undefined): void {
    if (context) {
      AppOrientation.context = context;
    }
    AppOrientation.refreshAutoRotateAsync();
    if (!AppOrientation.started) {
      AppOrientation.start(context);
      return;
    }
    AppOrientation.startGravity();
  }

  static onBackground(): void {
    AppOrientation.stopGravity();
  }

  static onDestroy(): void {
    AppOrientation.stopGravity();
    AppOrientation.started = false;
  }

  static start(context: common.UIAbilityContext | undefined): void {
    if (AppOrientation.started) {
      return;
    }
    AppOrientation.started = true;
    AppOrientation.context = context;
    AppOrientation.lockedDegrees = AppOrientation.readDisplayDegrees();
    AppOrientation.lastDeviceDegrees = AppOrientation.lockedDegrees;
    AppOrientation.rotateAllowedUntil = 0;
    AppOrientation.refreshAutoRotateAsync();
    AppOrientation.startGravity();
    if (!AppOrientation.gravityOn) {
      AppOrientation.started = false;
      AppOrientation.allowSystemRotation(context);
      return;
    }
    AppOrientation.lockWindow(context);
  }

  private static onGravity(data: sensor.GravityResponse): void {
    AppOrientation.handleGravity(data.x, data.y);
  }

  private static handleGravity(x: number, y: number): void {
    const device = AppOrientation.deviceDegrees(x, y);
    if (device >= 0) {
      AppOrientation.lastDeviceDegrees = device;
    }
    if (AppOrientation.pageAngle !== 0) {
      AppOrientation.publishAngle(0);
    }
  }

  private static deviceDegrees(x: number, y: number): number {
    const ax = Math.abs(x);
    const ay = Math.abs(y);
    if (ay >= ax + 1.5 && ay >= 6) {
      return y >= 0 ? 0 : 180;
    }
    if (ax >= ay + 1.5 && ax >= 6) {
      return x >= 0 ? 270 : 90;
    }
    return -1;
  }

  private static toPageAngle(windowDeg: number, deviceDeg: number): number {
    const delta = (windowDeg - deviceDeg + 360) % 360;
    if (delta === 90) {
      return 90;
    }
    if (delta === 270) {
      return -90;
    }
    return 0;
  }

  private static readDisplayDegrees(): number {
    try {
      const rotation = display.getDefaultDisplaySync().rotation;
      if (rotation === 1) {
        return 90;
      }
      if (rotation === 2) {
        return 180;
      }
      if (rotation === 3) {
        return 270;
      }
    } catch (err) {
      console.error(`[AppOrientation] 读取屏幕方向失败: ${JSON.stringify(err)}`);
    }
    return 0;
  }

  private static refreshAutoRotateAsync(): void {
    const ctx = AppOrientation.context;
    if (!ctx) {
      return;
    }
    try {
      settings.getValue(ctx, settings.general.ACCELEROMETER_ROTATION_STATUS).then((value: string) => {
        AppOrientation.rotateAllowed = value !== '0';
      }).catch((_e: Object) => {
      });
    } catch (_err) {
    }
  }

  private static readAutoRotate(): boolean {
    const now = Date.now();
    if (now >= AppOrientation.rotateAllowedUntil) {
      AppOrientation.rotateAllowedUntil = now + 1000;
      AppOrientation.refreshAutoRotateAsync();
    }
    return AppOrientation.rotateAllowed;
  }

  private static publishAngle(angle: number): void {
    if (angle === AppOrientation.pageAngle) {
      return;
    }
    console.info(`[AppOrientation] 页面旋转 ${AppOrientation.pageAngle} -> ${angle} window=${AppOrientation.lockedDegrees} device=${AppOrientation.lastDeviceDegrees}`);
    AppOrientation.pageAngle = angle;
    AppStorage.setOrCreate<number>(AppOrientation.ANGLE_KEY, angle);
    AppStorage.set<number>(AppOrientation.ANGLE_KEY, angle);
    AppOrientation.syncBars();
    WindowBar.refresh();
  }

  private static syncBars(): void {
    if (AppOrientation.barsHeld) {
      AppOrientation.hideBars();
      return;
    }
    const held = AppStorage.get<boolean>(AppOrientation.HELD_KEY) === true;
    const frozen = AppStorage.get<number>(AppOrientation.FROZEN_KEY) ?? 0;
    const angle = held ? frozen : AppOrientation.pageAngle;
    if (AppOrientation.barsHeld || angle !== 0) {
      AppOrientation.hideBars();
    } else {
      AppOrientation.restoreBars();
    }
  }

  private static restoreBars(): void {
    WindowBar.requestBars(AppOrientation.context, true);
  }

  private static hideBars(onDone?: () => void): void {
    WindowBar.requestBars(AppOrientation.context, false, onDone);
  }

  private static allowSystemRotation(context: common.UIAbilityContext | undefined): void {
    if (!context) {
      return;
    }
    window.getLastWindow(context).then((win: window.Window) => {
      win.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED).catch((err: Error) => {
        console.error(`[AppOrientation] 恢复系统旋转失败: ${JSON.stringify(err)}`);
      });
    }).catch((err: Error) => {
      console.error(`[AppOrientation] 获取窗口失败: ${JSON.stringify(err)}`);
    });
  }

  private static startGravity(): void {
    if (AppOrientation.gravityOn) {
      return;
    }
    try {
      sensor.on(sensor.SensorId.GRAVITY, AppOrientation.onGravity, { interval: 'normal' });
      AppOrientation.gravityOn = true;
      console.info('[AppOrientation] 重力监听已打开');
    } catch (err) {
      console.error(`[AppOrientation] 重力监听失败，改回系统旋转: ${JSON.stringify(err)}`);
    }
  }

  private static stopGravity(): void {
    if (!AppOrientation.gravityOn) {
      return;
    }
    AppOrientation.gravityOn = false;
    try {
      sensor.off(sensor.SensorId.GRAVITY, AppOrientation.onGravity);
    } catch (err) {
      console.error(`[AppOrientation] 关闭重力监听失败: ${JSON.stringify(err)}`);
    }
  }

  private static lockWindow(context: common.UIAbilityContext | undefined): void {
    if (!context) {
      return;
    }
    window.getLastWindow(context).then((win: window.Window) => {
      win.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED).then(() => {
        console.info(`[AppOrientation] 窗口跟随手持方向 preferred=${win.getPreferredOrientation()}`);
      }).catch((err: Error) => {
        console.error(`[AppOrientation] 设置跟随方向失败: ${JSON.stringify(err)}`);
      });
    }).catch((err: Error) => {
      console.error(`[AppOrientation] 获取窗口失败: ${JSON.stringify(err)}`);
    });
  }
}
