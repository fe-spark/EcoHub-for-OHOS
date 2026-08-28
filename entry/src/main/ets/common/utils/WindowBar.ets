import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppTheme } from '../constants/AppTheme';

export class WindowBar {
  private static applySeq: number = 0;
  private static listenedWin: window.Window | null = null;
  private static onAvoid?: (data: window.AvoidAreaOptions) => void;
  private static onInsets?: (top: number, bottom: number) => void;
  private static onDisplay?: (left: number, right: number, width: number, height: number) => void;

  static apply(context?: common.UIAbilityContext,
    onInsets?: (top: number, bottom: number) => void,
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
        statusBarColor: AppTheme.BG,
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
    if (WindowBar.listenedWin && WindowBar.onAvoid) {
      try {
        WindowBar.listenedWin.off('avoidAreaChange', WindowBar.onAvoid);
      } catch (_err) {
      }
    }
    WindowBar.listenedWin = win;
    WindowBar.onAvoid = (_data: window.AvoidAreaOptions) => {
      if (WindowBar.listenedWin) {
        WindowBar.notifyInsets(WindowBar.listenedWin);
      }
    };
    win.on('avoidAreaChange', WindowBar.onAvoid);
  }

  private static notifyInsets(win: window.Window): void {
    const system = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const cutout = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
    const nav = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    let top = system.topRect.height;
    if (top <= 0) {
      top = cutout.topRect.height;
    }
    let bottom = nav.bottomRect.height;
    if (bottom <= 0) {
      bottom = system.bottomRect.height;
    }
    if (WindowBar.onInsets) {
      WindowBar.onInsets(px2vp(top), px2vp(bottom));
    }
    if (!WindowBar.onDisplay) {
      return;
    }
    const left = Math.max(system.leftRect.width, cutout.leftRect.width);
    const right = Math.max(system.rightRect.width, cutout.rightRect.width);
    const rect = win.getWindowProperties().windowRect;
    WindowBar.onDisplay(px2vp(left), px2vp(right), px2vp(rect.width), px2vp(rect.height));
  }
}
