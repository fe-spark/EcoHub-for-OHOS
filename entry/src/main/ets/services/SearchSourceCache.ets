import { FilmApi } from '../api/FilmApi';
import { MovieBasicInfo, PageInfo, SearchResult, SearchSourceTab } from '../types/FilmModels';

export class CachedSource {
  list: MovieBasicInfo[] = [];
  page: PageInfo = { pageSize: 12, current: 1, pageCount: 0, total: 0 };
  error: string = '';
}

export function emptySearchPage(): PageInfo {
  return { pageSize: 12, current: 1, pageCount: 0, total: 0 };
}

export function tabsFromAggregate(
  sources: SearchSourceTab[],
  agg: SearchResult,
  cache: Record<string, CachedSource>
): SearchSourceTab[] {
  const out: SearchSourceTab[] = [];
  for (let i = 0; i < sources.length; i++) {
    const tab = sources[i];
    const id = tab.id || '';
    const cached = cache[id];
    let count = tab.count;
    let hasCache = false;
    if (id === '') {
      count = tab.count > 0 ? tab.count : agg.page.total;
    } else if (cached) {
      hasCache = true;
      count = cached.page.total;
    }
    const next: SearchSourceTab = {
      id: id,
      name: tab.name,
      count: count,
      loading: id !== '' && !hasCache
    };
    out.push(next);
  }
  return out;
}

export function patchTab(sources: SearchSourceTab[], id: string, count: number, loading: boolean): SearchSourceTab[] {
  const out: SearchSourceTab[] = [];
  for (let i = 0; i < sources.length; i++) {
    const tab = sources[i];
    if (tab.id === id) {
      const next: SearchSourceTab = { id: tab.id, name: tab.name, count: count, loading: loading };
      out.push(next);
    } else {
      out.push(tab);
    }
  }
  return out;
}

export class SearchSourceCache {
  gen: number = 0;
  cache: Record<string, CachedSource> = {};

  begin(): number {
    this.gen += 1;
    this.cache = {};
    return this.gen;
  }

  alive(gen: number): boolean {
    return this.gen === gen;
  }

  put(id: string, list: MovieBasicInfo[], page: PageInfo, error: string = ''): void {
    const bucket = new CachedSource();
    bucket.list = list;
    bucket.page = page;
    bucket.error = error;
    this.cache[id] = bucket;
  }

  get(id: string): CachedSource | null {
    const hit = this.cache[id];
    return hit ? hit : null;
  }

  async fetchOne(gen: number, kw: string, id: string): Promise<SearchResult> {
    const empty: SearchResult = { list: [], page: emptySearchPage(), sources: [], error: '' };
    try {
      const res = await FilmApi.searchFilm(kw, 1, id);
      if (!this.alive(gen)) {
        return empty;
      }
      this.put(id, res.list, res.page, res.error || '');
      return res;
    } catch (_e) {
      if (this.alive(gen)) {
        this.put(id, [], empty.page, '源站搜索失败');
      }
      return empty;
    }
  }
}

export class SearchBag {
  source: string = '';
  list: MovieBasicInfo[] = [];
  page: PageInfo = emptySearchPage();
  sources: SearchSourceTab[] = [];
  loading: boolean = false;
  submitted: string = '';
  errorText: string = '';
  sourceError: string = '';
  session: SearchSourceCache = new SearchSourceCache();
}

export function applyCached(bag: SearchBag, id: string): void {
  const hit = bag.session.get(id);
  if (hit) {
    bag.list = hit.list;
    bag.page = hit.page;
    bag.sourceError = hit.error;
    bag.loading = false;
    return;
  }
  bag.list = [];
  bag.sourceError = '';
  bag.loading = true;
}

function onSourceReady(bag: SearchBag, id: string, result: SearchResult): void {
  bag.sources = patchTab(bag.sources, id, result.page.total, false);
  if (bag.source === id) {
    bag.list = result.list;
    bag.page = result.page;
    bag.sourceError = result.error || '';
    bag.loading = false;
  }
}

export async function fanoutSearch(
  kw: string,
  currentSource: string,
  session: SearchSourceCache,
  onAggregate: (result: SearchResult, tabs: SearchSourceTab[]) => void,
  onSource: (id: string, result: SearchResult) => void
): Promise<boolean> {
  const gen = session.begin();
  try {
    const agg = await FilmApi.searchFilm(kw, 1, '');
    if (!session.alive(gen)) {
      return false;
    }
    session.put('', agg.list, agg.page, '');
    onAggregate(agg, tabsFromAggregate(agg.sources || [], agg, session.cache));
    const ids: string[] = [];
    const sources = agg.sources || [];
    if (currentSource) {
      ids.push(currentSource);
    }
    for (let i = 0; i < sources.length; i++) {
      const id = sources[i].id || '';
      if (!id || id === currentSource) {
        continue;
      }
      ids.push(id);
    }
    const tasks: Promise<void>[] = [];
    for (let i = 0; i < ids.length; i++) {
      const id = ids[i];
      tasks.push((async () => {
        const res = await session.fetchOne(gen, kw, id);
        if (!session.alive(gen)) {
          return;
        }
        onSource(id, res);
      })());
    }
    await Promise.all(tasks);
    return true;
  } catch (_e) {
    return false;
  }
}

export async function executeSearch(
  bag: SearchBag,
  kw: string,
  reset: boolean,
  fromPull: boolean,
  onUpdate: () => void
): Promise<boolean> {
  if (!reset) {
    const more = await FilmApi.searchFilm(kw, bag.page.current + 1, bag.source);
    bag.submitted = kw;
    bag.errorText = '';
    bag.sourceError = more.error || '';
    bag.page = more.page;
    bag.list = bag.list.concat(more.list);
    bag.session.put(bag.source, bag.list, more.page, bag.sourceError);
    onUpdate();
    return true;
  }
  if (!fromPull) {
    bag.loading = true;
    bag.list = [];
    onUpdate();
  }
  const ok = await fanoutSearch(kw, bag.source, bag.session, (result: SearchResult, tabs: SearchSourceTab[]) => {
    bag.submitted = kw;
    bag.errorText = '';
    bag.sourceError = '';
    bag.sources = tabs;
    if (!bag.source) {
      bag.list = result.list;
      bag.page = result.page;
      bag.loading = false;
    } else {
      applyCached(bag, bag.source);
    }
    onUpdate();
  }, (id: string, result: SearchResult) => {
    onSourceReady(bag, id, result);
    onUpdate();
  });
  if (!ok) {
    bag.submitted = kw;
    bag.errorText = '网络连接失败，请稍后重试';
    if (!fromPull) {
      bag.list = [];
    }
    bag.loading = false;
    onUpdate();
    return false;
  }
  if (bag.source && bag.session.get(bag.source) === null) {
    bag.loading = true;
  } else {
    bag.loading = false;
  }
  onUpdate();
  return true;
}
