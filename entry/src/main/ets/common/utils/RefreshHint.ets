import promptAction from '@ohos.promptAction';

export class RefreshHint {
  static succeed(): void {
    promptAction.showToast({ message: '已更新' });
  }
}
