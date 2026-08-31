import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const PREF_NAME = 'ecohub_settings';
const KEY_SERVER_URL = 'server_base_url';
const KEY_SERVER_HISTORY = 'server_url_history';
const MAX_SERVER_HISTORY = 10;

export class ServerConfigManager {
  private static instance: ServerConfigManager;
  private pref: preferences.Preferences | null = null;
  private cachedUrl: string = '';

  private constructor() {
  }

  public static getInstance(): ServerConfigManager {
    if (!ServerConfigManager.instance) {
      ServerConfigManager.instance = new ServerConfigManager();
    }
    return ServerConfigManager.instance;
  }

  public async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, PREF_NAME);
      this.cachedUrl = (await this.pref.get(KEY_SERVER_URL, '')) as string;
    } catch (err) {
      console.error('Failed to get preferences:', JSON.stringify(err));
    }
  }

  public async getServerUrl(): Promise<string> {
    if (this.cachedUrl) {
      return this.cachedUrl;
    }
    if (!this.pref) {
      return '';
    }
    try {
      this.cachedUrl = (await this.pref.get(KEY_SERVER_URL, '')) as string;
      return this.cachedUrl;
    } catch (err) {
      return '';
    }
  }

  public getCachedServerUrl(): string {
    return this.cachedUrl;
  }

  public getPreferences(): preferences.Preferences | null {
    return this.pref;
  }

  public getOrigin(): string {
    if (!this.cachedUrl.trim()) {
      return '';
    }
    return ServerConfigManager.stripApiSuffix(this.normalizeRaw(this.cachedUrl));
  }

  public storageScope(): string {
    return ServerConfigManager.hostScope(this.getOrigin());
  }

  public scopedKey(name: string): string {
    const scope = this.storageScope();
    if (!scope) {
      return '';
    }
    return `${name}@${scope}`;
  }

  public static hostScope(origin: string): string {
    let value = origin.trim().toLowerCase();
    if (!value) {
      return '';
    }
    if (value.indexOf('https://') === 0) {
      value = value.substring(8);
    } else if (value.indexOf('http://') === 0) {
      value = value.substring(7);
    }
    const slash = value.indexOf('/');
    if (slash >= 0) {
      value = value.substring(0, slash);
    }
    return value;
  }

  public getApiBase(): string {
    const origin = this.getOrigin();
    return origin ? `${origin}/api` : '';
  }

  public resolveMediaUrl(path: string): string {
    if (!path) {
      return '';
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    const origin = this.getOrigin();
    if (!origin) {
      return path;
    }
    return path.startsWith('/') ? `${origin}${path}` : `${origin}/${path}`;
  }

  public async getServerHistory(): Promise<string[]> {
    if (!this.pref) {
      return this.cachedUrl ? [this.cachedUrl] : [];
    }
    try {
      const raw = (await this.pref.get(KEY_SERVER_HISTORY, '[]')) as string;
      const list = JSON.parse(raw) as string[];
      if (Array.isArray(list) && list.length > 0) {
        return list;
      }
      if (this.cachedUrl) {
        return [this.cachedUrl];
      }
      return [];
    } catch (_err) {
      return this.cachedUrl ? [this.cachedUrl] : [];
    }
  }

  public async addServerHistory(url: string): Promise<void> {
    const cleanUrl = this.normalizeRaw(url);
    if (!cleanUrl || !this.pref) {
      return;
    }
    try {
      const current = await this.getServerHistory();
      const filtered = current.filter((item: string) => item !== cleanUrl);
      filtered.unshift(cleanUrl);
      if (filtered.length > MAX_SERVER_HISTORY) {
        filtered.length = MAX_SERVER_HISTORY;
      }
      await this.pref.put(KEY_SERVER_HISTORY, JSON.stringify(filtered));
      await this.pref.flush();
    } catch (_err) {
    }
  }

  public async removeServerHistory(url: string): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      const current = await this.getServerHistory();
      const filtered = current.filter((item: string) => item !== url);
      await this.pref.put(KEY_SERVER_HISTORY, JSON.stringify(filtered));
      await this.pref.flush();
    } catch (_err) {
    }
  }

  public async clearServerHistory(): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      await this.pref.put(KEY_SERVER_HISTORY, '[]');
      await this.pref.flush();
    } catch (_err) {
    }
  }

  public async setServerUrl(url: string): Promise<void> {
    const cleanUrl = this.normalizeRaw(url);
    this.cachedUrl = cleanUrl;
    if (!this.pref) {
      return;
    }
    try {
      await this.pref.put(KEY_SERVER_URL, cleanUrl);
      await this.pref.flush();
      await this.addServerHistory(cleanUrl);
    } catch (_err) {
    }
  }

  public async clearServerUrl(): Promise<void> {
    this.cachedUrl = '';
    if (!this.pref) {
      return;
    }
    try {
      await this.pref.delete(KEY_SERVER_URL);
      await this.pref.flush();
    } catch (_err) {
    }
  }

  public normalizeRaw(url: string): string {
    let cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.replace(/\/+$/g, '');
    }
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = `https://${cleanUrl}`;
    }
    return cleanUrl;
  }

  public static stripApiSuffix(url: string): string {
    let base = url.trim().replace(/\/+$/g, '');
    while (/\/api$/i.test(base)) {
      base = base.replace(/\/api$/i, '').replace(/\/+$/g, '');
    }
    return base;
  }

  public buildApiUrl(path: string): string {
    const apiBase = this.getApiBase();
    if (!apiBase) {
      throw new Error('未配置软件源');
    }
    const apiPath = path.startsWith('/') ? path : `/${path}`;
    return `${apiBase}${apiPath}`;
  }
}
