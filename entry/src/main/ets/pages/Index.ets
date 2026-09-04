import { ServerConfigManager } from '../common/utils/ServerConfigManager';
import { WindowBar } from '../common/utils/WindowBar';
import { common } from '@kit.AbilityKit';
import { FilmApi } from '../api/FilmApi';
import { BasicConfig } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { RecommendTab } from './RecommendTab';
import { DailyUpdatesTab } from './DailyUpdatesTab';
import { ProfileTab } from './ProfileTab';
import { AppIcon } from '../components/AppIcon';
import { NavUtil } from '../common/utils/NavUtil';
import { SourceGuard } from '../common/utils/SourceGuard';
import { SiteHeartbeat } from '../common/utils/SiteHeartbeat';
import { AppVersionUtil } from '../common/utils/AppVersionUtil';
import { HttpClient } from '../common/network/HttpClient';
import { NoticeDialog } from '../components/NoticeDialog';

@Entry
@Component
struct Index {
  @State currentTabIndex: number = 0;
  @State siteName: string = 'EcoHub';
  @State siteOpen: boolean = true;
  @State siteHint: string = '';
  @State ready: boolean = false;
  @State showNotice: boolean = false;
  @State noticeTitle: string = '站点公告';
  @State noticeContent: string = '';
  @StorageLink('HAS_APP_UPDATE') private hasAppUpdate: boolean = false;
  private hasDismissedNotice: boolean = false;
  @State private tabReady: boolean[] = [true, false, false];
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  @State private leftInset: number = 0;
  @State private rightInset: number = 0;
  private reconnectCb: () => void = () => {};
  private configCb: (config: BasicConfig) => void = () => {};

  private selectTab(index: number): void {
    this.currentTabIndex = index;
    if (!this.tabReady[index]) {
      const next: boolean[] = [this.tabReady[0], this.tabReady[1], this.tabReady[2]];
      next[index] = true;
      this.tabReady = next;
    }
  }

  private async checkNotice(config: BasicConfig): Promise<void> {
    if (config.state === false || !config.noticeEnabled || config.noticeShowInApp === false || !config.noticeContent || !config.noticeContent.trim()) {
      this.showNotice = false;
      return;
    }
    const targetVersion = config.noticeAppVersion || config.noticeVersion;
    const appVersion = await AppVersionUtil.getVersionName();
    const isMatched = AppVersionUtil.isVersionMatched(appVersion, targetVersion);
    // 版本号匹配且本次启动会话未关闭过时，弹出开屏公告
    if (isMatched && !this.hasDismissedNotice) {
      this.noticeTitle = config.noticeTitle || '站点公告';
      this.noticeContent = config.noticeContent;
      this.showNotice = true;
    } else if (!isMatched) {
      this.showNotice = false;
    }
  }

  private applyWindowBar(): void {
    WindowBar.apply(this.getUIContext().getHostContext() as common.UIAbilityContext, (top: number, bottom: number, left: number, right: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
      this.leftInset = left;
      this.rightInset = right;
    });
  }

  async aboutToAppear() {
    this.applyWindowBar();
    this.hasDismissedNotice = AppStorage.get<boolean>('NOTICE_DISMISSED_SESSION') === true;
    this.configCb = (config: BasicConfig) => {
      this.siteName = config.siteName || 'EcoHub';
      this.siteOpen = config.state !== false;
      this.siteHint = config.hint;
      this.checkNotice(config);
    };
    FilmApi.onConfigChange(this.configCb);
    const url = await ServerConfigManager.getInstance().getServerUrl();
    if (!url) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: 'pages/ServerConfigPage' });
      } catch (_e) {
      }
      return;
    }
    await this.loadSite(false);
    HttpClient.getInstance().trackView('browse', '', 'IndexPage');
    SiteHeartbeat.getInstance().start();
    this.reconnectCb = () => {
      this.loadSite(false);
    };
    SourceGuard.onReconnect(this.reconnectCb);
  }

  onPageShow(): void {
    this.applyWindowBar();
    if (this.ready) {
      this.loadSite(false);
    }
    SiteHeartbeat.getInstance().start();
  }

  onPageHide(): void {
  }

  aboutToDisappear(): void {
    FilmApi.offConfigChange(this.configCb);
    SourceGuard.offReconnect(this.reconnectCb);
  }

  private async loadSite(first: boolean): Promise<void> {
    if (first) {
      this.ready = false;
    }
    try {
      const config = await FilmApi.getSiteConfig(first);
      this.siteName = config.siteName || 'EcoHub';
      this.siteOpen = config.state !== false;
      this.siteHint = config.hint;
      await this.checkNotice(config);
    } catch (err) {
      this.siteOpen = true;
    }
    this.ready = true;
  }

  @Builder
  tabItem(index: number, label: string, icon: Resource, iconActive: Resource, hasBadge: boolean = false) {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        AppIcon({
          src: this.currentTabIndex === index ? iconActive : icon,
          iconSize: 22,
          color: this.currentTabIndex === index ? AppTheme.ACCENT : AppTheme.TEXT_MUTED
        })
        if (hasBadge) {
          Column()
            .width(8)
            .height(8)
            .borderRadius(4)
            .backgroundColor(AppTheme.DANGER)
            .margin({ top: -2, right: -4 })
        }
      }
      Text(label)
        .fontSize(10)
        .fontWeight(this.currentTabIndex === index ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.currentTabIndex === index ? AppTheme.ACCENT : AppTheme.TEXT_MUTED)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.selectTab(index);
    })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        if (!this.ready) {
          Column() {
            LoadingProgress().color(AppTheme.ACCENT).width(36).height(36)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (!this.siteOpen) {
          Column() {
            Stack({ alignContent: Alignment.Center }) {
              Column()
                .width(76)
                .height(76)
                .borderRadius(38)
                .backgroundColor(AppTheme.ACCENT_SOFT)
              AppIcon({
                src: $r('sys.symbol.info_circle'),
                iconSize: 36,
                color: AppTheme.ACCENT
              })
            }
            .margin({ bottom: 16 })

            Text(this.siteName)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT_PRIMARY)

            Row() {
              Text('站点维护中')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.ACCENT)
            }
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(AppTheme.ACCENT_SOFT)
            .borderRadius(AppTheme.RADIUS_PILL)
            .margin({ top: 8, bottom: 20 })

            Column() {
              Text(this.siteHint || '当前站点正在进行系统维护，暂无法提供观影服务，请稍后刷新重试或更换其他软件源。')
                .fontSize(14)
                .lineHeight(22)
                .fontColor(AppTheme.TEXT_SECONDARY)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 16 })
            .backgroundColor(AppTheme.BG_CARD)
            .borderRadius(AppTheme.RADIUS_LG)
            .margin({ bottom: 28 })

            Row({ space: 12 }) {
              Button() {
                Row() {
                  AppIcon({ src: $r('sys.symbol.arrow_counterclockwise'), iconSize: 15, color: AppTheme.TEXT_PRIMARY })
                  Text('刷新重试')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.TEXT_PRIMARY)
                    .margin({ left: 6 })
                }
              }
              .height(44)
              .layoutWeight(1)
              .backgroundColor(AppTheme.BG_CARD)
              .borderRadius(AppTheme.RADIUS_PILL)
              .onClick(() => {
                this.loadSite(true);
              })

              Button() {
                Row() {
                  AppIcon({ src: $r('sys.symbol.link'), iconSize: 15, color: AppTheme.TEXT_PRIMARY })
                  Text('更换软件源')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.TEXT_PRIMARY)
                    .margin({ left: 6 })
                }
              }
              .height(44)
              .layoutWeight(1)
              .backgroundColor(AppTheme.ACCENT)
              .borderRadius(AppTheme.RADIUS_PILL)
              .onClick(() => {
                try {
                  this.getUIContext().getRouter().pushUrl({ url: 'pages/ServerConfigPage' });
                } catch (_e) {
                }
              })
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 24 + this.leftInset, right: 24 + this.rightInset, top: 24, bottom: this.bottomInset + 24 })
        } else {
          Stack() {
            if (this.tabReady[0]) {
              RecommendTab({
                siteName: this.siteName,
                onOpenSearch: () => {
                  NavUtil.openSearch();
                }
              })
                .visibility(this.currentTabIndex === 0 ? Visibility.Visible : Visibility.None)
            }
            if (this.tabReady[1]) {
              DailyUpdatesTab()
                .padding({ top: this.topInset, left: this.leftInset, right: this.rightInset })
                .visibility(this.currentTabIndex === 1 ? Visibility.Visible : Visibility.None)
            }
            if (this.tabReady[2]) {
              ProfileTab()
                .padding({ top: this.topInset, left: this.leftInset, right: this.rightInset })
                .visibility(this.currentTabIndex === 2 ? Visibility.Visible : Visibility.None)
            }
          }
          .width('100%')
          .layoutWeight(1)

          Column() {
            Row() {
              this.tabItem(0, '推荐', $r('sys.symbol.house'), $r('sys.symbol.house_fill'))
              this.tabItem(1, '更新', $r('sys.symbol.flame'), $r('sys.symbol.flame_fill'))
              this.tabItem(2, '我的', $r('sys.symbol.person'), $r('sys.symbol.person_fill'), this.hasAppUpdate)
            }
            .width('100%')
            .height(AppTheme.TAB_HEIGHT)
            .padding({ left: this.leftInset, right: this.rightInset })
            .constraintSize({ maxWidth: 600 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ bottom: this.bottomInset })
          .backgroundColor(AppTheme.BG_ELEVATED)
          .border({ width: { top: 0.5 }, color: 'rgba(255,255,255,0.06)' })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.BG)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      if (this.showNotice && this.ready && this.siteOpen) {
        NoticeDialog({
          title: this.noticeTitle,
          content: this.noticeContent,
          onClose: () => {
            this.hasDismissedNotice = true;
            AppStorage.setOrCreate<boolean>('NOTICE_DISMISSED_SESSION', true);
            this.showNotice = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
