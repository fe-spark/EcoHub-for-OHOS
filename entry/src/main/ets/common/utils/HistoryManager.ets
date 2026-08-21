import { preferences } from '@kit.ArkData';
import { ServerConfigManager } from './ServerConfigManager';
import { HistoryItem } from '../../model/FilmModels';

const KEY_HISTORY = 'film_history';
const MAX_HISTORY = 200;

export class HistoryManager {
  private static store(): preferences.Preferences | null {
    return ServerConfigManager.getInstance().getPreferences();
  }

  static async find(id: string): Promise<HistoryItem | null> {
    const map = await HistoryManager.readMap();
    const item = map[id];
    return item ? item : null;
  }

  static async list(): Promise<HistoryItem[]> {
    const map = await HistoryManager.readMap();
    const items: HistoryItem[] = [];
    const keys = Object.keys(map);
    for (let i = 0; i < keys.length; i++) {
      items.push(map[keys[i]]);
    }
    items.sort((a: HistoryItem, b: HistoryItem) => b.timeStamp - a.timeStamp);
    return items;
  }

  static async save(item: HistoryItem): Promise<void> {
    const map = await HistoryManager.readMap();
    map[item.id] = item;
    const entries: HistoryItem[] = [];
    const keys = Object.keys(map);
    for (let i = 0; i < keys.length; i++) {
      entries.push(map[keys[i]]);
    }
    entries.sort((a: HistoryItem, b: HistoryItem) => b.timeStamp - a.timeStamp);
    const trimmed: Record<string, HistoryItem> = {};
    const limit = Math.min(MAX_HISTORY, entries.length);
    for (let i = 0; i < limit; i++) {
      trimmed[entries[i].id] = entries[i];
    }
    await HistoryManager.writeMap(trimmed);
  }

  static async remove(id: string): Promise<void> {
    const map = await HistoryManager.readMap();
    const next: Record<string, HistoryItem> = {};
    const keys = Object.keys(map);
    for (let i = 0; i < keys.length; i++) {
      if (keys[i] !== id) {
        next[keys[i]] = map[keys[i]];
      }
    }
    await HistoryManager.writeMap(next);
  }

  static async clear(): Promise<void> {
    await HistoryManager.writeMap({});
  }

  private static async readMap(): Promise<Record<string, HistoryItem>> {
    const store = HistoryManager.store();
    if (!store) {
      return {};
    }
    try {
      const raw = (await store.get(KEY_HISTORY, '{}')) as string;
      const parsed = JSON.parse(raw) as Record<string, HistoryItem>;
      return parsed ? parsed : {};
    } catch (err) {
      return {};
    }
  }

  private static async writeMap(map: Record<string, HistoryItem>): Promise<void> {
    const store = HistoryManager.store();
    if (!store) {
      return;
    }
    await store.put(KEY_HISTORY, JSON.stringify(map));
    await store.flush();
  }
}
