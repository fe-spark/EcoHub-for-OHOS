import { HttpClient } from '../common/network/HttpClient';
import { QueryParams } from '../common/utils/QueryParams';
import { ApiParser } from './ApiParser';
import { ApiEndpoint, ServerCompat } from '../services/ServerCompat';
import {
  BasicConfig,
  CategoryItem,
  ClassifyResult,
  DailyUpdateResult,
  FilterResult,
  HomeData,
  MovieBasicInfo,
  PlayInfo,
  DanmakuComment,
  DanmakuMeta,
  SearchResult,
  SearchSourceTab
} from '../types/FilmModels';

export interface DanmakuLoadResult {
  list: DanmakuComment[];
  meta: DanmakuMeta | null;
}

export class FilmApi {
  private static siteConfig: BasicConfig | null = null;
  private static configPromise: Promise<BasicConfig> | null = null;
  private static configListeners: Array<(config: BasicConfig) => void> = [];

  public static onConfigChange(listener: (config: BasicConfig) => void): void {
    if (FilmApi.configListeners.indexOf(listener) < 0) {
      FilmApi.configListeners.push(listener);
    }
  }

  public static offConfigChange(listener: (config: BasicConfig) => void): void {
    const next: Array<(config: BasicConfig) => void> = [];
    for (let i = 0; i < FilmApi.configListeners.length; i++) {
      if (FilmApi.configListeners[i] !== listener) {
        next.push(FilmApi.configListeners[i]);
      }
    }
    FilmApi.configListeners = next;
  }

  static async getHome(): Promise<HomeData> {
    const res = await HttpClient.getInstance().get(ServerCompat.getInstance().endpoint(ApiEndpoint.HOME));
    if (res.code !== 0 || !res.data) {
      throw new Error(res.msg || '首页数据获取失败');
    }
    return ApiParser.parseHome(res.data as Object);
  }

  static async getDailyUpdates(pid: number, current: number, pageSize: number = 21): Promise<DailyUpdateResult> {
    const params = new QueryParams()
      .set('pid', pid)
      .set('current', current)
      .set('pageSize', pageSize);
    const res = await HttpClient.getInstance().get(ServerCompat.getInstance().endpoint(ApiEndpoint.DAILY_UPDATES), params);
    if (res.code !== 0 || !res.data) {
      throw new Error(res.msg || '每日更新获取失败');
    }
    return ApiParser.parseDailyUpdate(res.data as Object);
  }

  static async getNavCategory(): Promise<CategoryItem[]> {
    const res = await HttpClient.getInstance().get(ServerCompat.getInstance().endpoint(ApiEndpoint.CATEGORIES));
    if (res.code !== 0 || !res.data) {
      return [];
    }
    if (Array.isArray(res.data)) {
      return ApiParser.parseCategories(res.data as Object[]);
    }
    return [];
  }

  static async getSiteConfig(force: boolean = false, timeout: number = 15000): Promise<BasicConfig> {
    if (!force && FilmApi.siteConfig) {
      return FilmApi.siteConfig;
    }
    if (!force && FilmApi.configPromise) {
      return FilmApi.configPromise;
    }
    const execute = async (): Promise<BasicConfig> => {
      const res = await HttpClient.getInstance().get('/config/basic', undefined, timeout);
      if (res.code !== 0 || !res.data) {
        throw new Error(res.msg || '站点配置获取失败');
      }
      const config = ApiParser.parseBasicConfig(res.data as Object);
      FilmApi.siteConfig = config;
      for (let i = 0; i < FilmApi.configListeners.length; i++) {
        try {
          FilmApi.configListeners[i](config);
        } catch (_e) {
        }
      }
      return config;
    };
    const reqPromise = execute();
    FilmApi.configPromise = reqPromise;
    reqPromise.finally(() => {
      if (FilmApi.configPromise === reqPromise) {
        FilmApi.configPromise = null;
      }
    }).catch(() => {});
    return reqPromise;
  }

  static clearSiteConfig(): void {
    FilmApi.siteConfig = null;
    FilmApi.configPromise = null;
  }

  static async getHotKeywords(limit: number = 8): Promise<string[]> {
    const params = new QueryParams().set('limit', limit);
    const res = await HttpClient.getInstance().get(ServerCompat.getInstance().endpoint(ApiEndpoint.HOT_KEYWORDS), params);
    if (res.code !== 0 || !res.data) {
      return [];
    }
    return ApiParser.parseStringList(res.data);
  }

  static async searchFilm(keyword: string, current: number = 1, source: string = ''): Promise<SearchResult> {
    const params = new QueryParams().set('keyword', keyword).set('current', current);
    if (source) {
      params.set('source', source);
    }
    const res = await HttpClient.getInstance().get(ServerCompat.getInstance().endpoint(ApiEndpoint.SEARCH), params);
    if (res.code !== 0 || !res.data) {
      const empty: SearchResult = {
        list: [],
        page: { pageSize: 10, current: current, pageCount: 0, total: 0 },
        sources: [] as SearchSourceTab[],
        error: '搜索失败'
      };
      return empty;
    }
    return ApiParser.parseSearch(res.data as Object);
  }

  static async getClassify(pid: string): Promise<ClassifyResult> {
    const params = new QueryParams().set('Pid', pid);
    const res = await HttpClient.getInstance().get(ServerCompat.getInstance().endpoint(ApiEndpoint.CATEGORY_OVERVIEW), params);
    if (res.code !== 0 || !res.data) {
      throw new Error(res.msg || '分类数据获取失败');
    }
    return ApiParser.parseClassify(res.data as Object);
  }

  static async getFilter(query: QueryParams): Promise<FilterResult> {
    const res = await HttpClient.getInstance().get(ServerCompat.getInstance().endpoint(ApiEndpoint.FILTER), query);
    if (res.code !== 0 || !res.data) {
      throw new Error(res.msg || '筛选数据获取失败');
    }
    return ApiParser.parseFilter(res.data as Object);
  }

  static async getPlayInfo(id: string, playFrom: string = '', episode: number = 0, sid: string = ''): Promise<PlayInfo> {
    if (ServerCompat.getInstance().isV2 && (!id || id === '0') && sid) {
      return FilmApi.getLivePlayInfo(playFrom, sid, episode);
    }
    const params = new QueryParams()
      .set('id', id)
      .set('playFrom', playFrom)
      .set('episode', episode);
    if (ServerCompat.getInstance().isV2 && sid) {
      params.set('sid', sid);
    }
    const res = await HttpClient.getInstance().get(ServerCompat.getInstance().endpoint(ApiEndpoint.PLAY_INFO), params, 20000);
    if (res.code !== 0 || !res.data) {
      throw new Error(res.msg || '播放数据获取失败');
    }
    return ApiParser.parsePlay(res.data as Object);
  }

  static async getLivePlayInfo(source: string, sid: string, episode: number = 0): Promise<PlayInfo> {
    const params = new QueryParams()
      .set('source', source)
      .set('sid', sid)
      .set('episode', episode);
    const res = await HttpClient.getInstance().get(ServerCompat.getInstance().endpoint(ApiEndpoint.LIVE_PLAY_INFO), params, 20000);
    if (res.code !== 0 || !res.data) {
      throw new Error(res.msg || '现场播放数据获取失败');
    }
    return ApiParser.parsePlay(res.data as Object);
  }

  static async getRelate(id: string): Promise<MovieBasicInfo[]> {
    const params = new QueryParams().set('id', id);
    const res = await HttpClient.getInstance().get(ServerCompat.getInstance().endpoint(ApiEndpoint.RELATED), params);
    if (res.code !== 0 || !res.data) {
      return [];
    }
    if (Array.isArray(res.data)) {
      return ApiParser.parseMovies(res.data as Object[]);
    }
    return [];
  }

  static async getLiveRelate(source: string, cid: number | string = 0, sid: number | string = 0): Promise<MovieBasicInfo[]> {
    const params = new QueryParams()
      .set('source', source)
      .set('cid', cid)
      .set('sid', sid);
    const res = await HttpClient.getInstance().get(ServerCompat.getInstance().endpoint(ApiEndpoint.LIVE_RELATE), params);
    if (res.code !== 0 || !res.data) {
      return [];
    }
    if (Array.isArray(res.data)) {
      return ApiParser.parseMovies(res.data as Object[]);
    }
    return [];
  }

  /** 0/1/2 为服务端归一化取值；4/5 为 B 站 / 弹弹play 原始取值（4 底部、5 顶部） */
  static normalizeDanmakuMode(v: number): number {
    const m = Math.floor(v);
    if (m === 1 || m === 5) {
      return 1;
    }
    if (m === 2 || m === 4) {
      return 2;
    }
    return 0;
  }

  /** 统一成 #RRGGBB：支持 #rgb、#rrggbb、#aarrggbb、0xrrggbb 与十进制整数（如 16777215） */
  static normalizeDanmakuColor(value: Object | undefined | null): string {
    if (value === undefined || value === null) {
      return '#FFFFFF';
    }
    if (typeof value === 'number') {
      return FilmApi.colorFromInt(value as number);
    }
    let s = `${value}`.trim();
    if (s.length === 0) {
      return '#FFFFFF';
    }
    if (s.startsWith('#')) {
      s = s.substring(1);
    } else if (s.toLowerCase().startsWith('0x')) {
      s = s.substring(2);
    } else if (/^\d+$/.test(s) && s.length !== 6) {
      // 无前缀的纯数字且不是 6 位：按 B 站 / 弹弹play 十进制颜色处理
      return FilmApi.colorFromInt(Number(s));
    }
    if (!/^[0-9a-fA-F]+$/.test(s)) {
      return '#FFFFFF';
    }
    if (s.length === 3) {
      s = `${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}`;
    }
    if (s.length === 8) {
      s = s.substring(2); // AARRGGBB
    }
    if (s.length !== 6) {
      return '#FFFFFF';
    }
    return `#${s.toUpperCase()}`;
  }

  private static colorFromInt(v: number): string {
    if (!isFinite(v) || v < 0 || v > 0xFFFFFF) {
      return '#FFFFFF';
    }
    let hex = Math.floor(v).toString(16).toUpperCase();
    while (hex.length < 6) {
      hex = '0' + hex;
    }
    return `#${hex}`;
  }

  private static toFlag(value: Object | undefined | null): boolean {
    if (value === undefined || value === null) {
      return false;
    }
    if (typeof value === 'boolean') {
      return value as boolean;
    }
    if (typeof value === 'number') {
      return (value as number) !== 0;
    }
    const s = `${value}`.trim().toLowerCase();
    return s === 'true' || s === '1';
  }

  private static parseDanmakuMeta(value: Object | null | undefined): DanmakuMeta | null {
    if (!value || typeof value !== 'object') {
      return null;
    }
    const row = ApiParser.asRecord(value);
    return {
      local: ApiParser.num(row, 'local'),
      network: ApiParser.num(row, 'network'),
      networkStatus: ApiParser.str(row, 'networkStatus'),
      networkReason: ApiParser.str(row, 'networkReason')
    };
  }

  /** 获取弹幕列表及响应顶层的 meta；接口返回失败码或网络异常时抛出，由调用方转成弹幕加载状态 */
  static async getDanmaku(mid: string, episode: number, title: string): Promise<DanmakuLoadResult> {
    if (!ServerCompat.getInstance().canDanmaku || !mid || mid.trim().length === 0) {
      console.info('[Danmaku] 当前非 V3 协议或缺少影片ID，跳过请求');
      return { list: [], meta: null };
    }
    const params = new QueryParams()
      .set('mid', mid)
      .set('episode', episode)
      .set('title', title);
    const ep = ServerCompat.getInstance().endpoint(ApiEndpoint.DANMAKU);
    console.info(`[Danmaku] 请求弹幕: ep=${ep} mid=${mid} epNum=${episode} title=${title}`);
    const res = await HttpClient.getInstance().get(ep, params);
    if (res.code !== 0 && res.code !== 1) {
      console.warn(`[Danmaku] 响应异常: code=${res.code} msg=${res.msg}`);
      throw new Error(res.msg || '');
    }
    const list: DanmakuComment[] = [];
    const raw: Object[] = Array.isArray(res.data) ? res.data as Object[] : [];
    for (let i = 0; i < raw.length; i++) {
      const row = ApiParser.asRecord(raw[i]);
      const text = ApiParser.str(row, 'text');
      if (!text) {
        continue;
      }
      const time = ApiParser.num(row, 'time', -1);
      if (!isFinite(time) || time < 0) {
        continue;
      }
      list.push({
        text: text,
        time: time,
        color: FilmApi.normalizeDanmakuColor(row['color']),
        mode: FilmApi.normalizeDanmakuMode(ApiParser.num(row, 'mode')),
        border: FilmApi.toFlag(row['border']) || FilmApi.toFlag(row['highlight'])
      });
    }
    console.info(`[Danmaku] 成功解析弹幕列表: ${list.length} 条`);
    return { list: list, meta: FilmApi.parseDanmakuMeta(res.meta) };
  }
}

