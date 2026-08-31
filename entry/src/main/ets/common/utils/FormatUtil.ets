import { BannerItem, MovieBasicInfo } from '../../model/FilmModels';
import { ServerConfigManager } from './ServerConfigManager';

export class FormatUtil {
  static text(value: string | number | undefined | null, fallback: string = ''): string {
    if (value === undefined || value === null) {
      return fallback;
    }
    const text = `${value}`.trim();
    if (text === '' || text === '0') {
      return fallback;
    }
    return text;
  }

  static year(value: string | number | undefined | null): string {
    const text = FormatUtil.text(value);
    return text.length >= 4 ? text.slice(0, 4) : text;
  }

  static poster(film: MovieBasicInfo): string {
    const raw = film.picture || film.poster || film.pictureSlide || '';
    return ServerConfigManager.getInstance().resolveMediaUrl(raw);
  }

  static bannerPoster(item: BannerItem): string {
    const raw = item.poster || item.picture || item.pictureSlide || '';
    return ServerConfigManager.getInstance().resolveMediaUrl(raw);
  }

  static bannerBackdrop(item: BannerItem): string {
    const raw = item.pictureSlide || item.picture || item.poster || '';
    return ServerConfigManager.getInstance().resolveMediaUrl(raw);
  }

  static filmId(film: MovieBasicInfo): string {
    if (film.id > 0) {
      return `${film.id}`;
    }
    return FormatUtil.text(film.mid);
  }

  static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  static duration(seconds: number): string {
    const total = Math.max(0, Math.floor(seconds));
    const hour = Math.floor(total / 3600);
    const minute = Math.floor((total % 3600) / 60);
    const second = total % 60;
    if (hour > 0) {
      return `${FormatUtil.pad2(hour)}:${FormatUtil.pad2(minute)}:${FormatUtil.pad2(second)}`;
    }
    return `${FormatUtil.pad2(minute)}:${FormatUtil.pad2(second)}`;
  }

  static progress(current: number, duration: number): string {
    if (!current || current <= 0) {
      return '未观看';
    }
    if (!duration || duration <= 0) {
      return `观看至 ${FormatUtil.duration(current)}`;
    }
    if (current >= duration - 2) {
      return '已看完';
    }
    const percent = Math.max(1, Math.min(99, Math.floor((current / duration) * 100)));
    return `观看至 ${FormatUtil.duration(current)} (${percent}%)`;
  }

  static dateTime(stamp: number): string {
    if (!stamp) {
      return '';
    }
    const date = new Date(stamp);
    return `${date.getFullYear()}-${FormatUtil.pad2(date.getMonth() + 1)}-${FormatUtil.pad2(date.getDate())} ${FormatUtil.pad2(date.getHours())}:${FormatUtil.pad2(date.getMinutes())}`;
  }

  static joinMeta(parts: string[]): string {
    const items: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      if (parts[i]) {
        items.push(parts[i]);
      }
    }
    return items.join(' · ');
  }

  private static readonly TAG_BG: string[] = [
    'rgba(250, 140, 22, 0.28)',
    'rgba(96, 165, 250, 0.28)',
    'rgba(52, 211, 153, 0.28)',
    'rgba(167, 139, 250, 0.28)',
    'rgba(251, 113, 133, 0.28)',
    'rgba(34, 211, 238, 0.28)',
    'rgba(250, 204, 21, 0.28)',
    'rgba(129, 140, 248, 0.28)'
  ];
  private static readonly TAG_BORDER: string[] = [
    'rgba(250, 140, 22, 0.48)',
    'rgba(96, 165, 250, 0.48)',
    'rgba(52, 211, 153, 0.48)',
    'rgba(167, 139, 250, 0.48)',
    'rgba(251, 113, 133, 0.48)',
    'rgba(34, 211, 238, 0.48)',
    'rgba(250, 204, 21, 0.48)',
    'rgba(129, 140, 248, 0.48)'
  ];

  private static tagIndex(id: number, name: string): number {
    let hash = id * 7;
    for (let i = 0; i < name.length; i++) {
      hash = (hash * 33 + name.charCodeAt(i)) | 0;
    }
    const n = FormatUtil.TAG_BG.length;
    let index = hash % n;
    if (index < 0) {
      index += n;
    }
    return index;
  }

  static tagBg(id: number, name: string = ''): string {
    return FormatUtil.TAG_BG[FormatUtil.tagIndex(id, name)];
  }

  static tagBorder(id: number, name: string = ''): string {
    return FormatUtil.TAG_BORDER[FormatUtil.tagIndex(id, name)];
  }
}
