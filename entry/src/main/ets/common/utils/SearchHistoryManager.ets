import { preferences } from '@kit.ArkData';
import { ServerConfigManager } from './ServerConfigManager';

const KEY_SEARCH_HISTORY = 'search_history';
const MAX_SEARCH_HISTORY = 20;

export class SearchHistoryManager {
  private static store(): preferences.Preferences | null {
    return ServerConfigManager.getInstance().getPreferences();
  }

  private static dataKey(): string {
    return ServerConfigManager.getInstance().scopedKey(KEY_SEARCH_HISTORY);
  }

  /**
   * 获取当前软件源下的搜索历史列表
   */
  static async list(): Promise<string[]> {
    const store = SearchHistoryManager.store();
    const key = SearchHistoryManager.dataKey();
    if (!store || !key) {
      return [];
    }
    try {
      const raw = (await store.get(key, '[]')) as string;
      const parsed = JSON.parse(raw) as string[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (_err) {
      return [];
    }
  }

  /**
   * 添加搜索关键词（自动去重并前置，超出上限截断）
   */
  static async add(keyword: string): Promise<void> {
    const kw = keyword.trim();
    if (!kw) {
      return;
    }
    const current = await SearchHistoryManager.list();
    const filtered = current.filter((item: string) => item !== kw);
    filtered.unshift(kw);
    if (filtered.length > MAX_SEARCH_HISTORY) {
      filtered.length = MAX_SEARCH_HISTORY;
    }
    await SearchHistoryManager.saveList(filtered);
  }

  /**
   * 删除单个搜索关键词
   */
  static async remove(keyword: string): Promise<void> {
    const current = await SearchHistoryManager.list();
    const filtered = current.filter((item: string) => item !== keyword);
    await SearchHistoryManager.saveList(filtered);
  }

  /**
   * 清空搜索历史
   */
  static async clear(): Promise<void> {
    await SearchHistoryManager.saveList([]);
  }

  private static async saveList(list: string[]): Promise<void> {
    const store = SearchHistoryManager.store();
    const key = SearchHistoryManager.dataKey();
    if (!store || !key) {
      return;
    }
    await store.put(key, JSON.stringify(list));
    await store.flush();
  }
}
