import { common } from '@kit.AbilityKit';
import { PiPWindow } from '@kit.ArkUI';
import { AppToast } from '../../common/utils/AppToast';
import { PlayerPip } from './PlayerPip';

export interface PlayerPipHost {
  getContext: () => common.UIAbilityContext | undefined;
  isCasting: () => boolean;
  getVideoUrl: () => string;
  hasPrev: () => boolean;
  hasNext: () => boolean;
  onPrev?: () => void;
  onNext?: () => void;
  isPlaying: () => boolean;
  isCompleted: () => boolean;
  getErrorText: () => string;
  getDuration: () => number;
  getCurrentTime: () => number;
  seekTo: (time: number) => void;
  pulseHud: () => void;
  play: () => void;
  pause: () => void;
  fullNow: () => boolean;
  exitFull: () => void;
  isPageActive: () => boolean;
  emitProgress: (isFinal?: boolean) => void;
  onPipActiveChanged: (active: boolean) => void;
}

/**
 * 画中画 (PiP) 业务协调器
 * 负责 PiPWindow 生命周期、事件监听、后台暂停保护及前后台联动
 */
export class PlayerPipCoordinator {
  private pip: PlayerPip = new PlayerPip();
  private host: PlayerPipHost | null = null;
  private isRestoring: boolean = false;
  private pendingHidePauseTimer: number = -1;
  private autoStartSetting: boolean = true;
  private static readonly SEEK_STEP_SEC: number = 10;

  get enabled(): boolean {
    return this.pip.enabled;
  }

  get active(): boolean {
    return this.pip.active;
  }

  get isReady(): boolean {
    return this.pip.isReady;
  }

  setSettingPipAutoStart(enabled: boolean): void {
    this.autoStartSetting = enabled;
    this.syncAutoStart();
  }

  private clearPendingHidePause(): void {
    if (this.pendingHidePauseTimer >= 0) {
      clearTimeout(this.pendingHidePauseTimer);
      this.pendingHidePauseTimer = -1;
    }
  }

  setup(
    host: PlayerPipHost,
    xComponentController: XComponentController,
    width: number,
    height: number
  ): void {
    this.host = host;
    const ctx = host.getContext();
    if (!ctx) {
      return;
    }
    this.pip.setup(
      ctx,
      xComponentController,
      width > 0 ? width : 16,
      height > 0 ? height : 9,
      {
        onPlayStateChanged: (play: boolean) => {
          if (!this.host) {
            return;
          }
          if (play) {
            if (this.host.isCompleted()) {
              this.host.seekTo(0);
            }
            this.host.play();
          } else {
            this.host.pause();
          }
        },
        onPipActiveChanged: (active: boolean) => {
          if (this.host) {
            this.host.onPipActiveChanged(active);
          }
        },
        onFastForward: () => {
          if (!this.host) {
            return;
          }
          const target = Math.min(this.host.getDuration(), this.host.getCurrentTime() + PlayerPipCoordinator.SEEK_STEP_SEC);
          this.host.seekTo(target);
          this.host.pulseHud();
        },
        onFastBackward: () => {
          if (!this.host) {
            return;
          }
          const target = Math.max(0, this.host.getCurrentTime() - PlayerPipCoordinator.SEEK_STEP_SEC);
          this.host.seekTo(target);
          this.host.pulseHud();
        },
        onNext: () => {
          if (this.host?.hasNext() && this.host.onNext) {
            this.host.onNext();
          }
        },
        onPrev: () => {
          if (this.host?.hasPrev() && this.host.onPrev) {
            this.host.onPrev();
          }
        },
        onRestore: () => {
          this.isRestoring = true;
          if (this.host) {
            this.host.onPipActiveChanged(false);
            this.host.pulseHud();
          }
        },
        onClosed: () => {
          if (!this.host) {
            return;
          }
          this.host.onPipActiveChanged(false);
          const wasRestoring = this.isRestoring;
          this.isRestoring = false;
          if (!this.host.isPageActive() && !wasRestoring) {
            this.host.pause();
            if (this.host.getCurrentTime() > 0) {
              this.host.emitProgress(true);
            }
          }
        }
      }
    ).then((success: boolean) => {
      if (success) {
        this.pip.syncPlayStatus(this.host?.isPlaying() ?? false);
        this.syncAutoStart();
        this.syncControls();
      }
    });
  }

  syncControls(): void {
    if (!this.host) {
      return;
    }
    this.pip.updateControlEnabled(PiPWindow.PiPControlType.VIDEO_PREVIOUS, this.host.hasPrev());
    this.pip.updateControlEnabled(PiPWindow.PiPControlType.VIDEO_NEXT, this.host.hasNext());
  }

  syncAutoStart(): void {
    if (!this.host) {
      return;
    }
    const canAuto = this.pip.isReady &&
      this.autoStartSetting &&
      !this.host.isCasting() &&
      !!this.host.getVideoUrl() &&
      !this.host.getErrorText() &&
      this.host.isPlaying() &&
      (!this.host.isCompleted() || this.host.hasNext());
    this.pip.setAutoStart(canAuto);
  }

  syncPlayStatus(playing: boolean): void {
    this.pip.syncPlayStatus(playing);
    this.syncAutoStart();
  }

  updateSize(width: number, height: number): void {
    this.pip.updateSize(width, height);
  }

  startManual(): void {
    if (!this.host) {
      return;
    }
    if (this.host.isCasting()) {
      try {
        AppToast.show('当前正在投屏，无法开启画中画');
      } catch (_e) {}
      return;
    }
    if (!this.pip.enabled) {
      try {
        AppToast.show('当前设备不支持画中画');
      } catch (_e) {}
      return;
    }
    if (this.host.fullNow()) {
      this.host.exitFull();
    }
    if (!this.host.isPlaying()) {
      this.host.play();
    }
    this.pip.start().catch((err: Error) => {
      console.error(`[PlayerPipCoordinator] 手动开启画中画失败: ${err.message}`);
      try {
        AppToast.show('开启画中画失败');
      } catch (_e) {}
    });
  }

  stop(): Promise<void> {
    return this.pip.stop();
  }

  setAutoStart(enable: boolean): void {
    this.pip.setAutoStart(enable);
  }

  handleError(): void {
    this.pip.setAutoStart(false);
    if (this.pip.active) {
      console.info('[PlayerPipCoordinator] 播放出错时画中画激活中，关闭画中画回页面展示错误');
      this.pip.stop().catch((_e: Object) => {});
      this.bringAppToFront();
    }
  }

  handleSourceChange(): void {
    if (this.pip.active) {
      console.info('[PlayerPipCoordinator] 切换片源时画中画激活中，关闭画中画并回页面加载');
      this.isRestoring = true;
      this.pip.stop().catch((_e: Object) => {});
      this.bringAppToFront();
    }
  }

  handlePageShow(): void {
    this.clearPendingHidePause();
    if (this.pip.active) {
      console.info('[PlayerPipCoordinator] 页面重新激活，自动停止画中画恢复原位播放');
      this.pip.stop().catch((_e: Object) => {});
    }
  }

  handlePageHide(): void {
    if (this.pip.active) {
      return;
    }
    const willAutoPip = this.autoStartSetting && this.pip.autoStart && (!this.host || !this.host.isCasting());
    if (willAutoPip) {
      this.clearPendingHidePause();
      this.pendingHidePauseTimer = setTimeout(() => {
        this.pendingHidePauseTimer = -1;
        if (this.host && !this.host.isPageActive() && !this.pip.active) {
          console.info('[PlayerPipCoordinator] 页面隐藏且未拉起画中画（应用内跳转），执行兜底暂停');
          if (this.host.isPlaying()) {
            this.host.pause();
          }
        }
      }, 200);
      return;
    }
    if (this.host?.isPlaying()) {
      this.host.pause();
    }
  }

  bringAppToFront(): void {
    const ctx = this.host?.getContext();
    if (!ctx) {
      return;
    }
    const bundleName = ctx.abilityInfo?.bundleName || ctx.applicationInfo?.name || 'com.ecohub.spark';
    if (!bundleName) {
      return;
    }
    ctx.startAbility({
      bundleName: bundleName,
      abilityName: 'EntryAbility'
    }).catch((err: Object) => {
      console.warn(`[PlayerPipCoordinator] 拉起应用前台失败: ${JSON.stringify(err)}`);
    });
  }

  destroy(): void {
    this.clearPendingHidePause();
    this.pip.setAutoStart(false);
    if (this.pip.active) {
      this.pip.stop().catch((_e: Object) => {});
    }
    this.pip.destroy();
  }
}
