import { common } from '@kit.AbilityKit';
import { PlayerPan, PlayerPanResult } from '../common/utils/PlayerPan';
import { PlayerWindow } from '../common/utils/PlayerWindow';

export interface GestureMoveOutput {
  mode: number;
  time?: number;
  bright?: number;
  volumeRatio?: number;
  feedback: string;
  feedbackKind: number;
}

export interface GestureFinishResult {
  shouldSeek: boolean;
  targetTime: number;
}

export class PlayerGestureCoordinator {
  public pan: PlayerPan = new PlayerPan();

  start(event: GestureEvent, canPlay: boolean, longPressing: boolean, currentTime: number, playerW: number, ctx?: common.UIAbilityContext): boolean {
    if (!canPlay || longPressing || !event.fingerList || event.fingerList.length === 0) {
      this.pan.reset();
      return false;
    }
    const finger = event.fingerList[0];
    this.pan.begin(finger.localX, finger.localY, currentTime, playerW);
    PlayerWindow.getBrightness(ctx).then((val: number) => {
      this.pan.primeBright(val);
    });
    PlayerWindow.getVolume().then((info) => {
      this.pan.primeVolume(info.max > 0 ? info.current / info.max : 0);
    });
    return true;
  }

  move(event: GestureEvent, longPressing: boolean, isFull: boolean, duration: number, playerW: number, playerH: number): GestureMoveOutput | null {
    if (this.pan.mode === 0 || longPressing || !event.fingerList || event.fingerList.length === 0) {
      return null;
    }
    const finger = event.fingerList[0];
    const result: PlayerPanResult | null = this.pan.move(finger.localX, finger.localY, isFull, duration, playerW, playerH);
    if (!result) {
      return null;
    }
    const output: GestureMoveOutput = {
      mode: result.mode,
      time: result.time,
      bright: result.bright,
      volumeRatio: result.volume,
      feedback: result.feedback,
      feedbackKind: result.kind
    };
    return output;
  }

  finish(currentTime: number): GestureFinishResult {
    const shouldSeek = this.pan.mode === 2;
    const target = currentTime;
    this.pan.reset();
    const res: GestureFinishResult = { shouldSeek: shouldSeek, targetTime: target };
    return res;
  }
}
