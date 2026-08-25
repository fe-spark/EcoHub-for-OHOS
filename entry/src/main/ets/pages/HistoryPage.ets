import promptAction from '@ohos.promptAction';
import { HistoryItem } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { HistoryManager } from '../common/utils/HistoryManager';
import { NavUtil } from '../common/utils/NavUtil';
import { ServerConfigManager } from '../common/utils/ServerConfigManager';
import { SourceGuard } from '../common/utils/SourceGuard';
import { WindowBar } from '../common/utils/WindowBar';
import { common } from '@kit.AbilityKit';
import { PageHeader } from '../components/PageHeader';
import { EmptyState } from '../components/EmptyState';
import { AppIcon } from '../components/AppIcon';
import { RefreshHint } from '../common/utils/RefreshHint';

@Entry
@Component
struct HistoryPage {
  @State private list: HistoryItem[] = [];
  @State private refreshing: boolean = false;
  @State private fetchLock: boolean = false;
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  private sourceCb: () => void = () => {};

  aboutToAppear() {
    WindowBar.apply(getContext(this) as common.UIAbilityContext, (top: number, bottom: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
    });
    this.sourceCb = () => {
      this.reload(false);
    };
    SourceGuard.onReconnect(this.sourceCb);
    this.reload(false);
  }

  onPageShow(): void {
    this.reload(false);
  }

  aboutToDisappear(): void {
    SourceGuard.offReconnect(this.sourceCb);
  }

  private async reload(fromPull: boolean): Promise<void> {
    if (this.fetchLock) {
      return;
    }
    this.fetchLock = true;
    this.list = await HistoryManager.list();
    this.fetchLock = false;
    this.refreshing = false;
    if (fromPull) {
      RefreshHint.succeed();
    }
  }

  private confirmClear(): void {
    AlertDialog.show({
      title: '清空观看历史',
      message: '确定删除当前软件源的全部观看记录吗？',
      primaryButton: {
        value: '清空',
        fontColor: AppTheme.DANGER,
        action: () => {
          HistoryManager.clear().then(() => {
            this.reload(false);
            promptAction.showToast({ message: '已清空' });
          });
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }

  private confirmDelete(item: HistoryItem): void {
    AlertDialog.show({
      title: '删除记录',
      message: `确定删除「${item.name}」吗？`,
      primaryButton: {
        value: '删除',
        fontColor: AppTheme.DANGER,
        action: () => {
          HistoryManager.remove(item.id).then(() => {
            this.reload(false);
          });
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }

  build() {
    Column() {
      PageHeader({
        title: '观看历史',
        rightText: this.list.length > 0 ? '清空' : '',
        rightTextColor: AppTheme.DANGER,
        onRight: () => this.confirmClear()
      })

      Refresh({ refreshing: $$this.refreshing }) {
      if (this.list.length === 0) {
        Scroll() {
        EmptyState({
          title: '暂无观看记录',
          subtitle: '播放影片后会显示在这里',
          icon: $r('sys.symbol.clock_fill')
        })
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      } else {
        List({ space: 12 }) {
          ForEach(this.list, (item: HistoryItem) => {
            ListItem() {
              Row() {
                // Poster
                Image(ServerConfigManager.getInstance().resolveMediaUrl(item.picture))
                  .width(80)
                  .height(116)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(AppTheme.RADIUS_MD)
                  .backgroundColor(AppTheme.BG_ELEVATED)
                  .onClick(() => {
                    NavUtil.openPlay(item.id, item.sourceId, item.episodeIndex, item.currentTime);
                  })

                // Info & Actions Column
                Column() {
                  // Top section: Name + Source/Episode + Timestamp
                  Column() {
                    Text(item.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppTheme.TEXT_PRIMARY)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(`${item.sourceName} · ${item.episode}`)
                      .fontSize(12)
                      .fontColor(AppTheme.TEXT_SECONDARY)
                      .margin({ top: 4 })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Row() {
                      AppIcon({ src: $r('sys.symbol.clock_fill'), iconSize: 11, color: AppTheme.TEXT_MUTED })
                      Text(FormatUtil.dateTime(item.timeStamp))
                        .fontSize(11)
                        .fontColor(AppTheme.TEXT_MUTED)
                        .margin({ left: 4 })
                    }
                    .margin({ top: 4 })
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                  .onClick(() => {
                    NavUtil.openPlay(item.id, item.sourceId, item.episodeIndex, item.currentTime);
                  })

                  // Bottom section: Progress (Left) & Delete Button (Right)
                  Row() {
                    Row() {
                      Text(FormatUtil.progress(item.currentTime, item.duration))
                        .fontSize(12)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(AppTheme.ACCENT)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .layoutWeight(1)
                    .alignItems(VerticalAlign.Center)
                    .onClick(() => {
                      NavUtil.openPlay(item.id, item.sourceId, item.episodeIndex, item.currentTime);
                    })

                    Row() {
                      AppIcon({ src: $r('sys.symbol.trash'), iconSize: 12, color: AppTheme.DANGER })
                      Text('删除')
                        .fontSize(11)
                        .fontColor(AppTheme.DANGER)
                        .margin({ left: 3 })
                    }
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor(AppTheme.DANGER_SOFT)
                    .borderRadius(AppTheme.RADIUS_SM)
                    .margin({ left: 8 })
                    .onClick(() => {
                      this.confirmDelete(item);
                    })
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                }
                .height(116)
                .layoutWeight(1)
                .margin({ left: 12 })
                .justifyContent(FlexAlign.SpaceBetween)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(12)
              .backgroundColor(AppTheme.BG_CARD)
              .borderRadius(AppTheme.RADIUS_LG)
            }
          }, (item: HistoryItem) => `${item.id}_${item.timeStamp}_${Math.floor(item.currentTime)}_${item.sourceId}_${item.episodeIndex}`)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, bottom: 16 })
        .scrollBar(BarState.Off)
      }
      }
      .onRefreshing(() => {
        if (this.fetchLock) {
          return;
        }
        this.reload(true);
      })
      .pullToRefresh(!this.fetchLock)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topInset, bottom: this.bottomInset })
    .backgroundColor(AppTheme.BG)
  }
}
