import { bundleManager } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';

export interface AppUpdateInfo {
  currentVersion: string;
  latestVersion: string;
  hasUpdate: boolean;
  releaseName: string;
  releaseNotes: string;
  releaseUrl: string;
  downloadUrl: string;
}

export class AppVersionUtil {
  public static readonly APP_VERSION: string = '1.1.2-beta.1';
  private static cachedVersionName: string = '';

  /**
   * 获取当前 App 的版本名称（如 "1.0.5"）
   */
  static async getVersionName(): Promise<string> {
    if (AppVersionUtil.cachedVersionName) {
      return AppVersionUtil.cachedVersionName;
    }
    try {
      const bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT;
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleFlags);
      if (bundleInfo && bundleInfo.versionName) {
        AppVersionUtil.cachedVersionName = bundleInfo.versionName;
        return AppVersionUtil.cachedVersionName;
      }
    } catch (_err) {
    }
    AppVersionUtil.cachedVersionName = AppVersionUtil.APP_VERSION;
    return AppVersionUtil.cachedVersionName;
  }

  /**
   * 规则：
   * 1. 默认留空（或 "*" / "all"）：所有版本都匹配（返回 true）
   * 2. 填写了单版本或多版本（逗号/分号/空格隔开，如 "1.0.2, 1.0.3"）：当前版本在列表中时返回 true
   */
  static isVersionMatched(currentVersion: string, targetVersionsConfig?: string): boolean {
    const raw = (targetVersionsConfig || '').trim();
    if (!raw || raw === '*' || raw.toLowerCase() === 'all') {
      return true;
    }
    const current = (currentVersion || '').trim().toLowerCase();
    const targets = raw.split(/[,;\s\n]+/)
      .map((item: string) => item.trim().toLowerCase())
      .filter((item: string) => item.length > 0);

    if (targets.length === 0) {
      return true;
    }
    return targets.indexOf(current) >= 0;
  }

  /**
   * 规范化版本号字符串（移除前缀 v/V 与前后空格）
   */
  static normalizeVersion(v: string): string {
    let s = (v || '').trim();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1).trim();
    }
    return s;
  }

  /**
   * 比较两个版本号（v1 > v2 返回 1；v1 < v2 返回 -1；相等返回 0）
   */
  static compareVersion(v1: string, v2: string): number {
    const s1 = AppVersionUtil.normalizeVersion(v1);
    const s2 = AppVersionUtil.normalizeVersion(v2);
    const base1 = s1.split('-')[0].split('+')[0];
    const base2 = s2.split('-')[0].split('+')[0];
    const parts1 = base1.split('.').map((p: string) => parseInt(p, 10) || 0);
    const parts2 = base2.split('.').map((p: string) => parseInt(p, 10) || 0);
    const maxLen = Math.max(parts1.length, parts2.length);
    for (let i = 0; i < maxLen; i++) {
      const num1 = i < parts1.length ? parts1[i] : 0;
      const num2 = i < parts2.length ? parts2[i] : 0;
      if (num1 > num2) {
        return 1;
      }
      if (num1 < num2) {
        return -1;
      }
    }
    return 0;
  }

  private static cachedUpdateInfo: AppUpdateInfo | null = null;
  private static lastCheckTime: number = 0;
  private static readonly CACHE_EXPIRE_MS: number = 10 * 60 * 1000; // 10分钟缓存

  /**
   * 判定最新版本是否严格高于当前版本
   */
  static isNewerVersion(latest: string, current: string): boolean {
    return AppVersionUtil.compareVersion(latest, current) > 0;
  }

  /**
   * 获取当前缓存的更新信息
   */
  static getCachedUpdateInfo(): AppUpdateInfo | null {
    return AppVersionUtil.cachedUpdateInfo;
  }

  /**
   * 检查 GitHub Release 最新版本
   * @param force 是否强制跳过缓存重新请求网络
   */
  static async checkUpdate(force: boolean = false): Promise<AppUpdateInfo> {
    const now = Date.now();
    if (!force && AppVersionUtil.cachedUpdateInfo && (now - AppVersionUtil.lastCheckTime < AppVersionUtil.CACHE_EXPIRE_MS)) {
      return AppVersionUtil.cachedUpdateInfo;
    }
    const currentVersion = await AppVersionUtil.getVersionName();
    const info: AppUpdateInfo = {
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      hasUpdate: false,
      releaseName: '',
      releaseNotes: '',
      releaseUrl: '',
      downloadUrl: ''
    };

    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(
        'https://api.github.com/repos/fe-spark/EcoHub-for-OHOS/releases?per_page=10',
        {
          method: http.RequestMethod.GET,
          header: {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'EcoHub-OHOS'
          },
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );
      httpRequest.destroy();
      if (response.responseCode !== 200 || !response.result) {
        throw new Error(`HTTP ${response.responseCode}`);
      }

      const releases = JSON.parse(response.result as string) as Array<Record<string, Object>>;
      if (!Array.isArray(releases) || releases.length === 0) {
        AppVersionUtil.cachedUpdateInfo = info;
        AppVersionUtil.lastCheckTime = now;
        return info;
      }

      for (let i = 0; i < releases.length; i++) {
        const item = releases[i];
        if (item['draft']) {
          continue;
        }
        // 正式版用户不提示测试版，已装 beta 的才跟 pre-release
        if (item['prerelease'] && currentVersion.indexOf('-') < 0) {
          continue;
        }
        const tagName = (item['tag_name'] as string) || '';
        const name = (item['name'] as string) || tagName;
        const body = (item['body'] as string) || '';
        const htmlUrl = (item['html_url'] as string) || '';
        let downloadUrl = htmlUrl;

        const assets = item['assets'] as Array<Record<string, Object>>;
        if (Array.isArray(assets) && assets.length > 0) {
          for (let j = 0; j < assets.length; j++) {
            const assetName = (assets[j]['name'] as string) || '';
            const browserDownloadUrl = (assets[j]['browser_download_url'] as string) || '';
            if (assetName.endsWith('.hap') && browserDownloadUrl) {
              downloadUrl = browserDownloadUrl;
              if (assetName.includes('signed')) {
                break;
              }
            }
          }
        }

        const normalizedTag = AppVersionUtil.normalizeVersion(tagName);
        info.latestVersion = normalizedTag;
        info.releaseName = name || `v${normalizedTag}`;
        info.releaseNotes = body;
        info.releaseUrl = htmlUrl;
        info.downloadUrl = downloadUrl;
        info.hasUpdate = AppVersionUtil.isNewerVersion(normalizedTag, currentVersion);
        break;
      }
      AppVersionUtil.cachedUpdateInfo = info;
      AppVersionUtil.lastCheckTime = now;
      return info;
    } catch (err) {
      httpRequest.destroy();
      if (AppVersionUtil.cachedUpdateInfo && !force) {
        return AppVersionUtil.cachedUpdateInfo;
      }
      if (err instanceof Error) {
        throw err;
      }
      throw new Error('检查版本失败');
    }
  }
}
