import { DanmakuMeta } from '../../types/FilmModels';

/** 状态点颜色：加载中 / 正常 / 没有全网弹幕 / 失败；none 不显示状态点 */
export class DanmakuStatusTone {
  static readonly LOADING: string = 'loading';
  static readonly OK: string = 'ok';
  static readonly WARN: string = 'warn';
  static readonly ERROR: string = 'error';
  static readonly NONE: string = 'none';
}

/**
 * 弹幕加载状态，文案与网页端 danmakuStatus.ts 保持一致：
 * placeholder 是控制条上的灰字，title 是完整说明（含失败原因），tone 决定状态点颜色。
 */
export interface DanmakuStatus {
  placeholder: string;
  title: string;
  tone: string;
}

/** 没有任何弹幕时沿用的占位文字 */
export const DEFAULT_DANMAKU_PLACEHOLDER: string = '发个友善的弹幕见证当下';

export const DANMAKU_LOADING_STATUS: DanmakuStatus = {
  placeholder: '弹幕加载中…',
  title: '弹幕加载中…',
  tone: DanmakuStatusTone.LOADING
};

/** 接口本身失败（非成功返回码或网络错误） */
export function danmakuRequestFailedStatus(msg?: string): DanmakuStatus {
  const reason = msg ? msg : '未知原因';
  return { placeholder: `弹幕加载失败：${reason}`, title: `弹幕加载失败：${reason}`, tone: DanmakuStatusTone.ERROR };
}

/** 弹幕列表装载完成后的状态。total 是本站和全网合计条数 */
export function danmakuLoadedStatus(total: number, meta: DanmakuMeta | null): DanmakuStatus {
  const say = total > 0 ? `共 ${total} 条弹幕，说点什么吧` : DEFAULT_DANMAKU_PLACEHOLDER;
  const networkStatus = meta ? meta.networkStatus : '';
  if (meta && networkStatus === 'ok') {
    return { placeholder: say, title: `已加载 ${total} 条弹幕（全网 ${meta.network} 条）`, tone: DanmakuStatusTone.OK };
  }
  if (meta && networkStatus === 'empty') {
    const reason = meta.networkReason ? `：${meta.networkReason}` : '';
    return {
      placeholder: total > 0 ? `共 ${total} 条弹幕，未找到全网弹幕` : '未找到全网弹幕，说点什么吧',
      title: `${total > 0 ? `已加载 ${total} 条弹幕，` : ''}未找到全网弹幕${reason}`,
      tone: DanmakuStatusTone.WARN
    };
  }
  if (meta && networkStatus === 'error') {
    const reason = meta.networkReason ? meta.networkReason : '未知原因';
    return {
      placeholder: `全网弹幕加载失败：${reason}`,
      title: `全网弹幕加载失败：${reason}${total > 0 ? `（已加载本站 ${total} 条）` : ''}`,
      tone: DanmakuStatusTone.ERROR
    };
  }
  // 没开全网弹幕（或老接口没有 meta）：只报本站条数，不显示状态点
  return { placeholder: say, title: total > 0 ? `已加载 ${total} 条弹幕` : '', tone: DanmakuStatusTone.NONE };
}

export function danmakuToneColor(tone: string): string {
  if (tone === DanmakuStatusTone.OK) {
    return '#52C41A';
  }
  if (tone === DanmakuStatusTone.WARN) {
    return '#FAAD14';
  }
  if (tone === DanmakuStatusTone.ERROR) {
    return '#FF4D4F';
  }
  return 'rgba(255,255,255,0.5)';
}

/** 6vp 状态点，颜色与网页端一致；加载中闪烁，none 不显示（由调用方判断） */
@Component
export struct DanmakuStatusDot {
  @Prop @Watch('syncPulse') tone: string = DanmakuStatusTone.NONE;
  @State private dotOpacity: number = 1;

  private syncPulse(): void {
    if (this.tone === DanmakuStatusTone.LOADING) {
      this.dotOpacity = 1;
      this.getUIContext()?.animateTo({ duration: 500, iterations: -1, playMode: PlayMode.Alternate }, () => {
        this.dotOpacity = 0.3;
      });
    } else {
      this.getUIContext()?.animateTo({ duration: 0 }, () => {
        this.dotOpacity = 1;
      });
    }
  }

  build() {
    Row()
      .width(6)
      .height(6)
      .borderRadius(3)
      .backgroundColor(danmakuToneColor(this.tone))
      .opacity(this.dotOpacity)
      .hitTestBehavior(HitTestMode.None)
      .onAppear(() => this.syncPulse())
  }
}
