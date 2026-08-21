import router from '@ohos.router';
import { FilmApi } from '../api/FilmApi';
import { BasicConfig } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { ServerConfigManager } from '../common/utils/ServerConfigManager';
import { AppIcon } from '../components/AppIcon';
import { SourceGuard } from '../common/utils/SourceGuard';

@Component
export struct ProfileTab {
  @State private config: BasicConfig = {
    siteName: 'EcoHub',
    siteUrl: '',
    logo: '',
    keyword: '',
    describe: '',
    state: true,
    hint: '',
    tipEnabled: false,
    tipTitle: '赞赏支持',
    tipMessage: '',
    tipChannels: []
  };
  @State private sourceUrl: string = '';
  private hasLoaded: boolean = false;
  private reconnectCb: () => void = () => {};

  async aboutToAppear() {
    this.reconnectCb = () => {
      this.reload();
    };
    SourceGuard.onReconnect(this.reconnectCb);
    if (this.hasLoaded) {
      return;
    }
    this.hasLoaded = true;
    await this.reload();
  }

  aboutToDisappear(): void {
    SourceGuard.offReconnect(this.reconnectCb);
  }

  private async reload(): Promise<void> {
    this.sourceUrl = await ServerConfigManager.getInstance().getServerUrl();
    try {
      this.config = await FilmApi.getSiteConfig(true);
    } catch (err) {
      console.error('load site config failed');
    }
  }

  private sourceHost(): string {
    if (!this.sourceUrl) {
      return '未配置';
    }
    let host = ServerConfigManager.stripApiSuffix(
      ServerConfigManager.getInstance().normalizeRaw(this.sourceUrl)
    );
    if (host.indexOf('https://') === 0) {
      host = host.substring(8);
    } else if (host.indexOf('http://') === 0) {
      host = host.substring(7);
    }
    return host || '未配置';
  }

  private logoLetter(): string {
    const name = this.config.siteName ? this.config.siteName : 'E';
    return name.substring(0, 1);
  }

  @Builder
  menuRow(icon: Resource, title: string) {
    Row() {
      Row() {
        AppIcon({ src: icon, iconSize: 18, color: AppTheme.ACCENT })
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.ACCENT_SOFT)
      .borderRadius(18)

      Text(title)
        .fontSize(15)
        .fontColor(AppTheme.TEXT_PRIMARY)
        .margin({ left: AppTheme.SPACE_MD })
        .layoutWeight(1)

      AppIcon({
        src: $r('sys.symbol.chevron_right'),
        iconSize: 14,
        color: AppTheme.TEXT_MUTED
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  menuLine() {
    Row() {
      Blank().width(64)
      Column()
        .layoutWeight(1)
        .height(0.5)
        .backgroundColor(AppTheme.BORDER)
    }
    .width('100%')
  }

  build() {
    Column() {
      Row() {
        AppIcon({ src: $r('sys.symbol.person_fill'), iconSize: 22, color: AppTheme.ACCENT })
        Text('我的')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .margin({ left: AppTheme.SPACE_SM })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ top: AppTheme.SPACE_SM, bottom: AppTheme.SPACE_LG })

      Row() {
        if (this.config.logo) {
          Image(ServerConfigManager.getInstance().resolveMediaUrl(this.config.logo))
            .width(56)
            .height(56)
            .objectFit(ImageFit.Cover)
            .borderRadius(AppTheme.RADIUS_LG)
            .backgroundColor(AppTheme.BG_CARD)
        } else {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(56)
              .height(56)
              .borderRadius(AppTheme.RADIUS_LG)
              .backgroundColor(AppTheme.ACCENT)
            Text(this.logoLetter())
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT_PRIMARY)
          }
        }

        Column() {
          Text(this.config.siteName)
            .width('100%')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('当前软件源')
            .width('100%')
            .fontSize(12)
            .fontColor(AppTheme.TEXT_SECONDARY)
            .margin({ top: AppTheme.SPACE_XS })
          Text(this.sourceHost())
            .width('100%')
            .fontSize(13)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .margin({ top: AppTheme.SPACE_XS })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .constraintSize({ minWidth: 0 })
        .margin({ left: AppTheme.SPACE_MD, right: AppTheme.SPACE_SM })

        AppIcon({
          src: $r('sys.symbol.chevron_right'),
          iconSize: 16,
          color: AppTheme.TEXT_SECONDARY
        })
      }
      .width('100%')
      .padding(AppTheme.SPACE_LG)
      .alignItems(VerticalAlign.Center)
      .clip(true)
      .linearGradient({
        angle: 135,
        colors: [['rgba(250, 140, 22, 0.28)', 0], [AppTheme.BG_CARD, 1]]
      })
      .borderRadius(AppTheme.RADIUS_LG)
      .margin({ bottom: AppTheme.SPACE_LG })
      .onClick(() => {
        router.pushUrl({ url: 'pages/ServerConfigPage' });
      })

      Column() {
        Column() {
          this.menuRow($r('sys.symbol.clock_fill'), '观看历史')
        }
        .onClick(() => {
          router.pushUrl({ url: 'pages/HistoryPage' });
        })
        this.menuLine()
        Column() {
          this.menuRow($r('sys.symbol.play_circle_fill'), '自定义播放')
        }
        .onClick(() => {
          router.pushUrl({ url: 'pages/CustomPlayerPage' });
        })
        if (this.config.tipEnabled) {
          this.menuLine()
          Column() {
            this.menuRow($r('sys.symbol.gift'), this.config.tipTitle || '赞赏支持')
          }
          .onClick(() => {
            router.pushUrl({ url: 'pages/TipPage' });
          })
        }
      }
      .width('100%')
      .backgroundColor(AppTheme.BG_ELEVATED)
      .borderRadius(AppTheme.RADIUS_LG)
      .clip(true)
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.BG)
  }
}
