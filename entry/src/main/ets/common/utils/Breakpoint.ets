import { AppTheme } from '../constants/AppTheme';

export class Breakpoint {
  static readonly KEY_BP: string = 'WIDTH_BP';
  static readonly KEY_WIDTH: string = 'WINDOW_WIDTH';
  static readonly KEY_HEIGHT: string = 'WINDOW_HEIGHT';

  static ofWidth(vp: number): string {
    if (vp >= 1440) {
      return 'xl';
    }
    if (vp >= 840) {
      return 'lg';
    }
    if (vp >= 600) {
      return 'md';
    }
    return 'sm';
  }

  static publish(widthVp: number, heightVp: number): void {
    AppStorage.setOrCreate<number>(Breakpoint.KEY_WIDTH, widthVp);
    AppStorage.setOrCreate<number>(Breakpoint.KEY_HEIGHT, heightVp);
    AppStorage.setOrCreate<string>(Breakpoint.KEY_BP, Breakpoint.ofWidth(widthVp));
  }

  static current(): string {
    const bp = AppStorage.get<string>(Breakpoint.KEY_BP);
    return bp ? bp : 'sm';
  }

  static windowWidth(): number {
    const w = AppStorage.get<number>(Breakpoint.KEY_WIDTH);
    return w !== undefined && w > 0 ? w : 360;
  }

  static windowHeight(): number {
    const h = AppStorage.get<number>(Breakpoint.KEY_HEIGHT);
    return h !== undefined && h > 0 ? h : 640;
  }

  static isWide(bp: string): boolean {
    return bp === 'md' || bp === 'lg' || bp === 'xl';
  }

  static isTabletOrFold(): boolean {
    const minSide = Math.min(Breakpoint.windowWidth(), Breakpoint.windowHeight());
    return minSide >= 560;
  }

  static gridCols(bp: string, windowWidth?: number): number {
    const w = (windowWidth !== undefined && windowWidth > 0) ? windowWidth : Breakpoint.windowWidth();
    if (w >= 1440 || bp === 'xl') {
      return 8;
    }
    if (w >= 1100) {
      return 7;
    }
    if (w >= 840 || bp === 'lg') {
      return 6;
    }
    if (w >= 600 || bp === 'md') {
      return 4;
    }
    return 3;
  }

  static gridColsOf(widthVp: number): number {
    return Breakpoint.gridCols(Breakpoint.ofWidth(widthVp), widthVp);
  }

  static cardWidth(bp: string, windowWidth?: number): number {
    const w = (windowWidth !== undefined && windowWidth > 0) ? windowWidth : Breakpoint.windowWidth();
    const cols = Breakpoint.gridCols(bp, w);
    const padding = AppTheme.SPACE_LG * 2;
    const gap = AppTheme.SPACE_SM;
    const cardW = Math.floor((w - padding - (cols - 1) * gap) / cols);
    return Math.max(104, cardW);
  }

  static listLanes(bp: string): number {
    if (bp === 'xl') {
      return 3;
    }
    if (bp === 'lg' || bp === 'md') {
      return 2;
    }
    return 1;
  }

  static bannerHeight(bp: string, multi: boolean, windowHeight?: number): number {
    const h = (windowHeight !== undefined && windowHeight > 0) ? windowHeight : Breakpoint.windowHeight();
    if (Breakpoint.isWide(bp)) {
      if (h > 0 && h < 500) {
        return multi ? 240 : 255;
      }
      return multi ? 340 : 360;
    }
    return multi ? 420 : 440;
  }

  static bannerPeek(bp: string, windowWidth?: number): number {
    const w = (windowWidth !== undefined && windowWidth > 0) ? windowWidth : Breakpoint.windowWidth();
    if (w >= 1440) {
      return 96;
    }
    if (w >= 1100) {
      return 64;
    }
    if (Breakpoint.isWide(bp)) {
      return 40;
    }
    return 20;
  }

  static columnsTemplate(cols: number): string {
    const n = cols > 1 ? cols : 3;
    let t = '1fr';
    for (let i = 1; i < n; i++) {
      t += ' 1fr';
    }
    return t;
  }

  static colIds(n: number): number[] {
    const ids: number[] = [];
    for (let i = 0; i < n; i++) {
      ids.push(i);
    }
    return ids;
  }

  static rowIds(total: number, cols: number): number[] {
    const safeCols = cols > 0 ? cols : 3;
    const n = Math.ceil(total / safeCols);
    const ids: number[] = [];
    for (let i = 0; i < n; i++) {
      ids.push(i);
    }
    return ids;
  }
}
