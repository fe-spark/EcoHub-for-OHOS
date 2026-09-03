import { PlayerScaleDialog } from './PlayerTip';
import { PlayerScaleMode } from '../common/utils/PlayerScale';

@Component
export struct PlayerScaleSheet {
  private static readonly DIALOG_MASK_COLOR: string = 'rgba(0, 0, 0, 0.52)';

  @Prop @Watch('onOpenChange') openSeq: number = 0;
  @Prop scaleMode: number = PlayerScaleMode.FIT;
  @Prop isPortrait: boolean = false;
  onPick: (mode: number) => void = (_mode: number) => {};
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
      builder: PlayerScaleDialog({
        scaleMode: this.scaleMode,
        isPortrait: this.isPortrait,
        onPickScale: (mode: number) => {
          this.onPick(mode);
          this.close();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      backgroundColor: Color.Transparent,
      maskColor: PlayerScaleSheet.DIALOG_MASK_COLOR,
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
