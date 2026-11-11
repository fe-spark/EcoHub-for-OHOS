import { PlayerSettingsDialog } from './PlayerTip';
import { PlayerScaleMode } from './PlayerScale';

@Component
export struct PlayerSpeedSheet {
  @Prop @Watch('onOpenChange') openSeq: number = 0;
  @Prop speedLabel: string = '1.0x';
  @Prop scaleMode: number = PlayerScaleMode.FIT;
  @Prop isPortrait: boolean = false;
  @Prop muted: boolean = false;
  onPick: (index: number) => void = (_index: number) => {};
  onPickScale: (mode: number) => void = (_mode: number) => {};
  onToggleMute: () => void = () => {};
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
      builder: PlayerSettingsDialog({
        speedLabel: this.speedLabel,
        scaleMode: this.scaleMode,
        isPortrait: this.isPortrait,
        muted: this.muted,
        onPickSpeed: (index: number) => {
          this.onPick(index);
        },
        onPickScale: (mode: number) => {
          this.onPickScale(mode);
        },
        onToggleMute: () => {
          this.onToggleMute();
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
