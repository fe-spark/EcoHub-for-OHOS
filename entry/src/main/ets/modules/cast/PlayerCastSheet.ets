import { AppTheme } from '../../common/constants/AppTheme';
import { DlnaClient } from './DlnaClient';
import { DlnaDevice, DlnaScanState, soapErrorMessage } from '../../types/DlnaTypes';

let launchStartSec: number = 0;

export function markCastStartSec(sec: number): void {
  launchStartSec = Math.max(0, sec);
  console.info(`[PlayerCastSheet] markCastStartSec=${launchStartSec}`);
}

export function peekCastStartSec(): number {
  return launchStartSec;
}

@CustomDialog
struct PlayerCastPicker {
  controller?: CustomDialogController;
  mediaUrl: string = '';
  mediaTitle: string = '';
  startPosition: number = 0;
  startDuration: number = 0;
  connectedUsn: string = '';
  seedDevice: DlnaDevice | null = null;
  getStartPosition: () => number = () => 0;
  onCasted: (device: DlnaDevice) => void = (_d: DlnaDevice) => {};
  private dismissed: boolean = false;

  @State private devices: DlnaDevice[] = [];
  @State private scanState: number = DlnaScanState.IDLE;
  @State private errorText: string = '';
  @State private casting: boolean = false;

  @StorageLink('SAFE_INSET_LEFT') private leftInset: number = 0;
  @StorageLink('SAFE_INSET_RIGHT') private rightInset: number = 0;
  @StorageLink('SAFE_INSET_BOTTOM') private bottomInset: number = 16;
  @StorageLink('WINDOW_HEIGHT') private windowHeight: number = 640;

  private client: DlnaClient = new DlnaClient();

  aboutToAppear(): void {
    this.dismissed = false;
    this.startScan();
  }

  aboutToDisappear(): void {
    this.dismissed = true;
    this.client.cancelDiscover();
  }

  private isLandscape(): boolean {
    return this.windowHeight > 0 && this.windowHeight < 500;
  }

  private statusText(): string {
    if (this.casting) {
      return '正在投屏…';
    }
    if (this.scanState === DlnaScanState.SCANNING) {
      return '正在搜索同一 Wi‑Fi 下的电视/盒子…';
    }
    if (this.scanState === DlnaScanState.ERROR) {
      return this.errorText || '搜索失败，请确认已连接 Wi‑Fi 后重试';
    }
    if (this.devices.length === 0) {
      return '未发现可投屏设备，请确认电视已开启投屏且与手机同一局域网';
    }
    return `发现 ${this.devices.length} 台设备，点选即可投屏`;
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg });
    } catch (_e) {
    }
  }

  private startScan(): void {
    this.client.cancelDiscover();
    this.scanState = DlnaScanState.SCANNING;
    this.errorText = '';
    const keep: DlnaDevice[] = [];
    if (this.seedDevice && this.connectedUsn) {
      keep.push(this.seedDevice);
    }
    this.devices = keep;
    this.client.discover((list: DlnaDevice[]) => {
      this.mergeDevices(list);
    }).then((list: DlnaDevice[]) => {
      this.mergeDevices(list);
      this.scanState = DlnaScanState.DONE;
    }).catch((err: Object) => {
      const msg: string = err instanceof Error ? err.message : '搜索失败';
      this.errorText = msg;
      this.scanState = DlnaScanState.ERROR;
    });
  }

  private mergeDevices(list: DlnaDevice[]): void {
    const map: Map<string, DlnaDevice> = new Map();
    if (this.seedDevice && this.connectedUsn) {
      map.set(this.deviceKey(this.seedDevice), this.seedDevice);
    }
    for (let i = 0; i < list.length; i++) {
      const d: DlnaDevice = list[i];
      if (d.controlURL) {
        map.set(this.deviceKey(d), d);
      }
    }
    const merged: DlnaDevice[] = [];
    map.forEach((d: DlnaDevice) => {
      merged.push(d);
    });
    this.devices = merged;
  }

  private deviceKey(d: DlnaDevice): string {
    const usn: string = d.usn || '';
    if (usn.indexOf('uuid:') === 0) {
      const cut: number = usn.indexOf('::');
      return cut >= 0 ? usn.substring(0, cut) : usn;
    }
    return d.location || d.controlURL || usn;
  }

  private async castTo(device: DlnaDevice): Promise<void> {
    if (!this.mediaUrl) {
      this.toast('当前没有可投屏的视频地址');
      return;
    }
    if (this.casting || this.connectedUsn === device.usn) {
      return;
    }
    this.casting = true;
    this.errorText = '';
    this.toast(`正在投屏到 ${device.friendlyName}…`);
    try {
      const startSec: number = Math.max(this.startPosition, launchStartSec);
      await this.client.cast(device, this.mediaUrl, this.mediaTitle || 'EcoHub',
        startSec, this.startDuration);
      if (this.dismissed) {
        this.client.stop(device).catch((_e: Object) => {});
        return;
      }
      this.onCasted(device);
      if (this.controller) {
        this.controller.close();
      }
    } catch (err) {
      const msg: string = soapErrorMessage(err);
      this.errorText = msg;
      this.toast(msg);
    } finally {
      this.casting = false;
    }
  }

  build() {
    Column() {
      Row() {
        Text('投屏到电视')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        Blank()
        Text('刷新')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.scanState === DlnaScanState.SCANNING ? AppTheme.TEXT_MUTED : AppTheme.ACCENT)
          .padding({ left: 8, right: 4, top: 6, bottom: 6 })
          .onClick(() => {
            if (this.scanState !== DlnaScanState.SCANNING && !this.casting) {
              this.startScan();
            }
          })
      }
      .width('100%')

      Text(this.statusText())
        .fontSize(12)
        .fontColor('rgba(255,255,255,0.55)')
        .margin({ top: 6, bottom: 12 })
        .width('100%')

      if (this.scanState === DlnaScanState.SCANNING && this.devices.length === 0) {
        Row() {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(AppTheme.ACCENT)
          Text('扫描中…')
            .fontSize(13)
            .fontColor(AppTheme.TEXT_SECONDARY)
            .margin({ left: 10 })
        }
        .width('100%')
        .height(72)
        .justifyContent(FlexAlign.Center)
      } else if (this.devices.length === 0) {
        Text(this.scanState === DlnaScanState.ERROR ? '点击右上角刷新重试' : '暂无设备')
          .fontSize(13)
          .fontColor(AppTheme.TEXT_MUTED)
          .width('100%')
          .height(72)
          .textAlign(TextAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.devices, (device: DlnaDevice) => {
            ListItem() {
              Row() {
                Column() {
                  Text(device.friendlyName)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FFFFFF')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(device.manufacturer ? `${device.manufacturer} · ${device.host}` : device.host)
                    .fontSize(11)
                    .fontColor(AppTheme.TEXT_MUTED)
                    .margin({ top: 2 })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (this.connectedUsn === device.usn) {
                  Text('已连接')
                    .fontSize(12)
                    .fontColor(AppTheme.ACCENT)
                } else {
                  Text('投屏')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor(AppTheme.ACCENT)
                    .borderRadius(8)
                    .opacity(this.casting ? 0.5 : 1)
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(this.connectedUsn === device.usn ? AppTheme.ACCENT_SOFT : 'rgba(255,255,255,0.06)')
              .borderRadius(12)
              .onClick(() => {
                this.castTo(device);
              })
            }
          }, (device: DlnaDevice) => device.usn)
        }
        .width('100%')
        .constraintSize({ maxHeight: this.isLandscape() ? 140 : 280 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
      }
    }
    .width('100%')
    .padding({
      left: AppTheme.SPACE_LG + this.leftInset,
      right: AppTheme.SPACE_LG + this.rightInset,
      top: 16,
      bottom: Math.max(24, this.bottomInset + 12)
    })
    .backgroundColor('#191B20')
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}

@Component
export struct PlayerCastSheet {
  @Prop @Watch('onOpenChange') openSeq: number = 0;
  @Prop mediaUrl: string = '';
  @Prop mediaTitle: string = '';
  @Prop startPosition: number = 0;
  @Prop startDuration: number = 0;
  @Prop connectedUsn: string = '';
  @Prop seedDevice: DlnaDevice | null = null;
  getStartPosition: () => number = () => 0;
  onCasted: (device: DlnaDevice) => void = (_device: DlnaDevice) => {};
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
      builder: PlayerCastPicker({
        mediaUrl: this.mediaUrl,
        mediaTitle: this.mediaTitle,
        startPosition: this.startPosition,
        startDuration: this.startDuration,
        getStartPosition: () => this.getStartPosition ? this.getStartPosition() : this.startPosition,
        connectedUsn: this.connectedUsn,
        seedDevice: this.seedDevice,
        onCasted: (device: DlnaDevice) => {
          this.onCasted(device);
          this.close();
          this.onClosed();
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
