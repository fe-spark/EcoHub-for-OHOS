import { PiPWindow } from '@kit.ArkUI';
import { common, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';

export interface PipActionDelegate {
  onPlayStateChanged: (play: boolean) => void;
  onPipActiveChanged?: (active: boolean) => void;
  onFastForward?: () => void;
  onFastBackward?: () => void;
  onNext?: () => void;
  onPrev?: () => void;
  onRestore?: () => void;
  onClosed?: () => void;
}

export class PlayerPip {
  private pipController: PiPWindow.PiPController | null = null;
  private isSupported: boolean = false;
  private isPipActive: boolean = false;
  private delegate: PipActionDelegate | null = null;
  private context: common.UIAbilityContext | null = null;
  private continuousTaskActive: boolean = false;
  private desiredAutoStart: boolean = false;
  private desiredWidth: number = 0;
  private desiredHeight: number = 0;
  private desiredPlayStatus: boolean = false;
  private isDestroyed: boolean = false;

  constructor() {
    this.isSupported = PiPWindow.isPiPEnabled();
    console.info(`[PlayerPip] isPiPEnabled: ${this.isSupported}`);
  }

  get enabled(): boolean {
    return this.isSupported;
  }

  get active(): boolean {
    return this.isPipActive;
  }

  get autoStart(): boolean {
    return this.desiredAutoStart;
  }

  get isReady(): boolean {
    return this.pipController !== null && !this.isDestroyed;
  }

  /**
   * 初始化并创建画中画控制器
   */
  async setup(
    context: common.UIAbilityContext,
    xComponentController: XComponentController,
    width: number,
    height: number,
    delegate: PipActionDelegate
  ): Promise<boolean> {
    if (!this.isSupported) {
      console.warn('[PlayerPip] 当前设备或系统环境不支持画中画');
      return false;
    }
    this.context = context;
    this.delegate = delegate;
    if (width > 0 && height > 0) {
      this.desiredWidth = width;
      this.desiredHeight = height;
    }

    console.info(`[PlayerPip] setup: context=${!!context} (${context}), ctrl=${!!xComponentController}, w=${width}, h=${height}`);
    const config: PiPWindow.PiPConfiguration = {
      context: context,
      componentController: xComponentController,
      templateType: PiPWindow.PiPTemplateType.VIDEO_PLAY,
      contentWidth: width > 0 ? width : 1920,
      contentHeight: height > 0 ? height : 1080
    };

    try {
      console.info(`[PlayerPip] 调用 PiPWindow.create 开始...`);
      const controller = await PiPWindow.create(config);
      if (this.isDestroyed) {
        console.info('[PlayerPip] PiPController 创建完成前实例已被销毁，立即关闭并释放');
        try {
          controller.setAutoStartEnabled(false);
          controller.stopPiP().catch((_e: Object) => {});
        } catch (_e) {}
        return false;
      }
      this.pipController = controller;
      this.bindEvents();
      console.info(`[PlayerPip] PiPController 创建成功, desiredAutoStart: ${this.desiredAutoStart}`);
      if (this.desiredAutoStart) {
        this.pipController.setAutoStartEnabled(true);
      }
      if (this.desiredWidth > 0 && this.desiredHeight > 0) {
        this.pipController.updateContentSize(this.desiredWidth, this.desiredHeight);
      }
      this.syncPlayStatus(this.desiredPlayStatus);
      return true;
    } catch (err) {
      const bErr = err as Record<string, Object>;
      console.error(`[PlayerPip] PiP create 失败: code=${bErr['code']}, msg=${bErr['message']}, stack=${bErr['stack']}`);
      return false;
    }
  }

  /**
   * 开启或关闭退后台自动切画中画
   */
  setAutoStart(enable: boolean): void {
    if (this.desiredAutoStart === enable && this.pipController !== null) {
      return;
    }
    this.desiredAutoStart = enable;
    if (!this.pipController) {
      console.info(`[PlayerPip] setAutoStart 暂存状态: ${enable} (pipController 正在创建中)`);
      return;
    }
    try {
      this.pipController.setAutoStartEnabled(enable);
      console.info(`[PlayerPip] setAutoStartEnabled(${enable}) 执行成功`);
    } catch (err) {
      console.error(`[PlayerPip] setAutoStartEnabled 失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 动态刷新画中画小窗宽高比
   */
  updateSize(width: number, height: number): void {
    if (width > 0 && height > 0) {
      this.desiredWidth = width;
      this.desiredHeight = height;
    }
    if (!this.pipController || width <= 0 || height <= 0) {
      return;
    }
    try {
      this.pipController.updateContentSize(width, height);
    } catch (err) {
      console.error(`[PlayerPip] updateContentSize 失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 同步播放状态到小窗控件图标
   */
  syncPlayStatus(isPlaying: boolean): void {
    this.desiredPlayStatus = isPlaying;
    if (!this.pipController) {
      return;
    }
    try {
      const status = isPlaying ? PiPWindow.PiPControlStatus.PLAY : PiPWindow.PiPControlStatus.PAUSE;
      this.pipController.updatePiPControlStatus(PiPWindow.PiPControlType.VIDEO_PLAY_PAUSE, status);
    } catch (err) {
      console.error(`[PlayerPip] syncPlayStatus 失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 动态控制系统控制栏指定按钮的可用状态
   */
  updateControlEnabled(controlType: PiPWindow.PiPControlType, enabled: boolean): void {
    if (!this.pipController) {
      return;
    }
    try {
      this.pipController.setPiPControlEnabled(controlType, enabled);
    } catch (_e) {}
  }

  /**
   * 手动开启画中画
   */
  async start(): Promise<void> {
    if (!this.pipController) {
      console.warn('[PlayerPip] startPiP 失败: pipController 未初始化');
      throw new Error('画中画未就绪');
    }
    try {
      await this.pipController.startPiP();
    } catch (err) {
      console.error(`[PlayerPip] startPiP 失败: ${JSON.stringify(err)}`);
      throw err as Error;
    }
  }

  /**
   * 手动停止画中画
   */
  async stop(): Promise<void> {
    if (!this.pipController) {
      return;
    }
    try {
      await this.pipController.stopPiP();
    } catch (err) {
      console.error(`[PlayerPip] stopPiP 失败: ${JSON.stringify(err)}`);
    }
  }

  private bindEvents(): void {
    if (!this.pipController) {
      return;
    }

    // 1. 画中画生命周期监听
    this.pipController.on('stateChange', (state: PiPWindow.PiPState, reason: string) => {
      console.info(`[PlayerPip] stateChange: state=${state}, reason=${reason}`);
      switch (state) {
        case PiPWindow.PiPState.ABOUT_TO_START:
          this.isPipActive = true;
          if (this.desiredPlayStatus) {
            this.startContinuousTask();
          }
          this.delegate?.onPipActiveChanged?.(true);
          break;
        case PiPWindow.PiPState.STARTED:
          this.isPipActive = true;
          this.delegate?.onPipActiveChanged?.(true);
          break;
        case PiPWindow.PiPState.ABOUT_TO_RESTORE:
          this.isPipActive = false;
          this.delegate?.onPipActiveChanged?.(false);
          this.delegate?.onRestore?.();
          break;
        case PiPWindow.PiPState.STOPPED:
          this.isPipActive = false;
          this.stopContinuousTask();
          this.delegate?.onPipActiveChanged?.(false);
          this.delegate?.onClosed?.();
          break;
        case PiPWindow.PiPState.ERROR:
          this.isPipActive = false;
          this.stopContinuousTask();
          this.delegate?.onPipActiveChanged?.(false);
          this.delegate?.onClosed?.();
          break;
      }
    });

    // 2. 画中画系统控制栏操作事件监听
    this.pipController.on('controlPanelActionEvent', (event: PiPWindow.PiPActionEventType, status?: number) => {
      console.info(`[PlayerPip] controlPanelActionEvent: event=${event}, status=${status}`);
      switch (event) {
        case 'playbackStateChanged':
          const willPlay = status === 1;
          if (willPlay) {
            this.startContinuousTask();
          }
          this.delegate?.onPlayStateChanged(willPlay);
          this.syncPlayStatus(willPlay);
          break;
        case 'fastForward':
          this.delegate?.onFastForward?.();
          break;
        case 'fastBackward':
          this.delegate?.onFastBackward?.();
          break;
        case 'nextVideo':
          this.delegate?.onNext?.();
          break;
        case 'previousVideo':
          this.delegate?.onPrev?.();
          break;
      }
    });
  }

  private async startContinuousTask(): Promise<void> {
    if (!this.context || this.continuousTaskActive) {
      return;
    }
    try {
      const bundleName = this.context.abilityInfo?.bundleName || this.context.applicationInfo?.name || 'com.ecohub.spark';
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: bundleName,
          abilityName: 'EntryAbility'
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent = await wantAgent.getWantAgent(wantAgentInfo);
      await backgroundTaskManager.startBackgroundRunning(
        this.context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        agent
      );
      this.continuousTaskActive = true;
      console.info('[PlayerPip] 成功申请后台长时任务 (AUDIO_PLAYBACK)');
    } catch (err) {
      console.error(`[PlayerPip] startBackgroundRunning 异常: ${JSON.stringify(err)}`);
    }
  }

  private async stopContinuousTask(): Promise<void> {
    if (!this.context || !this.continuousTaskActive) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(this.context);
      this.continuousTaskActive = false;
      console.info('[PlayerPip] 已释放后台长时任务');
    } catch (err) {
      console.error(`[PlayerPip] stopBackgroundRunning 异常: ${JSON.stringify(err)}`);
    }
  }

  destroy(): void {
    this.isDestroyed = true;
    this.setAutoStart(false);
    if (this.pipController) {
      try {
        if (this.isPipActive) {
          this.pipController.stopPiP().catch((_e: Object) => {});
        }
        this.pipController.off('stateChange');
        this.pipController.off('controlPanelActionEvent');
      } catch (_e) {}
      this.pipController = null;
    }
    this.isPipActive = false;
    this.stopContinuousTask();
    this.context = null;
    this.delegate = null;
  }
}
