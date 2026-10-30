import { promptAction } from '@kit.ArkUI';

export class AppToast {
  static show(message: string): void {
    if (!message) {
      return;
    }
    try {
      promptAction.showToast({
        message: message,
        duration: 2500
      });
    } catch (_err) {
    }
    const seq = (AppStorage.get<number>('APP_TOAST_SEQ') ?? 0) + 1;
    AppStorage.setOrCreate<string>('APP_TOAST', message);
    AppStorage.setOrCreate<number>('APP_TOAST_SEQ', seq);
  }
}
