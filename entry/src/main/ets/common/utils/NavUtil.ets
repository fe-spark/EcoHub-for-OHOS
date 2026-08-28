import { router } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';

export interface PlayRouteParams {
  id: string;
  sourceId: string;
  episodeIndex: string;
  currentTime: string;
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
  static openPlay(id: string | number, sourceId: string = '', episodeIndex: number = 0,
    currentTime: number = 0): void {
    if (!id && id !== 0) {
      return;
    }
    const params: PlayRouteParams = {
      id: `${id}`,
      sourceId: sourceId,
      episodeIndex: `${episodeIndex}`,
      currentTime: `${currentTime}`
    };
    router.pushUrl({
      url: 'pages/PlayPage',
      params: params
    });
  }

  static openFilter(pid: string | number, category: string = '', sort: string = ''): void {
    const params: FilterRouteParams = {
      Pid: `${pid}`,
      Category: category,
      Sort: sort
    };
    router.pushUrl({
      url: 'pages/FilterPage',
      params: params
    });
  }

  static openSearch(keyword: string = ''): void {
    if (keyword) {
      const params: SearchRouteParams = { keyword: keyword };
      router.pushUrl({
        url: 'pages/SearchPage',
        params: params
      });
      return;
    }
    router.pushUrl({
      url: 'pages/SearchPage'
    });
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
