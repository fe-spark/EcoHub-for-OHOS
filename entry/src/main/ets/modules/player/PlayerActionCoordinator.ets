import { common } from '@kit.AbilityKit';
import { PlayerTipKind } from './PlayerPan';
import { AudioMuteResult, PlayerAudioBridge } from './PlayerAudioBridge';
import { PlayerGestureCoordinator } from './PlayerGestureCoordinator';
import { PlayerSpeedController } from './PlayerSpeedController';
import { PlayerScaleController } from './PlayerScaleController';
import { PlayerWindow } from './PlayerWindow';
import { PlayerSkinEvents } from './PlayerSkinView';

export interface ScaleCycleResult {
  mode: number;
  label: string;
}

export interface PlayerActionHost {
  fullNow: () => boolean;
  toggleFull: () => void;
  togglePlay: () => void;
  toggleMute: () => void;
  openSpeedDialog: () => void;
  cycleScaleMode: () => void;
  retry: () => void;
  showErrorDetail: () => void;
  seekTo: (time: number) => void;
  pulseHud: () => void;
  armHide: () => void;
  clearHide: () => void;
  onBack?: () => void;
  onPrev?: () => void;
  onNext?: () => void;
  onCast: () => void;
  onStopCast: () => void;
  onPip?: () => void;
  isCasting: () => boolean;
  canPlay: () => boolean;
  isPlaying: () => boolean;
  isReady: () => boolean;
  isOpening: () => boolean;
  isDragging: () => boolean;
  setDragging: (dragging: boolean) => void;
  getDuration: () => number;
  getCurrentTime: () => number;
  setCurrentTime: (time: number) => void;
  getPlayerW: () => number;
  getPlayerH: () => number;
  getContext: () => common.UIAbilityContext | undefined;
  getTopInset?: () => number;
  setLongPressing: (val: boolean) => void;
  setSpeed: (index: number, label: string) => void;
  setFeedback: (msg: string, kind: number) => void;
  clearTip: () => void;
  setVolumeState: (vol: number, muted: boolean) => void;
  isShowHud: () => boolean;
  setShowHud: (show: boolean) => void;
  isPlayRequested: () => boolean;
  isCompleted: () => boolean;
}

/**
 * 播放器手势与交互协调器
 * 管理手势识别（亮度/音量/快进）、倍速调节、画面缩放比例以及系统音量监听
 */
export class PlayerActionCoordinator {
  audioBridge: PlayerAudioBridge = new PlayerAudioBridge();
  gestures: PlayerGestureCoordinator = new PlayerGestureCoordinator();
  speedCtrl: PlayerSpeedController = new PlayerSpeedController();
  scaleCtrl: PlayerScaleController = new PlayerScaleController();

  private volumeSub: (() => void) | null = null;
  private seekGesture: number = 0;
  private playEpoch: number = 0;
  private static readonly SEEK_STEP_SEC: number = 10;

  initAudio(
    onVolumeChanged: (vol: number, muted: boolean) => void,
    onCastVolumeSync?: () => void
  ): void {
    this.audioBridge.sync((vol, _max, isMuted) => {
      this.gestures.pan.primeVolume(this.audioBridge.max > 0 ? vol / this.audioBridge.max : 0);
      onVolumeChanged(vol, isMuted);
    });

    this.volumeSub = PlayerWindow.subscribeVolumeChange((info) => {
      this.audioBridge.updateFromSystem(info);
      this.gestures.pan.primeVolume(info.max > 0 ? info.current / info.max : 0);
      onVolumeChanged(info.current, this.audioBridge.muted);
      if (onCastVolumeSync) {
        onCastVolumeSync();
      }
    });
  }

  destroyAudio(): void {
    if (this.volumeSub) {
      this.volumeSub();
      this.volumeSub = null;
    }
  }

  bumpEpoch(): void {
    this.playEpoch++;
    this.seekGesture = 0;
  }

  toggleMute(): AudioMuteResult {
    const res = this.audioBridge.toggleMute();
    this.gestures.pan.primeVolume(this.audioBridge.max > 0 ? res.volume / this.audioBridge.max : 0);
    return res;
  }

  cycleScale(isPortrait: boolean): ScaleCycleResult {
    const mode = this.scaleCtrl.cycle();
    const label = this.scaleCtrl.label(isPortrait);
    const res: ScaleCycleResult = { mode, label };
    return res;
  }

  resetGestures(): void {
    this.gestures.pan.reset();
  }

  buildSkinEvents(host: PlayerActionHost): PlayerSkinEvents {
    return {
      onBack: () => {
        if (host.fullNow()) {
          host.toggleFull();
        } else if (host.onBack) {
          host.onBack();
        }
      },
      onPlay: () => host.togglePlay(),
      onFull: () => host.toggleFull(),
      onMute: () => host.toggleMute(),
      onPrev: () => { if (host.onPrev) host.onPrev(); },
      onNext: () => { if (host.onNext) host.onNext(); },
      onSpeed: () => host.openSpeedDialog(),
      onScale: () => host.cycleScaleMode(),
      onRetry: () => host.retry(),
      onErrorDetail: () => host.showErrorDetail(),
      onSeekBack: () => {
        host.seekTo(host.getCurrentTime() - PlayerActionCoordinator.SEEK_STEP_SEC);
        host.pulseHud();
      },
      onSeekForward: () => {
        host.seekTo(host.getCurrentTime() + PlayerActionCoordinator.SEEK_STEP_SEC);
        host.pulseHud();
      },
      onSeekStart: (val: number) => {
        if (!host.isReady() || host.isOpening()) return;
        this.seekGesture = this.playEpoch;
        host.setDragging(true);
        host.setCurrentTime(val);
        host.clearHide();
        host.setShowHud(true);
      },
      onSeekUpdate: (val: number) => {
        if (this.seekGesture === this.playEpoch) {
          host.setCurrentTime(val);
        }
      },
      onSeekEnd: (val: number) => {
        const accept = this.seekGesture === this.playEpoch && host.isReady() && !host.isOpening();
        this.seekGesture = 0;
        host.setDragging(false);
        if (accept) {
          host.setCurrentTime(val);
          host.seekTo(val);
          host.pulseHud();
        }
      },
      onToggleHud: () => {
        if (this.speedCtrl.showing || this.gestures.pan.mode > 1) return;
        if (host.isShowHud()) {
          if (!host.isPlayRequested() || host.isCompleted()) return;
          host.setShowHud(false);
          host.clearHide();
        } else {
          host.setShowHud(true);
          host.armHide();
        }
      },
      onLongPress: () => {
        if (host.isCasting()) return;
        if (this.speedCtrl.beginFastForward(host.canPlay(), host.isPlaying())) {
          host.setLongPressing(true);
          host.setSpeed(this.speedCtrl.index, this.speedCtrl.label);
          host.setFeedback('', PlayerTipKind.NONE);
          host.setShowHud(false);
        }
      },
      onLongPressEnd: () => {
        if (this.speedCtrl.endFastForward()) {
          host.setLongPressing(false);
          host.setSpeed(this.speedCtrl.index, this.speedCtrl.label);
          host.pulseHud();
        }
      },
      onPanStart: (e: GestureEvent) => {
        if (host.isCasting()) return;
        const topInset = host.getTopInset ? host.getTopInset() : 0;
        this.gestures.start(e, host.canPlay(), false, host.getCurrentTime(), host.getPlayerW(), host.getContext(), topInset);
      },
      onPanMove: (e: GestureEvent) => {
        const res = this.gestures.move(e, false, host.fullNow(), host.getDuration(), host.getPlayerW(), host.getPlayerH());
        if (!res) return;
        if (res.mode === 2 && res.time !== undefined) {
          if (this.seekGesture !== this.playEpoch) this.seekGesture = this.playEpoch;
          host.setDragging(true);
          host.setCurrentTime(res.time);
          host.clearHide();
        } else if (res.mode === 3 && res.bright !== undefined && res.bright >= 0) {
          PlayerWindow.setBrightness(host.getContext(), res.bright);
        } else if (res.mode === 4 && res.volumeRatio !== undefined && res.volumeRatio >= 0) {
          const vol = this.audioBridge.applyRatio(res.volumeRatio);
          host.setVolumeState(vol, vol <= 0);
        }
        host.setFeedback(res.feedback, res.feedbackKind);
      },
      onPanEnd: () => {
        const gesture = this.seekGesture;
        const res = this.gestures.finish(host.getCurrentTime());
        host.clearTip();
        host.setFeedback('', PlayerTipKind.NONE);
        this.seekGesture = 0;
        if (res.shouldSeek && gesture === this.playEpoch && host.isReady()) {
          host.seekTo(res.targetTime);
        }
        host.setDragging(false);
        host.pulseHud();
      },
      onPanCancel: () => {
        this.gestures.finish(host.getCurrentTime());
        host.clearTip();
        host.setFeedback('', PlayerTipKind.NONE);
        this.seekGesture = 0;
        host.setDragging(false);
        host.pulseHud();
      },
      onCast: () => host.onCast(),
      onStopCast: () => host.onStopCast(),
      onPip: host.onPip
    };
  }
}
