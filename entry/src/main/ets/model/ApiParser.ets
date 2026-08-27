import {
  BannerItem,
  BasicConfig,
  CategoryItem,
  ClassifyResult,
  DailyUpdateCategory,
  DailyUpdateResult,
  FilterResult,
  FilterSearchMeta,
  HomeData,
  HomeSection,
  MovieBasicInfo,
  MovieDescriptor,
  MovieDetail,
  MovieUrlInfo,
  PageInfo,
  PlayInfo,
  PlaySource,
  SearchResult,
  TipChannel
} from './FilmModels';
import { FormatUtil } from '../common/utils/FormatUtil';

export class ApiParser {
  static asRecord(value: Object | null | undefined): Record<string, Object> {
    if (!value) {
      return {} as Record<string, Object>;
    }
    return value as Record<string, Object>;
  }

  static str(record: Record<string, Object>, key: string, fallback: string = ''): string {
    const value = record[key];
    if (value === undefined || value === null) {
      return fallback;
    }
    const text = `${value}`.trim();
    return text === '' ? fallback : text;
  }

  static num(record: Record<string, Object>, key: string, fallback: number = 0): number {
    const value = record[key];
    if (typeof value === 'number') {
      return value as number;
    }
    const parsed = Number(ApiParser.str(record, key, `${fallback}`));
    return isFinite(parsed) ? parsed : fallback;
  }

  static bool(record: Record<string, Object>, key: string, fallback: boolean = false): boolean {
    const value = record[key];
    if (typeof value === 'boolean') {
      return value as boolean;
    }
    return fallback;
  }

  static list(record: Record<string, Object>, key: string): Object[] {
    const value = record[key];
    if (Array.isArray(value)) {
      return value as Object[];
    }
    return [];
  }

  static obj(record: Record<string, Object>, key: string): Record<string, Object> {
    const value = record[key];
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return value as Record<string, Object>;
    }
    return {} as Record<string, Object>;
  }

  static parseMovie(raw: Object): MovieBasicInfo {
    const record = ApiParser.asRecord(raw);
    const item: MovieBasicInfo = {
      id: ApiParser.num(record, 'id'),
      cid: ApiParser.num(record, 'cid'),
      pid: ApiParser.num(record, 'pid'),
      name: ApiParser.str(record, 'name'),
      subTitle: ApiParser.str(record, 'subTitle'),
      cName: ApiParser.str(record, 'cName'),
      state: ApiParser.str(record, 'state'),
      picture: ApiParser.str(record, 'picture'),
      pictureSlide: ApiParser.str(record, 'pictureSlide'),
      poster: ApiParser.str(record, 'poster'),
      actor: ApiParser.str(record, 'actor'),
      director: ApiParser.str(record, 'director'),
      blurb: ApiParser.str(record, 'blurb'),
      remarks: ApiParser.str(record, 'remarks') || ApiParser.str(record, 'remark'),
      area: ApiParser.str(record, 'area'),
      year: FormatUtil.year(ApiParser.str(record, 'year')),
      language: ApiParser.str(record, 'language'),
      classTag: ApiParser.str(record, 'classTag'),
      mid: ApiParser.str(record, 'mid')
    };
    return item;
  }

  static parseMovies(raw: Object[] | null | undefined): MovieBasicInfo[] {
    if (!raw || !Array.isArray(raw)) {
      return [];
    }
    const list: MovieBasicInfo[] = [];
    for (let i = 0; i < raw.length; i++) {
      const item = ApiParser.parseMovie(raw[i]);
      if (item.id > 0 || item.name) {
        list.push(item);
      }
    }
    return list;
  }

  static parseCategory(raw: Object): CategoryItem {
    const record = ApiParser.asRecord(raw);
    const item: CategoryItem = {
      id: ApiParser.num(record, 'id'),
      pid: ApiParser.num(record, 'pid'),
      name: ApiParser.str(record, 'name'),
      show: record['show'] === undefined ? true : ApiParser.bool(record, 'show', true),
      children: ApiParser.parseCategories(ApiParser.list(record, 'children'))
    };
    return item;
  }

  static parseCategories(raw: Object[]): CategoryItem[] {
    const list: CategoryItem[] = [];
    for (let i = 0; i < raw.length; i++) {
      list.push(ApiParser.parseCategory(raw[i]));
    }
    return list;
  }

  static parseBanner(raw: Object): BannerItem {
    const record = ApiParser.asRecord(raw);
    const item: BannerItem = {
      id: ApiParser.str(record, 'id'),
      mid: ApiParser.num(record, 'mid'),
      name: ApiParser.str(record, 'name'),
      year: FormatUtil.year(ApiParser.str(record, 'year')),
      cName: ApiParser.str(record, 'cName'),
      poster: ApiParser.str(record, 'poster'),
      picture: ApiParser.str(record, 'picture'),
      pictureSlide: ApiParser.str(record, 'pictureSlide'),
      remark: ApiParser.str(record, 'remark') || ApiParser.str(record, 'remarks'),
      blurb: ApiParser.str(record, 'blurb'),
      area: ApiParser.str(record, 'area')
    };
    return item;
  }

  static parseHome(raw: Object): HomeData {
    const record = ApiParser.asRecord(raw);
    const bannersRaw = ApiParser.list(record, 'banners');
    const banners: BannerItem[] = [];
    for (let i = 0; i < bannersRaw.length; i++) {
      banners.push(ApiParser.parseBanner(bannersRaw[i]));
    }
    const contentRaw = ApiParser.list(record, 'content');
    const content: HomeSection[] = [];
    for (let i = 0; i < contentRaw.length; i++) {
      const sectionRecord = ApiParser.asRecord(contentRaw[i]);
      const section: HomeSection = {
        nav: ApiParser.parseCategory(ApiParser.obj(sectionRecord, 'nav')),
        movies: ApiParser.parseMovies(ApiParser.list(sectionRecord, 'movies')),
        hot: ApiParser.parseMovies(ApiParser.list(sectionRecord, 'hot'))
      };
      content.push(section);
    }
    const data: HomeData = {
      banners: banners,
      content: content
    };
    return data;
  }

  static parsePage(raw: Object | null | undefined): PageInfo {
    const record = ApiParser.asRecord(raw as Object);
    const page: PageInfo = {
      pageSize: ApiParser.num(record, 'pageSize', 20),
      current: ApiParser.num(record, 'current', 1),
      pageCount: ApiParser.num(record, 'pageCount', 1),
      total: ApiParser.num(record, 'total')
    };
    return page;
  }

  static parseDailyUpdate(raw: Object): DailyUpdateResult {
    const record = ApiParser.asRecord(raw);
    const catsRaw = ApiParser.list(record, 'categories');
    const categories: DailyUpdateCategory[] = [];
    for (let i = 0; i < catsRaw.length; i++) {
      const item = ApiParser.asRecord(catsRaw[i]);
      categories.push({
        pid: ApiParser.num(item, 'pid'),
        name: ApiParser.str(item, 'name'),
        count: ApiParser.num(item, 'count')
      });
    }
    const result: DailyUpdateResult = {
      list: ApiParser.parseMovies(ApiParser.list(record, 'list')),
      page: ApiParser.parsePage(ApiParser.obj(record, 'page')),
      categories: categories
    };
    return result;
  }

  static parseSearch(raw: Object): SearchResult {
    const record = ApiParser.asRecord(raw);
    const result: SearchResult = {
      list: ApiParser.parseMovies(ApiParser.list(record, 'list')),
      page: ApiParser.parsePage(ApiParser.obj(record, 'page'))
    };
    return result;
  }

  static parseFilter(raw: Object): FilterResult {
    const record = ApiParser.asRecord(raw);
    const title = ApiParser.obj(record, 'title');
    const paramsObj = ApiParser.obj(record, 'params');
    const paramKeys = Object.keys(paramsObj);
    const params: string[] = [];
    for (let i = 0; i < paramKeys.length; i++) {
      params.push(ApiParser.str(paramsObj, paramKeys[i]));
    }
    const searchObj = ApiParser.obj(record, 'search');
    const titlesObj = ApiParser.obj(searchObj, 'titles');
    const titleKeys = Object.keys(titlesObj);
    const titles: string[] = [];
    for (let i = 0; i < titleKeys.length; i++) {
      titles.push(ApiParser.str(titlesObj, titleKeys[i]));
    }
    const sortRaw = ApiParser.list(searchObj, 'sortList');
    const sortList: string[] = [];
    for (let i = 0; i < sortRaw.length; i++) {
      sortList.push(`${sortRaw[i]}`);
    }
    const tagsObj = ApiParser.obj(searchObj, 'tags');
    const tagKeys = Object.keys(tagsObj);
    const tagNames: string[][] = [];
    const tagValues: string[][] = [];
    for (let i = 0; i < tagKeys.length; i++) {
      const tags = ApiParser.list(tagsObj, tagKeys[i]);
      const names: string[] = [];
      const values: string[] = [];
      for (let j = 0; j < tags.length; j++) {
        const tag = ApiParser.asRecord(tags[j]);
        names.push(ApiParser.str(tag, 'Name'));
        values.push(ApiParser.str(tag, 'Value'));
      }
      tagNames.push(names);
      tagValues.push(values);
    }
    const searchMeta: FilterSearchMeta = {
      titles: titles,
      titleKeys: titleKeys,
      sortList: sortList,
      tagKeys: tagKeys,
      tagNames: tagNames,
      tagValues: tagValues
    };
    const result: FilterResult = {
      titleName: ApiParser.str(title, 'name', '全部'),
      titleId: ApiParser.num(title, 'id'),
      list: ApiParser.parseMovies(ApiParser.list(record, 'list')),
      page: ApiParser.parsePage(ApiParser.obj(record, 'page')),
      params: params,
      paramKeys: paramKeys,
      search: searchMeta
    };
    return result;
  }

  static parseClassify(raw: Object): ClassifyResult {
    const record = ApiParser.asRecord(raw);
    const title = ApiParser.parseCategory(ApiParser.obj(record, 'title'));
    const content = ApiParser.obj(record, 'content');
    const result: ClassifyResult = {
      titleName: title.name,
      titleId: title.id,
      children: title.children,
      news: ApiParser.parseMovies(ApiParser.list(content, 'news')),
      top: ApiParser.parseMovies(ApiParser.list(content, 'top')),
      recent: ApiParser.parseMovies(ApiParser.list(content, 'recent'))
    };
    return result;
  }

  static parsePlay(raw: Object): PlayInfo {
    const record = ApiParser.asRecord(raw);
    const detailObj = ApiParser.obj(record, 'detail');
    const descriptorObj = ApiParser.obj(detailObj, 'descriptor');
    const descriptor: MovieDescriptor = {
      subTitle: ApiParser.str(descriptorObj, 'subTitle'),
      cName: ApiParser.str(descriptorObj, 'cName'),
      enName: ApiParser.str(descriptorObj, 'enName'),
      classTag: ApiParser.str(descriptorObj, 'classTag'),
      actor: ApiParser.str(descriptorObj, 'actor'),
      director: ApiParser.str(descriptorObj, 'director'),
      writer: ApiParser.str(descriptorObj, 'writer'),
      blurb: ApiParser.str(descriptorObj, 'blurb'),
      remarks: ApiParser.str(descriptorObj, 'remarks'),
      releaseDate: ApiParser.str(descriptorObj, 'releaseDate'),
      area: ApiParser.str(descriptorObj, 'area'),
      language: ApiParser.str(descriptorObj, 'language'),
      year: FormatUtil.year(ApiParser.str(descriptorObj, 'year')),
      state: ApiParser.str(descriptorObj, 'state'),
      updateTime: ApiParser.str(descriptorObj, 'updateTime'),
      dbScore: ApiParser.str(descriptorObj, 'dbScore'),
      content: ApiParser.str(descriptorObj, 'content')
    };
    const sourceRaw = ApiParser.list(detailObj, 'list');
    const sources: PlaySource[] = [];
    for (let i = 0; i < sourceRaw.length; i++) {
      const sourceObj = ApiParser.asRecord(sourceRaw[i]);
      const linkRaw = ApiParser.list(sourceObj, 'linkList');
      const links: MovieUrlInfo[] = [];
      for (let j = 0; j < linkRaw.length; j++) {
        const linkObj = ApiParser.asRecord(linkRaw[j]);
        const episode = ApiParser.str(linkObj, 'episode');
        const link = ApiParser.str(linkObj, 'link');
        if (link) {
          const urlInfo: MovieUrlInfo = { episode: episode, link: link };
          links.push(urlInfo);
        }
      }
      const source: PlaySource = {
        id: ApiParser.str(sourceObj, 'id'),
        sourceId: ApiParser.str(sourceObj, 'sourceId'),
        name: ApiParser.str(sourceObj, 'name', '默认源'),
        linkList: links
      };
      sources.push(source);
    }
    const detail: MovieDetail = {
      id: ApiParser.num(detailObj, 'id'),
      cid: ApiParser.num(detailObj, 'cid'),
      pid: ApiParser.num(detailObj, 'pid'),
      name: ApiParser.str(detailObj, 'name'),
      picture: ApiParser.str(detailObj, 'picture'),
      pictureSlide: ApiParser.str(detailObj, 'pictureSlide'),
      descriptor: descriptor,
      list: sources,
      localUpdateTime: ApiParser.num(detailObj, 'localUpdateTime')
    };
    const currentObj = ApiParser.obj(record, 'current');
    const current: MovieUrlInfo = {
      episode: ApiParser.str(currentObj, 'episode'),
      link: ApiParser.str(currentObj, 'link')
    };
    const info: PlayInfo = {
      detail: detail,
      current: current,
      currentPlayFrom: ApiParser.str(record, 'currentPlayFrom'),
      currentEpisode: ApiParser.num(record, 'currentEpisode')
    };
    return info;
  }

  static parseBasicConfig(raw: Object): BasicConfig {
    const record = ApiParser.asRecord(raw);
    const tip = ApiParser.obj(record, 'tip');
    const notice = ApiParser.obj(record, 'notice');
    const channelRaw = ApiParser.list(tip, 'channels');
    const channels: TipChannel[] = [];
    for (let i = 0; i < channelRaw.length; i++) {
      const item = ApiParser.asRecord(channelRaw[i]);
      const channel: TipChannel = {
        key: ApiParser.str(item, 'key'),
        label: ApiParser.str(item, 'label'),
        qrImage: ApiParser.str(item, 'qrImage'),
        link: ApiParser.str(item, 'link')
      };
      channels.push(channel);
    }
    const config: BasicConfig = {
      siteName: ApiParser.str(record, 'siteName', 'EcoHub'),
      siteUrl: ApiParser.str(record, 'siteUrl'),
      logo: ApiParser.str(record, 'logo'),
      keyword: ApiParser.str(record, 'keyword'),
      describe: ApiParser.str(record, 'describe'),
      state: record['state'] === undefined ? true : ApiParser.bool(record, 'state', true),
      hint: ApiParser.str(record, 'hint', '网站升级中, 暂时无法访问'),
      tipEnabled: ApiParser.bool(tip, 'enabled'),
      tipTitle: ApiParser.str(tip, 'title', '赞赏支持'),
      tipMessage: ApiParser.str(tip, 'message'),
      tipChannels: channels,
      noticeEnabled: ApiParser.bool(notice, 'enabled'),
      noticeTitle: ApiParser.str(notice, 'title', '站点公告'),
      noticeContent: ApiParser.str(notice, 'content'),
      noticeShowInWeb: notice['showInWeb'] === undefined ? true : ApiParser.bool(notice, 'showInWeb', true),
      noticeShowInApp: notice['showInApp'] === undefined ? true : ApiParser.bool(notice, 'showInApp', true),
      noticeAppVersion: ApiParser.str(notice, 'appVersion') || ApiParser.str(notice, 'version', ''),
      noticeVersion: ApiParser.str(notice, 'appVersion') || ApiParser.str(notice, 'version', '')
    };
    return config;
  }
}
