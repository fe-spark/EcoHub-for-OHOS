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

  private open(): void {
    this.dialog = new CustomDialogController({
      builder: PlayerSpeedDialog({
        speedLabel: this.speedLabel,
        onPickSpeed: (index: number) => {
          this.onPick(index);
          this.close();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      backgroundColor: Color.Transparent,
      maskColor: 'rgba(0,0,0,0.52)',
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
  }

  build() {
    Column()
      .width(0)
      .height(0)
      .hitTestBehavior(HitTestMode.None)
  }
}
