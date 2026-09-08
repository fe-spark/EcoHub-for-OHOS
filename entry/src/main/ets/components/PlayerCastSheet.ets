import { AppTheme } from '../common/constants/AppTheme';
import { CastSession } from '../common/utils/CastSession';
import { DlnaClient } from '../common/utils/DlnaClient';
import { DlnaDevice, DlnaPositionInfo, DlnaScanState } from '../common/utils/DlnaTypes';
import { FormatUtil } from '../common/utils/FormatUtil';

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

  @State private castPosition: number = 0;
  @State private castDuration: number = 0;
  @State private castVolume: number = 50;
  @State private volumeSupported: boolean = false;
  @State private transportState: string = '';
  @State private scrubbing: boolean = false;
  @State private volumeBusy: boolean = false;

  private pollToken: number = 0;
  private pollTimer: number = -1;
  private seekWarned: boolean = false;
  private volumeWarned: boolean = false;
  private positionFailCount: number = 0;

  // Seeded from VideoPlayer CastSession so reopen after screen-off shows fresh progress.
  seedPosition: number = 0;
  seedDuration: number = 0;
  seedVolume: number = 50;
  seedVolumeSupported: boolean = false;
  /** Shared with VideoPlayer so sheet poll shares remote-disconnect detection. */
  castSession: CastSession | null = null;

  aboutToAppear(): void {
    if (this.connectedUsn) {
      if (this.seedDuration > 0 || this.seedPosition > 0) {
        this.castPosition = this.seedPosition;
        this.castDuration = this.seedDuration;
      }
      if (this.seedVolumeSupported) {
        this.castVolume = this.seedVolume;
        this.volumeSupported = true;
      }
      this.startPoll();
      const device: DlnaDevice | null = this.connectedDevice();
      if (device) {
        this.loadVolume(device);
      }
    }
  }

  aboutToDisappear(): void {
    this.stopPoll();
  }

  private statusText(): string {
    if (this.casting) {
      return '正在投屏…';
    }
    if (this.connectedUsn) {
      const stateHint: string = this.transportLabel();
      if (stateHint) {
        return `正在投屏 · ${stateHint}`;
      }
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

  private transportLabel(): string {
    const s: string = this.transportState;
    if (!s) {
      return '';
    }
    if (s === 'PLAYING') {
      return '播放中';
    }
    if (s === 'PAUSED_PLAYBACK') {
      return '已暂停';
    }
    if (s === 'STOPPED') {
      return '已停止';
    }
    if (s === 'TRANSITIONING') {
      return '缓冲中';
    }
    return s;
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

  private connectedName(): string {
    const d: DlnaDevice | null = this.connectedDevice();
    return d ? d.friendlyName : '已连接设备';
  }

  private connectedHost(): string {
    const d: DlnaDevice | null = this.connectedDevice();
    return d ? d.host : '';
  }

  private castTimeText(): string {
    return `${FormatUtil.duration(this.castPosition)} / ${FormatUtil.duration(this.castDuration)}`;
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg });
    } catch (_e) {
    }
  }

  private resetCastUi(): void {
    this.castPosition = 0;
    this.castDuration = 0;
    this.castVolume = 50;
    this.volumeSupported = false;
    this.transportState = '';
    this.scrubbing = false;
    this.volumeBusy = false;
    this.seekWarned = false;
    this.volumeWarned = false;
    this.positionFailCount = 0;
  }

  private startPoll(): void {
    this.stopPoll();
    this.pollToken += 1;
    const token: number = this.pollToken;
    this.tickOnce(token);
    this.pollTimer = setInterval(() => {
      this.tickOnce(token);
    }, 1000) as number;
  }

  private stopPoll(): void {
    this.pollToken += 1;
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  private async tickOnce(token: number): Promise<void> {
    if (token !== this.pollToken) {
      return;
    }
    const device: DlnaDevice | null = this.connectedDevice();
    if (!device || !device.controlURL) {
      return;
    }
    let positionOk: boolean = false;
    let transportOk: boolean = false;
    try {
      const info: DlnaPositionInfo = await this.client.getPositionInfo(device);
      if (token !== this.pollToken) {
        return;
      }
      positionOk = true;
      this.positionFailCount = 0;
      if (this.castSession) {
        this.castSession.notePollSuccess();
        this.castSession.positionSec = info.positionSec;
        if (info.durationSec > 0) {
          this.castSession.durationSec = info.durationSec;
        }
      }
      if (!this.scrubbing) {
        this.castPosition = info.positionSec;
        if (info.durationSec > 0) {
          this.castDuration = info.durationSec;
        }
      }
    } catch (err) {
      this.positionFailCount += 1;
      console.error(`[PlayerCastSheet] GetPositionInfo fail: ${JSON.stringify(err)}`);
    }

    try {
      const state: string = await this.client.getTransportInfo(device);
      if (token !== this.pollToken) {
        return;
      }
      transportOk = true;
      this.transportState = state;
      if (this.castSession && this.castSession.noteTransportState(state)) {
        // Remote disconnect: CastSession already clearLocal + UI callback (no Stop SOAP).
        this.stopPoll();
        this.resetCastUi();
        return;
      }
    } catch (_e) {
      // Optional; many renderers support it but not required.
    }

    if (token !== this.pollToken) {
      return;
    }
    if (!positionOk && !transportOk && this.castSession) {
      if (this.castSession.notePollFailure()) {
        this.stopPoll();
        this.resetCastUi();
        return;
      }
    } else if (!positionOk && transportOk && this.positionFailCount === 3) {
      // Transport still alive — renderer likely lacks position sync, not a disconnect.
      this.toast('设备不支持进度同步');
    }
  }

  private async loadVolume(device: DlnaDevice): Promise<void> {
    if (!device.renderingControlURL) {
      this.volumeSupported = false;
      return;
    }
    try {
      const vol: number = await this.client.getVolume(device);
      this.castVolume = vol;
      this.volumeSupported = true;
    } catch (err) {
      console.error(`[PlayerCastSheet] GetVolume fail: ${JSON.stringify(err)}`);
      this.volumeSupported = false;
      if (!this.volumeWarned) {
        this.volumeWarned = true;
        this.toast('设备不支持音量控制');
      }
    }
  }

  private async castTo(device: DlnaDevice): Promise<void> {
    if (!this.mediaUrl) {
      this.toast('当前没有可投屏的视频地址');
      return;
    }
    this.casting = true;
    this.errorText = '';
    this.stopPoll();
    try {
      await this.client.cast(device, this.mediaUrl, this.mediaTitle || 'EcoHub');
      this.resetCastUi();
      this.connectedUsn = device.usn;
      this.onCasted(device);
      this.toast(`已投屏到 ${device.friendlyName}`);
      this.startPoll();
      this.loadVolume(device);
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : '投屏失败';
      this.errorText = msg;
      this.toast(msg);
    } finally {
      this.casting = false;
    }
  }

  private async stopCast(): Promise<void> {
    const device: DlnaDevice | null = this.connectedDevice();
    this.casting = true;
    this.stopPoll();
    try {
      if (device) {
        await this.client.stop(device);
      }
    } catch (err) {
      console.error(`[PlayerCastSheet] stop failed: ${JSON.stringify(err)}`);
    } finally {
      this.casting = false;
      this.connectedUsn = '';
      this.resetCastUi();
      this.onStopped();
      this.toast('已停止投屏');
    }
  }

  private async seekTo(sec: number): Promise<void> {
    const device: DlnaDevice | null = this.connectedDevice();
    if (!device) {
      return;
    }
    const target: number = Math.max(0, this.castDuration > 0 ? Math.min(sec, this.castDuration) : sec);
    try {
      await this.client.seek(device, target);
      this.castPosition = target;
    } catch (err) {
      console.error(`[PlayerCastSheet] Seek fail: ${JSON.stringify(err)}`);
      if (!this.seekWarned) {
        this.seekWarned = true;
        this.toast('设备不支持进度拖动');
      }
    }
  }

  private async applyVolume(vol: number): Promise<void> {
    const device: DlnaDevice | null = this.connectedDevice();
    if (!device || !this.volumeSupported || this.volumeBusy) {
      return;
    }
    const clamped: number = Math.max(0, Math.min(100, Math.round(vol)));
    this.castVolume = clamped;
    this.volumeBusy = true;
    try {
      await this.client.setVolume(device, clamped);
    } catch (err) {
      console.error(`[PlayerCastSheet] SetVolume fail: ${JSON.stringify(err)}`);
      if (!this.volumeWarned) {
        this.volumeWarned = true;
        this.toast('设备不支持音量控制');
      }
      this.volumeSupported = false;
    } finally {
      this.volumeBusy = false;
    }
  }

  private nudgeVolume(delta: number): void {
    this.applyVolume(this.castVolume + delta);
  }

  @Builder
  connectedControls() {
    Column() {
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

      // Progress + scrubber
      Column() {
        Text(this.castTimeText())
          .fontSize(12)
          .fontColor(AppTheme.TEXT_SECONDARY)
          .width('100%')
          .margin({ bottom: 4 })
        Slider({
          value: this.castPosition,
          min: 0,
          max: this.castDuration > 0 ? this.castDuration : 1,
          step: 1,
          style: SliderStyle.OutSet
        })
          .width('100%')
          .height(20)
          .trackThickness(2)
          .blockSize({ width: 12, height: 12 })
          .blockColor('#FFFFFF')
          .trackColor('rgba(255,255,255,0.28)')
          .selectedColor(AppTheme.ACCENT)
          .enabled(this.castDuration > 0 && !this.casting)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.castPosition = value;
            if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
              this.scrubbing = true;
            } else if (mode === SliderChangeMode.End) {
              this.scrubbing = false;
              this.seekTo(value);
            } else if (mode === SliderChangeMode.Click) {
              this.scrubbing = false;
              this.seekTo(value);
            }
          })
      }
      .width('100%')
      .margin({ top: 12 })

      // Volume
      if (this.volumeSupported) {
        Row() {
          Text('音量')
            .fontSize(12)
            .fontColor(AppTheme.TEXT_SECONDARY)
            .width(36)
          Text('−')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .backgroundColor('rgba(255,255,255,0.08)')
            .borderRadius(8)
            .onClick(() => this.nudgeVolume(-5))
          Slider({
            value: this.castVolume,
            min: 0,
            max: 100,
            step: 1,
            style: SliderStyle.OutSet
          })
            .layoutWeight(1)
            .height(20)
            .trackThickness(2)
            .blockSize({ width: 12, height: 12 })
            .blockColor('#FFFFFF')
            .trackColor('rgba(255,255,255,0.28)')
            .selectedColor(AppTheme.ACCENT)
            .margin({ left: 6, right: 6 })
            .enabled(!this.casting && !this.volumeBusy)
            .onChange((value: number, mode: SliderChangeMode) => {
              this.castVolume = value;
              if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                this.applyVolume(value);
              }
            })
          Text('+')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .backgroundColor('rgba(255,255,255,0.08)')
            .borderRadius(8)
            .onClick(() => this.nudgeVolume(5))
          Text(`${Math.round(this.castVolume)}`)
            .fontSize(12)
            .fontColor(AppTheme.TEXT_MUTED)
            .width(28)
            .textAlign(TextAlign.End)
            .margin({ left: 4 })
        }
        .width('100%')
        .margin({ top: 10 })
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding(12)
    .margin({ bottom: 10 })
    .backgroundColor(AppTheme.ACCENT_SOFT)
    .borderRadius(12)
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
        this.connectedControls()
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
  /** Linked from VideoPlayer so connection survives dialog close / screen-off. */
  @Link connectedUsn: string;
  @Prop @Watch('onSeedDeviceChange') seedDevice: DlnaDevice | null = null;
  @Prop seedPosition: number = 0;
  @Prop seedDuration: number = 0;
  @Prop seedVolume: number = 50;
  @Prop seedVolumeSupported: boolean = false;
  /** Shared CastSession for remote-disconnect detection while sheet poll owns the timer. */
  castSession: CastSession | null = null;
  onCasted: (device: DlnaDevice) => void = (_device: DlnaDevice) => {};
  onStopped: () => void = () => {};
  onClosed: () => void = () => {};

  @State private devices: DlnaDevice[] = [];
  @State private scanState: number = DlnaScanState.IDLE;
  @State private errorText: string = '';
  @State private casting: boolean = false;

  private dialog: CustomDialogController | null = null;
  private client: DlnaClient = new DlnaClient();
  private connectedDeviceCache: DlnaDevice | null = null;

  aboutToAppear(): void {
    this.syncSeedDevice();
  }

  aboutToDisappear(): void {
    this.client.cancelDiscover();
    this.close();
  }

  onSeedDeviceChange(): void {
    this.syncSeedDevice();
  }

  private syncSeedDevice(): void {
    if (this.seedDevice) {
      this.connectedDeviceCache = this.seedDevice;
    } else if (!this.connectedUsn) {
      this.connectedDeviceCache = null;
    }
  }

  onOpenChange(): void {
    this.close();
    if (this.openSeq <= 0) {
      // Dialog dismissed / page hide — do NOT clear connectedUsn or Stop TV.
      return;
    }
    this.syncSeedDevice();
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
        seedPosition: this.seedPosition,
        seedDuration: this.seedDuration,
        seedVolume: this.seedVolume,
        seedVolumeSupported: this.seedVolumeSupported,
        castSession: this.castSession,
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
        // UI only — connectedUsn / TV session stay alive for screen-off reopen.
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
