import { common } from '@kit.AbilityKit';
import { FilmApi } from '../api/FilmApi';
import { MovieBasicInfo, PageInfo } from '../model/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { NavUtil } from '../common/utils/NavUtil';
import { WindowBar } from '../common/utils/WindowBar';
import { EmptyState } from '../components/EmptyState';
import { LoadingView } from '../components/LoadingView';
import { AppIcon } from '../components/AppIcon';
import { BackIcon } from '../components/BackIcon';
import { SourceGuard } from '../common/utils/SourceGuard';
import { RefreshHint } from '../common/utils/RefreshHint';
import { SearchHistoryManager } from '../common/utils/SearchHistoryManager';
import { HttpClient } from '../common/network/HttpClient';
import { SearchResultItem } from '../components/SearchResultItem';

@Entry
@Component
struct SearchPage {
  @State keyword: string = '';
  @State submitted: string = '';
  @State list: MovieBasicInfo[] = [];
  @State page: PageInfo = { pageSize: 10, current: 1, pageCount: 0, total: 0 };
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State searchHistory: string[] = [];
  @State hotKeywords: string[] = [];
  @State private refreshing: boolean = false;
  @State private errorText: string = '';
  @State private fetchLock: boolean = false;
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  private reconnectCb: () => void = () => {};
  private inputController: TextInputController = new TextInputController();
  private static readonly DEFAULT_HOT_KEYWORDS: string[] = [
    '凡人修仙传', '庆余年', '仙逆', '吞噬星空', '遮天', '斗破苍穹', '白夜破晓', '大奉打更人'
  ];

  private hideKeyboard(): void {
    try {
      this.inputController.stopEditing();
    } catch (_e) {
    }
    setTimeout(() => {
      try {
        this.inputController.stopEditing();
      } catch (_e) {
      }
    }, 50);
  }

  private getSearchPlaceholder(): string {
    if (this.hotKeywords.length > 0 && this.hotKeywords[0]) {
      return `大家都在搜：${this.hotKeywords[0]}`;
    }
    return '搜索电影、剧集、动漫';
  }

  private applyWindowBar(): void {
    WindowBar.apply(this.getUIContext().getHostContext() as common.UIAbilityContext, (top: number, bottom: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
    });
  }

  aboutToAppear() {
    this.applyWindowBar();
    this.loadHistory();
    this.loadHotKeywords();
    const params = this.getUIContext().getRouter().getParams();
    const initialKw = NavUtil.param(params, 'keyword');
    if (initialKw) {
      this.keyword = initialKw;
      this.doSearch(true, false);
    }
    this.reconnectCb = () => {
      this.loadHistory();
      this.loadHotKeywords();
      if (this.submitted) {
        this.doSearch(true, false);
      }
    };
    SourceGuard.onReconnect(this.reconnectCb);
  }

  onPageShow(): void {
    this.applyWindowBar();
    const params = this.getUIContext().getRouter().getParams();
    const initialKw = NavUtil.param(params, 'keyword');
    if (!initialKw && !this.submitted) {
      setTimeout(() => {
        try {
          focusControl.requestFocus('SearchPage_Input');
        } catch (_e) {
        }
      }, 100);
    }
  }

  onBackPress(): boolean {
    this.hideKeyboard();
    return false;
  }

  aboutToDisappear(): void {
    SourceGuard.offReconnect(this.reconnectCb);
  }

  private async loadHistory(): Promise<void> {
    this.searchHistory = await SearchHistoryManager.list();
  }

  private async loadHotKeywords(): Promise<void> {
    try {
      const list = await FilmApi.getHotKeywords();
      if (list && list.length > 0) {
        this.hotKeywords = list;
        return;
      }
    } catch (_e) {
    }
    if (this.hotKeywords.length === 0) {
      this.hotKeywords = SearchPage.DEFAULT_HOT_KEYWORDS.slice();
    }
  }

  private confirmClearHistory(): void {
    this.getUIContext().showAlertDialog({
      title: '清空搜索历史',
      message: '确定要清空全部搜索记录吗？',
      primaryButton: {
        value: '清空',
        fontColor: AppTheme.DANGER,
        action: () => {
          SearchHistoryManager.clear().then(() => {
            this.loadHistory();
            try {
              this.getUIContext().getPromptAction().showToast({ message: '已清空搜索历史' });
            } catch (_e) {
            }
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
      if (reset && !fromPull) {
        try {
          this.getUIContext().getPromptAction().showToast({ message: '请输入搜索关键词' });
        } catch (_e) {
        }
      }
      return;
    }
    const nextPage = reset ? 1 : this.page.current + 1;
    if (!reset && nextPage > this.page.pageCount) {
      return;
    }
    if (this.fetchLock) {
      return;
    }
    if (reset) {
      HttpClient.getInstance().trackView('search', kw);
      this.errorText = '';
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
      this.errorText = '';
      this.page = result.page;
      this.list = reset ? result.list : this.list.concat(result.list);
      ok = true;
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : '网络连接失败，请稍后重试';
      if (reset) {
        this.submitted = kw;
        this.errorText = errorMsg;
        this.list = reset && !fromPull ? [] : this.list;
      }
      try {
        this.getUIContext().getPromptAction().showToast({
          message: reset ? `搜索失败: ${errorMsg}` : `加载更多失败: ${errorMsg}`
        });
      } catch (_e) {
      }
    } finally {
      this.fetchLock = false;
      this.loading = false;
      this.loadingMore = false;
      this.refreshing = false;
      if (fromPull && ok) {
        RefreshHint.succeed();
      }
      this.hideKeyboard();
    }
  }

  build() {
    Column() {
      // Top search bar with Back button
      Row() {
        BackIcon({ color: AppTheme.TEXT_PRIMARY })
          .onClick(() => {
            this.hideKeyboard();
            try {
              this.getUIContext().getRouter().back();
            } catch (_e) {
            }
          })

        Row() {
          AppIcon({
            src: $r('sys.symbol.magnifyingglass'),
            iconSize: 18,
            color: AppTheme.TEXT_MUTED
          })
          TextInput({
            text: this.keyword,
            placeholder: this.getSearchPlaceholder(),
            controller: this.inputController
          })
            .id('SearchPage_Input')
            .defaultFocus(true)
            .layoutWeight(1)
            .height(40)
            .fontSize(14)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .placeholderColor(AppTheme.TEXT_MUTED)
            .caretColor(AppTheme.ACCENT)
            .backgroundColor(Color.Transparent)
            .cancelButton({ style: CancelButtonStyle.INVISIBLE })
            .padding({ left: 8, right: 8 })
            .enterKeyType(EnterKeyType.Search)
            .onChange((val: string) => {
              this.keyword = val;
              if (!val.trim() && (this.submitted || this.errorText)) {
                this.submitted = '';
                this.errorText = '';
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
              this.errorText = '';
              this.list = [];
              this.hideKeyboard();
            })
          }
        }
        .layoutWeight(1)
        .height(40)
        .padding({ left: 12, right: 8 })
        .backgroundColor(AppTheme.BG_CARD)
        .borderRadius(AppTheme.RADIUS_PILL)
        .margin({ left: 4 })

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
      .padding({ left: 8, right: 16, top: 8, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      if (this.loading) {
        LoadingView({ label: '正在搜索' })
      } else if (this.errorText) {
        Refresh({ refreshing: $$this.refreshing }) {
          Scroll() {
            Column() {
              Blank().height(80)
              EmptyState({
                title: '搜索失败',
                subtitle: this.errorText,
                icon: $r('sys.symbol.info_circle'),
                actionText: '重新搜索',
                onAction: () => {
                  this.doSearch(true);
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
          .nestedScroll({
            scrollForward: NestedScrollMode.SELF_FIRST,
            scrollBackward: NestedScrollMode.SELF_FIRST
          })
          .width('100%')
          .height('100%')
        }
        .onRefreshing(() => {
          if (this.fetchLock) {
            this.refreshing = false;
            return;
          }
          this.doSearch(true, true);
        })
        .pullToRefresh(!this.fetchLock)
        .layoutWeight(1)
      } else if (!this.submitted) {
        Scroll() {
          Column() {
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
                      Row() {
                        Text(item)
                          .fontSize(13)
                          .fontColor(AppTheme.TEXT_SECONDARY)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .constraintSize({ maxWidth: 200 })
                      }
                      .padding({ left: 12, right: 4, top: 6, bottom: 6 })
                      .onClick(() => {
                        this.hideKeyboard();
                        this.keyword = item;
                        this.doSearch(true);
                      })

                      Row() {
                        AppIcon({
                          src: $r('sys.symbol.xmark'),
                          iconSize: 10,
                          color: AppTheme.TEXT_MUTED
                        })
                      }
                      .width(22)
                      .height(28)
                      .justifyContent(FlexAlign.Center)
                      .padding({ right: 6 })
                      .onClick(() => {
                        SearchHistoryManager.remove(item).then(() => {
                          this.loadHistory();
                        });
                      })
                    }
                    .margin({ right: 8, bottom: 8 })
                    .backgroundColor(AppTheme.BG_CARD)
                    .borderRadius(AppTheme.RADIUS_PILL)
                  }, (item: string) => item)
                }
                .padding({ left: 16, right: 16 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .margin({ bottom: 16 })
            }

            if (this.hotKeywords.length > 0) {
              Column() {
                Row() {
                  AppIcon({
                    src: $r('sys.symbol.flame_fill'),
                    iconSize: 15,
                    color: AppTheme.ACCENT
                  })
                  Text('热门搜索')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.TEXT_PRIMARY)
                    .margin({ left: 6 })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 8, bottom: 12 })

                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.hotKeywords, (item: string, index: number) => {
                    Row() {
                      Text(`${index + 1}`)
                        .fontSize(11)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(index < 3 ? AppTheme.ACCENT : AppTheme.TEXT_MUTED)
                        .margin({ right: 6 })
                      Text(item)
                        .fontSize(13)
                        .fontColor(AppTheme.TEXT_PRIMARY)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .constraintSize({ maxWidth: 200 })
                    }
                    .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                    .margin({ right: 8, bottom: 8 })
                    .backgroundColor(index < 3 ? AppTheme.BG_CHIP : AppTheme.BG_CARD)
                    .border({
                      width: 1,
                      color: index < 3 ? AppTheme.ACCENT_SOFT : AppTheme.BORDER
                    })
                    .borderRadius(AppTheme.RADIUS_PILL)
                    .onClick(() => {
                      this.hideKeyboard();
                      this.keyword = item;
                      this.doSearch(true);
                    })
                  }, (item: string) => item)
                }
                .padding({ left: 16, right: 16 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            if (this.searchHistory.length === 0 && this.hotKeywords.length === 0) {
              EmptyState({
                title: '搜索影片',
                subtitle: '输入片名、演员或关键词',
                icon: $r('sys.symbol.magnifyingglass')
              })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Start)
          .padding({ bottom: this.bottomInset + 20 })
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
        .onClick(() => {
          this.hideKeyboard();
        })
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
            .edgeEffect(EdgeEffect.None)
            .nestedScroll({
              scrollForward: NestedScrollMode.SELF_FIRST,
              scrollBackward: NestedScrollMode.SELF_FIRST
            })
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
                  SearchResultItem({
                    film: film,
                    onSelect: (selected: MovieBasicInfo) => {
                      this.hideKeyboard();
                      NavUtil.openPlay(selected.id);
                    }
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
                    .padding({ top: 8, bottom: this.bottomInset + 32 })
                    .onClick(() => this.doSearch(false))
                } else {
                  Text('没有更多了')
                    .fontSize(12)
                    .fontColor(AppTheme.TEXT_MUTED)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding({ top: 8, bottom: this.bottomInset + 32 })
                }
              }
            }
            .width('100%')
            .height('100%')
            .padding({ left: 16, right: 16 })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.None)
            .nestedScroll({
              scrollForward: NestedScrollMode.SELF_FIRST,
              scrollBackward: NestedScrollMode.SELF_FIRST
            })
            .onScrollFrameBegin((offset: number, _state: ScrollState) => {
              this.hideKeyboard();
              return { offsetRemain: offset };
            })
            .onReachEnd(() => {
              this.doSearch(false);
            })
          }
        }
        .onRefreshing(() => {
          if (this.fetchLock) {
            this.refreshing = false;
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
    .padding({ top: this.topInset })
    .backgroundColor(AppTheme.BG)
  }
}
