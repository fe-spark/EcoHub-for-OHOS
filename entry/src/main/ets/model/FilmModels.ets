export interface TipChannel {
  key: string;
  label: string;
  qrImage: string;
  link: string;
}

export interface BasicConfig {
  siteName: string;
  siteUrl: string;
  logo: string;
  keyword: string;
  describe: string;
  state: boolean;
  hint: string;
  tipEnabled: boolean;
  tipTitle: string;
  tipMessage: string;
  tipChannels: TipChannel[];
  noticeEnabled?: boolean;
  noticeTitle?: string;
  noticeContent?: string;
  noticeVersion?: string;
}

export interface CategoryItem {
  id: number;
  pid: number;
  name: string;
  show: boolean;
  children: CategoryItem[];
}

export interface MovieBasicInfo {
  id: number;
  cid: number;
  pid: number;
  name: string;
  subTitle: string;
  cName: string;
  state: string;
  picture: string;
  pictureSlide: string;
  poster: string;
  actor: string;
  director: string;
  blurb: string;
  remarks: string;
  area: string;
  year: string;
  language: string;
  classTag: string;
  mid: string;
}

export interface BannerItem {
  id: string;
  mid: number;
  name: string;
  year: string;
  cName: string;
  poster: string;
  picture: string;
  pictureSlide: string;
  remark: string;
  blurb: string;
  area: string;
}

export interface HomeSection {
  nav: CategoryItem;
  movies: MovieBasicInfo[];
  hot: MovieBasicInfo[];
}

export interface HomeData {
  banners: BannerItem[];
  content: HomeSection[];
}

export interface PageInfo {
  pageSize: number;
  current: number;
  pageCount: number;
  total: number;
}

export interface SearchTag {
  Name: string;
  Value: string;
}

export interface FilterSearchMeta {
  titles: string[];
  titleKeys: string[];
  sortList: string[];
  tagKeys: string[];
  tagNames: string[][];
  tagValues: string[][];
}

export interface FilterResult {
  titleName: string;
  titleId: number;
  list: MovieBasicInfo[];
  page: PageInfo;
  params: string[];
  paramKeys: string[];
  search: FilterSearchMeta;
}

export interface ClassifyResult {
  titleName: string;
  titleId: number;
  children: CategoryItem[];
  news: MovieBasicInfo[];
  top: MovieBasicInfo[];
  recent: MovieBasicInfo[];
}

export interface MovieUrlInfo {
  episode: string;
  link: string;
}

export interface PlaySource {
  id: string;
  sourceId: string;
  name: string;
  linkList: MovieUrlInfo[];
}

export interface MovieDescriptor {
  subTitle: string;
  cName: string;
  enName: string;
  classTag: string;
  actor: string;
  director: string;
  writer: string;
  blurb: string;
  remarks: string;
  releaseDate: string;
  area: string;
  language: string;
  year: string;
  state: string;
  updateTime: string;
  dbScore: string;
  content: string;
}

export interface MovieDetail {
  id: number;
  cid: number;
  pid: number;
  name: string;
  picture: string;
  pictureSlide: string;
  descriptor: MovieDescriptor;
  list: PlaySource[];
  localUpdateTime: number;
}

export interface PlayInfo {
  detail: MovieDetail;
  current: MovieUrlInfo;
  currentPlayFrom: string;
  currentEpisode: number;
}

export interface HistoryItem {
  id: string;
  name: string;
  picture: string;
  sourceId: string;
  sourceName: string;
  episodeIndex: number;
  episode: string;
  currentTime: number;
  duration: number;
  timeStamp: number;
}

export interface SearchResult {
  list: MovieBasicInfo[];
  page: PageInfo;
}
