import { FilmApi } from '../api/FilmApi';
import { BasicConfig, TipChannel } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { ServerConfigManager } from '../common/utils/ServerConfigManager';
import { WindowBar } from '../common/utils/WindowBar';
import { common } from '@kit.AbilityKit';
import { PageHeader } from '../components/PageHeader';
import { EmptyState } from '../components/EmptyState';
import { LoadingView } from '../components/LoadingView';
import { SourceGuard } from '../common/utils/SourceGuard';

@Component
struct TipQrImage {
  @Prop @Watch('onSrcChange') src: string = '';
  @State private loaded: boolean = false;
  @State private failed: boolean = false;

  onSrcChange(): void {
    this.loaded = false;
    this.failed = false;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (!this.loaded && !this.failed) {
        LoadingProgress()
          .width(32)
          .height(32)
          .color(AppTheme.ACCENT)
      }
      if (this.failed) {
        Text('图片加载失败')
          .fontSize(12)
          .fontColor(AppTheme.TEXT_MUTED)
      } else if (this.src) {
        Image(this.src)
          .width(200)
          .height(200)
          .objectFit(ImageFit.Contain)
          .opacity(this.loaded ? 1 : 0)
          .animation({ duration: 220, curve: Curve.EaseOut })
          .onComplete(() => {
            this.loaded = true;
          })
          .onError(() => {
            this.failed = true;
          })
      }
    }
    .width(200)
    .height(200)
    .backgroundColor(AppTheme.TEXT_PRIMARY)
    .borderRadius(AppTheme.RADIUS_MD)
    .clip(true)
  }
}

@Entry
@Component
struct TipPage {
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
    tipChannels: [],
    noticeEnabled: false,
    noticeTitle: '站点公告',
    noticeContent: '',
    noticeVersion: '1'
  };

  @State private loading: boolean = true;
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  private reconnectCb: () => void = () => {};

  private applyWindowBar(): void {
    WindowBar.apply(this.getUIContext().getHostContext() as common.UIAbilityContext, (top: number, bottom: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
    });
  }

  async aboutToAppear() {
    this.applyWindowBar();
    this.reconnectCb = () => {
      this.loadConfig();
    };
    SourceGuard.onReconnect(this.reconnectCb);
    await this.loadConfig();
  }

  onPageShow(): void {
    this.applyWindowBar();
  }

  aboutToDisappear(): void {
    SourceGuard.offReconnect(this.reconnectCb);
  }

  private async loadConfig(): Promise<void> {
    this.loading = true;
    try {
      this.config = await FilmApi.getSiteConfig(false);
    } catch (err) {
      console.error('load tip config failed');
    }
    this.loading = false;
  }

  private visibleChannels(): TipChannel[] {
    const list: TipChannel[] = [];
    for (let i = 0; i < this.config.tipChannels.length; i++) {
      const item = this.config.tipChannels[i];
      if (item.qrImage || item.link) {
        list.push(item);
      }
    }
    return list;
  }

  build() {
    Column() {
      PageHeader({ title: this.config.tipTitle || '赞赏支持' })

      Text(this.config.tipMessage || '如果这个站对你有帮助，欢迎请作者喝杯咖啡')
        .fontSize(14)
        .fontColor(AppTheme.TEXT_SECONDARY)
        .padding({ left: 16, right: 16, top: 8, bottom: 16 })

      if (this.loading) {
        LoadingView({ label: '加载中' })
      } else if (this.visibleChannels().length === 0) {
        EmptyState({
          title: '暂未配置赞赏渠道',
          icon: $r('sys.symbol.gift')
        })
      } else {
        List({ space: 24 }) {
          ForEach(this.visibleChannels(), (item: TipChannel) => {
            ListItem() {
              Column() {
                Text(item.label)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT_PRIMARY)
                  .margin({ bottom: 12 })
                if (item.qrImage) {
                  TipQrImage({ src: ServerConfigManager.getInstance().resolveMediaUrl(item.qrImage) })
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
            }
          }, (item: TipChannel) => item.key)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topInset, bottom: this.bottomInset })
    .backgroundColor(AppTheme.BG)
  }
}
