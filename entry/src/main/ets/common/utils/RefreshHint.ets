import { UIContext } from '@kit.ArkUI';
import { AppToast } from './AppToast';

export class RefreshHint {
  static succeed(uiContext?: UIContext): void {
    RefreshHint.toast('已更新', uiContext);
  }

  static fail(message: string = '刷新失败', uiContext?: UIContext): void {
    RefreshHint.toast(message, uiContext);
  }

  private static toast(message: string, uiContext?: UIContext): void {
    const ctx = uiContext || AppStorage.get<UIContext>('UI_CONTEXT');
    if (!ctx) {
      return;
    }
    try {
      AppToast.show(message);
    } catch (_e) {
    }
  }
}
