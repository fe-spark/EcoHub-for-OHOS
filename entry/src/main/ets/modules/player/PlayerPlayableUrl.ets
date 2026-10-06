import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

/**
 * 把采集站塞进一条字符串里的多地址，以及只含 EXT-X-STREAM-INF 的主列表，
 * 收成播放器能直接打开的媒体地址。
 * 这个源的主列表把 BANDWIDTH 写成 128，鸿蒙会拒掉唯一一路，或按错误的 RESOLUTION 排画面。
 */
export class PlayerPlayableUrl {
  private static readonly FETCH_MS: number = 1500;

  static async normalize(raw: string): Promise<string> {
    console.info(`[VideoLink] 列表解析前: ${raw}`);
    let current = PlayerPlayableUrl.firstUrl(raw);
    for (let hop = 0; hop < 2; hop++) {
      if (!PlayerPlayableUrl.isM3u8(current)) {
        return current;
      }
      const text = await PlayerPlayableUrl.fetchText(current);
      if (text.length === 0 || text.indexOf('#EXT-X-STREAM-INF') < 0 || text.indexOf('#EXTINF') >= 0) {
        return current;
      }
      const variant = PlayerPlayableUrl.bestVariant(text);
      if (variant.length === 0) {
        return current;
      }
      const next = PlayerPlayableUrl.resolve(current, variant);
      if (next === current) {
        return current;
      }
      console.info(`[PlayerPlayableUrl] 主列表改为媒体列表: ${next}`);
      current = next;
    }
    return current;
  }

  static firstUrl(raw: string): string {
    const text = raw.trim();
    const httpAt = text.indexOf('http://');
    const httpsAt = text.indexOf('https://');
    let start = -1;
    if (httpAt >= 0 && httpsAt >= 0) {
      start = httpAt < httpsAt ? httpAt : httpsAt;
    } else if (httpAt >= 0) {
      start = httpAt;
    } else if (httpsAt >= 0) {
      start = httpsAt;
    }
    if (start < 0) {
      return text;
    }
    let end = text.length;
    const stops: string[] = ['$$$', '#', ' ', '\n', '\r', '"', '\''];
    for (let i = 0; i < stops.length; i++) {
      const at = text.indexOf(stops[i], start);
      if (at >= 0 && at < end) {
        end = at;
      }
    }
    return text.substring(start, end).trim();
  }

  private static isM3u8(url: string): boolean {
    const q = url.indexOf('?');
    const path = (q >= 0 ? url.substring(0, q) : url).toLowerCase();
    return path.indexOf('.m3u8') >= 0;
  }

  private static async fetchText(url: string): Promise<string> {
    const client = http.createHttp();
    try {
      const res = await client.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: PlayerPlayableUrl.FETCH_MS,
        readTimeout: PlayerPlayableUrl.FETCH_MS,
        header: {
          'User-Agent': 'Mozilla/5.0 (Mobile; OpenHarmony)',
          'Accept': '*/*',
          'Accept-Encoding': 'identity'
        }
      });
      if (res.responseCode < 200 || res.responseCode >= 300) {
        return '';
      }
      return PlayerPlayableUrl.bodyText(res.result);
    } catch (err) {
      console.error(`[PlayerPlayableUrl] 读取列表失败: ${JSON.stringify(err)}`);
      return '';
    } finally {
      client.destroy();
    }
  }

  private static bodyText(result: string | Object | ArrayBuffer): string {
    if (typeof result === 'string') {
      return result;
    }
    if (result instanceof ArrayBuffer) {
      const decoder = util.TextDecoder.create('utf-8');
      return decoder.decodeToString(new Uint8Array(result));
    }
    return '';
  }

  private static bestVariant(text: string): string {
    const lines = text.split('\n');
    let pendingScore = -1;
    let bestScore = -1;
    let bestUri = '';
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line.length === 0) {
        continue;
      }
      if (line.indexOf('#EXT-X-STREAM-INF') === 0) {
        pendingScore = PlayerPlayableUrl.resolutionPixels(line);
        continue;
      }
      if (line.charAt(0) === '#') {
        continue;
      }
      if (pendingScore >= 0) {
        if (pendingScore >= bestScore) {
          bestScore = pendingScore;
          bestUri = line;
        }
        pendingScore = -1;
      }
    }
    return bestUri;
  }

  private static resolutionPixels(line: string): number {
    const upper = line.toUpperCase();
    const at = upper.indexOf('RESOLUTION=');
    if (at < 0) {
      return 0;
    }
    const rest = upper.substring(at + 'RESOLUTION='.length);
    const x = rest.indexOf('X');
    if (x <= 0) {
      return 0;
    }
    const w = Number.parseInt(rest.substring(0, x));
    let hEnd = x + 1;
    while (hEnd < rest.length && rest.charAt(hEnd) >= '0' && rest.charAt(hEnd) <= '9') {
      hEnd++;
    }
    const h = Number.parseInt(rest.substring(x + 1, hEnd));
    if (w > 0 && h > 0) {
      return w * h;
    }
    return 0;
  }

  private static resolve(base: string, ref: string): string {
    if (ref.indexOf('http://') === 0 || ref.indexOf('https://') === 0) {
      return ref;
    }
    const hash = base.indexOf('#');
    const noHash = hash >= 0 ? base.substring(0, hash) : base;
    const q = noHash.indexOf('?');
    const masterQuery = q >= 0 ? noHash.substring(q + 1) : '';
    const clean = q >= 0 ? noHash.substring(0, q) : noHash;
    const refQ = ref.indexOf('?');
    const refPath = refQ >= 0 ? ref.substring(0, refQ) : ref;
    const refQuery = refQ >= 0 ? ref.substring(refQ + 1) : '';
    let joined: string;
    if (refPath.charAt(0) === '/') {
      const proto = clean.indexOf('://');
      const hostStart = proto >= 0 ? proto + 3 : 0;
      const pathStart = clean.indexOf('/', hostStart);
      const origin = pathStart >= 0 ? clean.substring(0, pathStart) : clean;
      joined = origin + refPath;
    } else {
      const slash = clean.lastIndexOf('/');
      const dir = slash >= 0 ? clean.substring(0, slash + 1) : clean;
      joined = dir + refPath;
    }
    joined = PlayerPlayableUrl.normalizePath(joined);
    const query = PlayerPlayableUrl.mergeQuery(refQuery, masterQuery);
    if (query.length === 0) {
      return joined;
    }
    return joined + '?' + query;
  }

  private static normalizePath(url: string): string {
    const proto = url.indexOf('://');
    const hostStart = proto >= 0 ? proto + 3 : 0;
    const pathStart = url.indexOf('/', hostStart);
    if (pathStart < 0) {
      return url;
    }
    const origin = url.substring(0, pathStart);
    const parts = url.substring(pathStart).split('/');
    const stack: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      if (part.length === 0 || part === '.') {
        if (i === 0) {
          stack.push('');
        }
        continue;
      }
      if (part === '..') {
        if (stack.length > 1) {
          stack.pop();
        }
        continue;
      }
      stack.push(part);
    }
    if (stack.length === 0) {
      return origin + '/';
    }
    return origin + stack.join('/');
  }

  private static mergeQuery(refQuery: string, masterQuery: string): string {
    if (masterQuery.length === 0) {
      return refQuery;
    }
    if (refQuery.length === 0) {
      return masterQuery;
    }
    const seen: string[] = [];
    const refParts = refQuery.split('&');
    for (let i = 0; i < refParts.length; i++) {
      const key = PlayerPlayableUrl.queryKey(refParts[i]);
      if (key.length > 0) {
        seen.push(key);
      }
    }
    let merged = refQuery;
    const masterParts = masterQuery.split('&');
    for (let i = 0; i < masterParts.length; i++) {
      const part = masterParts[i];
      if (part.length === 0) {
        continue;
      }
      const key = PlayerPlayableUrl.queryKey(part);
      if (key.length > 0 && seen.indexOf(key) >= 0) {
        continue;
      }
      merged = merged + '&' + part;
      if (key.length > 0) {
        seen.push(key);
      }
    }
    return merged;
  }

  private static queryKey(part: string): string {
    const eq = part.indexOf('=');
    return eq >= 0 ? part.substring(0, eq) : part;
  }
}
