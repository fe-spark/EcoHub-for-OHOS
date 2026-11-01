import { AnimatorResult } from '@kit.ArkUI';
import { FilmApi } from '../../api/FilmApi';
import { DanmakuComment } from '../../types/FilmModels';
import { ServerCompat } from '../../services/ServerCompat';

export class ActiveDanmaku {
  text: string = '';
  color: string = '#FFFFFF';
  mode: number = 0; // 0: 滚动, 1: 顶部固定, 2: 底部固定
  time: number = 0; // 秒
  track: number = 0;
  width: number = 0; // vp
  height: number = 18; // vp
  x: number = 0; // vp
  y: number = 0; // vp
  speed: number = 0; // vp / 秒
  remainSec: number = 0;
}

@Component
export struct PlayerDanmakuLayer {
  private static readonly TRACK_HEIGHT: number = 26; // 轨道高度 26 vp
  private static readonly FONT_SIZE_VP: number = 14; // 字号 14 vp
  private static readonly SCROLL_DURATION: number = 7.0; // 滚动横屏时间 7 秒
  private static readonly FIXED_DURATION: number = 4.0; // 固定弹幕停留 4 秒

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
  private fixedTopFreeTime: Map<number, number> = new Map();
  private fixedBottomFreeTime: Map<number, number> = new Map();
  private nextIndex: number = 0;
  private currentVideoTime: number = 0;
  private loadKey: string = '';
  private gen: number = 0;

  private viewWidth: number = 0;
  private viewHeight: number = 0;

  aboutToAppear(): void {
    this.currentVideoTime = this.currentTime;
    this.reload();
  }

  aboutToDisappear(): void {
    this.gen++;
    this.stopAnimator();
    this.activeList = [];
    this.fixedTopFreeTime.clear();
    this.fixedBottomFreeTime.clear();
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
    const safeL = this.safeLeft();
    const safeW = this.safeRight() - safeL;
    const baseY = this.topBaseY();
    const bottomBase = this.safeBottom() - 24.0;
    for (let i = 0; i < this.activeList.length; i++) {
      const item = this.activeList[i];
      if (item.mode === 0 || item.mode === 1) {
        item.y = baseY + item.track * PlayerDanmakuLayer.TRACK_HEIGHT;
      } else if (item.mode === 2) {
        item.y = Math.max(baseY, bottomBase - item.track * PlayerDanmakuLayer.TRACK_HEIGHT);
      }
      if (item.mode === 1 || item.mode === 2) {
        item.x = safeL + (safeW - item.width) / 2;
      }
    }
    this.renderDanmaku();
  }

  private isLandscapeView(): boolean {
    return this.viewWidth > this.viewHeight && this.viewHeight > 0;
  }

  private topBaseY(): number {
    // 严禁绕开安全区：不论全屏、横屏分栏还是竖屏，弹幕起始 Y 轴均锚定在安全区顶沿以下 8vp 呼吸距离
    return this.safeTop() + 8.0;
  }

  private bottomSafeMargin(): number {
    return Math.max(0, this.bottomInset) + 24.0;
  }

  private calculateMaxTracks(usableHeight: number): number {
    if (this.isLandscapeView()) {
      // 横屏模式：将弹幕严格限制在屏幕上方 38% 高度内（3~5 轨），保持居顶紧凑，避免大面积分散遮挡画面主体与字幕
      const tracksByHeight = Math.floor((usableHeight * 0.38) / PlayerDanmakuLayer.TRACK_HEIGHT);
      return Math.min(5, Math.max(3, tracksByHeight));
    }
    // 竖屏模式：播放器高度紧凑，限制在 2~4 轨
    const tracksByHeight = Math.floor((usableHeight * 0.50) / PlayerDanmakuLayer.TRACK_HEIGHT);
    return Math.min(4, Math.max(2, tracksByHeight));
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
    let hex = raw.replace('#', '').trim();
    if (hex.length === 6) {
      return '#' + hex;
    }
    if (hex.length === 8) {
      return '#' + hex.substring(2);
    }
    return '#FFFFFF';
  }

  private static hashCode(str: string): number {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      hash = ((hash << 5) - hash) + str.charCodeAt(i);
      hash |= 0;
    }
    return hash;
  }

  private reload(): void {
    if (!ServerCompat.getInstance().canDanmaku) {
      this.allComments = [];
      this.activeList = [];
      this.fixedTopFreeTime.clear();
      this.fixedBottomFreeTime.clear();
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
    this.fixedTopFreeTime.clear();
    this.fixedBottomFreeTime.clear();
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

  private syncCanvasFont(): void {
    if (this.isCanvasReady) {
      try {
        this.context.textBaseline = 'top';
        this.context.font = `600 ${vp2px(PlayerDanmakuLayer.FONT_SIZE_VP)}px sans-serif`;
      } catch (_e) {}
    }
  }

  private measureText(text: string): number {
    if (this.isCanvasReady) {
      try {
        this.syncCanvasFont();
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
    this.fixedTopFreeTime.clear();
    this.fixedBottomFreeTime.clear();

    if (this.allComments.length === 0) {
      this.nextIndex = 0;
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

    const minTime = seekTime - PlayerDanmakuLayer.SCROLL_DURATION;
    let startIdx = low - 1;
    while (startIdx >= 0 && this.allComments[startIdx].time >= minTime) {
      startIdx--;
    }
    startIdx = Math.max(0, startIdx + 1);

    const usableHeight = Math.max(60, this.viewHeight - this.topBaseY() - this.bottomSafeMargin());
    const maxTracks = this.calculateMaxTracks(usableHeight);
    const maxActive = this.isLandscapeView() ? 36 : 20;

    for (let i = startIdx; i < low; i++) {
      if (this.activeList.length >= maxActive) {
        break;
      }
      const c = this.allComments[i];
      const elapsed = seekTime - c.time;
      if (elapsed < 0 || elapsed >= PlayerDanmakuLayer.SCROLL_DURATION) {
        continue;
      }
      this.spawnSingleComment(c, maxTracks, elapsed);
    }

    this.renderDanmaku();
  }

  private spawnBetween(fromTime: number, toTime: number): void {
    if (!this.visible || this.viewWidth <= 0 || this.viewHeight <= 0) {
      return;
    }
    const usableHeight = Math.max(60, this.viewHeight - this.topBaseY() - this.bottomSafeMargin());
    const maxTracks = this.calculateMaxTracks(usableHeight);
    const maxActive = this.isLandscapeView() ? 36 : 20;
    let spawnedThisTick = 0;

    while (this.nextIndex < this.allComments.length) {
      const c = this.allComments[this.nextIndex];
      if (c.time > toTime) {
        break;
      }
      this.nextIndex++;

      if (c.time < fromTime - 0.5) {
        continue;
      }
      if (this.activeList.length >= maxActive) {
        continue;
      }
      if (spawnedThisTick >= 4) {
        continue;
      }

      const elapsed = Math.max(0, toTime - c.time);
      if (this.spawnSingleComment(c, maxTracks, elapsed)) {
        spawnedThisTick++;
      }
    }
  }

  private getScrollSpeed(): number {
    const safeW = this.safeRight() - this.safeLeft();
    // 恒定流速：同一视口下所有滚动弹幕速度一致，两车间距恒定不变，杜绝长短文本速度差异引发的追尾重叠
    return Math.max(60.0, (safeW + 160.0) / PlayerDanmakuLayer.SCROLL_DURATION);
  }

  private spawnSingleComment(c: DanmakuComment, maxTracks: number, elapsed: number = 0.0): boolean {
    const itemWidth = this.measureText(c.text);
    const itemHeight = 18;
    const color = PlayerDanmakuLayer.parseColor(c.color);
    const mode = c.mode === 1 ? 1 : (c.mode === 2 ? 2 : 0);
    const safeL = this.safeLeft();
    const safeR = this.safeRight();
    const safeW = safeR - safeL;
    const safeB = this.safeBottom();
    const baseY = this.topBaseY();
    const bottomBase = safeB - 24.0;

    if (mode === 0) {
      const speed = this.getScrollSpeed();
      const startX = safeR - (speed * elapsed);
      // 若因历史恢复计算出的位置已经滑出安全左边缘，直接跳过
      if (startX + itemWidth < safeL - 10) {
        return false;
      }

      let bestTrack = -1;

      // 工业级物理右边缘防撞判定：检查该轨道当前在屏的最右侧弹幕实体
      for (let t = 0; t < maxTracks; t++) {
        let rightmost: ActiveDanmaku | null = null;
        for (let i = this.activeList.length - 1; i >= 0; i--) {
          const act = this.activeList[i];
          if (act.mode === 0 && act.track === t) {
            if (rightmost === null || (act.x + act.width > rightmost.x + rightmost.width)) {
              rightmost = act;
            }
          }
        }

        // 该轨当前无弹幕：立即可用
        if (rightmost === null) {
          bestTrack = t;
          break;
        }

        // 该轨已有弹幕：前车尾部 + 32vp 安全空隙必须在当前新车入场位置左侧，杜绝压车重叠
        if (rightmost.x + rightmost.width + 32.0 <= startX) {
          bestTrack = t;
          break;
        }
      }

      // 所有轨道均处于拥堵占用状态：坚决丢弃，绝不强行取模重叠覆盖
      if (bestTrack < 0) {
        return false;
      }

      const item: ActiveDanmaku = {
        text: c.text,
        color: color,
        mode: 0,
        time: c.time,
        track: bestTrack,
        width: itemWidth,
        height: itemHeight,
        x: startX,
        y: baseY + bestTrack * PlayerDanmakuLayer.TRACK_HEIGHT,
        speed: speed,
        remainSec: Math.max(0.1, PlayerDanmakuLayer.SCROLL_DURATION - elapsed)
      };

      this.activeList.push(item);
      return true;
    } else if (mode === 1) {
      if (elapsed >= PlayerDanmakuLayer.FIXED_DURATION) {
        return false;
      }
      const maxFixedTracks = Math.min(3, Math.max(1, Math.floor(maxTracks / 2)));
      let bestTrack = -1;
      for (let t = 0; t < maxFixedTracks; t++) {
        const freeTime = this.fixedTopFreeTime.get(t) || 0;
        if (c.time >= freeTime) {
          bestTrack = t;
          break;
        }
      }
      if (bestTrack < 0) {
        return false; // 顶部固定弹幕全部占满，丢弃避免文字重叠
      }
      this.fixedTopFreeTime.set(bestTrack, c.time + PlayerDanmakuLayer.FIXED_DURATION);

      // 顶部固定弹幕严格居中于安全可视区域内
      const fixedX = safeL + (safeW - itemWidth) / 2;
      const item: ActiveDanmaku = {
        text: c.text,
        color: color,
        mode: 1,
        time: c.time,
        track: bestTrack,
        width: itemWidth,
        height: itemHeight,
        x: fixedX,
        y: baseY + bestTrack * PlayerDanmakuLayer.TRACK_HEIGHT,
        speed: 0,
        remainSec: Math.max(0.1, PlayerDanmakuLayer.FIXED_DURATION - elapsed)
      };
      this.activeList.push(item);
      return true;
    } else {
      if (elapsed >= PlayerDanmakuLayer.FIXED_DURATION) {
        return false;
      }
      const maxFixedTracks = Math.min(3, Math.max(1, Math.floor(maxTracks / 2)));
      let bestTrack = -1;
      for (let t = 0; t < maxFixedTracks; t++) {
        const freeTime = this.fixedBottomFreeTime.get(t) || 0;
        if (c.time >= freeTime) {
          bestTrack = t;
          break;
        }
      }
      if (bestTrack < 0) {
        return false; // 底部固定弹幕全部占满，丢弃避免文字重叠
      }
      this.fixedBottomFreeTime.set(bestTrack, c.time + PlayerDanmakuLayer.FIXED_DURATION);

      // 底部固定弹幕严格居中于安全可视区域内
      const fixedX = safeL + (safeW - itemWidth) / 2;
      const item: ActiveDanmaku = {
        text: c.text,
        color: color,
        mode: 2,
        time: c.time,
        track: bestTrack,
        width: itemWidth,
        height: itemHeight,
        x: fixedX,
        y: Math.max(baseY, bottomBase - bestTrack * PlayerDanmakuLayer.TRACK_HEIGHT),
        speed: 0,
        remainSec: Math.max(0.1, PlayerDanmakuLayer.FIXED_DURATION - elapsed)
      };
      this.activeList.push(item);
      return true;
    }
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
    // 强制执行硬件级安全区域裁剪：任何超出安全区矩形的绘制均被拦截，绝对不侵入系统状态栏/挖孔/导航条
    ctx.beginPath();
    ctx.rect(safeL, safeT, safeW, safeH);
    ctx.clip();

    ctx.textBaseline = 'top';
    ctx.font = `600 ${vp2px(PlayerDanmakuLayer.FONT_SIZE_VP)}px sans-serif`;
    ctx.shadowColor = 'rgba(0, 0, 0, 0.75)';
    ctx.shadowBlur = 2;
    ctx.shadowOffsetX = 1;
    ctx.shadowOffsetY = 1;

    for (let i = 0; i < this.activeList.length; i++) {
      const item = this.activeList[i];
      if (item.y < safeT || item.y + item.height > safeB) {
        continue;
      }
      ctx.fillStyle = item.color;
      ctx.fillText(item.text, item.x, item.y);
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
        const isOldLandscape = this.viewWidth > this.viewHeight && this.viewHeight > 0;
        const isNewLandscape = w > h && h > 0;
        const orientationChanged = (this.viewWidth > 0 && this.viewHeight > 0) && (isOldLandscape !== isNewLandscape);

        this.viewWidth = w;
        this.viewHeight = h;

        if (orientationChanged) {
          // 横竖屏发生旋转切换：视口宽度发生成倍突变，按当前视频进度根据新视口与新速度平滑重排在屏弹幕
          this.handleSeek(this.currentVideoTime);
        } else {
          this.onLayoutChange();
        }
      }
    })
  }
}
