import { pasteboard } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export interface SniffResult {
  url: string;
  raw: string;
  requiresAuth?: boolean;
}

export class ClipboardSniffer {
  private static readonly PREF_NAME: string = 'ecohub_clipboard_history';
  private static readonly KEY_LAST_HANDLED_RAW: string = 'last_handled_raw';

  private static pref: preferences.Preferences | null = null;
  private static isListening: boolean = false;
  private static lastHandledRawText: string = '';
  private static lastDismissedTime: number = 0;
  private static lastDismissedSource: string = '';
  private static hasSystemUpdate: boolean = false;

  /**
   * 初始化剪贴板监听器与持久化偏好
   */
  static async init(context?: common.UIAbilityContext): Promise<void> {
    if (context && !ClipboardSniffer.pref) {
      try {
        ClipboardSniffer.pref = await preferences.getPreferences(context, ClipboardSniffer.PREF_NAME);
        ClipboardSniffer.lastHandledRawText = (await ClipboardSniffer.pref.get(ClipboardSniffer.KEY_LAST_HANDLED_RAW, '')) as string;
      } catch (err) {
        console.warn('[ClipboardSniffer] init preferences failed:', JSON.stringify(err));
      }
    }

    if (!ClipboardSniffer.isListening) {
      try {
        pasteboard.getSystemPasteboard().on('update', () => {
          console.info('[ClipboardSniffer] 系统剪贴板内容发生变更');
          ClipboardSniffer.hasSystemUpdate = true;
          ClipboardSniffer.lastDismissedTime = 0;
          AppStorage.setOrCreate<number>('CLIPBOARD_UPDATE_TICK', Date.now());
        });
        ClipboardSniffer.isListening = true;
      } catch (e) {
        console.warn('[ClipboardSniffer] 注册剪贴板更新监听失败:', JSON.stringify(e));
      }
    }
  }

  /**
   * 获取当前剪贴板数据来源包名
   */
  static getClipSource(): string {
    try {
      const pb = pasteboard.getSystemPasteboard();
      if (typeof pb.getDataSource === 'function') {
        return pb.getDataSource() || '';
      }
    } catch (_e) {}
    return '';
  }

  /**
   * 检查系统剪贴板是否有内容（系统原生免权限 API）
   */
  static hasClipData(): boolean {
    if (AppStorage.get<boolean>('SETTING_CLIPBOARD_SNIFFER') === false) {
      return false;
    }
    try {
      return pasteboard.getSystemPasteboard().hasDataSync();
    } catch (_e) {
      return false;
    }
  }

  /**
   * 从剪切板文本中解析出有效的 http/https 播放直链
   */
  static extractVideoUrl(text: string): string {
    if (!text) return '';
    const cleanText = text.trim();
    if (!cleanText) return '';

    // 1. 匹配 http:// 或 https:// 起始的完整 URL（排除空格及中文字符）
    const urlRegex = /(https?:\/\/[^\s"'<>\u4e00-\u9fa5\r\n]+)/i;
    const match = cleanText.match(urlRegex);
    if (match && match[1]) {
      let url = match[1].trim().replace(/[。，！？；：、）】》"'\]\)\>]+$/, '');
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
      }
    }

    // 2. 兼容省略协议头的直链格式 (如 192.168.1.10:8080/live.m3u8 或 domain.com/test.mp4)
    if (cleanText.includes('.m3u8') || cleanText.includes('.mp4') || cleanText.includes('.flv')) {
      const noProtoRegex = /([a-zA-Z0-9][-a-zA-Z0-9.]*(\.[a-zA-Z]{2,}|:[0-9]+)\/[^\s"'<>\u4e00-\u9fa5\r\n]+)/i;
      const m = cleanText.match(noProtoRegex);
      if (m && m[1]) {
        return 'http://' + m[1].trim().replace(/[。，！？；：、）】》"'\]\)\>]+$/, '');
      }
    }

    return '';
  }

  /**
   * 判断当前是否应该向用户展示底部嗅探浮条
   * @param isForegroundEvent 是否由切回前台事件触发
   */
  static shouldShowBanner(isForegroundEvent: boolean = false): boolean {
    if (AppStorage.get<boolean>('SETTING_CLIPBOARD_SNIFFER') === false) {
      return false;
    }
    if (!ClipboardSniffer.hasClipData()) {
      return false;
    }

    // 1. 若系统剪贴板更新事件触发，必定响应展示
    if (ClipboardSniffer.hasSystemUpdate) {
      return true;
    }

    // 2. 若当前处于冷却期内（用户刚关闭/超时/处理过）：
    if (ClipboardSniffer.lastDismissedTime > 0) {
      const currentSource = ClipboardSniffer.getClipSource();
      // 数据来源发生变更（例如从本应用切换到微信/浏览器复制），立即解除冷却响应
      if (currentSource && currentSource !== ClipboardSniffer.lastDismissedSource) {
        return true;
      }
      // 来源未变且在冷却期内（3分钟内），绝不重复弹出
      if (Date.now() - ClipboardSniffer.lastDismissedTime < 3 * 60 * 1000) {
        return false;
      }
    }

    // 3. 冷启动或冷却期结束后，允许展示
    return true;
  }

  /**
   * 检查文本是否已被消费处理
   */
  static isHandled(rawText: string): boolean {
    const trimmed = (rawText || '').trim();
    return !!trimmed && trimmed === ClipboardSniffer.lastHandledRawText;
  }

  /**
   * 从已获得的 PasteData 中解析视频链接
   */
  static parsePasteData(pasteData: pasteboard.PasteData | null): SniffResult {
    if (!pasteData) {
      return { url: '', raw: '' };
    }
    let rawText: string = '';
    try {
      rawText = pasteData.getPrimaryText() || '';
    } catch (_e) {}

    if (!rawText) {
      try {
        rawText = pasteData.getPrimaryUri() || '';
      } catch (_e) {}
    }

    if (!rawText && pasteData.getRecordCount) {
      try {
        const count: number = pasteData.getRecordCount();
        for (let i = 0; i < count; i++) {
          const rec: pasteboard.PasteDataRecord = pasteData.getRecord(i);
          if (rec) {
            const plain: string = rec.toPlainText ? rec.toPlainText() : '';
            if (plain && plain.trim()) {
              rawText = plain;
              break;
            }
            const uriStr: string = rec.uri;
            if (uriStr && uriStr.trim()) {
              rawText = uriStr;
              break;
            }
          }
        }
      } catch (_e) {}
    }

    if (!rawText || !rawText.trim()) {
      return { url: '', raw: '' };
    }

    const trimmed = rawText.trim();
    const videoUrl = ClipboardSniffer.extractVideoUrl(trimmed);
    return { url: videoUrl, raw: trimmed };
  }

  /**
   * 嗅探当前剪切板（兼容直接读取与传入数据两种模式）
   */
  static async sniff(providedData?: pasteboard.PasteData): Promise<SniffResult> {
    if (AppStorage.get<boolean>('SETTING_CLIPBOARD_SNIFFER') === false) {
      return { url: '', raw: '', requiresAuth: false };
    }
    try {
      let pasteData: pasteboard.PasteData | null = providedData || null;
      let requiresAuth = false;
      if (!pasteData) {
        const pb = pasteboard.getSystemPasteboard();
        try {
          pasteData = await pb.getData();
        } catch (_e) {
          requiresAuth = true;
        }
      }

      if (requiresAuth) {
        return { url: '', raw: '', requiresAuth: true };
      }

      const res = ClipboardSniffer.parsePasteData(pasteData);
      return { url: res.url, raw: res.raw, requiresAuth: false };
    } catch (_err) {
      return { url: '', raw: '', requiresAuth: true };
    }
  }

  /**
   * 标记指定剪切板原始文本已处理，更新持久化状态并开启冷却
   */
  static markHandled(rawText: string): void {
    const trimmed = (rawText || '').trim();
    ClipboardSniffer.lastHandledRawText = trimmed;
    ClipboardSniffer.markDismissed();
    if (ClipboardSniffer.pref && trimmed) {
      ClipboardSniffer.pref.put(ClipboardSniffer.KEY_LAST_HANDLED_RAW, trimmed).then(() => {
        return ClipboardSniffer.pref?.flush();
      }).catch((_e: Object) => {});
    }
  }

  /**
   * 标记当前提示已被消费或忽略（同来源未变前开启冷却，不再重复提示）
   */
  static markDismissed(): void {
    ClipboardSniffer.hasSystemUpdate = false;
    ClipboardSniffer.lastDismissedTime = Date.now();
    ClipboardSniffer.lastDismissedSource = ClipboardSniffer.getClipSource();
  }

  /**
   * 重置处理历史
   */
  static reset(): void {
    ClipboardSniffer.lastHandledRawText = '';
    ClipboardSniffer.lastDismissedTime = 0;
    ClipboardSniffer.lastDismissedSource = '';
    ClipboardSniffer.hasSystemUpdate = false;
    if (ClipboardSniffer.pref) {
      ClipboardSniffer.pref.delete(ClipboardSniffer.KEY_LAST_HANDLED_RAW).catch((_e: Object) => {});
    }
  }
}
