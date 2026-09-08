import { AppTheme } from '../common/constants/AppTheme';
import { DlnaClient } from '../common/utils/DlnaClient';
import { DlnaDevice, DlnaScanState } from '../common/utils/DlnaTypes';

@CustomDialog
struct PlayerCastDialog {
  controller?: CustomDialogController;
  @Link devices: DlnaDevice[];
  @Link scanState: number;
  @Link errorText: string;
  @Link connectedUsn: string;
  @Link casting: boolean;
  mediaUrl: string = '';
  mediaTitle: string = '';
  onCasted: (device: DlnaDevice) => void = (_d: DlnaDevice) => {};
  onStopped: () => void = () => {};
  onRescan: () => void = () => {};
  private client: DlnaClient = new DlnaClient();

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

  private connectedDevice(): DlnaDevice | null {
    if (!this.connectedUsn) {
      return null;
    }
    for (let i = 0; i < this.devices.length; i++) {
      if (this.devices[i].usn === this.connectedUsn) {
        return this.devices[i];
      }
    }
    return null;
  }

  private async castTo(device: DlnaDevice): Promise<void> {
    if (!this.mediaUrl) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '当前没有可投屏的视频地址' });
      } catch (_e) {
      }
      return;
    }
    this.casting = true;
    this.errorText = '';
    try {
      await this.client.cast(device, this.mediaUrl, this.mediaTitle || 'EcoHub');
      this.connectedUsn = device.usn;
      this.onCasted(device);
      try {
        this.getUIContext().getPromptAction().showToast({ message: `已投屏到 ${device.friendlyName}` });
      } catch (_e) {
      }
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : '投屏失败';
      this.errorText = msg;
      try {
        this.getUIContext().getPromptAction().showToast({ message: msg });
      } catch (_e) {
      }
    } finally {
      this.casting = false;
    }
  }

  private async stopCast(): Promise<void> {
    const device: DlnaDevice | null = this.connectedDevice();
    this.casting = true;
    try {
      if (device) {
        await this.client.stop(device);
      }
    } catch (err) {
      console.error(`[PlayerCastSheet] stop failed: ${JSON.stringify(err)}`);
    } finally {
      this.casting = false;
      this.connectedUsn = '';
      this.onStopped();
      try {
        this.getUIContext().getPromptAction().showToast({ message: '已停止投屏' });
      } catch (_e) {
      }
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
              this.onRescan();
            }
          })
      }
      .width('100%')

      Text(this.statusText())
        .fontSize(12)
        .fontColor('rgba(255,255,255,0.55)')
        .margin({ top: 6, bottom: 12 })
        .width('100%')

      if (this.connectedUsn) {
        Row() {
          Column() {
            Text(this.connectedName())
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.connectedHost())
              .fontSize(11)
              .fontColor(AppTheme.TEXT_MUTED)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text('停止投屏')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(AppTheme.DANGER)
            .borderRadius(10)
            .onClick(() => {
              this.stopCast();
            })
        }
        .width('100%')
        .padding(12)
        .margin({ bottom: 10 })
        .backgroundColor(AppTheme.ACCENT_SOFT)
        .borderRadius(12)
      }

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
                if (!this.casting && this.connectedUsn !== device.usn) {
                  this.castTo(device);
                }
              })
            }
          }, (device: DlnaDevice) => device.usn)
        }
        .width('100%')
        .constraintSize({ maxHeight: 280 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 28 })
    .backgroundColor('#191B20')
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}

@Component
export struct PlayerCastSheet {
  @Prop @Watch('onOpenChange') openSeq: number = 0;
  @Prop mediaUrl: string = '';
  @Prop mediaTitle: string = '';
  onCasted: (device: DlnaDevice) => void = (_device: DlnaDevice) => {};
  onStopped: () => void = () => {};
  onClosed: () => void = () => {};

  @State private devices: DlnaDevice[] = [];
  @State private scanState: number = DlnaScanState.IDLE;
  @State private errorText: string = '';
  @State private connectedUsn: string = '';
  @State private casting: boolean = false;

  private dialog: CustomDialogController | null = null;
  private client: DlnaClient = new DlnaClient();
  private connectedDeviceCache: DlnaDevice | null = null;

  aboutToDisappear(): void {
    this.client.cancelDiscover();
    this.close();
  }

  onOpenChange(): void {
    this.close();
    if (this.openSeq <= 0) {
      return;
    }
    this.open();
    this.startScan();
  }

  private open(): void {
    this.dialog = new CustomDialogController({
      builder: PlayerCastDialog({
        devices: $devices,
        scanState: $scanState,
        errorText: $errorText,
        connectedUsn: $connectedUsn,
        casting: $casting,
        mediaUrl: this.mediaUrl,
        mediaTitle: this.mediaTitle,
        onCasted: (device: DlnaDevice) => {
          this.connectedDeviceCache = device;
          this.onCasted(device);
        },
        onStopped: () => {
          this.connectedDeviceCache = null;
          this.onStopped();
        },
        onRescan: () => this.startScan()
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      backgroundColor: Color.Transparent,
      maskColor: 'rgba(0,0,0,0.52)',
      cancel: () => {
        this.dialog = null;
        this.client.cancelDiscover();
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

  private startScan(): void {
    this.client.cancelDiscover();
    this.scanState = DlnaScanState.SCANNING;
    this.errorText = '';
    // Keep connected device visible while rescanning.
    const keep: DlnaDevice[] = [];
    if (this.connectedDeviceCache && this.connectedUsn) {
      keep.push(this.connectedDeviceCache);
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
    if (this.connectedDeviceCache && this.connectedUsn) {
      map.set(this.connectedUsn, this.connectedDeviceCache);
    }
    for (let i = 0; i < list.length; i++) {
      const d: DlnaDevice = list[i];
      if (d.controlURL) {
        map.set(d.usn, d);
      }
    }
    const merged: DlnaDevice[] = [];
    map.forEach((d: DlnaDevice) => {
      merged.push(d);
    });
    this.devices = merged;
  }


  build() {
    Column()
      .width(0)
      .height(0)
      .hitTestBehavior(HitTestMode.None)
  }
}
