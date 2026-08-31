import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { audio } from '@kit.AudioKit';
import { WindowBar } from './WindowBar';

export class PlayerVolumeInfo {
  current: number = 8;
  max: number = 15;
}

export class PlayerWindow {
  static async setFullscreen(context: common.UIAbilityContext | undefined, full: boolean): Promise<void> {
    if (!context) {
      return;
    }
    try {
      const win = await window.getLastWindow(context);
      if (full) {
        await win.setWindowSystemBarEnable([]);
        await win.setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE);
      } else {
        await win.setPreferredOrientation(window.Orientation.PORTRAIT);
        WindowBar.apply(context);
      }
    } catch (err) {
      console.error('player fullscreen failed:', JSON.stringify(err));
    }
  }

  static async getBrightness(context: common.UIAbilityContext | undefined): Promise<number> {
    if (!context) {
      return 0.5;
    }
    try {
      const win = await window.getLastWindow(context);
      const value = win.getWindowProperties().brightness;
      if (value < 0) {
        return 0.5;
      }
      return Math.min(1, Math.max(0, value));
    } catch (err) {
      console.error('get brightness failed:', JSON.stringify(err));
      return 0.5;
    }
  }

  static async setBrightness(context: common.UIAbilityContext | undefined, value: number): Promise<void> {
    if (!context) {
      return;
    }
    try {
      const win = await window.getLastWindow(context);
      const next = Math.min(1, Math.max(0, value));
      await win.setWindowBrightness(next);
    } catch (err) {
      console.error('set brightness failed:', JSON.stringify(err));
    }
  }

  static async resetBrightness(context: common.UIAbilityContext | undefined): Promise<void> {
    if (!context) {
      return;
    }
    try {
      const win = await window.getLastWindow(context);
      await win.setWindowBrightness(-1);
    } catch (err) {
      console.error('reset brightness failed:', JSON.stringify(err));
    }
  }

  static async getVolume(): Promise<PlayerVolumeInfo> {
    const info = new PlayerVolumeInfo();
    try {
      const volumeManager = audio.getAudioManager().getVolumeManager();
      info.max = Math.max(1, volumeManager.getMaxVolumeByStream(audio.StreamUsage.STREAM_USAGE_MOVIE));
      info.current = Math.min(info.max, Math.max(0, volumeManager.getVolumeByStream(audio.StreamUsage.STREAM_USAGE_MOVIE)));
    } catch (err) {
      console.error('get volume failed:', JSON.stringify(err));
    }
    return info;
  }

  static async setKeepScreenOn(context: common.UIAbilityContext | undefined, on: boolean): Promise<void> {
    if (!context) {
      return;
    }
    try {
      const win = await window.getLastWindow(context);
      await win.setWindowKeepScreenOn(on);
    } catch (err) {
      console.error('keep screen on failed:', JSON.stringify(err));
    }
  }
}
