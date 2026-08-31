import { common } from '@kit.AbilityKit';
import { ServerConfigManager } from '../common/utils/ServerConfigManager';
import { FilmApi } from '../api/FilmApi';
import { AppTheme } from '../common/constants/AppTheme';
import { WindowBar } from '../common/utils/WindowBar';

const MIN_SPLASH_TIME = 800;
const PROBE_ATTEMPTS = 3;
const PROBE_TIMEOUT_MS = 5000;

@Entry
@Component
struct SplashPage {
  @State private statusText: string = '正在接入服务...';
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;

  async aboutToAppear() {
    AppStorage.setOrCreate('UI_CONTEXT', this.getUIContext());
    WindowBar.apply(this.getUIContext().getHostContext() as common.UIAbilityContext, (top: number, bottom: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
    });
    this.checkAndBootstrap();
  }

  private async checkAndBootstrap(): Promise<void> {
    const startTime = Date.now();
    const url = await ServerConfigManager.getInstance().getServerUrl();

    if (!url || !url.trim()) {
      await this.ensureMinTime(startTime, MIN_SPLASH_TIME);
      try {
        this.getUIContext().getPromptAction().showToast({ message: '请先配置软件源' });
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/ServerConfigPage' });
      } catch (_e) {
      }
      return;
    }

    this.statusText = '正在检测软件源连通性...';
    let ok = false;
    for (let i = 0; i < PROBE_ATTEMPTS; i++) {
      if (i > 0) {
        this.statusText = `正在重试软件源连通性 (${i + 1}/${PROBE_ATTEMPTS})...`;
      }
      try {
        await FilmApi.getSiteConfig(true, PROBE_TIMEOUT_MS);
        ok = true;
        break;
      } catch (_e) {
      }
    }

    await this.ensureMinTime(startTime, MIN_SPLASH_TIME);

    if (ok) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
      } catch (_e) {
      }
    } else {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '软件源连接失败，请检查网络或重新配置' });
        this.getUIContext().getRouter().replaceUrl({
          url: 'pages/ServerConfigPage',
          params: { mode: 'reconnect' }
        });
      } catch (_e) {
      }
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
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topInset, bottom: this.bottomInset })
    .backgroundColor(AppTheme.BG)
  }
}
