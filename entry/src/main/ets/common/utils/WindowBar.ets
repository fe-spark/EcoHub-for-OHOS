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
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: '#FFFFFF',
        navigationBarColor: AppTheme.BG_ELEVATED,
        navigationBarContentColor: '#FFFFFF'
      });
      WindowBar.bindListener(win);
      WindowBar.notifyInsets(win);
    }).catch((err: Error) => {
      console.error('apply window bar failed:', JSON.stringify(err));
    });
  }

  private static bindListener(win: window.Window): void {
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
      if (WindowBar.listenedWin) {
        WindowBar.notifyInsets(WindowBar.listenedWin);
      }
    };
    WindowBar.onSize = (_size: Size) => {
      if (WindowBar.listenedWin) {
        WindowBar.notifyInsets(WindowBar.listenedWin);
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

      AppStorage.setOrCreate<number>('SAFE_INSET_TOP', topVp);
      AppStorage.setOrCreate<number>('SAFE_INSET_BOTTOM', bottomVp);
      AppStorage.setOrCreate<number>('SAFE_INSET_LEFT', leftVp);
      AppStorage.setOrCreate<number>('SAFE_INSET_RIGHT', rightVp);
      AppStorage.setOrCreate<number>('KEYBOARD_HEIGHT', keyboardVp);

      if (WindowBar.onInsets) {
        WindowBar.onInsets(topVp, bottomVp, leftVp, rightVp);
      }
      const rect = win.getWindowProperties().windowRect;
      const widthVp = uiContext.px2vp(rect.width);
      const heightVp = uiContext.px2vp(rect.height);
      Breakpoint.publish(widthVp, heightVp);
      if (WindowBar.onDisplay) {
        WindowBar.onDisplay(leftVp, rightVp, widthVp, heightVp);
      }
    } catch (err) {
      console.error('notifyInsets failed:', JSON.stringify(err));
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
    return AppStorage.get<number>('SAFE_INSET_BOTTOM') || 16;
  }

  static keyboardHeight(): number {
    return AppStorage.get<number>('KEYBOARD_HEIGHT') || 0;
  }
}
