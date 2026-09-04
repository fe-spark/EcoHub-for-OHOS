import { FavoriteItem } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { FavoriteManager } from '../common/utils/FavoriteManager';
import { HttpClient } from '../common/network/HttpClient';
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
struct FavoritePage {
  @State private list: FavoriteItem[] = [];
  @State private refreshing: boolean = false;
  @State private fetchLock: boolean = false;
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  private sourceCb: () => void = () => {};
  private favChangeCb: () => void = () => {};

  private applyWindowBar(): void {
    WindowBar.apply(this.getUIContext().getHostContext() as common.UIAbilityContext, (top: number, bottom: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
    });
  }

  aboutToAppear(): void {
    this.applyWindowBar();
    HttpClient.getInstance().trackView('browse', '', 'FavoritePage');
    this.sourceCb = () => {
      this.reload(false);
    };
    SourceGuard.onReconnect(this.sourceCb);
    this.favChangeCb = () => {
      this.reload(false);
    };
    FavoriteManager.onFavoriteChange(this.favChangeCb);
    this.reload(false);
  }

  onPageShow(): void {
    this.applyWindowBar();
    this.reload(false);
  }

  aboutToDisappear(): void {
    SourceGuard.offReconnect(this.sourceCb);
    FavoriteManager.offFavoriteChange(this.favChangeCb);
  }

  private async reload(fromPull: boolean): Promise<void> {
    if (this.fetchLock) {
      return;
    }
    this.fetchLock = true;
    try {
      this.list = await FavoriteManager.list();
      if (fromPull) {
        RefreshHint.succeed();
      }
    } catch (_e) {
    } finally {
      this.fetchLock = false;
      this.refreshing = false;
    }
  }

  private confirmClear(): void {
    this.getUIContext().showAlertDialog({
      title: '清空收藏',
      message: '确定清空当前软件源的所有收藏记录吗？',
      primaryButton: {
        value: '清空',
        fontColor: AppTheme.DANGER,
        action: () => {
          FavoriteManager.clear().then(() => {
            this.reload(false);
            try {
              this.getUIContext().getPromptAction().showToast({ message: '已清空收藏' });
            } catch (_e) {
            }
          });
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }

  private deleteItem(item: FavoriteItem): void {
    FavoriteManager.remove(item.id).then(() => {
      this.reload(false);
      try {
        this.getUIContext().getPromptAction().showToast({ message: '已取消收藏' });
      } catch (_e) {
      }
    });
  }

  private subInfoText(item: FavoriteItem): string {
    const parts: string[] = [];
    if (item.cName) {
      parts.push(item.cName);
    }
    if (item.year) {
      parts.push(item.year);
    }
    if (item.area) {
      parts.push(item.area);
    }
    return parts.length > 0 ? parts.join(' · ') : (item.subTitle || '未知');
  }

  @Builder
  itemEnd(item: FavoriteItem) {
    Row() {
      Button({ type: ButtonType.Normal }) {
        Column({ space: 4 }) {
          AppIcon({ src: $r('sys.symbol.trash'), iconSize: 20, color: AppTheme.TEXT_PRIMARY })
          Text('删除')
            .fontSize(12)
            .fontColor(AppTheme.TEXT_PRIMARY)
        }
      }
      .backgroundColor(AppTheme.DANGER)
      .borderRadius(AppTheme.RADIUS_LG)
      .width(72)
      .height('100%')
      .onClick(() => {
        this.deleteItem(item);
      })
    }
    .padding({ left: 8 })
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      PageHeader({
        title: '我的收藏',
        rightText: this.list.length > 0 ? '清空' : '',
        rightTextColor: AppTheme.DANGER,
        onRight: () => this.confirmClear()
      })

      Refresh({ refreshing: $$this.refreshing }) {
        if (this.list.length === 0) {
          Scroll() {
            EmptyState({
              title: '暂无收藏',
              subtitle: '在播放页点击收藏后会显示在这里',
              icon: $r('sys.symbol.star_fill')
            })
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
          .nestedScroll({
            scrollForward: NestedScrollMode.SELF_FIRST,
            scrollBackward: NestedScrollMode.SELF_FIRST
          })
          .width('100%')
          .height('100%')
        } else {
          List({ space: 12 }) {
            ForEach(this.list, (item: FavoriteItem) => {
              ListItem() {
                Row() {
                  // 封面图
                  Image(ServerConfigManager.getInstance().resolveMediaUrl(item.picture))
                    .width(80)
                    .height(116)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(AppTheme.RADIUS_MD)
                    .backgroundColor(AppTheme.BG_ELEVATED)

                  // 信息栏
                  Column() {
                    Column() {
                      Text(item.name)
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(AppTheme.TEXT_PRIMARY)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })

                      Text(this.subInfoText(item))
                        .fontSize(12)
                        .fontColor(AppTheme.TEXT_SECONDARY)
                        .margin({ top: 4 })
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })

                      if (item.remarks) {
                        Text(item.remarks)
                          .fontSize(11)
                          .fontColor(AppTheme.ACCENT)
                          .margin({ top: 4 })
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                      }
                    }
                    .width('100%')
                    .alignItems(HorizontalAlign.Start)

                    // 底部收藏时间
                    Row() {
                      AppIcon({ src: $r('sys.symbol.clock_fill'), iconSize: 11, color: AppTheme.TEXT_MUTED })
                      Text(`收藏于 ${FormatUtil.dateTime(item.createdAt)}`)
                        .fontSize(11)
                        .fontColor(AppTheme.TEXT_MUTED)
                        .margin({ left: 4 })
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
                .onClick(() => {
                  NavUtil.openPlay(item.id);
                })
              }
              .swipeAction({
                end: {
                  builder: () => {
                    this.itemEnd(item);
                  }
                },
                edgeEffect: SwipeEdgeEffect.Spring
              })
            }, (item: FavoriteItem) => `${item.id}_${item.createdAt}`)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
          .nestedScroll({
            scrollForward: NestedScrollMode.SELF_FIRST,
            scrollBackward: NestedScrollMode.SELF_FIRST
          })
        }
      }
      .onRefreshing(() => {
        if (this.fetchLock) {
          this.refreshing = false;
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
