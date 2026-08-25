import { bundleManager } from '@kit.AbilityKit';

export class AppVersionUtil {
  public static readonly APP_VERSION: string = '1.0.5';
  private static cachedVersionName: string = '';

  /**
   * 获取当前 App 的版本名称（如 "1.0.3"）
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
}
