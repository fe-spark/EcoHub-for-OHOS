import promptAction from '@ohos.promptAction';
import { HistoryItem } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { HistoryManager } from '../common/utils/HistoryManager';
import { NavUtil } from '../common/utils/NavUtil';
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

  aboutToAppear() {
    WindowBar.apply(getContext(this) as common.UIAbilityContext, (top: number, bottom: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
    });
    this.reload(false);
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
      message: '确定删除全部观看记录吗？',
      primaryButton: {
        value: '清空',
        fontColor: AppTheme.ACCENT,
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
        fontColor: AppTheme.ACCENT,
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
        List({ space: 16 }) {
          ForEach(this.list, (item: HistoryItem) => {
            ListItem() {
              Row() {
                Image(item.picture)
                  .width(86)
                  .height(128)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(AppTheme.RADIUS_MD)
                  .backgroundColor(AppTheme.BG_CARD)
                  .onClick(() => {
                    NavUtil.openPlay(item.id, item.sourceId, item.episodeIndex, item.currentTime);
                  })
                Column() {
                  Text(item.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.TEXT_PRIMARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Row() {
                    AppIcon({ src: $r('sys.symbol.clock_fill'), iconSize: 12, color: AppTheme.TEXT_MUTED })
                    Text(FormatUtil.dateTime(item.timeStamp))
                      .fontSize(12)
                      .fontColor(AppTheme.TEXT_MUTED)
                      .margin({ left: 4 })
                  }
                  .margin({ top: 8 })
                  Text(`${item.sourceName} · ${item.episode}`)
                    .fontSize(12)
                    .fontColor(AppTheme.TEXT_SECONDARY)
                    .margin({ top: 6 })
                  Text(FormatUtil.progress(item.currentTime, item.duration))
                    .fontSize(12)
                    .fontColor(AppTheme.ACCENT)
                    .margin({ top: 8 })
                  Row() {
                    AppIcon({ src: $r('sys.symbol.trash'), iconSize: 14, color: AppTheme.TEXT_MUTED })
                    Text('删除')
                      .fontSize(12)
                      .fontColor(AppTheme.TEXT_MUTED)
                      .margin({ left: 4 })
                  }
                  .margin({ top: 12 })
                  .onClick(() => this.confirmDelete(item))
                }
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 12 })
                .layoutWeight(1)
                .onClick(() => {
                  NavUtil.openPlay(item.id, item.sourceId, item.episodeIndex, item.currentTime);
                })
              }
              .width('100%')
            }
          }, (item: HistoryItem) => item.id)
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
