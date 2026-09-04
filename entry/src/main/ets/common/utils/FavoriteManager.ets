import { preferences } from '@kit.ArkData';
import { ServerConfigManager } from './ServerConfigManager';
import { FavoriteItem } from '../../model/FilmModels';

const KEY_FAVORITE = 'film_favorite';
const MAX_FAVORITE = 300;

export class FavoriteManager {
  private static listeners: Array<() => void> = [];

  private static store(): preferences.Preferences | null {
    return ServerConfigManager.getInstance().getPreferences();
  }

  private static dataKey(): string {
    return ServerConfigManager.getInstance().scopedKey(KEY_FAVORITE);
  }

  static onFavoriteChange(cb: () => void): void {
    if (FavoriteManager.listeners.indexOf(cb) < 0) {
      FavoriteManager.listeners.push(cb);
    }
  }

  static offFavoriteChange(cb: () => void): void {
    const idx = FavoriteManager.listeners.indexOf(cb);
    if (idx >= 0) {
      FavoriteManager.listeners.splice(idx, 1);
    }
  }

  private static notifyChange(): void {
    for (let i = 0; i < FavoriteManager.listeners.length; i++) {
      try {
        FavoriteManager.listeners[i]();
      } catch (_e) {
      }
    }
  }

  static async isFavorite(id: string): Promise<boolean> {
    if (!id) {
      return false;
    }
    const item = await FavoriteManager.find(id);
    return item !== null;
  }

  static async find(id: string): Promise<FavoriteItem | null> {
    if (!id) {
      return null;
    }
    const map = await FavoriteManager.readMap();
    const item = map[id];
    return item ? item : null;
  }

  static async count(): Promise<number> {
    const map = await FavoriteManager.readMap();
    return Object.keys(map).length;
  }

  static async list(): Promise<FavoriteItem[]> {
    const map = await FavoriteManager.readMap();
    const items: FavoriteItem[] = [];
    const keys = Object.keys(map);
    for (let i = 0; i < keys.length; i++) {
      items.push(map[keys[i]]);
    }
    items.sort((a: FavoriteItem, b: FavoriteItem) => b.createdAt - a.createdAt);
    return items;
  }

  static async toggle(item: FavoriteItem): Promise<boolean> {
    const exists = await FavoriteManager.isFavorite(item.id);
    if (exists) {
      await FavoriteManager.remove(item.id);
      return false;
    } else {
      await FavoriteManager.save(item);
      return true;
    }
  }

  static async toggleFavorite(item: FavoriteItem): Promise<boolean> {
    return FavoriteManager.toggle(item);
  }

  static async save(item: FavoriteItem): Promise<void> {
    if (!item || !item.id) {
      return;
    }
    const map = await FavoriteManager.readMap();
    map[item.id] = item;
    const entries: FavoriteItem[] = [];
    const keys = Object.keys(map);
    for (let i = 0; i < keys.length; i++) {
      entries.push(map[keys[i]]);
    }
    entries.sort((a: FavoriteItem, b: FavoriteItem) => b.createdAt - a.createdAt);
    const trimmed: Record<string, FavoriteItem> = {};
    const limit = Math.min(MAX_FAVORITE, entries.length);
    for (let i = 0; i < limit; i++) {
      trimmed[entries[i].id] = entries[i];
    }
    await FavoriteManager.writeMap(trimmed);
    FavoriteManager.notifyChange();
  }

  static async remove(id: string): Promise<void> {
    if (!id) {
      return;
    }
    const map = await FavoriteManager.readMap();
    if (!map[id]) {
      return;
    }
    const next: Record<string, FavoriteItem> = {};
    const keys = Object.keys(map);
    for (let i = 0; i < keys.length; i++) {
      if (keys[i] !== id) {
        next[keys[i]] = map[keys[i]];
      }
    }
    await FavoriteManager.writeMap(next);
    FavoriteManager.notifyChange();
  }

  static async clear(): Promise<void> {
    await FavoriteManager.writeMap({});
    FavoriteManager.notifyChange();
  }

  private static async readMap(): Promise<Record<string, FavoriteItem>> {
    const store = FavoriteManager.store();
    const key = FavoriteManager.dataKey();
    if (!store || !key) {
      return {};
    }
    try {
      const raw = (await store.get(key, '{}')) as string;
      const parsed = JSON.parse(raw) as Record<string, FavoriteItem>;
      return parsed ? parsed : {};
    } catch (err) {
      return {};
    }
  }

  private static async writeMap(map: Record<string, FavoriteItem>): Promise<void> {
    const store = FavoriteManager.store();
    const key = FavoriteManager.dataKey();
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
