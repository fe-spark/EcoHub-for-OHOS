import { AnimatorResult } from '@kit.ArkUI';
import { FilmApi } from '../../api/FilmApi';
import { DanmakuComment } from '../../types/FilmModels';
import { ServerCompat } from '../../services/ServerCompat';

export class ActiveDanmaku {
  text: string = '';
  color: string = '#FFFFFF';
  shadow: string = 'rgba(0, 0, 0, 0.75)';
  border: boolean = false; // 高亮弹幕：加粗 + 圆角边框
  mode: number = 0; // 0: 滚动, 1: 顶部固定, 2: 底部固定
  time: number = 0; // 秒
  lane: number = 0; // 滚动：layer * 100 + row；固定：固定行序号
  row: number = 0; // 在统一行网格里的起始行
  rowSpan: number = 1; // 占几行（错开半行的第 1 层跨两行）
  width: number = 0; // vp
  height: number = 18; // vp
  x: number = 0; // vp
  y: number = 0; // vp
  speed: number = 0; // vp / 秒
  remainSec: number = 0;
}

class LanePick {
  lane: number = -1;
  row: number = 0;
  rowSpan: number = 1;
  y: number = 0;
}

/**
 * 弹幕渲染层，与 Android(Flutter) 端 `player_danmaku_layer.dart` 保持同一套排版模型：
 * - 安全区内的可用高度切成统一行网格，行高由实测文字高度 + 阴影 + 高亮边框留白 + 行间隙算出，
 *   保证相邻两行文字上下不重叠。
 * - 滚动弹幕使用上方 scrollAreaRatio 比例的行；第 0 层满了（仅全屏级别的大播放器）再用错开半行的第 1 层，
 *   第 1 层与它跨的两行做横向区间碰撞检测，绝不压在已用的相邻行上；仍满则排队，
 *   最多等待 MAX_WAIT_SEC 秒，等不到才丢弃（不再一满就丢）。
 * - 顶部固定弹幕从第 0 行往下、底部固定弹幕从最后一行往上各自占行，居中停留 FIXED_DURATION 秒；
 *   被固定弹幕占住的行，新的滚动弹幕会避开。
 * - 每条弹幕使用自身颜色；border 为 true 的高亮弹幕加粗并绘制圆角边框。
 */
@Component
export struct PlayerDanmakuLayer {
  private static readonly FONT_SIZE_VP: number = 14; // 字号 14 vp
  private static readonly SHADOW_EXTENT: number = 2; // 阴影偏移 1 + 模糊 2，上下各溢出约 2vp
  private static readonly BORDER_EXTENT: number = 2; // 高亮圆角框比文字上下各多出 2vp
  private static readonly ROW_GAP: number = 2; // 相邻两行之间额外留白
  private static readonly OFFSET_LAYER_MIN_ROWS: number = 10; // 行数不足时（小窗/竖屏）禁用错开半行的第 1 层
  private static readonly SCROLL_DURATION: number = 7.0; // 滚动横屏时间 7 秒
  private static readonly FIXED_DURATION: number = 4.0; // 固定弹幕停留 4 秒
  private static readonly LANE_GAP: number = 20; // 同一行前后两条弹幕最小间距 vp
  private static readonly MAX_WAIT_SEC: number = 2.0; // 行满时最多排队等待的视频时长
  private static readonly CATCH_UP_WINDOW: number = 2.0; // 时钟对齐跳跃后仍补发的最大滞后
  private static readonly MAX_PENDING: number = 300;
  private static readonly MAX_SPAWN_PER_TICK: number = 16;
  private static readonly TOP_PAD: number = 6;
  private static readonly BOTTOM_PAD: number = 8;
  private static readonly BORDER_PAD: number = 4;

  @Prop @Watch('reload') filmId: string = '';
  @Prop @Watch('reload') episode: number = 1;
  @Prop @Watch('reload') filmTitle: string = '';
  @Prop @Watch('onClock') currentTime: number = 0;
  @Prop @Watch('onPlaying') playing: boolean = false;
  @Prop @Watch('onVisibleChange') visible: boolean = true;
  @Prop playbackSpeed: number = 1.0;
  @Prop @Watch('onLayoutChange') isFull: boolean = false;
  @Prop @Watch('onLayoutChange') topInset: number = 0;
  @Prop @Watch('onLayoutChange') bottomInset: number = 0;
  @Prop @Watch('onLayoutChange') leftInset: number = 0;
  @Prop @Watch('onLayoutChange') rightInset: number = 0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private isCanvasReady: boolean = false;

  private animator: AnimatorResult | null = null;
  private isAnimating: boolean = false;
  private lastTickMs: number = 0;

  private allComments: DanmakuComment[] = [];
  private activeList: ActiveDanmaku[] = [];
  private pending: DanmakuComment[] = [];
  private nextIndex: number = 0;
  private currentVideoTime: number = 0;
  private loadKey: string = '';
  private gen: number = 0;

  private viewWidth: number = 0;
  private viewHeight: number = 0;
  private rowHeightCache: number = 0; // 0 表示尚未测量
  private textHeightCache: number = 0;

  aboutToAppear(): void {
    this.currentVideoTime = this.currentTime;
    this.reload();
  }

  aboutToDisappear(): void {
    this.gen++;
    this.stopAnimator();
    this.activeList = [];
    this.pending = [];
    this.allComments = [];
    this.isCanvasReady = false;
  }

  private onVisibleChange(): void {
    this.syncAnimatorState();
    if (!this.visible) {
      this.clearCanvas();
    } else {
      this.renderDanmaku();
    }
  }

  private onPlaying(): void {
    this.syncAnimatorState();
  }

  private onClock(): void {
    const drift = this.currentTime - this.currentVideoTime;
    // 跨度大于 2.0 秒（拖拽进度条 Seek、重新进入、切集）时触发完整重排回填
    if (Math.abs(drift) > 2.0) {
      this.currentVideoTime = this.currentTime;
      this.handleSeek(this.currentVideoTime);
    } else if (Math.abs(drift) > 0.4) {
      // 微小时间差仅平滑对齐基准时钟，不重排已有在屏弹幕，避免画面闪现跳动
      this.currentVideoTime = this.currentTime;
    }
  }

  private safeLeft(): number {
    return Math.max(0, this.leftInset);
  }

  private safeRight(): number {
    const minRight = this.safeLeft() + 100;
    const actualRight = this.viewWidth - Math.max(0, this.rightInset);
    return Math.max(minRight, actualRight);
  }

  private safeTop(): number {
    return Math.max(0, this.topInset);
  }

  private safeBottom(): number {
    const minBottom = this.safeTop() + 60;
    const actualBottom = this.viewHeight - Math.max(0, this.bottomInset);
    return Math.max(minBottom, actualBottom);
  }

  private onLayoutChange(): void {
    if (this.viewWidth <= 0 || this.viewHeight <= 0) {
      return;
    }
    // 安全区或全屏状态变化：行网格随之变化，按当前进度重排在屏弹幕，避免新旧行位叠在一起
    this.handleSeek(this.currentVideoTime);
  }

  private isLandscapeView(): boolean {
    return this.viewWidth > this.viewHeight && this.viewHeight > 0;
  }

  private gridTop(): number {
    // 弹幕起始 Y 轴锚定在安全区顶沿以下，绝不侵入状态栏/挖孔
    return this.safeTop() + PlayerDanmakuLayer.TOP_PAD;
  }

  /** 安全区内可用高度上的总行数 */
  private totalRows(): number {
    const usable = this.safeBottom() - PlayerDanmakuLayer.BOTTOM_PAD - this.gridTop();
    return Math.max(1, Math.floor(usable / this.rowHeight()));
  }

  /** 滚动弹幕显示区域：横屏上方约一半，竖屏小窗约 3/4（小窗行数本来就少） */
  private scrollRows(): number {
    const total = this.totalRows();
    const ratio = this.isLandscapeView() ? 0.55 : 0.75;
    const rows = Math.floor(total * ratio);
    return Math.min(16, Math.max(Math.min(2, total), rows));
  }

  /** 顶部、底部固定弹幕各自最多占几行 */
  private fixedRows(): number {
    return Math.max(1, Math.min(4, Math.floor(this.totalRows() / 3)));
  }

  private maxActive(): number {
    return this.isLandscapeView() ? 150 : 80;
  }

  private rowY(row: number): number {
    return this.gridTop() + row * this.rowHeight();
  }

  /** 单行文字实测高度（vp）：用中英混排样本、最粗字重测量，Canvas 未就绪时按字号 1.4 倍兜底 */
  private textHeight(): number {
    if (this.textHeightCache > 0) {
      return this.textHeightCache;
    }
    let h = 0;
    if (this.isCanvasReady) {
      try {
        this.context.font = this.fontFor(true);
        const metrics = this.context.measureText('国Ag弹幕');
        if (metrics && metrics.height > 0) {
          h = metrics.height;
        }
      } catch (_e) {}
    }
    if (h <= 0) {
      // 未就绪时不缓存，就绪后重新实测
      return Math.ceil(PlayerDanmakuLayer.FONT_SIZE_VP * 1.4);
    }
    this.textHeightCache = Math.max(h, PlayerDanmakuLayer.FONT_SIZE_VP);
    return this.textHeightCache;
  }

  /** 行高 = 文字高度 + 上下阴影/高亮框溢出 + 行间隙，保证相邻行文字不会上下重叠 */
  private rowHeight(): number {
    if (this.rowHeightCache > 0) {
      return this.rowHeightCache;
    }
    const extent = Math.max(PlayerDanmakuLayer.SHADOW_EXTENT, PlayerDanmakuLayer.BORDER_EXTENT);
    const h = Math.ceil(this.textHeight() + extent * 2 + PlayerDanmakuLayer.ROW_GAP);
    if (this.textHeightCache > 0) {
      this.rowHeightCache = h;
    }
    return h;
  }

  /** 错开半行的第 1 层只在大播放器（横屏且行数充足，即全屏级别）启用 */
  private allowOffsetLayer(): boolean {
    return this.isLandscapeView() && this.totalRows() >= PlayerDanmakuLayer.OFFSET_LAYER_MIN_ROWS;
  }

  /**
   * 候选位置（起始行 row、跨 span 行、横向区间 [x, x+w]）是否与在屏滚动弹幕冲突。
   * 所有滚动弹幕同速，相对位置恒定，只需比较当前横向区间。
   */
  private scrollBlocked(row: number, span: number, x: number, w: number): boolean {
    for (let i = 0; i < this.activeList.length; i++) {
      const act = this.activeList[i];
      if (act.mode !== 0) {
        continue;
      }
      const rowsIntersect = act.row < row + span && row < act.row + act.rowSpan;
      if (!rowsIntersect) {
        continue;
      }
      const separated = act.x + act.width + PlayerDanmakuLayer.LANE_GAP <= x ||
        x + w + PlayerDanmakuLayer.LANE_GAP <= act.x;
      if (!separated) {
        return true;
      }
    }
    return false;
  }

  private static cleanTitle(raw: string): string {
    let s = (raw || '').trim();
    const dotIdx = s.indexOf('·');
    if (dotIdx > 0) {
      s = s.substring(0, dotIdx).trim();
    }
    return s;
  }

  private static parseColor(raw: string): string {
    if (!raw) {
      return '#FFFFFF';
    }
    const hex = raw.replace('#', '').trim();
    if (hex.length === 6) {
      return '#' + hex;
    }
    if (hex.length === 8) {
      return '#' + hex.substring(2);
    }
    return '#FFFFFF';
  }

  /** 深色弹幕配浅色描边阴影，浅色弹幕配深色阴影，保证在任意画面上都看得清 */
  private static shadowFor(color: string): string {
    const hex = color.replace('#', '');
    if (hex.length !== 6) {
      return 'rgba(0, 0, 0, 0.75)';
    }
    const r = parseInt(hex.substring(0, 2), 16) / 255;
    const g = parseInt(hex.substring(2, 4), 16) / 255;
    const b = parseInt(hex.substring(4, 6), 16) / 255;
    if (isNaN(r) || isNaN(g) || isNaN(b)) {
      return 'rgba(0, 0, 0, 0.75)';
    }
    const lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    return lum < 0.25 ? 'rgba(255, 255, 255, 0.8)' : 'rgba(0, 0, 0, 0.75)';
  }

  private reload(): void {
    if (!ServerCompat.getInstance().canDanmaku || !this.filmId || this.filmId.trim().length === 0) {
      this.allComments = [];
      this.activeList = [];
      this.pending = [];
      this.nextIndex = 0;
      this.stopAnimator();
      this.clearCanvas();
      return;
    }

    const title = PlayerDanmakuLayer.cleanTitle(this.filmTitle);
    const key = `${this.filmId}_${this.episode}_${title}`;
    if (key === this.loadKey) {
      return;
    }
    this.loadKey = key;
    const token = ++this.gen;

    this.allComments = [];
    this.activeList = [];
    this.pending = [];
    this.nextIndex = 0;

    if (!this.filmId && !title) {
      return;
    }

    FilmApi.getDanmaku(this.filmId, this.episode > 0 ? this.episode : 1, title)
      .then((list: DanmakuComment[]) => {
        if (token !== this.gen) {
          return;
        }
        if (list.length === 0) {
          return;
        }
        list.sort((a: DanmakuComment, b: DanmakuComment) => a.time - b.time);
        this.allComments = list;
        this.handleSeek(this.currentVideoTime);
        this.syncAnimatorState();
      })
      .catch((err: Object) => {
        console.error(`[DanmakuLayer] 弹幕加载失败: ${JSON.stringify(err)}`);
      });
  }

  /**
   * Canvas 默认单位是 vp（measureText、坐标都是 vp），字号直接写 vp。
   * 旧写法 `${vp2px(14)}px` 混用了 px 与 vp，与 measureText 的 vp 结果不一致，字号可能被放大导致行间上下重叠。
   */
  private fontFor(bold: boolean): string {
    return `${bold ? 800 : 600} ${PlayerDanmakuLayer.FONT_SIZE_VP}vp sans-serif`;
  }

  private measureText(text: string, bold: boolean): number {
    if (this.isCanvasReady) {
      try {
        this.context.textBaseline = 'top';
        this.context.font = this.fontFor(bold);
        const metrics = this.context.measureText(text);
        if (metrics && metrics.width > 0) {
          // 系统 Canvas measureText(text).width 本身即为视口逻辑尺度(vp)，切勿二次 px2vp 缩小
          // 额外补充 6vp 规避加粗字形与特殊字符/Emoji渲染外溢
          return metrics.width + 6.0;
        }
      } catch (_e) {}
    }
    // Canvas 未就绪时的保守兜底：中文按 16.5vp 计算，英文按 9.5vp 计算，确保不低估字长导致压车
    let w = 0;
    for (let i = 0; i < text.length; i++) {
      const code = text.charCodeAt(i);
      w += code > 255 ? 16.5 : 9.5;
    }
    return w + 6.0;
  }

  private handleSeek(seekTime: number): void {
    this.activeList = [];
    this.pending = [];

    if (this.allComments.length === 0) {
      this.nextIndex = 0;
      this.renderDanmaku();
      return;
    }

    let low = 0;
    let high = this.allComments.length;
    while (low < high) {
      const mid = Math.floor((low + high) / 2);
      if (this.allComments[mid].time < seekTime) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    this.nextIndex = low;

    if (!this.visible || this.viewWidth <= 0 || this.viewHeight <= 0) {
      return;
    }

    // 回填最近 7 秒内本应在屏的弹幕（按已飞行时长摆位，排不下的直接跳过，不进队列）
    const minTime = seekTime - PlayerDanmakuLayer.SCROLL_DURATION;
    let startIdx = low - 1;
    while (startIdx >= 0 && this.allComments[startIdx].time >= minTime) {
      startIdx--;
    }
    startIdx = Math.max(0, startIdx + 1);

    const maxActive = this.maxActive();
    for (let i = startIdx; i < low; i++) {
      if (this.activeList.length >= maxActive) {
        break;
      }
      const c = this.allComments[i];
      const elapsed = seekTime - c.time;
      if (elapsed < 0 || elapsed >= PlayerDanmakuLayer.SCROLL_DURATION) {
        continue;
      }
      this.spawnSingleComment(c, elapsed);
    }

    this.renderDanmaku();
  }

  private spawnBetween(fromTime: number, toTime: number): void {
    if (!this.visible || this.viewWidth <= 0 || this.viewHeight <= 0) {
      return;
    }
    const maxActive = this.maxActive();
    let spawnedThisTick = 0;

    // 1. 先处理排队中的弹幕（先来先上），超过等待上限的丢弃
    if (this.pending.length > 0) {
      const keep: DanmakuComment[] = [];
      for (let i = 0; i < this.pending.length; i++) {
        const c = this.pending[i];
        if (toTime - c.time > PlayerDanmakuLayer.MAX_WAIT_SEC) {
          continue;
        }
        if (spawnedThisTick < PlayerDanmakuLayer.MAX_SPAWN_PER_TICK &&
          this.activeList.length < maxActive &&
          this.spawnSingleComment(c, 0)) {
          spawnedThisTick++;
        } else {
          keep.push(c);
        }
      }
      this.pending = keep;
    }

    // 2. 时间轴上新到点的弹幕
    while (this.nextIndex < this.allComments.length) {
      const c = this.allComments[this.nextIndex];
      if (c.time > toTime) {
        break;
      }
      this.nextIndex++;

      // 时钟对齐跳跃造成的滞后在 2 秒内仍补发（按已飞行时长摆位），更早的视为过期
      if (toTime - c.time > PlayerDanmakuLayer.CATCH_UP_WINDOW) {
        continue;
      }

      const canSpawnNow = spawnedThisTick < PlayerDanmakuLayer.MAX_SPAWN_PER_TICK &&
        this.activeList.length < maxActive;
      if (canSpawnNow && this.spawnSingleComment(c, Math.max(0, toTime - c.time))) {
        spawnedThisTick++;
        continue;
      }
      this.enqueue(c);
    }
  }

  private enqueue(c: DanmakuComment): void {
    if (this.pending.length >= PlayerDanmakuLayer.MAX_PENDING) {
      this.pending.shift();
    }
    this.pending.push(c);
  }

  private getScrollSpeed(): number {
    const safeW = this.safeRight() - this.safeLeft();
    // 恒定流速：同一视口下所有滚动弹幕速度一致，两车间距恒定不变，杜绝长短文本速度差异引发的追尾重叠
    return Math.max(60.0, (safeW + 160.0) / PlayerDanmakuLayer.SCROLL_DURATION);
  }

  /** 被在屏固定弹幕占用的行 */
  private fixedOccupiedRows(): Set<number> {
    const rows: Set<number> = new Set<number>();
    for (let i = 0; i < this.activeList.length; i++) {
      const act = this.activeList[i];
      if (act.mode !== 0) {
        rows.add(act.row);
      }
    }
    return rows;
  }

  /** 为滚动弹幕挑一条可用的行：第 0 层整行；大播放器上第 0 层全满时启用错开半行的第 1 层 */
  private pickScrollLane(startX: number, itemWidth: number): LanePick {
    const pick = new LanePick();
    const occupied = this.fixedOccupiedRows();
    const scrollRows = this.scrollRows();
    const rowH = this.rowHeight();
    const layers = this.allowOffsetLayer() ? 2 : 1;
    for (let layer = 0; layer < layers; layer++) {
      const span = layer === 0 ? 1 : 2;
      const rowsInLayer = scrollRows - (span - 1);
      for (let r = 0; r < rowsInLayer; r++) {
        let blocked = false;
        for (let k = 0; k < span; k++) {
          if (occupied.has(r + k)) {
            blocked = true;
          }
        }
        if (blocked || this.scrollBlocked(r, span, startX, itemWidth)) {
          continue;
        }
        pick.lane = layer * 100 + r;
        pick.row = r;
        pick.rowSpan = span;
        pick.y = this.rowY(r) + layer * rowH / 2;
        return pick;
      }
    }
    return pick;
  }

  /** 为固定弹幕挑一条空闲的固定行：顶部从上往下，底部从下往上 */
  private pickFixedLane(mode: number): LanePick {
    const pick = new LanePick();
    const maxFixed = this.fixedRows();
    const total = this.totalRows();
    for (let t = 0; t < maxFixed; t++) {
      let busy = false;
      for (let i = 0; i < this.activeList.length; i++) {
        const act = this.activeList[i];
        if (act.mode === mode && act.lane === t) {
          busy = true;
          break;
        }
      }
      if (!busy) {
        pick.lane = t;
        pick.row = mode === 1 ? t : Math.max(0, total - 1 - t);
        pick.y = this.rowY(pick.row);
        return pick;
      }
    }
    return pick;
  }

  private spawnSingleComment(c: DanmakuComment, elapsed: number = 0.0): boolean {
    const mode = c.mode === 1 ? 1 : (c.mode === 2 ? 2 : 0);
    if (mode !== 0 && elapsed >= PlayerDanmakuLayer.FIXED_DURATION) {
      return false;
    }
    const highlight = c.border === true;
    const safeL = this.safeLeft();
    const safeR = this.safeRight();
    const safeW = safeR - safeL;
    const speed = this.getScrollSpeed();
    const startX = safeR - (speed * elapsed);

    const pad = highlight ? PlayerDanmakuLayer.BORDER_PAD : 0;
    const itemWidth = this.measureText(c.text, highlight) + pad * 2;
    // 若因历史恢复计算出的位置已经滑出安全左边缘，直接跳过
    if (mode === 0 && startX + itemWidth < safeL - 10) {
      return false;
    }

    const pick = mode === 0 ? this.pickScrollLane(startX, itemWidth) : this.pickFixedLane(mode);
    if (pick.lane < 0) {
      return false; // 行满：由调用方决定排队还是放弃
    }
    const textH = this.textHeight();

    const color = PlayerDanmakuLayer.parseColor(c.color);
    const item = new ActiveDanmaku();
    item.text = c.text;
    item.color = color;
    item.shadow = PlayerDanmakuLayer.shadowFor(color);
    item.border = highlight;
    item.mode = mode;
    item.time = c.time;
    item.lane = pick.lane;
    item.row = pick.row;
    item.rowSpan = pick.rowSpan;
    item.width = itemWidth;
    item.height = textH;
    // 固定弹幕严格居中于安全可视区域内
    item.x = mode === 0 ? startX : safeL + Math.max(0, (safeW - itemWidth) / 2);
    // 文字在行内垂直居中（第 1 层跨两行时居中于两行交界，与上下行文字仍留有间隙）
    item.y = pick.y + (this.rowHeight() - textH) / 2;
    item.speed = mode === 0 ? speed : 0;
    item.remainSec = mode === 0 ?
      Math.max(0.1, PlayerDanmakuLayer.SCROLL_DURATION - elapsed) :
      Math.max(0.1, PlayerDanmakuLayer.FIXED_DURATION - elapsed);
    this.activeList.push(item);
    return true;
  }

  private onTick(): void {
    if (!this.visible || !this.playing || !this.isCanvasReady) {
      return;
    }
    const now = Date.now();
    if (this.lastTickMs === 0) {
      this.lastTickMs = now;
      return;
    }
    const dt = (now - this.lastTickMs) / 1000.0;
    this.lastTickMs = now;

    if (dt <= 0 || dt > 0.1) {
      return;
    }

    const speedFactor = Math.max(0.2, this.playbackSpeed > 0 ? this.playbackSpeed : 1.0);
    const lastTime = this.currentVideoTime;
    this.currentVideoTime += dt * speedFactor;

    this.spawnBetween(lastTime, this.currentVideoTime);

    const safeL = this.safeLeft();
    for (let i = this.activeList.length - 1; i >= 0; i--) {
      const item = this.activeList[i];
      if (item.mode === 0) {
        item.x -= item.speed * dt * speedFactor;
        if (item.x + item.width < safeL - 10) {
          this.activeList.splice(i, 1);
        }
      } else {
        item.remainSec -= dt * speedFactor;
        if (item.remainSec <= 0) {
          this.activeList.splice(i, 1);
        }
      }
    }

    this.renderDanmaku();
  }

  private drawBorderBox(ctx: CanvasRenderingContext2D, item: ActiveDanmaku): void {
    const x = item.x;
    const y = item.y - PlayerDanmakuLayer.BORDER_EXTENT;
    const w = item.width - 2;
    const h = item.height + PlayerDanmakuLayer.BORDER_EXTENT * 2;
    const r = h / 2;
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.arcTo(x + w, y, x + w, y + r, r);
    ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
    ctx.lineTo(x + r, y + h);
    ctx.arcTo(x, y + h, x, y + h - r, r);
    ctx.arcTo(x, y, x + r, y, r);
    ctx.closePath();
    ctx.fillStyle = 'rgba(0, 0, 0, 0.25)';
    ctx.fill();
    ctx.lineWidth = 1.2;
    ctx.strokeStyle = item.color;
    ctx.stroke();
  }

  private renderDanmaku(): void {
    if (!this.isCanvasReady || this.viewWidth <= 0 || this.viewHeight <= 0) {
      return;
    }
    const ctx = this.context;
    ctx.clearRect(0, 0, this.viewWidth, this.viewHeight);
    if (!this.visible || this.activeList.length === 0) {
      return;
    }

    const safeL = this.safeLeft();
    const safeR = this.safeRight();
    const safeT = this.safeTop();
    const safeB = this.safeBottom();
    const safeW = safeR - safeL;
    const safeH = safeB - safeT;

    if (safeW <= 0 || safeH <= 0) {
      return;
    }

    ctx.save();
    // 强制执行安全区域裁剪：任何超出安全区矩形的绘制均被拦截，绝对不侵入系统状态栏/挖孔/导航条
    ctx.beginPath();
    ctx.rect(safeL, safeT, safeW, safeH);
    ctx.clip();

    ctx.textBaseline = 'top';
    const normalFont = this.fontFor(false);
    const boldFont = this.fontFor(true);

    for (let i = 0; i < this.activeList.length; i++) {
      const item = this.activeList[i];
      if (item.y < safeT || item.y + item.height > safeB) {
        continue;
      }
      let textX = item.x;
      if (item.border) {
        ctx.shadowBlur = 0;
        ctx.shadowOffsetX = 0;
        ctx.shadowOffsetY = 0;
        this.drawBorderBox(ctx, item);
        textX = item.x + PlayerDanmakuLayer.BORDER_PAD + 2;
      }
      ctx.font = item.border ? boldFont : normalFont;
      ctx.shadowColor = item.shadow;
      ctx.shadowBlur = 2;
      ctx.shadowOffsetX = 1;
      ctx.shadowOffsetY = 1;
      ctx.fillStyle = item.color;
      ctx.fillText(item.text, textX, item.y);
    }
    ctx.restore();
  }

  private clearCanvas(): void {
    if (this.isCanvasReady && this.viewWidth > 0 && this.viewHeight > 0) {
      try {
        this.context.clearRect(0, 0, this.viewWidth, this.viewHeight);
      } catch (_e) {}
    }
  }

  private syncAnimatorState(): void {
    const shouldAnimate = this.visible && this.playing && ServerCompat.getInstance().canDanmaku;
    if (shouldAnimate) {
      if (!this.isAnimating) {
        this.lastTickMs = 0;
        this.startAnimator();
      }
    } else {
      this.stopAnimator();
      if (!this.visible) {
        this.clearCanvas();
      }
    }
  }

  private startAnimator(): void {
    if (this.isAnimating) {
      return;
    }
    if (!this.animator) {
      this.animator = this.getUIContext().createAnimator({
        duration: 16,
        easing: 'linear',
        begin: 0,
        end: 1,
        iterations: -1,
        fill: 'none',
        direction: 'normal',
        delay: 0
      });
      this.animator.setExpectedFrameRateRange({
        min: 30,
        max: 120,
        expected: 60
      });
      this.animator.onFrame = (_val: number) => {
        this.onTick();
      };
      this.animator.onFinish = () => {
        this.isAnimating = false;
      };
    }
    this.isAnimating = true;
    this.animator.play();
  }

  private stopAnimator(): void {
    if (this.animator) {
      try {
        this.animator.finish();
      } catch (_e) {}
      this.animator = null;
    }
    this.isAnimating = false;
  }

  build() {
    Stack() {
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .backgroundColor(Color.Transparent)
        .onReady(() => {
          this.isCanvasReady = true;
          // Canvas 就绪后才能实测文字高度：清掉兜底行高并按实测行高重排
          this.textHeightCache = 0;
          this.rowHeightCache = 0;
          if (this.allComments.length > 0) {
            this.handleSeek(this.currentVideoTime);
          }
          this.renderDanmaku();
          this.syncAnimatorState();
        })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
    .opacity(this.visible ? 0.82 : 0)
    .onAreaChange((_old: Area, area: Area) => {
      const w = Number(area.width);
      const h = Number(area.height);
      if (w > 0 && h > 0 && (w !== this.viewWidth || h !== this.viewHeight)) {
        this.viewWidth = w;
        this.viewHeight = h;
        // 尺寸或横竖屏变化：行网格与滚动速度都变了，按当前视频进度根据新视口平滑重排在屏弹幕
        this.handleSeek(this.currentVideoTime);
      }
    })
  }
}
