import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { ServerConfigManager } from '../common/utils/ServerConfigManager';
import { HttpClient } from '../common/network/HttpClient';
import { FilmApi } from '../api/FilmApi';
import { AppTheme } from '../common/constants/AppTheme';
import { WindowBar } from '../common/utils/WindowBar';
import { NavUtil } from '../common/utils/NavUtil';
import { SourceGuard } from '../common/utils/SourceGuard';
import { common } from '@kit.AbilityKit';
import { AppIcon } from '../components/AppIcon';
import { SiteHeartbeat } from '../common/utils/SiteHeartbeat';

@Entry
@Component
struct ServerConfigPage {
  @State serverUrl: string = '';
  @State isLoading: boolean = false;
  @State private reconnect: boolean = false;
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;

  async aboutToAppear() {
    WindowBar.apply(getContext(this) as common.UIAbilityContext, (top: number, bottom: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
    });
    const params = router.getParams() as Object;
    this.reconnect = NavUtil.param(params, 'mode') === 'reconnect';
    this.serverUrl = await ServerConfigManager.getInstance().getServerUrl();
  }

  aboutToDisappear(): void {
    SourceGuard.markClosed();
  }

  onBackPress(): boolean {
    return this.reconnect;
  }

  private async saveAndConnect() {
    if (!this.serverUrl.trim()) {
      promptAction.showToast({ message: '请输入软件源地址' });
      return;
    }
    this.isLoading = true;
    const ok = await HttpClient.getInstance().testConnection(this.serverUrl);
    this.isLoading = false;
    if (!ok) {
      promptAction.showToast({ message: '无法连接该源，请检查地址' });
      return;
    }
    await ServerConfigManager.getInstance().setServerUrl(this.serverUrl);
    FilmApi.clearSiteConfig();
    SiteHeartbeat.getInstance().resetFailures();
    if (this.reconnect) {
      promptAction.showToast({ message: '已重新接入' });
      SourceGuard.markClosed();
      router.back();
      SourceGuard.notifyReconnected();
      return;
    }
    promptAction.showToast({ message: '源已接入' });
    SourceGuard.notifyReconnected();
    router.replaceUrl({ url: 'pages/Index' });
  }

  build() {
    Column() {
      Blank().height(72)

      Column() {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(72)
            .height(72)
            .borderRadius(AppTheme.RADIUS_LG)
            .backgroundColor(AppTheme.ACCENT)
          AppIcon({ src: $r('sys.symbol.play_fill'), iconSize: 32, color: AppTheme.TEXT_PRIMARY })
        }

        Text('EcoHub')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .margin({ top: 16 })

        Text(this.reconnect ? '软件源连接失败，请检查后重新接入' : '配置软件源后即可观影')
          .fontSize(14)
          .fontColor(AppTheme.TEXT_SECONDARY)
          .margin({ top: 8 })
      }
      .margin({ bottom: 40 })

      Column() {
        Text('软件源地址')
          .fontSize(13)
          .fontColor(AppTheme.TEXT_SECONDARY)
          .width('100%')
          .margin({ bottom: 8 })

        Row() {
          AppIcon({ src: $r('sys.symbol.link'), iconSize: 18, color: AppTheme.TEXT_MUTED })
          TextInput({ text: this.serverUrl, placeholder: '请输入软件源地址' })
            .layoutWeight(1)
            .height(48)
            .fontSize(14)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .placeholderColor(AppTheme.TEXT_MUTED)
            .caretColor(AppTheme.ACCENT)
            .backgroundColor(Color.Transparent)
            .padding({ left: 8, right: 8 })
            .onChange((val: string) => {
              this.serverUrl = val;
            })
        }
        .width('100%')
        .height(48)
        .padding({ left: 12, right: 12 })
        .backgroundColor(AppTheme.BG_CARD)
        .borderRadius(AppTheme.RADIUS_MD)

        Button(this.isLoading ? '正在连接...' : (this.reconnect ? '重新接入' : '开始观影'))
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .backgroundColor(AppTheme.ACCENT)
          .borderRadius(AppTheme.RADIUS_MD)
          .margin({ top: 32 })
          .enabled(!this.isLoading)
          .onClick(() => this.saveAndConnect())
          .alignSelf(ItemAlign.Stretch)

        Text('接口形如 https://your-host/api，配置后所有请求均走该源。')
          .fontSize(12)
          .fontColor(AppTheme.TEXT_MUTED)
          .margin({ top: 16 })
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 24, right: 24 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topInset, bottom: this.bottomInset })
    .backgroundColor(AppTheme.BG)
  }
}
