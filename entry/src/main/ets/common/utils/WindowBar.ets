import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppTheme } from '../constants/AppTheme';
import { Breakpoint } from './Breakpoint';

export class WindowBar {
  private static applySeq: number = 0;
  private static listenedWin: window.Window | null = null;
  private static onAvoid?: (data: window.AvoidAreaOptions) => void;
  private static onSize?: (size: Size) => void;
  private static onInsets?: (top: number, bottom: number, left: number, right: number) => void;
  private static onDisplay?: (left: number, right: number, width: number, height: number) => void;
  private static avoidTimer: number = -1;
  private static overlayCount: number = 0;
  private static rawW: number = 0;
  private static rawH: number = 0;

  static requestBars(context: common.UIAbilityContext | undefined, show: boolean): void {
    if (!context) {
      return;
    }
    if (show) {
      WindowBar.apply(context);
      return;
    }
    const seq = ++WindowBar.applySeq;
    window.getLastWindow(context).then((win: window.Window) => {
      if (seq !== WindowBar.applySeq) {
        return;
      }
      win.setWindowSystemBarEnable([]).catch((err: Error) => {
        console.error(`[WindowBar] 隐藏系统栏失败: ${JSON.stringify(err)}`);
      });
    }).catch((err: Error) => {
      console.error(`[WindowBar] 获取窗口失败: ${JSON.stringify(err)}`);
    });
  }

  static apply(context?: common.UIAbilityContext,
    onInsets?: (top: number, bottom: number, left: number, right: number) => void,
    onDisplay?: (left: number, right: number, width: number, height: number) => void): void {
    if (!context) {
      return;
    }
    if (onInsets !== undefined || onDisplay !== undefined) {
      WindowBar.onInsets = onInsets;
      WindowBar.onDisplay = onDisplay;
    }
    const seq = ++WindowBar.applySeq;
    window.getLastWindow(context).then((win: window.Window) => {
      if (seq !== WindowBar.applySeq) {
        return;
      }
      win.setWindowSystemBarEnable(['status', 'navigation']);
      win.setWindowLayoutFullScreen(true);
      WindowBar.applyBarColors(win);
      WindowBar.bindListener(win);
      WindowBar.notifyInsets(win);
      WindowBar.notifySize(win);
    }).catch((err: Error) => {
      console.error('apply window bar failed:', JSON.stringify(err));
    });
  }

  private static bindListener(win: window.Window): void {
    if (WindowBar.avoidTimer !== -1) {
      clearTimeout(WindowBar.avoidTimer);
      WindowBar.avoidTimer = -1;
    }
    if (WindowBar.listenedWin) {
      if (WindowBar.onAvoid) {
        try {
          WindowBar.listenedWin.off('avoidAreaChange', WindowBar.onAvoid);
        } catch (_err) {
        }
      }
      if (WindowBar.onSize) {
        try {
          WindowBar.listenedWin.off('windowSizeChange', WindowBar.onSize);
        } catch (_err) {
        }
      }
    }
    WindowBar.listenedWin = win;
    WindowBar.onAvoid = (_data: window.AvoidAreaOptions) => {
      if (WindowBar.avoidTimer !== -1) {
        clearTimeout(WindowBar.avoidTimer);
      }
      WindowBar.avoidTimer = setTimeout(() => {
        WindowBar.avoidTimer = -1;
        if (WindowBar.listenedWin) {
          WindowBar.notifyInsets(WindowBar.listenedWin);
        }
      }, 80);
    };
    WindowBar.onSize = (size: Size) => {
      if (WindowBar.avoidTimer !== -1) {
        clearTimeout(WindowBar.avoidTimer);
        WindowBar.avoidTimer = -1;
      }
      if (WindowBar.listenedWin) {
        WindowBar.notifyInsets(WindowBar.listenedWin);
        WindowBar.notifySize(WindowBar.listenedWin, size);
      }
    };
    win.on('avoidAreaChange', WindowBar.onAvoid);
    win.on('windowSizeChange', WindowBar.onSize);
  }

  private static notifyInsets(win: window.Window): void {
    try {
      const uiContext = win.getUIContext();
      const system = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const cutout = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const nav = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const keyboard = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD);
      const top = Math.max(system.topRect.height, cutout.topRect.height);
      const bottom = Math.max(nav.bottomRect.height, system.bottomRect.height, cutout.bottomRect.height);
      const left = Math.max(system.leftRect.width, cutout.leftRect.width, nav.leftRect.width);
      const right = Math.max(system.rightRect.width, cutout.rightRect.width, nav.rightRect.width);
      const keyboardHeight = keyboard.bottomRect.height;

      const topVp = uiContext.px2vp(top);
      const bottomVp = uiContext.px2vp(bottom);
      const leftVp = uiContext.px2vp(left);
      const rightVp = uiContext.px2vp(right);
      const keyboardVp = uiContext.px2vp(keyboardHeight);
      const turned = WindowBar.isTurned(WindowBar.pageAngle());
      const mapped = WindowBar.mapInsets(topVp, turned ? bottomVp + keyboardVp : bottomVp, leftVp, rightVp);

      AppStorage.setOrCreate<number>('SAFE_INSET_TOP', mapped.top);
      AppStorage.setOrCreate<number>('SAFE_INSET_BOTTOM', mapped.bottom);
      AppStorage.setOrCreate<number>('SAFE_INSET_LEFT', mapped.left);
      AppStorage.setOrCreate<number>('SAFE_INSET_RIGHT', mapped.right);
      AppStorage.setOrCreate<number>('KEYBOARD_HEIGHT', turned ? 0 : keyboardVp);

      if (WindowBar.onInsets) {
        WindowBar.onInsets(mapped.top, mapped.bottom, mapped.left, mapped.right);
      }
    } catch (err) {
      console.error('notifyInsets failed:', JSON.stringify(err));
    }
  }

  private static notifySize(win: window.Window, size?: Size): void {
    try {
      const uiContext = win.getUIContext();
      let widthPx: number;
      let heightPx: number;
      if (size && size.width > 0 && size.height > 0) {
        widthPx = size.width;
        heightPx = size.height;
      } else {
        const rect = win.getWindowProperties().windowRect;
        widthPx = rect.width;
        heightPx = rect.height;
      }
      WindowBar.rawW = uiContext.px2vp(widthPx);
      WindowBar.rawH = uiContext.px2vp(heightPx);
      AppStorage.setOrCreate<number>('WINDOW_RAW_W', WindowBar.rawW);
      AppStorage.set<number>('WINDOW_RAW_W', WindowBar.rawW);
      AppStorage.setOrCreate<number>('WINDOW_RAW_H', WindowBar.rawH);
      AppStorage.set<number>('WINDOW_RAW_H', WindowBar.rawH);
      WindowBar.republish();
    } catch (err) {
      console.error('notifySize failed:', JSON.stringify(err));
    }
  }

  // 全屏弹窗期间把系统导航栏背景透明掉，避免和遮罩叠成「两层蒙版 / 底部安全区色条」
  static setImmersiveOverlay(active: boolean): void {
    if (active) {
      WindowBar.overlayCount++;
    } else {
      WindowBar.overlayCount = Math.max(0, WindowBar.overlayCount - 1);
    }
    WindowBar.applyBarColors();
  }

  private static applyBarColors(win?: window.Window): void {
    const target = win || WindowBar.listenedWin;
    if (!target) {
      return;
    }
    try {
      target.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: '#FFFFFF',
        navigationBarColor: WindowBar.overlayCount > 0 ? '#00000000' : AppTheme.BG_ELEVATED,
        navigationBarContentColor: '#FFFFFF'
      });
    } catch (err) {
      console.error('applyBarColors failed:', JSON.stringify(err));
    }
  }

  static leftInset(): number {
    return AppStorage.get<number>('SAFE_INSET_LEFT') || 0;
  }

  static rightInset(): number {
    return AppStorage.get<number>('SAFE_INSET_RIGHT') || 0;
  }

  static topInset(): number {
    return AppStorage.get<number>('SAFE_INSET_TOP') || 0;
  }

  static bottomInset(): number {
    const value = AppStorage.get<number>('SAFE_INSET_BOTTOM');
    return value === undefined ? 16 : value;
  }

  static keyboardHeight(): number {
    return AppStorage.get<number>('KEYBOARD_HEIGHT') || 0;
  }

  static refresh(): void {
    if (WindowBar.listenedWin) {
      WindowBar.notifyInsets(WindowBar.listenedWin);
    }
    WindowBar.republish();
  }

  private static pageAngle(): number {
    const held = AppStorage.get<boolean>('APP_ROTATION_HELD') === true;
    const frozen = AppStorage.get<number>('APP_FROZEN_ANGLE') ?? 0;
    const sensor = AppStorage.get<number>('APP_DEVICE_ANGLE') ?? 0;
    return held ? frozen : sensor;
  }

  private static isTurned(angle: number): boolean {
    return angle === 90 || angle === -90 || angle === 270 || angle === -270;
  }

  private static republish(): void {
    if (WindowBar.rawW <= 0 || WindowBar.rawH <= 0) {
      return;
    }
    const turned = WindowBar.isTurned(WindowBar.pageAngle());
    const width = turned ? WindowBar.rawH : WindowBar.rawW;
    const height = turned ? WindowBar.rawW : WindowBar.rawH;
    Breakpoint.publish(width, height);
    if (WindowBar.onDisplay) {
      WindowBar.onDisplay(WindowBar.leftInset(), WindowBar.rightInset(), width, height);
    }
  }

  private static mapInsets(top: number, bottom: number, left: number, right: number): EdgeInsets {
    const angle = WindowBar.pageAngle();
    const mapped = new EdgeInsets();
    if (angle === 90 || angle === -270) {
      mapped.top = right;
      mapped.bottom = left;
      mapped.left = top;
      mapped.right = bottom;
      return mapped;
    }
    if (angle === -90 || angle === 270) {
      mapped.top = left;
      mapped.bottom = right;
      mapped.left = bottom;
      mapped.right = top;
      return mapped;
    }
    mapped.top = top;
    mapped.bottom = bottom;
    mapped.left = left;
    mapped.right = right;
    return mapped;
  }
}

class EdgeInsets {
  top: number = 0;
  bottom: number = 0;
  left: number = 0;
  right: number = 0;
}
