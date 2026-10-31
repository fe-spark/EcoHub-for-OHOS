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
  private static debounceTimer: number = -1;
  private static overlayCount: number = 0;
  private static barsWanted: boolean = true;
  private static rawW: number = 0;
  private static rawH: number = 0;
  private static pendingWidth: number = 0;
  private static pendingHeight: number = 0;
  private static cachedSystem: window.AvoidArea | null = null;
  private static cachedCutout: window.AvoidArea | null = null;
  private static cachedNav: window.AvoidArea | null = null;
  private static cachedKeyboard: window.AvoidArea | null = null;
  private static lastTop: number = -1;
  private static lastBottom: number = -1;
  private static lastLeft: number = -1;
  private static lastRight: number = -1;
  private static lastKeyboard: number = -1;
  private static lastW: number = -1;
  private static lastH: number = -1;

  static requestBars(context: common.UIAbilityContext | undefined, show: boolean, onDone?: () => void): void {
    WindowBar.barsWanted = show;
    if (!context) {
      if (onDone) {
        onDone();
      }
      return;
    }
    if (show) {
      WindowBar.apply(context);
      if (onDone) {
        onDone();
      }
      return;
    }
    const seq = ++WindowBar.applySeq;
    window.getLastWindow(context).then((win: window.Window) => {
      if (seq !== WindowBar.applySeq) {
        return;
      }
      WindowBar.setSystemBarsVisible(win, onDone);
    }).catch((err: Error) => {
      console.error(`[WindowBar] 获取窗口失败: ${JSON.stringify(err)}`);
      if (onDone) {
        onDone();
      }
    });
  }

  private static setSystemBarsVisible(win: window.Window, onDone?: () => void): void {
    const show = WindowBar.barsWanted;
    try {
      win.setWindowLayoutFullScreen(true);
    } catch (_err) {
    }
    const finish = (): void => {
      if (WindowBar.barsWanted !== show) {
        WindowBar.setSystemBarsVisible(win, onDone);
        return;
      }
      WindowBar.flush(win);
      if (onDone) {
        onDone();
      }
    };
    win.setSpecificSystemBarEnabled('status', show, false).then(() => {
      win.setSpecificSystemBarEnabled('navigation', show, false).then(() => {
        finish();
      }).catch((err: Error) => {
        console.error(`[WindowBar] 设置导航栏失败: ${JSON.stringify(err)}`);
        finish();
      });
    }).catch((err: Error) => {
      console.error(`[WindowBar] 设置状态栏失败: ${JSON.stringify(err)}`);
      finish();
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
    // 1. 同步立即回显已知边距（防止异步延迟导致的瞬间顶入状态栏）
    if (onInsets) {
      const top = WindowBar.lastTop >= 0 ? WindowBar.lastTop : WindowBar.topInset();
      const bottom = WindowBar.lastBottom >= 0 ? WindowBar.lastBottom : WindowBar.bottomInset();
      const left = WindowBar.lastLeft >= 0 ? WindowBar.lastLeft : WindowBar.leftInset();
      const right = WindowBar.lastRight >= 0 ? WindowBar.lastRight : WindowBar.rightInset();
      onInsets(top, bottom, left, right);
    }
    if (onDisplay && WindowBar.rawW > 0 && WindowBar.rawH > 0) {
      onDisplay(WindowBar.leftInset(), WindowBar.rightInset(), WindowBar.rawW, WindowBar.rawH);
    }
    const seq = ++WindowBar.applySeq;
    window.getLastWindow(context).then((win: window.Window) => {
      if (seq !== WindowBar.applySeq) {
        return;
      }
      WindowBar.setSystemBarsVisible(win);
      if (WindowBar.barsWanted) {
        WindowBar.applyBarColors(win);
      }
      WindowBar.bindListener(win);
      WindowBar.flush(win, true);
    }).catch((err: Error) => {
      console.error('apply window bar failed:', JSON.stringify(err));
    });
  }

  private static initAvoidCache(win: window.Window): void {
    try {
      WindowBar.cachedSystem = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      WindowBar.cachedCutout = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      WindowBar.cachedNav = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      WindowBar.cachedKeyboard = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD);
    } catch (_err) {
    }
  }

  private static updateAvoidCache(type: window.AvoidAreaType, area: window.AvoidArea): void {
    if (type === window.AvoidAreaType.TYPE_SYSTEM) {
      WindowBar.cachedSystem = area;
    } else if (type === window.AvoidAreaType.TYPE_CUTOUT) {
      WindowBar.cachedCutout = area;
    } else if (type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
      WindowBar.cachedNav = area;
    } else if (type === window.AvoidAreaType.TYPE_KEYBOARD) {
      WindowBar.cachedKeyboard = area;
    }
  }

  private static bindListener(win: window.Window): void {
    if (WindowBar.debounceTimer !== -1) {
      clearTimeout(WindowBar.debounceTimer);
      WindowBar.debounceTimer = -1;
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
    WindowBar.initAvoidCache(win);

    WindowBar.onAvoid = (data: window.AvoidAreaOptions) => {
      if (!WindowBar.listenedWin) {
        return;
      }
      if (data && data.area) {
        WindowBar.updateAvoidCache(data.type, data.area);
      }
      WindowBar.scheduleFlush(WindowBar.listenedWin);
    };

    WindowBar.onSize = (size: Size) => {
      if (!WindowBar.listenedWin) {
        return;
      }
      if (size && size.width > 0 && size.height > 0) {
        WindowBar.pendingWidth = size.width;
        WindowBar.pendingHeight = size.height;
      }
      WindowBar.scheduleFlush(WindowBar.listenedWin);
    };

    win.on('avoidAreaChange', WindowBar.onAvoid);
    win.on('windowSizeChange', WindowBar.onSize);
  }

  private static scheduleFlush(win: window.Window): void {
    if (WindowBar.debounceTimer !== -1) {
      clearTimeout(WindowBar.debounceTimer);
    }
    // 16ms 帧对齐：将屏幕旋转期间密集爆发的多次 avoidAreaChange 与 windowSizeChange 合并为单次结算
    WindowBar.debounceTimer = setTimeout(() => {
      WindowBar.debounceTimer = -1;
      WindowBar.flush(win);
    }, 16);
  }

  private static flush(win: window.Window, forceNotify: boolean = false): void {
    try {
      const uiContext = win.getUIContext();
      if (!uiContext) {
        return;
      }
      // 1. 规避区运算（基于内存缓存，0 次跨进程 IPC 查询）
      const top = Math.max(
        WindowBar.cachedSystem?.topRect.height || 0,
        WindowBar.cachedCutout?.topRect.height || 0
      );
      const bottom = Math.max(
        WindowBar.cachedNav?.bottomRect.height || 0,
        WindowBar.cachedSystem?.bottomRect.height || 0,
        WindowBar.cachedCutout?.bottomRect.height || 0
      );
      const left = Math.max(
        WindowBar.cachedSystem?.leftRect.width || 0,
        WindowBar.cachedCutout?.leftRect.width || 0,
        WindowBar.cachedNav?.leftRect.width || 0
      );
      const right = Math.max(
        WindowBar.cachedSystem?.rightRect.width || 0,
        WindowBar.cachedCutout?.rightRect.width || 0,
        WindowBar.cachedNav?.rightRect.width || 0
      );
      const keyboardHeight = WindowBar.cachedKeyboard?.bottomRect.height || 0;

      const topVp = Math.round(uiContext.px2vp(top));
      const bottomVp = Math.round(uiContext.px2vp(bottom));
      const leftVp = Math.round(uiContext.px2vp(left));
      const rightVp = Math.round(uiContext.px2vp(right));
      const keyboardVp = Math.round(uiContext.px2vp(keyboardHeight));

      // 规避区严格比对去重：未变动绝不写入 AppStorage，绝不触发全局 UI 脏标记
      const insetsChanged = (
        topVp !== WindowBar.lastTop ||
        bottomVp !== WindowBar.lastBottom ||
        leftVp !== WindowBar.lastLeft ||
        rightVp !== WindowBar.lastRight ||
        keyboardVp !== WindowBar.lastKeyboard
      );
      if (insetsChanged) {
        WindowBar.lastTop = topVp;
        WindowBar.lastBottom = bottomVp;
        WindowBar.lastLeft = leftVp;
        WindowBar.lastRight = rightVp;
        WindowBar.lastKeyboard = keyboardVp;
        AppStorage.setOrCreate<number>('SAFE_INSET_TOP', topVp);
        AppStorage.setOrCreate<number>('SAFE_INSET_BOTTOM', bottomVp);
        AppStorage.setOrCreate<number>('SAFE_INSET_LEFT', leftVp);
        AppStorage.setOrCreate<number>('SAFE_INSET_RIGHT', rightVp);
        AppStorage.setOrCreate<number>('KEYBOARD_HEIGHT', keyboardVp);
      }
      if (insetsChanged || forceNotify) {
        if (WindowBar.onInsets) {
          WindowBar.onInsets(topVp, bottomVp, leftVp, rightVp);
        }
      }

      // 2. 窗口尺寸运算与比对去重
      let widthPx = WindowBar.pendingWidth;
      let heightPx = WindowBar.pendingHeight;
      if (widthPx <= 0 || heightPx <= 0) {
        const rect = win.getWindowProperties().windowRect;
        widthPx = rect.width;
        heightPx = rect.height;
      }
      const rawW = Math.round(uiContext.px2vp(widthPx));
      const rawH = Math.round(uiContext.px2vp(heightPx));

      if (rawW > 0 && rawH > 0 && (rawW !== WindowBar.lastW || rawH !== WindowBar.lastH)) {
        WindowBar.lastW = rawW;
        WindowBar.lastH = rawH;
        WindowBar.rawW = rawW;
        WindowBar.rawH = rawH;
        AppStorage.setOrCreate<number>('WINDOW_RAW_W', rawW);
        AppStorage.setOrCreate<number>('WINDOW_RAW_H', rawH);
        Breakpoint.publish(rawW, rawH);
        if (WindowBar.onDisplay) {
          WindowBar.onDisplay(WindowBar.leftInset(), WindowBar.rightInset(), rawW, rawH);
        }
      }
    } catch (err) {
      console.error('WindowBar flush failed:', JSON.stringify(err));
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
      target.setWindowBackgroundColor(AppTheme.BG);
    } catch (_err) {
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
      WindowBar.flush(WindowBar.listenedWin);
    }
  }
  private static republish(): void {
    if (WindowBar.rawW <= 0 || WindowBar.rawH <= 0) {
      return;
    }
    Breakpoint.publish(WindowBar.rawW, WindowBar.rawH);
    if (WindowBar.onDisplay) {
      WindowBar.onDisplay(WindowBar.leftInset(), WindowBar.rightInset(), WindowBar.rawW, WindowBar.rawH);
    }
  }
}
