import {
  BaseDanmaku,
  BaseDanmakuParser,
  Callback,
  DANMAKU_STYLE_STROKEN,
  DanmakuContext,
  DanmakuTimer,
  DanmakuView,
  Danmakus,
  IDanmakus,
  RenderMode,
  ST_BY_TIME
} from '@ohos/danmakuflamemaster';
import { FilmApi } from '../../api/FilmApi';
import { DanmakuComment } from '../../types/FilmModels';
import { ServerCompat } from '../../services/ServerCompat';

class CommentParser extends BaseDanmakuParser {
  comments: DanmakuComment[] = [];

  protected parse(): IDanmakus {
    const out = new Danmakus({ sortType: ST_BY_TIME });
    const density = this.mDispDensity > 0 ? this.mDispDensity : 2;
    for (let i = 0; i < this.comments.length; i++) {
      const item = this.comments[i];
      if (!item.text) {
        continue;
      }
      const type = item.mode === 1 ? BaseDanmaku.TYPE_FIX_TOP
        : item.mode === 2 ? BaseDanmaku.TYPE_FIX_BOTTOM
          : BaseDanmaku.TYPE_SCROLL_RL;
      const ctx = this.mContext as DanmakuContext;
      const danmaku: BaseDanmaku = ctx.mDanmakuFactory.createDanmaku(type);
      danmaku.text = item.text;
      danmaku.setTime(Math.max(0, item.time) * 1000);
      danmaku.textSize = 16 * density;
      danmaku.textColor = CommentParser.colorOf(item.color);
      danmaku.textShadowColor = 0x99000000;
      danmaku.padding = 4;
      out.addItem(danmaku);
    }
    return out;
  }

  private static colorOf(raw: string): number {
    const hex = raw.replace('#', '').trim();
    if (hex.length !== 6) {
      return 0xffffffff;
    }
    const value = Number.parseInt(hex, 16);
    if (Number.isNaN(value)) {
      return 0xffffffff;
    }
    return 0xff000000 + value;
  }
}

class EngineHook implements Callback {
  onPrepared: () => void = () => {};
  prepared(): void {
    this.onPrepared();
  }
  updateTimer(_timer: DanmakuTimer): void {}
  danmakuShown(_danmaku: BaseDanmaku): void {}
  drawingFinished(): void {}
}

@Component
export struct PlayerDanmakuLayer {
  private static readonly DRIFT_MS: number = 1200;

  @Prop @Watch('reload') filmId: string = '';
  @Prop @Watch('reload') episode: number = 1;
  @Prop @Watch('reload') filmTitle: string = '';
  @Prop @Watch('onClock') currentTime: number = 0;
  @Prop @Watch('onPlaying') playing: boolean = false;

  @State model: DanmakuView.Model = new DanmakuView.Model();
  @State private active: boolean = false;
  private parser: CommentParser = new CommentParser();
  private hook: EngineHook = new EngineHook();
  private loadKey: string = '';
  private started: boolean = false;
  private gen: number = 0;

  aboutToAppear(): void {
    this.model.setMode(RenderMode.CANVAS_2D);
    this.hook.onPrepared = () => this.onEngineReady();
    this.reload();
  }

  aboutToDisappear(): void {
    this.gen++;
    this.started = false;
    this.model.stop();
    this.model.release();
  }

  build() {
    if (!this.active) {
      Stack()
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
    } else {
      DanmakuView({ model: $model })
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .onAreaChange((_old: Area, area: Area) => {
          const w = Number(area.width);
          const h = Number(area.height);
          if (w > 0 && h > 0) {
            this.model.setWidth(w);
            this.model.setHeight(h);
          }
        })
        .onAppear(() => this.boot())
    }
  }

  private reload(): void {
    const key = `${this.filmId}|${this.episode}|${this.filmTitle}`;
    if (key === this.loadKey) {
      return;
    }
    this.loadKey = key;
    this.started = false;
    this.active = false;
    const token = ++this.gen;
    const mid = Number(this.filmId);
    if (!this.filmId || Number.isNaN(mid) || mid <= 0 || !ServerCompat.getInstance().canDanmaku) {
      return;
    }
    FilmApi.getDanmaku(this.filmId, this.episode > 0 ? this.episode : 1, this.filmTitle).then((list: DanmakuComment[]) => {
      if (token !== this.gen) {
        return;
      }
      if (list.length === 0) {
        return;
      }
      this.parser.comments = list;
      this.active = true;
    }).catch((_err: Object) => {});
  }

  private boot(): void {
    if (!this.active || !this.model.isViewReady() || this.started) {
      return;
    }
    const ctx = DanmakuContext.create();
    ctx.setDanmakuStyle(DANMAKU_STYLE_STROKEN, 3);
    this.model.setCallback(this.hook);
    this.model.prepare(this.parser, ctx);
  }

  private onEngineReady(): void {
    this.started = true;
    const ms = Math.max(0, Math.floor(this.currentTime * 1000));
    this.model.start(ms);
    if (!this.playing) {
      this.model.pause();
    }
  }

  private onPlaying(): void {
    if (!this.started) {
      return;
    }
    if (this.playing) {
      this.model.resume();
    } else {
      this.model.pause();
    }
  }

  private onClock(): void {
    if (!this.started) {
      return;
    }
    const target = Math.max(0, Math.floor(this.currentTime * 1000));
    if (Math.abs(this.model.getCurrentTime() - target) > PlayerDanmakuLayer.DRIFT_MS) {
      this.model.seekTo(target);
    }
  }
}
