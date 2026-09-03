import { UIContext } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';

export interface PlayRouteParams {
  id: string;
  sourceId?: string;
  episodeIndex?: string;
  currentTime?: string;
}

export interface FilterRouteParams {
  Pid: string;
  Category: string;
  Sort: string;
}

export interface SearchRouteParams {
  keyword: string;
}

export class NavUtil {
  private static getRouter(uiContext?: UIContext) {
    const ctx = uiContext || AppStorage.get<UIContext>('UI_CONTEXT');
    return ctx ? ctx.getRouter() : undefined;
  }

  static openHistory(uiContext?: UIContext): void {
    try {
      const r = NavUtil.getRouter(uiContext);
      if (r) {
        r.pushUrl({ url: 'pages/HistoryPage' });
      }
    } catch (_e) {
    }
  }

  static openTip(uiContext?: UIContext): void {
    try {
      const r = NavUtil.getRouter(uiContext);
      if (r) {
        r.pushUrl({ url: 'pages/TipPage' });
      }
    } catch (_e) {
    }
  }

  static openPlay(id: string | number, sourceId: string = '', episodeIndex?: number,
    currentTime?: number, uiContext?: UIContext): void {
    if (!id && id !== 0) {
      return;
    }
    const params: PlayRouteParams = {
      id: `${id}`
    };
    if (sourceId) {
      params.sourceId = sourceId;
    }
    if (episodeIndex !== undefined && episodeIndex >= 0) {
      params.episodeIndex = `${episodeIndex}`;
    }
    if (currentTime !== undefined && currentTime >= 0) {
      params.currentTime = `${currentTime}`;
    }
    try {
      const r = NavUtil.getRouter(uiContext);
      if (r) {
        r.pushUrl({
          url: 'pages/PlayPage',
          params: params
        });
      }
    } catch (_e) {
    }
  }

  static openFilter(pid: string | number, category: string = '', sort: string = '', uiContext?: UIContext): void {
    const params: FilterRouteParams = {
      Pid: `${pid}`,
      Category: category,
      Sort: sort
    };
    try {
      const r = NavUtil.getRouter(uiContext);
      if (r) {
        r.pushUrl({
          url: 'pages/FilterPage',
          params: params
        });
      }
    } catch (_e) {
    }
  }

  static openSearch(keyword: string = '', uiContext?: UIContext): void {
    try {
      const r = NavUtil.getRouter(uiContext);
      if (!r) {
        return;
      }
      if (keyword) {
        const params: SearchRouteParams = { keyword: keyword };
        r.pushUrl({
          url: 'pages/SearchPage',
          params: params
        });
        return;
      }
      r.pushUrl({
        url: 'pages/SearchPage'
      });
    } catch (_e) {
    }
  }

  static openCustomPlayer(url: string = '', uiContext?: UIContext): void {
    try {
      const r = NavUtil.getRouter(uiContext);
      if (!r) {
        return;
      }
      if (url) {
        r.pushUrl({
          url: 'pages/CustomPlayerPage',
          params: { url: url }
        });
        return;
      }
      r.pushUrl({
        url: 'pages/CustomPlayerPage'
      });
    } catch (_e) {
    }
  }

  static openBrowser(context: common.UIAbilityContext, url: string): void {
    if (!url) {
      return;
    }
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url
    };
    try {
      context.startAbility(want).catch((_err: Object) => {
        try {
          context.openLink(url).catch((_e: Object) => {});
        } catch (_e) {}
      });
    } catch (_err) {
      try {
        context.openLink(url).catch((_e: Object) => {});
      } catch (_e) {}
    }
  }

  static param(params: Object | undefined | null, key: string, fallback: string = ''): string {
    if (!params) {
      return fallback;
    }
    const record = params as Record<string, Object>;
    const value = record[key];
    if (value === undefined || value === null) {
      return fallback;
    }
    return `${value}`;
  }
}
