import { preferences } from '@kit.ArkData';

export enum ServerProtocolVersion {
  V2 = 2,
  V3 = 3,
}

export enum ApiEndpoint {
  HOME,
  DAILY_UPDATES,
  CATEGORIES,
  CATEGORY_OVERVIEW,
  PLAY_INFO,
  RELATED,
  SEARCH,
  FILTER,
  HOT_KEYWORDS,
  STATS_VIEW,
  DANMAKU,
  LIVE_PLAY_INFO,
  LIVE_RELATE,
}

export interface PlayRouteTarget {
  url: string;
  params: Record<string, Object>;
}

export class ServerCompat {
  private static instance: ServerCompat;
  private version: ServerProtocolVersion = ServerProtocolVersion.V3;
  private rawVersionStr: string = '';
  private pref: preferences.Preferences | null = null;

  private constructor() {}

  public static getInstance(): ServerCompat {
    if (!ServerCompat.instance) {
      ServerCompat.instance = new ServerCompat();
    }
    return ServerCompat.instance;
  }

  public get protocolVersion(): ServerProtocolVersion {
    return this.version;
  }

  public get isV3(): boolean {
    return this.version === ServerProtocolVersion.V3;
  }

  public get isV2(): boolean {
    return this.version === ServerProtocolVersion.V2;
  }

  public get rawVersion(): string {
    return this.rawVersionStr;
  }

  // 特性开关
  public get canCmsDirectSearch(): boolean {
    return this.isV2;
  }

  public get canLivePlay(): boolean {
    return this.isV2;
  }

  public get canDanmaku(): boolean {
    return this.isV3;
  }

  public attachPreferences(pref: preferences.Preferences | null, hostScope: string = ''): void {
    this.pref = pref;
    if (hostScope && this.pref) {
      try {
        const cached = this.pref.getSync(`protocol_ver@${hostScope}`, '') as string;
        if (cached === 'v2') {
          this.version = ServerProtocolVersion.V2;
        } else if (cached === 'v3') {
          this.version = ServerProtocolVersion.V3;
        }
      } catch (_e) {}
    }
  }

  public switchHostScope(hostScope: string): void {
    if (!hostScope || !this.pref) return;
    try {
      const cached = this.pref.getSync(`protocol_ver@${hostScope}`, '') as string;
      if (cached === 'v2') {
        this.version = ServerProtocolVersion.V2;
      } else if (cached === 'v3') {
        this.version = ServerProtocolVersion.V3;
      }
    } catch (_e) {}
  }

  public async updateFromProvideApp(data: Object | null, hostScope: string): Promise<void> {
    let ver = '';
    let protocol = 0;
    if (data && typeof data === 'object') {
      const record = data as Record<string, Object>;
      if (record['version'] !== undefined && record['version'] !== null) {
        ver = String(record['version']).trim().toLowerCase();
      }
      if (typeof record['protocol'] === 'number') {
        protocol = record['protocol'] as number;
      }
    }
    this.rawVersionStr = ver;
    if (protocol >= 3 || ver.startsWith('v3.') || ver.startsWith('3.')) {
      this.version = ServerProtocolVersion.V3;
    } else if (protocol === 2 || ver.startsWith('v2.') || ver.startsWith('2.')) {
      this.version = ServerProtocolVersion.V2;
    } else {
      this.version = ServerProtocolVersion.V3;
    }
    if (hostScope && this.pref) {
      try {
        await this.pref.put(`protocol_ver@${hostScope}`, this.isV3 ? 'v3' : 'v2');
        await this.pref.flush();
      } catch (_e) {}
    }
  }

  public async markFallbackV2(hostScope: string): Promise<void> {
    this.version = ServerProtocolVersion.V2;
    this.rawVersionStr = 'v2.x-legacy';
    if (hostScope && this.pref) {
      try {
        await this.pref.put(`protocol_ver@${hostScope}`, 'v2');
        await this.pref.flush();
      } catch (_e) {}
    }
  }

  public endpoint(ep: ApiEndpoint): string {
    if (this.isV3) {
      switch (ep) {
        case ApiEndpoint.HOME:
          return '/home';
        case ApiEndpoint.DAILY_UPDATES:
          return '/daily-updates';
        case ApiEndpoint.CATEGORIES:
          return '/categories';
        case ApiEndpoint.CATEGORY_OVERVIEW:
          return '/categories/overview';
        case ApiEndpoint.PLAY_INFO:
          return '/films/play-info';
        case ApiEndpoint.RELATED:
          return '/films/related';
        case ApiEndpoint.SEARCH:
          return '/films/search';
        case ApiEndpoint.FILTER:
          return '/films/filter';
        case ApiEndpoint.HOT_KEYWORDS:
          return '/search/hot-keywords';
        case ApiEndpoint.STATS_VIEW:
          return '/stats/view';
        case ApiEndpoint.DANMAKU:
          return '/film/danmaku';
        case ApiEndpoint.LIVE_PLAY_INFO:
          return '/films/play-info';
        case ApiEndpoint.LIVE_RELATE:
          return '/films/related';
      }
    } else {
      switch (ep) {
        case ApiEndpoint.HOME:
          return '/index';
        case ApiEndpoint.DAILY_UPDATES:
          return '/dailyUpdates';
        case ApiEndpoint.CATEGORIES:
          return '/navCategory';
        case ApiEndpoint.CATEGORY_OVERVIEW:
          return '/filmClassify';
        case ApiEndpoint.PLAY_INFO:
          return '/filmPlayInfo';
        case ApiEndpoint.RELATED:
          return '/filmRelate';
        case ApiEndpoint.SEARCH:
          return '/searchFilm';
        case ApiEndpoint.FILTER:
          return '/filmClassifySearch';
        case ApiEndpoint.HOT_KEYWORDS:
          return '/hotKeywords';
        case ApiEndpoint.STATS_VIEW:
          return '/stat/view';
        case ApiEndpoint.DANMAKU:
          return '';
        case ApiEndpoint.LIVE_PLAY_INFO:
          return '/liveFilmPlayInfo';
        case ApiEndpoint.LIVE_RELATE:
          return '/liveFilmRelate';
      }
    }
  }

  public resolvePlayTarget(
    id: string | number,
    sourceId: string = '',
    sourceMid: string = '',
    episodeIndex?: number,
    currentTime?: number,
    title?: string
  ): PlayRouteTarget {
    const cleanId = `${id || ''}`.trim();
    const isLocalId = cleanId !== '' &&
      cleanId !== '0' &&
      cleanId.indexOf(':') < 0 &&
      !Number.isNaN(Number(cleanId));

    const params: Record<string, Object> = { 'id': cleanId };
    if (sourceId) params['sourceId'] = sourceId;
    if (episodeIndex !== undefined && episodeIndex >= 0) params['episodeIndex'] = `${episodeIndex}`;
    if (currentTime !== undefined && currentTime >= 0) params['currentTime'] = `${currentTime}`;
    if (title) params['title'] = title;

    if (this.isV3 || isLocalId) {
      return { url: 'pages/PlayPage', params };
    }

    let liveSource = sourceId;
    let liveSid = sourceMid;
    if (cleanId.indexOf(':') >= 0) {
      const parts = cleanId.split(':');
      if (parts.length >= 2) {
        liveSource = parts[0];
        liveSid = parts[1];
      }
    }
    if (!liveSource || !liveSid) {
      return { url: '', params: {} };
    }
    const liveParams: Record<string, Object> = {
      'id': '',
      'sourceId': liveSource,
      'sourceMid': liveSid,
    };
    if (episodeIndex !== undefined && episodeIndex >= 0) liveParams['episodeIndex'] = `${episodeIndex}`;
    if (currentTime !== undefined && currentTime >= 0) liveParams['currentTime'] = `${currentTime}`;
    if (title) liveParams['title'] = title;
    return { url: 'pages/LivePlayPage', params: liveParams };
  }
}
