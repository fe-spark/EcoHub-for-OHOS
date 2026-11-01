import { PlayerSpeedDialog } from './PlayerTip';

@Component
export struct PlayerSpeedSheet {
  @Prop @Watch('onOpenChange') openSeq: number = 0;
  @Prop speedLabel: string = '1.0x';
  onPick: (index: number) => void = (_index: number) => {};
  onClosed: () => void = () => {};
  private dialog: CustomDialogController | null = null;

  aboutToDisappear(): void {
    this.close();
  }

  onOpenChange(): void {
    this.close();
    if (this.openSeq <= 0) {
      return;
    }
    this.open();
  }

  private isLandscape(): boolean {
    const w = AppStorage.get<number>('WINDOW_WIDTH') || 0;
    const h = AppStorage.get<number>('WINDOW_HEIGHT') || 0;
    return w > h && h > 0;
  }

  private open(): void {
    const isLand = this.isLandscape();
    this.dialog = new CustomDialogController({
      builder: PlayerSpeedDialog({
        speedLabel: this.speedLabel,
        onPickSpeed: (index: number) => {
          this.onPick(index);
          this.close();
        },
        onClose: () => {
          this.close();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      backgroundColor: Color.Transparent,
      maskColor: 'rgba(0, 0, 0, 0.25)',
      cancel: () => {
        this.dialog = null;
        this.onClosed();
      }
    });
    this.dialog.open();
  }

  private close(): void {
    if (this.dialog) {
      this.dialog.close();
      this.dialog = null;
    }
    this.onClosed();
  }

  build() {
    Column()
      .width(0)
      .height(0)
      .hitTestBehavior(HitTestMode.None)
  }
}
