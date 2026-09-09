import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo, storageStatistics } from '@kit.CoreFileKit';

export class AppSettingsManager {
  private static instance: AppSettingsManager;
  private pref: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;

  public static readonly PREF_NAME: string = 'ecohub_app_settings';
  public static readonly KEY_PIP_AUTO_START: string = 'setting_pip_auto_start';
  public static readonly KEY_AUTO_PLAY_NEXT: string = 'setting_auto_play_next';
  public static readonly KEY_CLIPBOARD_SNIFFER: string = 'setting_clipboard_sniffer';

  public static readonly STORAGE_KEY_PIP_AUTO_START: string = 'SETTING_PIP_AUTO_START';
  public static readonly STORAGE_KEY_AUTO_PLAY_NEXT: string = 'SETTING_AUTO_PLAY_NEXT';
  public static readonly STORAGE_KEY_CLIPBOARD_SNIFFER: string = 'SETTING_CLIPBOARD_SNIFFER';

  private constructor() {}

  public static getInstance(): AppSettingsManager {
    if (!AppSettingsManager.instance) {
      AppSettingsManager.instance = new AppSettingsManager();
    }
    return AppSettingsManager.instance;
  }

  public async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      this.pref = await preferences.getPreferences(context, AppSettingsManager.PREF_NAME);
      const pipAuto = (await this.pref.get(AppSettingsManager.KEY_PIP_AUTO_START, true)) as boolean;
      const autoPlayNext = (await this.pref.get(AppSettingsManager.KEY_AUTO_PLAY_NEXT, true)) as boolean;
      const clipboardSniffer = (await this.pref.get(AppSettingsManager.KEY_CLIPBOARD_SNIFFER, true)) as boolean;

      AppStorage.setOrCreate(AppSettingsManager.STORAGE_KEY_PIP_AUTO_START, pipAuto);
      AppStorage.setOrCreate(AppSettingsManager.STORAGE_KEY_AUTO_PLAY_NEXT, autoPlayNext);
      AppStorage.setOrCreate(AppSettingsManager.STORAGE_KEY_CLIPBOARD_SNIFFER, clipboardSniffer);
      console.info(`[AppSettingsManager] init loaded: pipAuto=${pipAuto}, autoNext=${autoPlayNext}, sniffer=${clipboardSniffer}`);
    } catch (err) {
      console.error('[AppSettingsManager] init failed:', JSON.stringify(err));
      AppStorage.setOrCreate(AppSettingsManager.STORAGE_KEY_PIP_AUTO_START, true);
      AppStorage.setOrCreate(AppSettingsManager.STORAGE_KEY_AUTO_PLAY_NEXT, true);
      AppStorage.setOrCreate(AppSettingsManager.STORAGE_KEY_CLIPBOARD_SNIFFER, true);
    }
  }

  public async setPipAutoStart(enabled: boolean): Promise<void> {
    AppStorage.setOrCreate(AppSettingsManager.STORAGE_KEY_PIP_AUTO_START, enabled);
    if (this.pref) {
      try {
        await this.pref.put(AppSettingsManager.KEY_PIP_AUTO_START, enabled);
        await this.pref.flush();
      } catch (_e) {}
    }
  }

  public async setAutoPlayNext(enabled: boolean): Promise<void> {
    AppStorage.setOrCreate(AppSettingsManager.STORAGE_KEY_AUTO_PLAY_NEXT, enabled);
    if (this.pref) {
      try {
        await this.pref.put(AppSettingsManager.KEY_AUTO_PLAY_NEXT, enabled);
        await this.pref.flush();
      } catch (_e) {}
    }
  }

  public async setClipboardSniffer(enabled: boolean): Promise<void> {
    AppStorage.setOrCreate(AppSettingsManager.STORAGE_KEY_CLIPBOARD_SNIFFER, enabled);
    if (this.pref) {
      try {
        await this.pref.put(AppSettingsManager.KEY_CLIPBOARD_SNIFFER, enabled);
        await this.pref.flush();
      } catch (_e) {}
    }
  }

  private getCacheDirs(context?: common.UIAbilityContext): string[] {
    const ctx = context || this.context;
    const dirs: string[] = [];

    const addIfValid = (dirPath: string | undefined | null) => {
      if (!dirPath || dirs.includes(dirPath)) return;
      try {
        if (fileIo.accessSync(dirPath)) {
          dirs.push(dirPath);
        }
      } catch (_e) {}
    };

    if (ctx) {
      // 1. Ability-level cache/temp
      addIfValid(ctx.cacheDir);
      addIfValid(ctx.tempDir);

      // 2. Base application-level dirs (el2)
      // ctx.cacheDir is typically: "/data/storage/el2/base/haps/entry/cache"
      if (ctx.cacheDir) {
        const hapsIdx = ctx.cacheDir.indexOf('/haps/');
        if (hapsIdx > 0) {
          const el2Base = ctx.cacheDir.substring(0, hapsIdx);
          addIfValid(`${el2Base}/cache`);
          addIfValid(`${el2Base}/temp`);

          // 3. Base application-level dirs (el1)
          if (el2Base.includes('/el2/')) {
            const el1Base = el2Base.replace('/el2/', '/el1/');
            addIfValid(`${el1Base}/cache`);
            addIfValid(`${el1Base}/temp`);
          }
        }
      }
    }

    // 4. Explicit standard sandbox root caches
    addIfValid('/data/storage/el2/base/cache');
    addIfValid('/data/storage/el2/base/temp');
    addIfValid('/data/storage/el1/base/cache');
    addIfValid('/data/storage/el1/base/temp');

    return dirs;
  }

  public async getCacheSize(context?: common.UIAbilityContext): Promise<string> {
    let systemCacheBytes = 0;
    try {
      const stats = await storageStatistics.getCurrentBundleStats();
      if (stats && stats.cacheSize >= 0) {
        systemCacheBytes = stats.cacheSize;
        console.info(`[AppSettingsManager] storageStatistics.cacheSize: ${systemCacheBytes}`);
      }
    } catch (err) {
      console.warn('[AppSettingsManager] getCurrentBundleStats failed:', JSON.stringify(err));
    }

    const dirsToScan = this.getCacheDirs(context);
    let dirBytes = 0;
    for (let i = 0; i < dirsToScan.length; i++) {
      const sz = this.getDirSize(dirsToScan[i]);
      dirBytes += sz;
    }
    console.info(`[AppSettingsManager] dirs size: ${dirBytes}, systemCacheBytes: ${systemCacheBytes}`);

    const totalBytes = Math.max(systemCacheBytes, dirBytes);
    return this.formatBytes(totalBytes);
  }

  private formatBytes(bytes: number): string {
    if (bytes <= 0) {
      return '0.0 MB';
    }
    if (bytes < 1024 * 1024) {
      const kb = bytes / 1024;
      return `${kb.toFixed(1)} KB`;
    }
    const mb = bytes / (1024 * 1024);
    return `${mb.toFixed(1)} MB`;
  }

  private getDirSize(path: string): number {
    let size = 0;
    try {
      if (!fileIo.accessSync(path)) {
        return 0;
      }
      const filenames = fileIo.listFileSync(path);
      for (let i = 0; i < filenames.length; i++) {
        try {
          const fullPath = `${path}/${filenames[i]}`;
          const stat = fileIo.statSync(fullPath);
          if (stat.isDirectory()) {
            size += this.getDirSize(fullPath);
          } else {
            size += stat.size;
          }
        } catch (_fileErr) {}
      }
    } catch (_dirErr) {}
    return size;
  }

  public async clearCache(context?: common.UIAbilityContext): Promise<void> {
    const dirsToClear = this.getCacheDirs(context);
    console.info(`[AppSettingsManager] clearing cache dirs: ${JSON.stringify(dirsToClear)}`);
    for (let i = 0; i < dirsToClear.length; i++) {
      this.deleteDirContents(dirsToClear[i]);
    }
  }

  private deleteDirContents(path: string): void {
    try {
      if (!fileIo.accessSync(path)) {
        return;
      }
      const filenames = fileIo.listFileSync(path);
      for (let i = 0; i < filenames.length; i++) {
        const fullPath = `${path}/${filenames[i]}`;
        try {
          const stat = fileIo.statSync(fullPath);
          if (stat.isDirectory()) {
            this.deleteDirContents(fullPath);
            try {
              fileIo.rmdirSync(fullPath);
            } catch (_e) {}
          } else {
            fileIo.unlinkSync(fullPath);
          }
        } catch (_e) {}
      }
    } catch (_e) {}
  }
}
