import { common } from '@kit.AbilityKit';
import { ServerConfigManager } from '../common/utils/ServerConfigManager';
import { FilmApi } from '../api/FilmApi';
import { AppTheme } from '../common/constants/AppTheme';
import { WindowBar } from '../common/utils/WindowBar';
import { AppVersionUtil, AppUpdateInfo } from '../common/utils/AppVersionUtil';
import { VersionUpdateDialog } from '../components/VersionUpdateDialog';
import { BasicConfig } from '../model/FilmModels';

const MIN_SPLASH_TIME = 800;
const PROBE_ATTEMPTS = 3;
const PROBE_TIMEOUT_MS = 5000;

@Entry
@Component
struct SplashPage {
  @State private statusText: string = '正在接入服务...';
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  @State private leftInset: number = 0;
  @State private rightInset: number = 0;
  @State private showUpdateDialog: boolean = false;
  @State private updateInfo: AppUpdateInfo = {
    currentVersion: '',
    latestVersion: '',
    hasUpdate: false,
    releaseName: '',
    releaseNotes: '',
    releaseUrl: '',
    downloadUrl: ''
  };
  private updateCheckPromise: Promise<AppUpdateInfo | null> | null = null;

  async aboutToAppear() {
    AppStorage.setOrCreate('UI_CONTEXT', this.getUIContext());
    WindowBar.apply(this.getUIContext().getHostContext() as common.UIAbilityContext, (top: number, bottom: number, left: number, right: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
      this.leftInset = left;
      this.rightInset = right;
    });
    this.startBootstrapPipeline();
  }

  private async startBootstrapPipeline(): Promise<void> {
    const startTime = Date.now();
    this.statusText = '正在接入服务...';

    // 步骤 1: 异步并行启动版本检查（弱依赖，不阻塞开屏冷启动流水线）
    this.updateCheckPromise = AppVersionUtil.checkUpdate(false, 2500).catch(() => null);

    // 步骤 2: 继续软件源连通性检测与开屏流水线
    await this.continueSourceAndNoticePipeline(startTime);
  }

  private onUpdateDialogDismiss(): void {
    this.showUpdateDialog = false;
    this.updateCheckPromise = null;
    this.navigateToIndex();
  }

  private async continueSourceAndNoticePipeline(startTime: number = Date.now()): Promise<void> {
    const url = await ServerConfigManager.getInstance().getServerUrl();

    // 步骤 2: 检查是否已配置软件源
    if (!url || !url.trim()) {
      await this.ensureMinTime(startTime, MIN_SPLASH_TIME);
      try {
        this.getUIContext().getPromptAction().showToast({ message: '请先配置软件源' });
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/ServerConfigPage' });
      } catch (_e) {
      }
      return;
    }

    // 步骤 3: 连通性检测（最多重试 3 次，单次 5s）
    this.statusText = '正在检测软件源连通性...';
    let ok = false;
    let siteConfig: BasicConfig | null = null;
    for (let i = 0; i < PROBE_ATTEMPTS; i++) {
      if (i > 0) {
        this.statusText = `正在重试软件源连通性 (${i + 1}/${PROBE_ATTEMPTS})...`;
      }
      try {
        siteConfig = await FilmApi.getSiteConfig(true, PROBE_TIMEOUT_MS);
        ok = true;
        break;
      } catch (_e) {
      }
    }

    await this.ensureMinTime(startTime, MIN_SPLASH_TIME);

    if (!ok || !siteConfig) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '软件源连接失败，请检查网络或重新配置' });
        this.getUIContext().getRouter().replaceUrl({
          url: 'pages/ServerConfigPage',
          params: { mode: 'reconnect' }
        });
      } catch (_e) {
      }
      return;
    }

    // 步骤 4: 检查在开屏耗时内已就绪的 App 版本更新（零等待，未就绪则在主页后台静默更新红点）
    if (this.updateCheckPromise) {
      const fastUpdate = await Promise.race([
        this.updateCheckPromise,
        new Promise<null>((resolve) => setTimeout(() => resolve(null), 50))
      ]);
      if (fastUpdate && fastUpdate.hasUpdate) {
        this.updateInfo = fastUpdate;
        this.showUpdateDialog = true;
        return;
      }
    }

    // 步骤 5: 连通成功极速切入主页（公告统一由主页 Index 接管展示，避免关闭弹窗露底闪屏）
    this.navigateToIndex();
  }

  private navigateToIndex(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
    } catch (_e) {
    }
  }

  private async ensureMinTime(startTime: number, minTime: number): Promise<void> {
    const elapsed = Date.now() - startTime;
    if (elapsed < minTime) {
      await new Promise<void>((resolve) => setTimeout(resolve, minTime - elapsed));
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Image($r('app.media.startIcon'))
          .width(84)
          .height(84)
          .borderRadius(20)
          .clip(true)

        Text('EcoHub')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .margin({ top: 16 })

        Row({ space: 8 }) {
          LoadingProgress()
            .color(AppTheme.ACCENT)
            .width(18)
            .height(18)
          Text(this.statusText)
            .fontSize(12)
            .fontColor(AppTheme.TEXT_MUTED)
        }
        .margin({ top: 24 })
      }
      .justifyContent(FlexAlign.Center)

      if (this.showUpdateDialog) {
        VersionUpdateDialog({
          updateInfo: this.updateInfo,
          onClose: () => {
            this.onUpdateDialogDismiss();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.topInset,
      bottom: this.bottomInset,
      left: this.leftInset,
      right: this.rightInset
    })
    .backgroundColor(AppTheme.BG)
  }
}
