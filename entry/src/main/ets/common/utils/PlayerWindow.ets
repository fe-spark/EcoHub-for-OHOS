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
      const group = await audio.getAudioManager().getVolumeManager()
        .getVolumeGroupManager(audio.DEFAULT_VOLUME_GROUP_ID);
      info.max = Math.max(1, await group.getMaxVolume(audio.AudioVolumeType.MEDIA));
      info.current = Math.min(info.max, Math.max(0, await group.getVolume(audio.AudioVolumeType.MEDIA)));
    } catch (err) {
      console.error('get volume failed:', JSON.stringify(err));
    }
    return info;
  }

  static subscribeVolumeChange(callback: (info: PlayerVolumeInfo) => void): () => void {
    try {
      let active = true;
      const volumeManager = audio.getAudioManager().getVolumeManager();
      let cachedMax = 15;
      let lastMediaVol = -1;

      PlayerWindow.getVolume().then((initial: PlayerVolumeInfo) => {
        if (!active) {
          return;
        }
        cachedMax = initial.max;
        lastMediaVol = initial.current;
      }).catch(() => {});

      const handler = (event: audio.VolumeEvent) => {
        if (event.volumeType !== audio.AudioVolumeType.MEDIA || !active) {
          return;
        }
        if (event.volume === lastMediaVol) {
          return;
        }
        lastMediaVol = event.volume;
        const info = new PlayerVolumeInfo();
        info.max = Math.max(1, cachedMax);
        info.current = Math.min(info.max, Math.max(0, event.volume));
        callback(info);
      };
      volumeManager.on('volumeChange', handler);
      return () => {
        active = false;
        try {
          volumeManager.off('volumeChange', handler);
        } catch (err) {
          console.error('off volumeChange failed:', JSON.stringify(err));
        }
      };
    } catch (err) {
      console.error('subscribe volumeChange failed:', JSON.stringify(err));
      return () => {};
    }
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
