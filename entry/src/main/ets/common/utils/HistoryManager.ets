import { preferences } from '@kit.ArkData';
import { ServerConfigManager } from './ServerConfigManager';
import { HistoryItem } from '../../model/FilmModels';

const KEY_HISTORY = 'film_history';
const MAX_HISTORY = 200;

export class HistoryManager {
  private static store(): preferences.Preferences | null {
    return ServerConfigManager.getInstance().getPreferences();
  }

  private static dataKey(): string {
    return ServerConfigManager.getInstance().scopedKey(KEY_HISTORY);
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

  static async migrateLegacy(): Promise<void> {
    const store = HistoryManager.store();
    const key = HistoryManager.dataKey();
    if (!store || !key) {
      return;
    }
    const origin = ServerConfigManager.getInstance().getOrigin().toLowerCase();
    const aliases: string[] = [KEY_HISTORY];
    if (origin) {
      aliases.push(`${KEY_HISTORY}@${origin}`);
      if (origin.indexOf('https://') === 0) {
        aliases.push(`${KEY_HISTORY}@http://${origin.substring(8)}`);
      } else if (origin.indexOf('http://') === 0) {
        aliases.push(`${KEY_HISTORY}@https://${origin.substring(7)}`);
      }
    }
    try {
      let current = (await store.get(key, '')) as string;
      for (let i = 0; i < aliases.length; i++) {
        const alias = aliases[i];
        if (alias === key) {
          continue;
        }
        const raw = (await store.get(alias, '')) as string;
        if (!raw || raw === '{}') {
          continue;
        }
        if (!current || current === '{}') {
          await store.put(key, raw);
          current = raw;
        }
        await store.delete(alias);
      }
      await store.flush();
    } catch (err) {
    }
  }

  private static async readMap(): Promise<Record<string, HistoryItem>> {
    const store = HistoryManager.store();
    const key = HistoryManager.dataKey();
    if (!store || !key) {
      return {};
    }
    try {
      const raw = (await store.get(key, '{}')) as string;
      const parsed = JSON.parse(raw) as Record<string, HistoryItem>;
      return parsed ? parsed : {};
    } catch (err) {
      return {};
    }
  }

  private static async writeMap(map: Record<string, HistoryItem>): Promise<void> {
    const store = HistoryManager.store();
    const key = HistoryManager.dataKey();
    if (!store || !key) {
      return;
    }
    try {
      await store.put(key, JSON.stringify(map));
      await store.flush();
    } catch (_err) {
    }
  }
}
