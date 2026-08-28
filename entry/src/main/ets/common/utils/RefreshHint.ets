import { promptAction } from '@kit.ArkUI';

export class RefreshHint {
  static succeed(): void {
    promptAction.showToast({ message: '已更新' });
  }

  static fail(message: string = '刷新失败'): void {
    promptAction.showToast({ message: message });
  }
}
