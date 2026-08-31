import { pasteboard } from '@kit.BasicServicesKit';

export interface SniffResult {
  url: string;
  raw: string;
}

export class ClipboardSniffer {
  private static lastHandledRawText: string = '';

  /**
   * 从剪切板文本中解析出有效的 http/https 播放直链
   */
  static extractVideoUrl(text: string): string {
    if (!text) {
      return '';
    }
    const cleanText = text.trim();
    if (!cleanText) {
      return '';
    }

    // 匹配 http:// 或 https:// 起始的完整 URL（排除空格及中文字符）
    const urlRegex = /(https?:\/\/[^\s"'<>\u4e00-\u9fa5\r\n]+)/i;
    const match = cleanText.match(urlRegex);
    if (!match || !match[1]) {
      return '';
    }

    let url = match[1].trim();
    // 移除末尾常见的中文或英文标点符号
    url = url.replace(/[。，！？；：、）】》"'\]\)\>]+$/, '');

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    return '';
  }

  /**
   * 嗅探当前剪切板（兼容多种 API 获取方式与数据格式）
   * @returns 解析到的视频链接与原始文本（若已处理过或无匹配则 url 为空）
   */
  static async sniff(): Promise<SniffResult> {
    try {
      const pb = pasteboard.getSystemPasteboard() as Object as Record<string, Function>;
      let pasteData: pasteboard.PasteData | null = null;

      if (typeof pb['getDataSync'] === 'function') {
        try {
          pasteData = pb['getDataSync']() as pasteboard.PasteData;
        } catch (_e) {
        }
      }

      if (!pasteData && typeof pb['getData'] === 'function') {
        try {
          pasteData = await (pb['getData']() as Promise<pasteboard.PasteData>);
        } catch (_e) {
        }
      }

      if (!pasteData) {
        return { url: '', raw: '' };
      }

      let rawText: string = '';
      try {
        rawText = pasteData.getPrimaryText() || '';
      } catch (_e) {
      }

      if (!rawText) {
        try {
          rawText = pasteData.getPrimaryUri() || '';
        } catch (_e) {
        }
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
        } catch (_e) {
        }
      }

      if (!rawText || !rawText.trim()) {
        return { url: '', raw: '' };
      }

      const trimmed = rawText.trim();
      if (trimmed === ClipboardSniffer.lastHandledRawText) {
        return { url: '', raw: trimmed };
      }

      const videoUrl = ClipboardSniffer.extractVideoUrl(trimmed);
      return { url: videoUrl, raw: trimmed };
    } catch (_err) {
      return { url: '', raw: '' };
    }
  }

  /**
   * 标记指定剪切板原始文本已处理，避免后续重复弹窗
   */
  static markHandled(rawText: string): void {
    ClipboardSniffer.lastHandledRawText = (rawText || '').trim();
  }

  /**
   * 重置处理历史
   */
  static reset(): void {
    ClipboardSniffer.lastHandledRawText = '';
  }
}
