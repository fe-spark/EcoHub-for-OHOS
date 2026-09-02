import { ServerConfigManager } from '../common/utils/ServerConfigManager';
import { HttpClient } from '../common/network/HttpClient';
import { FilmApi } from '../api/FilmApi';
import { AppTheme } from '../common/constants/AppTheme';
import { WindowBar } from '../common/utils/WindowBar';
import { NavUtil } from '../common/utils/NavUtil';
import { SourceGuard } from '../common/utils/SourceGuard';
import { common } from '@kit.AbilityKit';
import { AppIcon } from '../components/AppIcon';
import { BackIcon } from '../components/BackIcon';
import { SiteHeartbeat } from '../common/utils/SiteHeartbeat';

@Entry
@Component
struct ServerConfigPage {
  @State serverUrl: string = '';
  @State isLoading: boolean = false;
  @State private reconnect: boolean = false;
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  @State private serverHistory: string[] = [];
  @State private showHistoryDialog: boolean = false;
  private inputController: TextInputController = new TextInputController();
  private lastBackPressTime: number = 0;

  private applyWindowBar(): void {
    WindowBar.apply(this.getUIContext().getHostContext() as common.UIAbilityContext, (top: number, bottom: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
    });
  }

  async aboutToAppear() {
    this.applyWindowBar();
    const params = this.getUIContext().getRouter().getParams() as Object;
    this.reconnect = NavUtil.param(params, 'mode') === 'reconnect';
    this.serverUrl = await ServerConfigManager.getInstance().getServerUrl();
    await this.loadHistory();
  }

  onPageShow(): void {
    this.applyWindowBar();
  }

  aboutToDisappear(): void {
    SourceGuard.markClosed();
  }

  onBackPress(): boolean {
    if (this.showHistoryDialog) {
      this.showHistoryDialog = false;
      return true;
    }
    if (this.reconnect) {
      const now = Date.now();
      if (now - this.lastBackPressTime < 2000) {
        try {
          const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
          ctx.terminateSelf();
        } catch (_e) {
        }
        return false;
      }
      this.lastBackPressTime = now;
      try {
        this.getUIContext().getPromptAction().showToast({ message: '再按一次退出应用' });
      } catch (_e) {
      }
      return true;
    }
    return false;
  }

  private async loadHistory(): Promise<void> {
    this.serverHistory = await ServerConfigManager.getInstance().getServerHistory();
  }

  private confirmClearHistory(): void {
    this.getUIContext().showAlertDialog({
      title: '清空历史软件源',
      message: '确定要清空全部历史软件源记录吗？',
      primaryButton: {
        value: '清空',
        fontColor: AppTheme.DANGER,
        action: () => {
          ServerConfigManager.getInstance().clearServerHistory().then(() => {
            this.serverHistory = [];
            try {
              this.getUIContext().getPromptAction().showToast({ message: '已清空历史软件源' });
            } catch (_e) {
            }
          });
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }

  private async saveAndConnect() {
    this.showHistoryDialog = false;
    try {
      this.inputController.stopEditing();
    } catch (_e) {
    }
    if (!this.serverUrl.trim()) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '请输入软件源地址' });
      } catch (_e) {
      }
      return;
    }
    this.isLoading = true;
    const ok = await HttpClient.getInstance().testConnection(this.serverUrl);
    this.isLoading = false;
    if (!ok) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '无法连接该源，请检查地址' });
      } catch (_e) {
      }
      return;
    }
    await ServerConfigManager.getInstance().setServerUrl(this.serverUrl);
    await this.loadHistory();
    FilmApi.clearSiteConfig();
    SiteHeartbeat.getInstance().resetFailures();
    AppStorage.setOrCreate<number>('SOURCE_EPOCH', Date.now());
    SourceGuard.markClosed();
    SourceGuard.notifyReconnected();

    try {
      this.getUIContext().getPromptAction().showToast({ message: this.reconnect ? '已重新接入' : '源已接入' });
    } catch (_e) {
    }

    const r = this.getUIContext().getRouter();
    try {
      r.clear();
    } catch (_e) {
    }
    try {
      r.replaceUrl({ url: 'pages/Index' });
    } catch (_e) {
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // Main Page Content
      Column() {
        // Top header with back button if not in forced reconnect mode
        Row() {
          if (!this.reconnect) {
            BackIcon({ color: AppTheme.TEXT_PRIMARY })
              .onClick(() => {
                try {
                  this.getUIContext().getRouter().back();
                } catch (_e) {
                }
              })
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: 12, right: 16 })
        .alignItems(VerticalAlign.Center)

        Blank().height(24)

        Column() {
          Image($r('app.media.startIcon'))
            .width(72)
            .height(72)
            .borderRadius(AppTheme.RADIUS_LG)
            .clip(true)

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
        .margin({ bottom: 32 })

        Column() {
          Row() {
            Text('软件源地址')
              .fontSize(13)
              .fontColor(AppTheme.TEXT_SECONDARY)

            if (this.serverHistory.length > 0) {
              Row() {
                AppIcon({
                  src: $r('sys.symbol.clock_fill'),
                  iconSize: 12,
                  color: AppTheme.ACCENT
                })
                Text(`历史记录 (${this.serverHistory.length})`)
                  .fontSize(12)
                  .fontColor(AppTheme.ACCENT)
                  .margin({ left: 4 })
              }
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(AppTheme.ACCENT_SOFT)
              .borderRadius(AppTheme.RADIUS_SM)
              .onClick(() => {
                try {
                  this.inputController.stopEditing();
                } catch (_e) {
                }
                this.showHistoryDialog = true;
              })
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 8 })

          // Input row
          Row() {
            TextInput({ text: this.serverUrl, placeholder: '请输入软件源地址', controller: this.inputController })
              .layoutWeight(1)
              .height(48)
              .fontSize(14)
              .fontColor(AppTheme.TEXT_PRIMARY)
              .placeholderColor(AppTheme.TEXT_MUTED)
              .caretColor(AppTheme.ACCENT)
              .backgroundColor(Color.Transparent)
              .padding({ left: 14, right: 8 })
              .enterKeyType(EnterKeyType.Done)
              .onChange((val: string) => {
                this.serverUrl = val;
              })
              .onSubmit(() => {
                this.saveAndConnect();
              })

            if (this.serverUrl.length > 0) {
              Row() {
                AppIcon({
                  src: $r('sys.symbol.xmark_circle_fill'),
                  iconSize: 16,
                  color: AppTheme.TEXT_MUTED
                })
              }
              .width(36)
              .height(48)
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                this.serverUrl = '';
              })
            }
          }
          .width('100%')
          .height(48)
          .padding({ right: 4 })
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
            .margin({ top: 28 })
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

      // Modal Dialog Layer (Overlay Backdrop + Centered Dialog Box)
      if (this.showHistoryDialog) {
        // Dimmed backdrop
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.72)')
          .onClick(() => {
            this.showHistoryDialog = false;
          })

        // Centered Modal Box
        Column() {
          // Dialog Header
          Row() {
            Row() {
              AppIcon({ src: $r('sys.symbol.clock_fill'), iconSize: 16, color: AppTheme.ACCENT })
              Text('历史软件源')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.TEXT_PRIMARY)
                .margin({ left: 6 })
            }

            Row() {
              if (this.serverHistory.length > 0) {
                Row() {
                  AppIcon({ src: $r('sys.symbol.trash'), iconSize: 12, color: AppTheme.DANGER })
                  Text('清空')
                    .fontSize(12)
                    .fontColor(AppTheme.DANGER)
                    .margin({ left: 3 })
                }
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(AppTheme.DANGER_SOFT)
                .borderRadius(AppTheme.RADIUS_SM)
                .margin({ right: 12 })
                .onClick(() => {
                  this.confirmClearHistory();
                })
              }

              Row() {
                AppIcon({ src: $r('sys.symbol.xmark'), iconSize: 14, color: AppTheme.TEXT_MUTED })
              }
              .width(28)
              .height(28)
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                this.showHistoryDialog = false;
              })
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(VerticalAlign.Center)
          .padding({ left: 16, right: 12, top: 16, bottom: 12 })

          // Dialog Body with Max Height & Internal Scroll
          if (this.serverHistory.length === 0) {
            Column() {
              Text('暂无历史记录')
                .fontSize(13)
                .fontColor(AppTheme.TEXT_MUTED)
            }
            .width('100%')
            .height(140)
            .justifyContent(FlexAlign.Center)
          } else {
            List({ space: 8 }) {
              ForEach(this.serverHistory, (item: string) => {
                ListItem() {
                  Row() {
                    // Clickable area to choose item
                    Row() {
                      AppIcon({
                        src: $r('sys.symbol.link'),
                        iconSize: 15,
                        color: item === this.serverUrl ? AppTheme.ACCENT : AppTheme.TEXT_MUTED
                      })

                      Text(item)
                        .fontSize(13)
                        .fontColor(item === this.serverUrl ? AppTheme.ACCENT : AppTheme.TEXT_PRIMARY)
                        .fontWeight(item === this.serverUrl ? FontWeight.Bold : FontWeight.Normal)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ left: 8 })
                        .layoutWeight(1)

                      if (item === this.serverUrl) {
                        Row() {
                          Text('当前')
                            .fontSize(10)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(AppTheme.ACCENT)
                        }
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .backgroundColor(AppTheme.ACCENT_SOFT)
                        .borderRadius(AppTheme.RADIUS_SM)
                        .margin({ left: 6, right: 4 })
                      }
                    }
                    .layoutWeight(1)
                    .alignItems(VerticalAlign.Center)
                    .onClick(() => {
                      this.serverUrl = item;
                      this.showHistoryDialog = false;
                    })

                    // Delete single history item button
                    Row() {
                      AppIcon({
                        src: $r('sys.symbol.trash'),
                        iconSize: 13,
                        color: AppTheme.TEXT_MUTED
                      })
                    }
                    .width(32)
                    .height(36)
                    .justifyContent(FlexAlign.Center)
                    .onClick(() => {
                      ServerConfigManager.getInstance().removeServerHistory(item).then(async () => {
                        await this.loadHistory();
                      });
                    })
                  }
                  .width('100%')
                  .padding({ left: 12, right: 8, top: 10, bottom: 10 })
                  .backgroundColor(AppTheme.BG_CARD)
                  .borderRadius(AppTheme.RADIUS_MD)
                }
              }, (item: string) => item)
            }
            .width('100%')
            .constraintSize({ maxHeight: 280 })
            .scrollBar(BarState.Auto)
            .edgeEffect(EdgeEffect.Spring)
            .padding({ left: 16, right: 16, bottom: 12 })
          }

          // Bottom footer hint
          Row() {
            Text('点击任意软件源即可直接选择填入')
              .fontSize(11)
              .fontColor(AppTheme.TEXT_MUTED)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ bottom: 14 })
        }
        .width('88%')
        .constraintSize({ maxWidth: 380 })
        .backgroundColor(AppTheme.BG_ELEVATED)
        .borderRadius(AppTheme.RADIUS_LG)
        .border({ width: 0.5, color: AppTheme.BORDER })
        .shadow({ radius: 28, color: 'rgba(0, 0, 0, 0.8)', offsetY: 12 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BG)
  }
}

