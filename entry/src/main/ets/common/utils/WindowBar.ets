import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppTheme } from '../constants/AppTheme';

export class WindowBar {
  static apply(context?: common.UIAbilityContext,
    onInsets?: (top: number, bottom: number) => void,
    onDisplay?: (left: number, right: number, width: number, height: number) => void): void {
    if (!context) {
      return;
    }
    window.getLastWindow(context).then((win: window.Window) => {
      win.setWindowSystemBarEnable(['status', 'navigation']);
      win.setWindowLayoutFullScreen(true);
      win.setWindowSystemBarProperties({
        statusBarColor: AppTheme.BG,
        statusBarContentColor: '#FFFFFF',
        navigationBarColor: AppTheme.BG_ELEVATED,
        navigationBarContentColor: '#FFFFFF'
      });
      WindowBar.notifyInsets(win, onInsets, onDisplay);
      win.on('avoidAreaChange', (_data: window.AvoidAreaOptions) => {
        WindowBar.notifyInsets(win, onInsets, onDisplay);
      });
    }).catch((err: Error) => {
      console.error('apply window bar failed:', JSON.stringify(err));
    });
  }

  private static notifyInsets(win: window.Window,
    onInsets?: (top: number, bottom: number) => void,
    onDisplay?: (left: number, right: number, width: number, height: number) => void): void {
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
    if (onInsets) {
      onInsets(px2vp(top), px2vp(bottom));
    }
    if (!onDisplay) {
      return;
    }
    const left = Math.max(system.leftRect.width, cutout.leftRect.width);
    const right = Math.max(system.rightRect.width, cutout.rightRect.width);
    const rect = win.getWindowProperties().windowRect;
    onDisplay(px2vp(left), px2vp(right), px2vp(rect.width), px2vp(rect.height));
  }
}
