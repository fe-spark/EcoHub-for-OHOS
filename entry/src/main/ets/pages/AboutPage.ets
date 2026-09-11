import { AppTheme } from '../common/constants/AppTheme';
import { PageHeader } from '../components/common/PageHeader';
import { AppIcon } from '../components/common/AppIcon';
import { WindowBar } from '../common/utils/WindowBar';
import { NavUtil } from '../common/utils/NavUtil';
import { AppVersionUtil, AppUpdateInfo } from '../common/utils/AppVersionUtil';
import { VersionUpdateDialog } from '../components/dialogs/VersionUpdateDialog';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';

interface ProjectLinkItem {
  title: string;
  desc: string;
  url: string;
  icon: Resource;
}

@Entry
@Component
struct AboutPage {
  @State private appVersion: string = '1.0.0';
  @State private isCheckingVersion: boolean = false;
  @StorageLink('HAS_APP_UPDATE') private hasAppUpdate: boolean = false;
  @StorageLink('APP_UPDATE_INFO') private updateInfo: AppUpdateInfo = {
    currentVersion: '', latestVersion: '', hasUpdate: false,
    releaseName: '', releaseNotes: '', releaseUrl: '', downloadUrl: ''
  };
  @State private showUpdateDialog: boolean = false;
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  @State private leftInset: number = 0;
  @State private rightInset: number = 0;

  private readonly projectLinks: ProjectLinkItem[] = [
    {
      title: 'EcoHub 开源项目',
      desc: '服务端、Web 管理后台与前台源码',
      url: 'https://github.com/fe-spark/EcoHub',
      icon: $r('sys.symbol.website')
    },
    {
      title: 'EcoHub for OHOS',
      desc: 'HarmonyOS NEXT 原生客户端源码',
      url: 'https://github.com/fe-spark/EcoHub-for-OHOS',
      icon: $r('sys.symbol.phone_1')
    },
    {
      title: 'EcoHub for Android',
      desc: 'Android 客户端应用源码',
      url: 'https://github.com/fe-spark/EcoHub-for-Android',
      icon: $r('sys.symbol.phone_1')
    },
    {
      title: 'Telegram 交流群组',
      desc: '社区交流、反馈与动态探讨',
      url: 'https://t.me/ecohub_club',
      icon: $r('sys.symbol.message_on_message')
    }
  ];

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
    AppVersionUtil.getVersionName().then((v: string) => {
      this.appVersion = v;
    }).catch(() => {});

    // 进入关于页面时静默检查是否有更新，用于状态同步
    AppVersionUtil.checkUpdate(false).then((info) => {
      this.updateInfo = info;
      this.hasAppUpdate = info.hasUpdate;
    }).catch(() => {});
  }

  private async handleCheckVersion(force: boolean = false): Promise<void> {
    if (this.isCheckingVersion) {
      return;
    }
    if (!force && this.hasAppUpdate) {
      this.showUpdateDialog = true;
      return;
    }
    this.isCheckingVersion = true;
    try {
      this.getUIContext().getPromptAction().showToast({ message: '正在检查版本更新...' });
    } catch (_e) {
    }
    try {
      const info = await AppVersionUtil.checkUpdate(true);
      this.updateInfo = info;
      this.hasAppUpdate = info.hasUpdate;
      if (info.hasUpdate) {
        this.showUpdateDialog = true;
      } else {
        try {
          this.getUIContext().getPromptAction().showToast({ message: `当前已是最新版本 (v${this.appVersion})` });
        } catch (_e) {
        }
      }
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '检查版本失败，请稍后重试' });
      } catch (_e) {
      }
    } finally {
      this.isCheckingVersion = false;
    }
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

  private copyToClipboard(text: string): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setDataSync(data);
      this.getUIContext().getPromptAction().showToast({ message: '链接已复制到剪贴板' });
    } catch (_e) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '复制失败，请手动复制' });
      } catch (_err) {}
    }
  }

  private openUrl(url: string): void {
    const ctx = this.getContextSafe();
    if (ctx) {
      NavUtil.openBrowser(ctx, url);
    }
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
      .color(AppTheme.BORDER)
      .margin({ left: 56, right: 16 })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        PageHeader({ title: '关于' })

        Scroll() {
          Column({ space: 14 }) {
            // 1. App 头部基础信息
            Column() {
              Image($r('app.media.startIcon'))
                .width(72)
                .height(72)
                .borderRadius(AppTheme.RADIUS_LG)
                .clip(true)
                .margin({ bottom: 12 })

              Text('EcoHub')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.TEXT_PRIMARY)

              Text(`版本 v${this.appVersion}`)
                .fontSize(13)
                .fontColor(AppTheme.TEXT_MUTED)
                .margin({ top: 4, bottom: 6 })

              Text('自托管高性能多源影视聚合系统')
                .fontSize(13)
                .fontColor(AppTheme.TEXT_SECONDARY)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding({ top: 16, bottom: 12 })

            // 2. 版本更新卡片
            Column() {
              Row() {
                Row() {
                  AppIcon({ src: $r('sys.symbol.arrow_counterclockwise'), iconSize: 18, color: AppTheme.ACCENT })
                }
                .width(36)
                .height(36)
                .justifyContent(FlexAlign.Center)
                .backgroundColor(AppTheme.ACCENT_SOFT)
                .borderRadius(18)

                Row() {
                  Text('版本更新')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.TEXT_PRIMARY)

                  if (this.hasAppUpdate) {
                    Row() {
                      Text('NEW')
                        .fontSize(10)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(AppTheme.TEXT_PRIMARY)
                    }
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .backgroundColor(AppTheme.DANGER)
                    .borderRadius(AppTheme.RADIUS_PILL)
                    .margin({ left: AppTheme.SPACE_SM })
                    .justifyContent(FlexAlign.Center)
                  }
                }
                .layoutWeight(1)
                .margin({ left: 12, right: 8 })
                .alignItems(VerticalAlign.Center)

                Text(this.isCheckingVersion
                  ? '检查中...'
                  : (this.hasAppUpdate ? `发现新版本 v${this.updateInfo.latestVersion}` : `v${this.appVersion}`))
                  .fontSize(13)
                  .fontColor(this.hasAppUpdate ? AppTheme.ACCENT : AppTheme.TEXT_MUTED)
                  .fontWeight(this.hasAppUpdate ? FontWeight.Medium : FontWeight.Normal)
                  .margin({ right: 6 })

                AppIcon({
                  src: $r('sys.symbol.chevron_right'),
                  iconSize: 14,
                  color: AppTheme.TEXT_MUTED
                })
              }
              .width('100%')
              .padding({ left: 16, right: 14, top: 14, bottom: 14 })
              .alignItems(VerticalAlign.Center)
            }
            .backgroundColor(AppTheme.BG_ELEVATED)
            .borderRadius(AppTheme.RADIUS_LG)
            .clip(true)
            .border({ width: 0.5, color: AppTheme.BORDER })
            .onClick(() => {
              this.handleCheckVersion();
            })

            // 3. 相关项目地址列表
            Column() {
              this.sectionTitle('相关项目地址')

              Column() {
                ForEach(this.projectLinks, (item: ProjectLinkItem, index: number) => {
                  if (index > 0) {
                    this.cardDivider()
                  }

                  Row() {
                    Row() {
                      AppIcon({ src: item.icon, iconSize: 18, color: AppTheme.ACCENT })
                    }
                    .width(36)
                    .height(36)
                    .justifyContent(FlexAlign.Center)
                    .backgroundColor(AppTheme.ACCENT_SOFT)
                    .borderRadius(18)

                    Column({ space: 3 }) {
                      Text(item.title)
                        .fontSize(15)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(AppTheme.TEXT_PRIMARY)

                      Text(item.desc)
                        .fontSize(12)
                        .fontColor(AppTheme.TEXT_MUTED)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })

                      Text(item.url)
                        .fontSize(11)
                        .fontColor(AppTheme.ACCENT)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                    .margin({ left: 12, right: 8 })

                    // 复制图标按钮
                    Row() {
                      AppIcon({
                        src: $r('sys.symbol.doc_text_on_doc_text'),
                        iconSize: 16,
                        color: AppTheme.TEXT_MUTED
                      })
                    }
                    .width(32)
                    .height(32)
                    .borderRadius(16)
                    .justifyContent(FlexAlign.Center)
                    .backgroundColor('rgba(255, 255, 255, 0.04)')
                    .margin({ right: 6 })
                    .onClick(() => {
                      this.copyToClipboard(item.url);
                    })

                    // 跳转箭头
                    AppIcon({
                      src: $r('sys.symbol.chevron_right'),
                      iconSize: 14,
                      color: AppTheme.TEXT_MUTED
                    })
                  }
                  .width('100%')
                  .padding({ left: 16, right: 14, top: 12, bottom: 12 })
                  .alignItems(VerticalAlign.Center)
                  .onClick(() => {
                    this.openUrl(item.url);
                  })
                }, (item: ProjectLinkItem) => item.url)
              }
              .backgroundColor(AppTheme.BG_ELEVATED)
              .borderRadius(AppTheme.RADIUS_LG)
              .clip(true)
              .border({ width: 0.5, color: AppTheme.BORDER })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // 4. 使用须知卡片
            Column() {
              this.sectionTitle('使用须知')

              Column() {
                Text('EcoHub 为开源自托管影视聚合系统，不提供、不存储任何影视文件。片源来自使用者自行配置的采集接口。请遵守所在地区的法律法规及源站使用约定，仅供学习与技术交流。')
                  .fontSize(13)
                  .fontColor(AppTheme.TEXT_SECONDARY)
                  .lineHeight(20)
              }
              .width('100%')
              .padding(16)
              .backgroundColor(AppTheme.BG_ELEVATED)
              .borderRadius(AppTheme.RADIUS_LG)
              .border({ width: 0.5, color: AppTheme.BORDER })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // 5. 版权与开源协议声明
            Column() {
              Text('开源协议：MIT License')
                .fontSize(12)
                .fontColor(AppTheme.TEXT_MUTED)
              Text('Copyright © 2026 fe-spark. All Rights Reserved.')
                .fontSize(11)
                .fontColor(AppTheme.TEXT_MUTED)
                .margin({ top: 4 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding({ top: 12, bottom: 24 })
          }
          .width('100%')
          .constraintSize({ maxWidth: AppTheme.CONTENT_MAX_WIDTH })
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
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

      if (this.showUpdateDialog) {
        VersionUpdateDialog({
          updateInfo: this.updateInfo,
          onClose: () => {
            this.showUpdateDialog = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BG)
  }
}
