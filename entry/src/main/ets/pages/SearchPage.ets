import { common } from '@kit.AbilityKit';
import { FilmApi } from '../api/FilmApi';
import { MovieBasicInfo, PageInfo, SearchSourceTab } from '../types/FilmModels';
import { AppTheme } from '../common/constants/AppTheme';
import { NavUtil } from '../common/utils/NavUtil';
import { WindowBar } from '../common/utils/WindowBar';
import { EmptyState } from '../components/common/EmptyState';
import { LoadingView } from '../components/common/LoadingView';
import { AppIcon } from '../components/common/AppIcon';
import { BackIcon } from '../components/common/BackIcon';
import { SourceGuard } from '../services/SourceGuard';
import { FavoriteManager } from '../services/FavoriteManager';
import { RefreshHint } from '../common/utils/RefreshHint';
import { SearchHistoryManager } from '../services/SearchHistoryManager';
import { HttpClient } from '../common/network/HttpClient';
import { SearchResultRows } from '../components/film/SearchResultRows';
import { SearchSourceTabs } from '../components/film/SearchSourceTabs';
import { SearchSuggestPane } from '../components/film/SearchSuggestPane';
import { applyCached, executeSearch, SearchBag } from '../services/SearchSourceCache';


@Entry
@Component
struct SearchPage {
  @State keyword: string = '';
  @State submitted: string = '';
  @State list: MovieBasicInfo[] = [];
  @State sources: SearchSourceTab[] = [];
  @State source: string = '';
  @State page: PageInfo = { pageSize: 10, current: 1, pageCount: 0, total: 0 };
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State searchHistory: string[] = [];
  @State hotKeywords: string[] = [];
  @State private refreshing: boolean = false;
  @State private errorText: string = '';
  @State private sourceError: string = '';
  @State private fetchLock: boolean = false;
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  @State private leftInset: number = 0;
  @State private rightInset: number = 0;
  @StorageLink('WIDTH_BP') private widthBp: string = 'sm';
  private reconnectCb: () => void = () => {};
  private inputController: TextInputController = new TextInputController();
  private bag: SearchBag = new SearchBag();
  private static readonly DEFAULT_HOT_KEYWORDS: string[] = [
    '凡人修仙传', '庆余年', '仙逆', '吞噬星空', '遮天', '斗破苍穹', '白夜破晓', '大奉打更人'
  ];

  private hideKeyboard(): void {
    try { this.inputController.stopEditing(); } catch (_e) {}
    setTimeout(() => {
      try { this.inputController.stopEditing(); } catch (_e) {}
    }, 50);
  }

  private getSearchPlaceholder(): string {
    if (this.hotKeywords.length > 0 && this.hotKeywords[0]) {
      return `大家都在搜：${this.hotKeywords[0]}`;
    }
    return '搜索电影、剧集、动漫';
  }

  private applyWindowBar(): void {
    WindowBar.apply(this.getUIContext().getHostContext() as common.UIAbilityContext, (top: number, bottom: number, left: number, right: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
      this.leftInset = left;
      this.rightInset = right;
    });
  }

  aboutToAppear() {
    this.applyWindowBar();
    FavoriteManager.preload();
    this.loadHistory();
    this.loadHotKeywords();
    const params = this.getUIContext().getRouter().getParams();
    const initialKw = NavUtil.param(params, 'keyword');
    if (initialKw) {
      this.keyword = initialKw;
      this.doSearch(true, false);
    }
    this.reconnectCb = () => {
      FavoriteManager.preload();
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
    FavoriteManager.preload();
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
        try { this.getUIContext().getPromptAction().showToast({ message: '已清空搜索历史' }); } catch (_e) {}
          });
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }

  private syncBag(): void {
    this.list = this.bag.list;
    this.page = this.bag.page;
    this.sources = this.bag.sources;
    this.loading = this.bag.loading;
    this.submitted = this.bag.submitted;
    this.errorText = this.bag.errorText;
    this.sourceError = this.bag.sourceError;
  }

  private applySource(id: string): void {
    this.source = id;
    this.bag.source = id;
    applyCached(this.bag, id);
    this.syncBag();
  }

  private async doSearch(reset: boolean, fromPull: boolean = false, keepSource: boolean = false): Promise<void> {
    const kw = this.keyword.trim();
    if (!kw) {
      this.refreshing = false;
      if (reset && !fromPull) {
        try { this.getUIContext().getPromptAction().showToast({ message: '请输入搜索关键词' }); } catch (_e) {}
      }
      return;
    }
    if (!reset && this.page.current + 1 > this.page.pageCount) {
      return;
    }
    if (this.fetchLock) {
      return;
    }
    if (reset && !keepSource && !fromPull) {
      this.source = '';
    }
    if (reset) {
      HttpClient.getInstance().trackView('search', kw, 'SearchPage');
      this.errorText = '';
      this.sourceError = '';
      SearchHistoryManager.add(kw).then(() => {
        this.loadHistory();
      });
    } else {
      this.loadingMore = true;
    }
    this.fetchLock = true;
    this.bag.source = this.source;
    this.bag.list = this.list;
    this.bag.page = this.page;
    this.bag.sources = this.sources;
    this.bag.loading = this.loading;
    this.bag.submitted = this.submitted;
    this.bag.errorText = this.errorText;
    this.bag.sourceError = this.sourceError;
    let ok = false;
    try {
      ok = await executeSearch(this.bag, kw, reset, fromPull, () => {
        this.syncBag();
      });
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : '网络连接失败，请稍后重试';
      if (reset) {
        this.submitted = kw;
        this.errorText = errorMsg;
        this.list = fromPull ? this.list : [];
      }
      try {
        this.getUIContext().getPromptAction().showToast({
          message: reset ? `搜索失败: ${errorMsg}` : `加载更多失败: ${errorMsg}`
        });
      } catch (_e) {
      }
    } finally {
      this.fetchLock = false;
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
              if (!val.trim() && (this.submitted || this.errorText || this.sourceError)) {
                this.submitted = '';
                this.errorText = '';
                this.sourceError = '';
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
              this.sourceError = '';
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
      .constraintSize({ maxWidth: AppTheme.CONTENT_MAX_WIDTH })
      .padding({ left: 8, right: 16, top: 8, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      SearchSourceTabs({
        sources: this.sources,
        activeId: this.source,
        onChange: (id: string) => {
          if (id === this.source || !this.submitted) {
            return;
          }
          this.applySource(id);
        }
      })

      if (this.loading) {
        LoadingView({ label: this.source ? '正在搜索该采集源' : '正在搜索' })
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
        SearchSuggestPane({
          searchHistory: this.searchHistory,
          hotKeywords: this.hotKeywords,
          onSelectKeyword: (kw: string) => {
            this.hideKeyboard();
            this.keyword = kw;
            this.doSearch(true);
          },
          onClearHistory: () => {
            this.confirmClearHistory();
          },
          onRemoveHistory: (item: string) => {
            SearchHistoryManager.remove(item).then(() => {
              this.loadHistory();
            });
          }
        })
      } else if (this.list.length === 0) {
        Refresh({ refreshing: $$this.refreshing }) {
          Scroll() {
            Column() {
              Blank().height(80)
              if (this.sourceError) {
                EmptyState({
                  title: '该采集源搜索失败',
                  subtitle: this.sourceError,
                  icon: $r('sys.symbol.info_circle'),
                  actionText: '重新搜索',
                  onAction: () => {
                    this.doSearch(true, false, true);
                  }
                })
              } else {
                EmptyState({
                  title: '未找到相关影片',
                  subtitle: `未找到与“${this.submitted}”相关的影片\n建议缩短或更换搜索词，也可以尝试切换其他采集源`,
                  icon: $r('sys.symbol.film')
                })
              }
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
          this.doSearch(true, true, true);
        })
        .pullToRefresh(!this.fetchLock)
        .layoutWeight(1)
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          Column() {
            List({ space: 12 }) {
              ListItem() {
                SearchResultRows({
                  list: this.list,
                  widthBp: this.widthBp,
                  onSelect: (selected: MovieBasicInfo) => {
                    this.hideKeyboard();
                    NavUtil.openPlay(selected.id, selected.sourceId, undefined, undefined,
                      selected.sourceMid > 0 ? `${selected.sourceMid}` : '');
                  }
                })
              }

              ListItem() {
                Text(this.loadingMore ? '加载中...' : (this.page.current >= this.page.pageCount ? '没有更多了' : ''))
                  .fontSize(12)
                  .fontColor(AppTheme.TEXT_MUTED)
                  .width('100%')
                  .height(60)
                  .textAlign(TextAlign.Center)
              }
            }
            .width('100%')
            .height('100%')
            .padding({ left: 16, right: 16, top: 8 })
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
          .width('100%')
          .height('100%')
          .constraintSize({ maxWidth: AppTheme.CONTENT_MAX_WIDTH })
        }
        .onRefreshing(() => {
          if (this.fetchLock) {
            this.refreshing = false;
            return;
          }
          this.doSearch(true, true, true);
        })
        .pullToRefresh(!this.fetchLock)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.topInset,
      bottom: this.bottomInset,
      left: this.leftInset,
      right: this.rightInset
    })
    .backgroundColor(AppTheme.BG)
  }
}
