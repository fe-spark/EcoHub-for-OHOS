export interface LivePlayIdentity {
  sourceId: string;
  sid: string;
}

export class PlayNavigation {
  static isLocalFilmId(id: string | number): boolean {
    const text = `${id}`.trim();
    if (!text || text.indexOf(':') >= 0) {
      return false;
    }
    const value = Number(text);
    return isFinite(value) && value > 0;
  }

  static livePlayHistoryId(sourceId: string, sourceMid: string): string {
    const source = sourceId.trim();
    const sid = sourceMid.trim();
    if (!source || !sid || sid === '0') {
      return '';
    }
    return `${source}:${sid}`;
  }

  static splitLivePlayId(id: string): LivePlayIdentity | null {
    const text = id.trim();
    const sep = text.lastIndexOf(':');
    if (sep <= 0 || sep === text.length - 1) {
      return null;
    }
    return {
      sourceId: text.substring(0, sep),
      sid: text.substring(sep + 1)
    };
  }
}
