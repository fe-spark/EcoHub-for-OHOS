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
  SearchResult,
  SearchSourceTab
} from '../types/FilmModels';
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

  static async getDanmaku(mid: string, episode: number, title: string): Promise<DanmakuComment[]> {
    if (!ServerCompat.getInstance().canDanmaku) {
      console.info('[Danmaku] 当前非 V3 协议或环境不支持弹幕特性，跳过请求');
      return [];
    }
    const params = new QueryParams()
      .set('mid', mid)
      .set('episode', episode)
      .set('title', title);
    try {
      const ep = ServerCompat.getInstance().endpoint(ApiEndpoint.DANMAKU);
      console.info(`[Danmaku] 请求弹幕: ep=${ep} mid=${mid} epNum=${episode} title=${title}`);
      const res = await HttpClient.getInstance().get(ep, params);
      if ((res.code !== 0 && res.code !== 1) || !Array.isArray(res.data)) {
        console.warn(`[Danmaku] 响应异常或无数据: code=${res.code} msg=${res.msg}`);
        return [];
      }
      const list: DanmakuComment[] = [];
      const raw = res.data as Object[];
      for (let i = 0; i < raw.length; i++) {
        const row = ApiParser.asRecord(raw[i]);
        const text = ApiParser.str(row, 'text');
        if (!text) {
          continue;
        }
        list.push({
          text: text,
          time: ApiParser.num(row, 'time'),
          color: ApiParser.str(row, 'color', '#ffffff'),
          mode: ApiParser.num(row, 'mode')
        });
      }
      console.info(`[Danmaku] 成功解析弹幕列表: ${list.length} 条`);
      return list;
    } catch (err) {
      console.error(`[Danmaku] 请求发生异常: ${err instanceof Error ? err.message : JSON.stringify(err)}`);
      return [];
    }
  }
}

