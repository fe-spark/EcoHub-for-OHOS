import { FilmApi } from '../api/FilmApi';
import { MovieBasicInfo, PageInfo } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { FormatUtil } from '../common/utils/FormatUtil';
import { NavUtil } from '../common/utils/NavUtil';
import { EmptyState } from '../components/EmptyState';
import { LoadingView } from '../components/LoadingView';
import { AppIcon } from '../components/AppIcon';
import { SourceGuard } from '../common/utils/SourceGuard';
import { RefreshHint } from '../common/utils/RefreshHint';
import { SearchHistoryManager } from '../common/utils/SearchHistoryManager';
import promptAction from '@ohos.promptAction';

@Component
export struct SearchTab {
  @State keyword: string = '';
  @State submitted: string = '';
  @State list: MovieBasicInfo[] = [];
  @State page: PageInfo = { pageSize: 10, current: 1, pageCount: 0, total: 0 };
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State searchHistory: string[] = [];
  @State private refreshing: boolean = false;
  @State private fetchLock: boolean = false;
  private reconnectCb: () => void = () => {};

  aboutToAppear() {
    this.loadHistory();
    this.reconnectCb = () => {
      this.loadHistory();
      if (this.submitted) {
        this.doSearch(true, false);
      }
    };
    SourceGuard.onReconnect(this.reconnectCb);
  }

  aboutToDisappear(): void {
    SourceGuard.offReconnect(this.reconnectCb);
  }

  private async loadHistory(): Promise<void> {
    this.searchHistory = await SearchHistoryManager.list();
  }

  private confirmClearHistory(): void {
    AlertDialog.show({
      title: '清空搜索历史',
      message: '确定要清空全部搜索记录吗？',
      primaryButton: {
        value: '清空',
        fontColor: AppTheme.ACCENT,
        action: () => {
          SearchHistoryManager.clear().then(() => {
            this.loadHistory();
            promptAction.showToast({ message: '已清空搜索历史' });
          });
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }

  private async doSearch(reset: boolean, fromPull: boolean = false): Promise<void> {
    const kw = this.keyword.trim();
    if (!kw) {
      this.refreshing = false;
      return;
    }
    const nextPage = reset ? 1 : this.page.current + 1;
    if (!reset && nextPage > this.page.pageCount) {
      return;
    }
    if (this.fetchLock) {
      return;
    }
    this.fetchLock = true;
    if (reset) {
      if (!fromPull) {
        this.loading = true;
        this.list = [];
      }
      SearchHistoryManager.add(kw).then(() => {
        this.loadHistory();
      });
    } else {
      this.loadingMore = true;
    }
    let ok = false;
    try {
      const result = await FilmApi.searchFilm(kw, nextPage);
      this.submitted = kw;
      this.page = result.page;
      this.list = reset ? result.list : this.list.concat(result.list);
      ok = true;
    } catch (err) {
      this.list = reset && !fromPull ? [] : this.list;
    } finally {
      this.fetchLock = false;
      this.loading = false;
      this.loadingMore = false;
      this.refreshing = false;
      if (fromPull && ok) {
        RefreshHint.succeed();
      }
    }
  }

  build() {
    Column() {
      Row() {
        Row() {
          AppIcon({
            src: $r('sys.symbol.magnifyingglass'),
            iconSize: 18,
            color: AppTheme.TEXT_MUTED
          })
          TextInput({ text: this.keyword, placeholder: '搜索电影、剧集、动漫' })
            .layoutWeight(1)
            .height(40)
            .fontSize(14)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .placeholderColor(AppTheme.TEXT_MUTED)
            .caretColor(AppTheme.ACCENT)
            .backgroundColor(Color.Transparent)
            .cancelButton({ style: CancelButtonStyle.INVISIBLE })
            .padding({ left: 8, right: 8 })
            .onChange((val: string) => {
              this.keyword = val;
              if (!val.trim() && this.submitted) {
                this.submitted = '';
                this.list = [];
              }
            })
            .onSubmit(() => {
              this.doSearch(true);
            })

          if (this.keyword.length > 0) {
            Row() {
              AppIcon({
                src: $r('sys.symbol.xmark_circle_fill'),
                iconSize: 16,
                color: AppTheme.TEXT_MUTED
              })
            }
            .width(28)
            .height(28)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.keyword = '';
              this.submitted = '';
              this.list = [];
            })
          }
        }
        .layoutWeight(1)
        .height(40)
        .padding({ left: 12, right: 8 })
        .backgroundColor(AppTheme.BG_CARD)
        .borderRadius(AppTheme.RADIUS_PILL)

        Row() {
          AppIcon({
            src: $r('sys.symbol.magnifyingglass'),
            iconSize: 18,
            color: AppTheme.TEXT_PRIMARY
          })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.ACCENT)
        .borderRadius(20)
        .margin({ left: 8 })
        .onClick(() => {
          this.doSearch(true);
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })

      if (this.loading) {
        LoadingView({ label: '正在搜索' })
      } else if (!this.submitted) {
        if (this.searchHistory.length > 0) {
          Column() {
            Row() {
              Text('搜索历史')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT_PRIMARY)

              Row() {
                AppIcon({
                  src: $r('sys.symbol.trash'),
                  iconSize: 14,
                  color: AppTheme.TEXT_MUTED
                })
                Text('清空')
                  .fontSize(12)
                  .fontColor(AppTheme.TEXT_MUTED)
                  .margin({ left: 4 })
              }
              .onClick(() => this.confirmClearHistory())
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .padding({ left: 16, right: 16, top: 8, bottom: 12 })

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.searchHistory, (item: string) => {
                Row() {
                  Text(item)
                    .fontSize(13)
                    .fontColor(AppTheme.TEXT_SECONDARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: 200 })

                  Row() {
                    AppIcon({
                      src: $r('sys.symbol.xmark'),
                      iconSize: 10,
                      color: AppTheme.TEXT_MUTED
                    })
                  }
                  .width(16)
                  .height(16)
                  .justifyContent(FlexAlign.Center)
                  .margin({ left: 4 })
                  .onClick(() => {
                    SearchHistoryManager.remove(item).then(() => {
                      this.loadHistory();
                    });
                  })
                }
                .padding({ left: 12, right: 8, top: 6, bottom: 6 })
                .margin({ right: 8, bottom: 8 })
                .backgroundColor(AppTheme.BG_CARD)
                .borderRadius(AppTheme.RADIUS_PILL)
                .onClick(() => {
                  this.keyword = item;
                  this.doSearch(true);
                })
              }, (item: string) => item)
            }
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        } else {
          EmptyState({
            title: '搜索影片',
            subtitle: '输入片名、演员或关键词',
            icon: $r('sys.symbol.magnifyingglass')
          })
        }
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          if (this.list.length === 0) {
            Scroll() {
              EmptyState({
                title: '没有结果',
                subtitle: `未找到与「${this.submitted}」相关的影片`,
                icon: $r('sys.symbol.magnifyingglass')
              })
            }
            .scrollBar(BarState.Off)
            .width('100%')
            .height('100%')
          } else {
        List({ space: 16 }) {
          ListItem() {
            Text(`共 ${this.page.total} 部与「${this.submitted}」相关`)
              .fontSize(12)
              .fontColor(AppTheme.TEXT_MUTED)
              .width('100%')
              .padding({ bottom: 8 })
          }
          ForEach(this.list, (film: MovieBasicInfo) => {
            ListItem() {
              Row() {
                Stack({ alignContent: Alignment.Center }) {
                  Image(FormatUtil.poster(film))
                    .width(86)
                    .height(128)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(AppTheme.RADIUS_MD)
                    .backgroundColor(AppTheme.BG_CARD)
                  Row() {
                    AppIcon({
                      src: $r('sys.symbol.play_fill'),
                      iconSize: 12,
                      color: AppTheme.TEXT_PRIMARY
                    })
                  }
                  .width(28)
                  .height(28)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor('rgba(0,0,0,0.55)')
                  .borderRadius(14)
                }
                Column() {
                  Text(film.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.TEXT_PRIMARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(FormatUtil.joinMeta([film.cName, film.year, film.area, film.remarks]))
                    .fontSize(12)
                    .fontColor(AppTheme.TEXT_SECONDARY)
                    .margin({ top: 8 })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`导演 ${film.director || '未知'}`)
                    .fontSize(12)
                    .fontColor(AppTheme.TEXT_MUTED)
                    .margin({ top: 6 })
                    .maxLines(1)
                  Text(`主演 ${film.actor || '未知'}`)
                    .fontSize(12)
                    .fontColor(AppTheme.TEXT_MUTED)
                    .margin({ top: 4 })
                    .maxLines(1)
                  Text(film.blurb || '暂无简介')
                    .fontSize(12)
                    .fontColor(AppTheme.TEXT_SECONDARY)
                    .margin({ top: 8 })
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 12 })
              }
              .width('100%')
              .onClick(() => {
                NavUtil.openPlay(film.id);
              })
            }
          }, (film: MovieBasicInfo) => `${film.id}`)

          ListItem() {
            if (this.page.current < this.page.pageCount) {
              Text(this.loadingMore ? '加载中...' : '加载更多')
                .fontSize(13)
                .fontColor(AppTheme.TEXT_SECONDARY)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 8, bottom: 80 })
                .onClick(() => this.doSearch(false))
            } else {
              Text('没有更多了')
                .fontSize(12)
                .fontColor(AppTheme.TEXT_MUTED)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 8, bottom: 80 })
            }
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Off)
        .onReachEnd(() => {
          this.doSearch(false);
        })
          }
        }
        .onRefreshing(() => {
          if (this.fetchLock) {
            return;
          }
          this.doSearch(true, true);
        })
        .pullToRefresh(!this.fetchLock)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BG)
  }
}
