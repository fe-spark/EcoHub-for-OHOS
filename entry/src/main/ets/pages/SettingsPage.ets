import { AppTheme } from '../common/constants/AppTheme';
import { PageHeader } from '../components/common/PageHeader';
import { AppIcon } from '../components/common/AppIcon';
import { WindowBar } from '../common/utils/WindowBar';
import { AppSettingsManager } from '../services/AppSettingsManager';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct SettingsPage {
  @StorageLink('SETTING_PIP_AUTO_START') private pipAutoStart: boolean = true;
  @StorageLink('SETTING_AUTO_PLAY_NEXT') private autoPlayNext: boolean = true;
  @StorageLink('SETTING_CLIPBOARD_SNIFFER') private clipboardSniffer: boolean = true;
  @State private cacheSize: string = '0.0 MB';
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  @State private leftInset: number = 0;
  @State private rightInset: number = 0;

  aboutToAppear(): void {
    const ctx = this.getContextSafe();
    if (ctx) {
      WindowBar.apply(ctx, (top: number, bottom: number, left: number, right: number) => {
        this.topInset = top;
        this.bottomInset = bottom;
        this.leftInset = left;
        this.rightInset = right;
      });
    }
    this.refreshCacheSize();
  }

  onPageShow(): void {
    this.refreshCacheSize();
  }

  private getContextSafe(): common.UIAbilityContext | undefined {
    try {
      const c = getContext(this) as common.UIAbilityContext;
      if (c) {
        return c;
      }
    } catch (_e) {}
    try {
      return this.getUIContext().getHostContext() as common.UIAbilityContext;
    } catch (_e) {
      return undefined;
    }
  }

  private async refreshCacheSize(): Promise<void> {
    try {
      const ctx = this.getContextSafe();
      const size = await AppSettingsManager.getInstance().getCacheSize(ctx);
      this.cacheSize = size;
      console.info(`[SettingsPage] refreshCacheSize updated: ${size}`);
    } catch (err) {
      console.error('[SettingsPage] refreshCacheSize error:', JSON.stringify(err));
      this.cacheSize = '0.0 MB';
    }
  }

  private handleClearCache(): void {
    this.getUIContext().showAlertDialog({
      title: '清理本地缓存',
      message: '确定清理本地缓存吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清理',
        fontColor: AppTheme.ACCENT,
        action: () => {
          (async () => {
            try {
              const ctx = this.getContextSafe();
              await AppSettingsManager.getInstance().clearCache(ctx);
              await this.refreshCacheSize();
              this.getUIContext().getPromptAction().showToast({ message: '缓存已清理' });
            } catch (_e) {}
          })();
        }
      }
    });
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppTheme.TEXT_MUTED)
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })
  }

  @Builder
  cardDivider() {
    Divider()
      .color('rgba(255, 255, 255, 0.06)')
      .margin({ left: 16, right: 16 })
  }

  build() {
    Column() {
      PageHeader({ title: '设置' })

      Scroll() {
        Column({ space: 14 }) {
          // 1. 播放
          Column() {
            this.sectionTitle('播放')

            Column() {
              // 1.1 回到桌面画中画
              Row() {
                Column({ space: 4 }) {
                  Text('回到桌面开启画中画')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.TEXT_PRIMARY)
                  Text('返回桌面时自动开启小窗悬浮')
                    .fontSize(12)
                    .fontColor(AppTheme.TEXT_MUTED)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ right: 12 })

                Toggle({ type: ToggleType.Switch, isOn: this.pipAutoStart })
                  .selectedColor(AppTheme.ACCENT)
                  .switchPointColor(Color.White)
                  .onChange((isOn: boolean) => {
                    AppSettingsManager.getInstance().setPipAutoStart(isOn);
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .alignItems(VerticalAlign.Center)

              this.cardDivider()

              // 1.2 自动连播下一集
              Row() {
                Column({ space: 4 }) {
                  Text('自动连播下一集')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.TEXT_PRIMARY)
                  Text('当前视频播完后自动播放下一集')
                    .fontSize(12)
                    .fontColor(AppTheme.TEXT_MUTED)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ right: 12 })

                Toggle({ type: ToggleType.Switch, isOn: this.autoPlayNext })
                  .selectedColor(AppTheme.ACCENT)
                  .switchPointColor(Color.White)
                  .onChange((isOn: boolean) => {
                    AppSettingsManager.getInstance().setAutoPlayNext(isOn);
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .alignItems(VerticalAlign.Center)
            }
            .backgroundColor(AppTheme.BG_ELEVATED)
            .borderRadius(AppTheme.RADIUS_LG)
            .clip(true)
            .border({ width: 0.5, color: 'rgba(255, 255, 255, 0.08)' })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 2. 通用
          Column() {
            this.sectionTitle('通用')

            Column() {
              // 2.1 剪贴板识别
              Row() {
                Column({ space: 4 }) {
                  Text('剪贴板链接自动识别')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.TEXT_PRIMARY)
                  Text('自动检测剪贴板中的视频链接')
                    .fontSize(12)
                    .fontColor(AppTheme.TEXT_MUTED)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ right: 12 })

                Toggle({ type: ToggleType.Switch, isOn: this.clipboardSniffer })
                  .selectedColor(AppTheme.ACCENT)
                  .switchPointColor(Color.White)
                  .onChange((isOn: boolean) => {
                    AppSettingsManager.getInstance().setClipboardSniffer(isOn);
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .alignItems(VerticalAlign.Center)

              this.cardDivider()

              // 2.2 清理缓存
              Row() {
                Column({ space: 4 }) {
                  Text('清理本地缓存')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.TEXT_PRIMARY)
                  Text('清理图片与临时网络数据')
                    .fontSize(12)
                    .fontColor(AppTheme.TEXT_MUTED)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ right: 12 })

                Text(this.cacheSize)
                  .fontSize(14)
                  .fontColor(AppTheme.TEXT_MUTED)
                  .margin({ right: 6 })

                AppIcon({
                  src: $r('sys.symbol.chevron_right'),
                  iconSize: 14,
                  color: AppTheme.TEXT_MUTED
                })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .alignItems(VerticalAlign.Center)
              .onClick(() => this.handleClearCache())
            }
            .backgroundColor(AppTheme.BG_ELEVATED)
            .borderRadius(AppTheme.RADIUS_LG)
            .clip(true)
            .border({ width: 0.5, color: 'rgba(255, 255, 255, 0.08)' })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.CONTENT_MAX_WIDTH })
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor(AppTheme.BG)
    .padding({
      top: this.topInset,
      bottom: this.bottomInset,
      left: this.leftInset,
      right: this.rightInset
    })
  }
}
