import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { common } from '@kit.AbilityKit';
import { ServerConfigManager } from '../common/utils/ServerConfigManager';
import { HttpClient } from '../common/network/HttpClient';
import { FilmApi } from '../api/FilmApi';
import { AppTheme } from '../common/constants/AppTheme';
import { WindowBar } from '../common/utils/WindowBar';

@Entry
@Component
struct SplashPage {
  @State private statusText: string = '正在接入服务...';
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;

  async aboutToAppear() {
    WindowBar.apply(getContext(this) as common.UIAbilityContext, (top: number, bottom: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
    });
    this.checkAndBootstrap();
  }

  private async checkAndBootstrap(): Promise<void> {
    const startTime = Date.now();
    const MIN_SPLASH_TIME = 800;

    const url = await ServerConfigManager.getInstance().getServerUrl();

    // 1. 无源拦截：未配置软件源，直接前往配置页
    if (!url || !url.trim()) {
      await this.ensureMinTime(startTime, MIN_SPLASH_TIME);
      promptAction.showToast({ message: '请先配置软件源' });
      router.replaceUrl({ url: 'pages/ServerConfigPage' });
      return;
    }

    // 2. 有源校验：发起探活
    this.statusText = '正在检测软件源连通性...';
    const isHealthy = await HttpClient.getInstance().testConnection(url);

    await this.ensureMinTime(startTime, MIN_SPLASH_TIME);

    if (isHealthy) {
      // 3. 探活成功：预拉取站点配置并秒开进入主页
      try {
        await FilmApi.getSiteConfig(true);
      } catch (_e) {
      }
      router.replaceUrl({ url: 'pages/Index' });
    } else {
      // 4. 源报错 / 断网拦截：强制拦截至配置页，提示错误
      promptAction.showToast({ message: '软件源连接失败，请检查网络或重新配置' });
      router.replaceUrl({
        url: 'pages/ServerConfigPage',
        params: { mode: 'reconnect' }
      });
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
