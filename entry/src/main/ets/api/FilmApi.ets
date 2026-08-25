import { HttpClient } from '../common/network/HttpClient';
import { QueryParams } from '../common/utils/QueryParams';
import { ApiParser } from '../model/ApiParser';
import {
  BasicConfig,
  CategoryItem,
  ClassifyResult,
  FilterResult,
  HomeData,
  MovieBasicInfo,
  PlayInfo,
  SearchResult
} from '../model/FilmModels';

export class FilmApi {
  private static siteConfig: BasicConfig | null = null;
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
    const res = await HttpClient.getInstance().get('/index');
    if (res.code !== 0 || !res.data) {
      throw new Error(res.msg || '首页数据获取失败');
    }
    return ApiParser.parseHome(res.data as Object);
  }

  static async getDailyUpdates(limit: number = 0, exclude: string = ''): Promise<MovieBasicInfo[]> {
    const params = new QueryParams();
    if (limit > 0) {
      params.set('limit', limit);
    }
    if (exclude) {
      params.set('exclude', exclude);
    }
    const res = await HttpClient.getInstance().get('/index/dailyUpdates', params);
    if (res.code !== 0) {
      return [];
    }
    if (Array.isArray(res.data)) {
      return ApiParser.parseMovies(res.data as Object[]);
    }
    return [];
  }

  static async getNavCategory(): Promise<CategoryItem[]> {
    const res = await HttpClient.getInstance().get('/navCategory');
    if (res.code !== 0 || !res.data) {
      return [];
    }
    if (Array.isArray(res.data)) {
      return ApiParser.parseCategories(res.data as Object[]);
    }
    return [];
  }

  static async getSiteConfig(force: boolean = false): Promise<BasicConfig> {
    if (!force && FilmApi.siteConfig) {
      return FilmApi.siteConfig;
    }
    const res = await HttpClient.getInstance().get('/config/basic');
    if (res.code !== 0 || !res.data) {
      throw new Error(res.msg || '站点配置获取失败');
    }
    const config = ApiParser.parseBasicConfig(res.data as Object);
    FilmApi.siteConfig = config;
    for (let i = 0; i < FilmApi.configListeners.length; i++) {
      FilmApi.configListeners[i](config);
    }
    return config;
  }

  static clearSiteConfig(): void {
    FilmApi.siteConfig = null;
  }

  static async searchFilm(keyword: string, current: number = 1): Promise<SearchResult> {
    const params = new QueryParams().set('keyword', keyword).set('current', current);
    const res = await HttpClient.getInstance().get('/searchFilm', params);
    if (res.code !== 0 || !res.data) {
      const empty: SearchResult = {
        list: [],
        page: { pageSize: 10, current: current, pageCount: 0, total: 0 }
      };
      return empty;
    }
    return ApiParser.parseSearch(res.data as Object);
  }

  static async getClassify(pid: string): Promise<ClassifyResult> {
    const params = new QueryParams().set('Pid', pid);
    const res = await HttpClient.getInstance().get('/filmClassify', params);
    if (res.code !== 0 || !res.data) {
      throw new Error(res.msg || '分类数据获取失败');
    }
    return ApiParser.parseClassify(res.data as Object);
  }

  static async getFilter(query: QueryParams): Promise<FilterResult> {
    const res = await HttpClient.getInstance().get('/filmClassifySearch', query);
    if (res.code !== 0 || !res.data) {
      throw new Error(res.msg || '筛选数据获取失败');
    }
    return ApiParser.parseFilter(res.data as Object);
  }

  static async getPlayInfo(id: string, playFrom: string = '', episode: number = 0): Promise<PlayInfo> {
    const params = new QueryParams()
      .set('id', id)
      .set('playFrom', playFrom)
      .set('episode', episode);
    const res = await HttpClient.getInstance().get('/filmPlayInfo', params, 20000);
    if (res.code !== 0 || !res.data) {
      throw new Error(res.msg || '播放数据获取失败');
    }
    return ApiParser.parsePlay(res.data as Object);
  }

  static async getRelate(id: string): Promise<MovieBasicInfo[]> {
    const params = new QueryParams().set('id', id);
    const res = await HttpClient.getInstance().get('/filmRelate', params);
    if (res.code !== 0 || !res.data) {
      return [];
    }
    if (Array.isArray(res.data)) {
      return ApiParser.parseMovies(res.data as Object[]);
    }
    return [];
  }
}

