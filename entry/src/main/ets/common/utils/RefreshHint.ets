import { UIContext } from '@kit.ArkUI';

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
      ctx.getPromptAction().showToast({ message: message });
    } catch (_e) {
    }
  }
}
