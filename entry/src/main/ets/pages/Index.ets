import router from '@ohos.router';
import { ServerConfigManager } from '../common/utils/ServerConfigManager';
import { WindowBar } from '../common/utils/WindowBar';
import { common } from '@kit.AbilityKit';
import { FilmApi } from '../api/FilmApi';
import { AppTheme } from '../common/constants/AppTheme';
import { RecommendTab } from './RecommendTab';
import { DailyUpdatesTab } from './DailyUpdatesTab';
import { SearchTab } from './SearchTab';
import { ProfileTab } from './ProfileTab';
import { AppIcon } from '../components/AppIcon';
import { SourceGuard } from '../common/utils/SourceGuard';

@Entry
@Component
struct Index {
  @State currentTabIndex: number = 0;
  @State siteName: string = 'EcoHub';
  @State siteOpen: boolean = true;
  @State siteHint: string = '';
  @State ready: boolean = false;
  @State private tabReady: boolean[] = [true, false, false, false];
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  private reconnectCb: () => void = () => {};

  private selectTab(index: number): void {
    this.currentTabIndex = index;
    if (!this.tabReady[index]) {
      const next: boolean[] = [this.tabReady[0], this.tabReady[1], this.tabReady[2], this.tabReady[3]];
      next[index] = true;
      this.tabReady = next;
    }
  }

  async aboutToAppear() {
    WindowBar.apply(getContext(this) as common.UIAbilityContext, (top: number, bottom: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
    });
    const url = await ServerConfigManager.getInstance().getServerUrl();
    if (!url) {
      router.replaceUrl({ url: 'pages/ServerConfigPage' });
      return;
    }
    await this.loadSite(true);
    this.reconnectCb = () => {
      this.loadSite(false);
    };
    SourceGuard.onReconnect(this.reconnectCb);
  }

  aboutToDisappear(): void {
    SourceGuard.offReconnect(this.reconnectCb);
  }

  private async loadSite(first: boolean): Promise<void> {
    if (first) {
      this.ready = false;
    }
    try {
      const config = await FilmApi.getSiteConfig(true);
      this.siteName = config.siteName || 'EcoHub';
      this.siteOpen = config.state !== false;
      this.siteHint = config.hint;
    } catch (err) {
      this.siteOpen = true;
    }
    this.ready = true;
  }

  @Builder
  tabItem(index: number, label: string, icon: Resource, iconActive: Resource) {
    Column() {
      AppIcon({
        src: this.currentTabIndex === index ? iconActive : icon,
        iconSize: 22,
        color: this.currentTabIndex === index ? AppTheme.ACCENT : AppTheme.TEXT_MUTED
      })
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
          Text(this.siteName)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT_PRIMARY)
          AppIcon({
            src: $r('sys.symbol.info_circle'),
            iconSize: 40,
            color: AppTheme.ACCENT
          })
            .margin({ bottom: 16 })
          Text(this.siteHint || '站点维护中')
            .fontSize(14)
            .fontColor(AppTheme.TEXT_SECONDARY)
            .margin({ top: 12 })
            .textAlign(TextAlign.Center)
          Button('更换软件源')
            .margin({ top: 24 })
            .backgroundColor(AppTheme.ACCENT)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .onClick(() => {
              router.pushUrl({ url: 'pages/ServerConfigPage' });
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding(24)
      } else {
        Stack() {
          if (this.tabReady[0]) {
            RecommendTab({
              siteName: this.siteName,
              onOpenSearch: () => {
                this.selectTab(2);
              }
            })
              .visibility(this.currentTabIndex === 0 ? Visibility.Visible : Visibility.None)
          }
          if (this.tabReady[1]) {
            DailyUpdatesTab()
              .visibility(this.currentTabIndex === 1 ? Visibility.Visible : Visibility.None)
          }
          if (this.tabReady[2]) {
            SearchTab()
              .visibility(this.currentTabIndex === 2 ? Visibility.Visible : Visibility.None)
          }
          if (this.tabReady[3]) {
            ProfileTab()
              .visibility(this.currentTabIndex === 3 ? Visibility.Visible : Visibility.None)
          }
        }
        .width('100%')
        .layoutWeight(1)
      }

      Column() {
        Row() {
          this.tabItem(0, '推荐', $r('sys.symbol.house'), $r('sys.symbol.house_fill'))
          this.tabItem(1, '更新', $r('sys.symbol.flame'), $r('sys.symbol.flame_fill'))
          this.tabItem(2, '搜索', $r('sys.symbol.magnifyingglass'), $r('sys.symbol.magnifyingglass'))
          this.tabItem(3, '我的', $r('sys.symbol.person'), $r('sys.symbol.person_fill'))
        }
        .width('100%')
        .height(AppTheme.TAB_HEIGHT)
      }
      .width('100%')
      .padding({ bottom: this.bottomInset })
      .backgroundColor(AppTheme.BG_ELEVATED)
      .border({ width: { top: 0.5 }, color: 'rgba(255,255,255,0.06)' })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topInset })
    .backgroundColor(AppTheme.BG)
  }
}
