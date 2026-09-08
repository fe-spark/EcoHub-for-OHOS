import { AppTheme } from '../common/constants/AppTheme';
import { CastSession } from '../common/utils/CastSession';
import { DlnaClient } from '../common/utils/DlnaClient';
import { DlnaDevice, DlnaPositionInfo } from '../common/utils/DlnaTypes';
import { FormatUtil } from '../common/utils/FormatUtil';
import { peekCastStartSec } from './PlayerCastSheet';
import { PlayerIconBtn } from './PlayerControl';

@Component
export struct PlayerCastHud {
  @Prop deviceName: string = '';
  @Prop seedDuration: number = 0;
  seedDevice: DlnaDevice | null = null;
  castSession: CastSession | null = null;
  onStopped: (positionSec: number) => void = (_positionSec: number) => {};
  onFailed: (positionSec: number) => void = (_positionSec: number) => {};
  onProgress: (positionSec: number, durationSec: number) => void = (_p: number, _d: number) => {};

  @State private castPosition: number = 0;
  @State private castDuration: number = 0;
  @State private transportState: string = '';
  @State private scrubbing: boolean = false;
  @State private stopping: boolean = false;
  @State private transportBusy: boolean = false;
  private transportHoldUntil: number = 0;

  private client: DlnaClient = new DlnaClient();
  private pollToken: number = 0;
  private pollTimer: number = -1;
  private seekWarned: boolean = false;
  private positionFailCount: number = 0;
  private pendingStartSec: number = -1;
  private startSeekTries: number = 0;
  private startSeeking: boolean = false;
  private startAtMs: number = 0;
  private playbackConfirmed: boolean = false;
  private failNotified: boolean = false;
  private originMs: number = 0;
  private stoppedTicks: number = 0;
  private logTicks: number = 0;

  private static readonly CONFIRM_TIMEOUT_MS: number = 12000;
  private static readonly STOPPED_FAIL_WAIT_MS: number = 8000;
  private static readonly STOPPED_FAIL_TICKS: number = 5;

  aboutToAppear(): void {
    this.startAtMs = Date.now();
    const sessionDur: number = this.castSession ? this.castSession.durationSec : 0;
    this.castDuration = Math.max(sessionDur, this.seedDuration);
    if (this.castSession) {
      this.castSession.stopPoll();
      const start: number = Math.max(this.castSession.positionSec, peekCastStartSec());
      this.castPosition = start;
      if (start >= 2) {
        this.pendingStartSec = start;
      }
      if (this.castDuration > 0 && this.castSession.durationSec <= 0) {
        this.castSession.durationSec = this.castDuration;
      }
      console.info(`[PlayerCastHud] pendingStart=${this.pendingStartSec} dur=${this.castDuration}`);
    }
    this.startPoll();
  }

  aboutToDisappear(): void {
    this.stopPoll();
    if (this.castSession && this.castSession.active) {
      this.castSession.startPoll(2000);
    }
  }

  private device(): DlnaDevice | null {
    if (this.seedDevice && this.seedDevice.controlURL) {
      return this.seedDevice;
    }
    if (this.castSession && this.castSession.device) {
      return this.castSession.device;
    }
    return null;
  }

  private stateLabel(): string {
    if (!this.playbackConfirmed) {
      return '正在连接…';
    }
    const s: string = (this.transportState || '').toUpperCase();
    if (s === 'PLAYING') { return '播放中'; }
    if (s === 'PAUSED_PLAYBACK') { return '已暂停'; }
    if (s === 'STOPPED') { return '已停止'; }
    if (s === 'TRANSITIONING') { return '缓冲中'; }
    return '正在投屏';
  }

  private toast(msg: string): void {
    try { this.getUIContext().getPromptAction().showToast({ message: msg }); } catch (_e) {}
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
    if (token !== this.pollToken || this.failNotified) {
      return;
    }
    const device: DlnaDevice | null = this.device();
    if (!device || !device.controlURL) {
      return;
    }
    let positionOk: boolean = false;
    let transportOk: boolean = false;
    let tvPos: number = 0;
    let tvDur: number = this.castDuration;
    let tvReportedDur: number = 0;
    let relRaw: string = '';
    let durRaw: string = '';
    try {
      const info: DlnaPositionInfo = await this.client.getPositionInfo(device);
      if (token !== this.pollToken) {
        return;
      }
      positionOk = true;
      this.positionFailCount = 0;
      tvPos = info.positionSec;
      relRaw = info.relTime;
      durRaw = info.trackDuration;
      if (info.durationSec > 0) {
        tvDur = info.durationSec;
        tvReportedDur = info.durationSec;
      }
      this.applyPosition(info, tvDur);
    } catch (err) {
      this.positionFailCount += 1;
      console.error(`[PlayerCastHud] GetPositionInfo fail: ${JSON.stringify(err)}`);
    }

    try {
      const state: string = await this.client.getTransportInfo(device);
      if (token !== this.pollToken) {
        return;
      }
      transportOk = true;
      if (!this.transportBusy && Date.now() >= this.transportHoldUntil) {
        this.transportState = state;
      }
      if (this.castSession && this.castSession.noteTransportState(state)) {
        this.stopPoll();
        return;
      }
    } catch (_e) {
    }

    if (token !== this.pollToken) {
      return;
    }
    if (this.logTicks < 6) {
      this.logTicks += 1;
      console.info(`[PlayerCastHud] tick RelTime=${relRaw} TrackDuration=${durRaw} ` +
        `tv=${tvPos}/${tvDur} state=${this.transportState} confirmed=${this.playbackConfirmed}`);
    }
    if (!positionOk && !transportOk && this.castSession) {
      if (this.castSession.notePollFailure()) {
        this.stopPoll();
        return;
      }
    } else if (!positionOk && transportOk && this.positionFailCount === 3) {
      this.toast('设备不支持进度同步');
    }
    if (this.judgePlayback(tvPos, tvReportedDur)) {
      return;
    }
    this.applyPendingStart(device, tvPos, tvDur);
  }

  private applyPosition(info: DlnaPositionInfo, tvDur: number): void {
    if (this.castDuration <= 0 && this.seedDuration > 0) {
      this.castDuration = this.seedDuration;
    }
    if (this.castSession) {
      this.castSession.notePollSuccess();
      this.castSession.positionSec = this.pendingStartSec >= 2 ? this.pendingStartSec : info.positionSec;
      if (info.durationSec > 0) {
        this.castSession.durationSec = info.durationSec;
      } else if (this.castSession.durationSec <= 0 && this.castDuration > 0) {
        this.castSession.durationSec = this.castDuration;
      }
    }
    if (info.durationSec > 0) {
      this.castDuration = info.durationSec;
    }
    if (this.scrubbing) {
      this.onProgress(this.castPosition, this.castDuration);
      return;
    }
    const upper: string = (this.transportState || '').toUpperCase();
    if (this.pendingStartSec >= 2) {
      if (info.positionSec > 0 && Math.abs(info.positionSec - this.pendingStartSec) <= 8) {
        this.pendingStartSec = -1;
        this.castPosition = info.positionSec;
        this.originMs = Date.now() - info.positionSec * 1000;
      } else {
        this.castPosition = this.pendingStartSec;
      }
    } else if (info.positionSec > 0) {
      this.castPosition = info.positionSec;
      this.originMs = Date.now() - info.positionSec * 1000;
    } else if (this.playbackConfirmed && upper === 'PLAYING') {
      if (this.originMs <= 0) {
        this.originMs = Date.now() - Math.max(0, this.castPosition) * 1000;
      }
      let est: number = (Date.now() - this.originMs) / 1000;
      if (this.castDuration > 1) {
        est = Math.min(est, this.castDuration);
      }
      this.castPosition = Math.max(0, est);
    }
    this.onProgress(this.pendingStartSec >= 2 ? this.pendingStartSec : this.castPosition,
      tvDur > 0 ? tvDur : this.castDuration);
  }

  private isTransportPlaying(): boolean {
    const upper: string = (this.transportState || '').toUpperCase();
    return upper === 'PLAYING' || upper === 'TRANSITIONING' || upper === 'PAUSED_PLAYBACK';
  }

  /** @returns true if this tick already failed and stopped polling. */
  private judgePlayback(tvPos: number, tvReportedDur: number): boolean {
    const upper: string = (this.transportState || '').toUpperCase();
    if (this.isTransportPlaying() || tvPos > 0 || (tvReportedDur > 1 && upper !== 'STOPPED')) {
      this.playbackConfirmed = true;
      this.stoppedTicks = 0;
      return false;
    }
    if (upper === 'ERROR') {
      this.failCast('ERROR');
      return true;
    }
    const waited: number = Date.now() - this.startAtMs;
    if (upper === 'STOPPED' || upper === 'NO_MEDIA_PRESENT') {
      this.stoppedTicks += 1;
    } else {
      this.stoppedTicks = 0;
    }
    if (!this.playbackConfirmed && this.stoppedTicks >= PlayerCastHud.STOPPED_FAIL_TICKS &&
      waited >= PlayerCastHud.STOPPED_FAIL_WAIT_MS) {
      this.failCast(upper || 'STOPPED');
      return true;
    }
    if (!this.playbackConfirmed && waited >= PlayerCastHud.CONFIRM_TIMEOUT_MS) {
      this.failCast('timeout');
      return true;
    }
    return false;
  }

  private failCast(reason: string): void {
    if (this.failNotified || this.stopping) {
      return;
    }
    this.failNotified = true;
    this.stopPoll();
    console.info(`[PlayerCastHud] playback fail: ${reason}`);
    const device: DlnaDevice | null = this.device();
    const pos: number = this.castPosition > 0 ? this.castPosition :
      (this.castSession ? this.castSession.positionSec : 0);
    this.onFailed(pos);
    if (device) {
      this.client.stop(device).catch((_e: Object) => {});
    }
  }

  private applyPendingStart(device: DlnaDevice, tvPos: number, durationSec: number): void {
    if (this.pendingStartSec < 2 || this.startSeeking) {
      return;
    }
    if (tvPos > 0 && Math.abs(tvPos - this.pendingStartSec) <= 8) {
      this.pendingStartSec = -1;
      return;
    }
    if (this.startSeekTries >= 8) {
      if (!this.seekWarned) {
        this.seekWarned = true;
        this.pendingStartSec = -1;
        this.toast('未能跳到手机进度，可手动拖动');
      }
      return;
    }
    const upper: string = (this.transportState || '').toUpperCase();
    const clockReady: boolean = durationSec > 1;
    const playing: boolean = upper === 'PLAYING' || upper === 'TRANSITIONING' || upper === 'PAUSED_PLAYBACK';
    const waited: number = Date.now() - this.startAtMs;
    if (!clockReady && waited < 2500) {
      return;
    }
    if (!playing && waited < 4000) {
      return;
    }
    const target: number = durationSec > 1 ?
      Math.min(this.pendingStartSec, Math.max(0, durationSec - 1)) : this.pendingStartSec;
    this.startSeeking = true;
    this.startSeekTries += 1;
    console.info(`[PlayerCastHud] resume seek try=${this.startSeekTries} target=${target} ` +
      `tv=${tvPos} dur=${durationSec} state=${upper}`);
    this.client.seek(device, target).then(() => {
      this.startSeeking = false;
    }).catch((err: Object) => {
      this.startSeeking = false;
      console.error(`[PlayerCastHud] resume seek fail: ${JSON.stringify(err)}`);
      if (this.startSeekTries >= 8 && !this.seekWarned) {
        this.seekWarned = true;
        this.pendingStartSec = -1;
        this.toast('未能跳到手机进度，可手动拖动');
      }
    });
  }

  private isPaused(): boolean {
    const s: string = (this.transportState || '').toUpperCase();
    return s === 'PAUSED_PLAYBACK' || s === 'STOPPED';
  }

  private async togglePause(): Promise<void> {
    if (this.stopping || this.transportBusy) {
      return;
    }
    const device: DlnaDevice | null = this.device();
    if (!device || !device.controlURL) {
      return;
    }
    const pause: boolean = !this.isPaused();
    this.transportBusy = true;
    this.transportHoldUntil = Date.now() + 2000;
    this.transportState = pause ? 'PAUSED_PLAYBACK' : 'PLAYING';
    try {
      if (pause) {
        await this.client.pause(device);
      } else {
        await this.client.play(device);
      }
      if (this.castSession) {
        this.castSession.transportState = this.transportState;
      }
    } catch (err) {
      console.error(`[PlayerCastHud] pause/play fail: ${JSON.stringify(err)}`);
      this.toast(pause ? '设备不支持暂停' : '设备不支持继续播放');
    } finally {
      this.transportBusy = false;
    }
  }

  private async stopCast(): Promise<void> {
    if (this.stopping) {
      return;
    }
    const device: DlnaDevice | null = this.device();
    this.stopping = true;
    this.stopPoll();
    try {
      if (device) {
        await this.client.stop(device);
      }
    } catch (err) {
      console.error(`[PlayerCastHud] stop failed: ${JSON.stringify(err)}`);
    } finally {
      this.stopping = false;
      const pos: number = this.castPosition > 0 ? this.castPosition :
        (this.castSession ? this.castSession.positionSec : 0);
      this.onStopped(pos);
      this.toast('已停止投屏');
    }
  }

  private async seekTo(sec: number): Promise<void> {
    const device: DlnaDevice | null = this.device();
    if (!device) {
      return;
    }
    this.pendingStartSec = -1;
    const target: number = Math.max(0, this.castDuration > 0 ? Math.min(sec, this.castDuration) : sec);
    try {
      await this.client.seek(device, target);
      this.castPosition = target;
      if (this.castSession) {
        this.castSession.positionSec = target;
      }
    } catch (err) {
      console.error(`[PlayerCastHud] Seek fail: ${JSON.stringify(err)}`);
      if (!this.seekWarned) {
        this.seekWarned = true;
        this.toast('设备不支持进度拖动');
      }
    }
  }

  build() {
    Column() {
      Text(`投屏至 ${this.deviceName || '电视'}`)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .width('100%')
      Text(this.stateLabel())
        .fontSize(11)
        .fontColor(AppTheme.TEXT_MUTED)
        .margin({ top: 2 })

      Row() {
        Text(FormatUtil.duration(this.castPosition))
          .fontSize(11)
          .fontColor(AppTheme.TEXT_MUTED)
        Slider({
          value: this.castPosition,
          min: 0,
          max: this.castDuration > 0 ? this.castDuration : 1,
          step: 1,
          style: SliderStyle.OutSet
        })
          .layoutWeight(1)
          .height(16)
          .trackThickness(2)
          .blockSize({ width: 10, height: 10 })
          .blockColor('#FFFFFF')
          .trackColor('rgba(255,255,255,0.28)')
          .selectedColor(AppTheme.ACCENT)
          .margin({ left: 6, right: 6 })
          .enabled(this.castDuration > 0)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.castPosition = value;
            if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
              this.scrubbing = true;
            } else if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              this.scrubbing = false;
              this.seekTo(value);
            }
          })
        Text(FormatUtil.duration(this.castDuration))
          .fontSize(11)
          .fontColor(AppTheme.TEXT_MUTED)
      }
      .width('100%')
      .margin({ top: 10 })
      .alignItems(VerticalAlign.Center)

      PlayerIconBtn({
        src: this.isPaused() ? $r('sys.symbol.play_fill') : $r('sys.symbol.pause_fill'),
        iconSize: 22,
        boxSize: 44,
        circle: true,
        prominent: true,
        canTap: !this.transportBusy,
        onTap: () => this.togglePause()
      })
        .margin({ top: 8 })
    }
    .width(268)
    .padding({
      left: AppTheme.SPACE_LG,
      right: AppTheme.SPACE_LG,
      top: AppTheme.SPACE_MD,
      bottom: AppTheme.SPACE_MD
    })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('rgba(255,255,255,0.08)')
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK, {
      colorMode: ThemeColorMode.DARK,
      adaptiveColor: AdaptiveColor.DEFAULT
    })
    .borderRadius(AppTheme.RADIUS_LG)
    .clip(true)
    .border({ width: 1, color: 'rgba(255,255,255,0.18)' })
  }
}
