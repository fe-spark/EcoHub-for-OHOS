import router from '@ohos.router';

export class NavUtil {
  static openPlay(id: string | number, sourceId: string = '', episodeIndex: number = 0,
    currentTime: number = 0): void {
    if (!id && id !== 0) {
      return;
    }
    router.pushUrl({
      url: 'pages/PlayPage',
      params: {
        id: `${id}`,
        sourceId: sourceId,
        episodeIndex: `${episodeIndex}`,
        currentTime: `${currentTime}`
      }
    });
  }

  static openFilter(pid: string | number, category: string = '', sort: string = ''): void {
    router.pushUrl({
      url: 'pages/FilterPage',
      params: {
        Pid: `${pid}`,
        Category: category,
        Sort: sort
      }
    });
  }

  static openSearch(): void {
    router.pushUrl({
      url: 'pages/SearchPage'
    });
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
