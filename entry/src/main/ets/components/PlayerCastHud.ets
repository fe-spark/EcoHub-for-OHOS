import { AppTheme } from '../common/constants/AppTheme';
import { CastSession } from '../common/utils/CastSession';
import { CastPhase } from '../common/utils/DlnaTypes';
import { FormatUtil } from '../common/utils/FormatUtil';
import { PlayerIconBtn } from './PlayerControl';

@Component
export struct PlayerCastHud {
  @Prop deviceName: string = '';
  @Prop positionSec: number = 0;
  @Prop durationSec: number = 0;
  @Prop phase: string = '';
  @Prop transportState: string = '';
  castSession: CastSession | null = null;

  @State private scrubPos: number = 0;
  @State private scrubbing: boolean = false;
  @State private transportBusy: boolean = false;
  private seekWarned: boolean = false;

  aboutToAppear(): void {
    this.scrubPos = this.positionSec;
    if (this.castSession) {
      this.castSession.setHudPolling(true);
    }
  }

  aboutToDisappear(): void {
    if (this.castSession) {
      this.castSession.setHudPolling(false);
    }
  }

  private displayPos(): number {
    return this.scrubbing ? this.scrubPos : this.positionSec;
  }

  private stateLabel(): string {
    const s: string = (this.transportState || '').toUpperCase();
    if (s === 'TRANSITIONING' &&
      (this.phase === CastPhase.LAUNCHING || this.phase === CastPhase.PLAYING)) {
      return '缓冲中';
    }
    if (this.phase === CastPhase.LAUNCHING) {
      return '正在连接…';
    }
    if (this.phase === CastPhase.PLAYING) {
      return '播放中';
    }
    if (this.phase === CastPhase.PAUSED) {
      return '已暂停';
    }
    return '正在投屏';
  }

  private isPaused(): boolean {
    return this.phase === CastPhase.PAUSED ||
      (this.transportState || '').toUpperCase() === 'PAUSED_PLAYBACK';
  }

  private canToggle(): boolean {
    return !this.transportBusy &&
      (this.phase === CastPhase.PLAYING || this.phase === CastPhase.PAUSED);
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg });
    } catch (_e) {
    }
  }

  private async togglePause(): Promise<void> {
    if (!this.canToggle() || !this.castSession) {
      return;
    }
    const pause: boolean = !this.isPaused();
    this.transportBusy = true;
    try {
      if (pause) {
        await this.castSession.pause();
      } else {
        await this.castSession.play();
      }
    } catch (err) {
      console.error(`[PlayerCastHud] pause/play fail: ${JSON.stringify(err)}`);
      this.toast(pause ? '设备不支持暂停' : '设备不支持继续播放');
    } finally {
      this.transportBusy = false;
    }
  }

  private async seekTo(sec: number): Promise<void> {
    if (!this.castSession) {
      return;
    }
    const target: number = Math.max(0, this.durationSec > 0 ? Math.min(sec, this.durationSec) : sec);
    try {
      await this.castSession.seek(target);
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
        Text(FormatUtil.duration(this.displayPos()))
          .fontSize(11)
          .fontColor(AppTheme.TEXT_MUTED)
        Slider({
          value: this.displayPos(),
          min: 0,
          max: this.durationSec > 0 ? this.durationSec : 1,
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
          .enabled(this.durationSec > 0)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.scrubPos = value;
            if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
              this.scrubbing = true;
            } else if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              this.scrubbing = false;
              this.seekTo(value);
            }
          })
        Text(FormatUtil.duration(this.durationSec))
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
        canTap: this.canToggle(),
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
