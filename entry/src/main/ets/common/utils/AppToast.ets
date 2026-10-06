export class AppToast {
  static show(message: string): void {
    if (!message) {
      return;
    }
    const seq = (AppStorage.get<number>('APP_TOAST_SEQ') ?? 0) + 1;
    AppStorage.setOrCreate<string>('APP_TOAST', message);
    AppStorage.set<string>('APP_TOAST', message);
    AppStorage.setOrCreate<number>('APP_TOAST_SEQ', seq);
    AppStorage.set<number>('APP_TOAST_SEQ', seq);
  }
}
