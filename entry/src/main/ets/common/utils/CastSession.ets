import { DlnaClient } from './DlnaClient';
import { DlnaDevice, DlnaPositionInfo } from './DlnaTypes';

/**
 * Lightweight cast session that outlives the cast dialog.
 * Keeps device state + optional background GetPositionInfo poll so
 * screen-off / brief background does not tear down TV playback, and
 * progress stays fresh when the sheet reopens.
 */
export class CastSession {
  device: DlnaDevice | null = null;
  positionSec: number = 0;
  durationSec: number = 0;
  volume: number = 50;
  volumeSupported: boolean = false;
  transportState: string = '';

  private client: DlnaClient = new DlnaClient();
  private pollTimer: number = -1;
  private pollToken: number = 0;

  get active(): boolean {
    return this.device !== null;
  }

  get usn(): string {
    return this.device ? this.device.usn : '';
  }

  get deviceName(): string {
    return this.device ? this.device.friendlyName : '';
  }

  attach(device: DlnaDevice): void {
    this.device = device;
    this.positionSec = 0;
    this.durationSec = 0;
    this.transportState = '';
  }

  /** Clear local session state without sending Stop to the renderer. */
  clearLocal(): void {
    this.stopPoll();
    this.device = null;
    this.positionSec = 0;
    this.durationSec = 0;
    this.volume = 50;
    this.volumeSupported = false;
    this.transportState = '';
  }

  startPoll(intervalMs: number = 2000): void {
    this.stopPoll();
    if (!this.device || !this.device.controlURL) {
      return;
    }
    this.pollToken += 1;
    const token: number = this.pollToken;
    this.tickOnce(token);
    this.pollTimer = setInterval(() => {
      this.tickOnce(token);
    }, intervalMs) as number;
  }

  stopPoll(): void {
    this.pollToken += 1;
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  async refreshVolume(): Promise<void> {
    const device: DlnaDevice | null = this.device;
    if (!device || !device.renderingControlURL) {
      this.volumeSupported = false;
      return;
    }
    try {
      this.volume = await this.client.getVolume(device);
      this.volumeSupported = true;
    } catch (err) {
      console.error(`[CastSession] GetVolume fail: ${JSON.stringify(err)}`);
      this.volumeSupported = false;
    }
  }

  /**
   * Send Stop to the renderer and clear local state.
   * Only call on explicit user Stop or true leave of PlayPage.
   */
  async stopRemote(): Promise<void> {
    const device: DlnaDevice | null = this.device;
    this.clearLocal();
    if (!device) {
      return;
    }
    try {
      await this.client.stop(device);
    } catch (err) {
      console.error(`[CastSession] stop failed: ${JSON.stringify(err)}`);
    }
  }

  private async tickOnce(token: number): Promise<void> {
    if (token !== this.pollToken) {
      return;
    }
    const device: DlnaDevice | null = this.device;
    if (!device || !device.controlURL) {
      return;
    }
    try {
      const info: DlnaPositionInfo = await this.client.getPositionInfo(device);
      if (token !== this.pollToken) {
        return;
      }
      this.positionSec = info.positionSec;
      if (info.durationSec > 0) {
        this.durationSec = info.durationSec;
      }
    } catch (err) {
      console.error(`[CastSession] GetPositionInfo fail: ${JSON.stringify(err)}`);
    }
    try {
      const state: string = await this.client.getTransportInfo(device);
      if (token !== this.pollToken) {
        return;
      }
      this.transportState = state;
    } catch (_e) {
      // Optional.
    }
  }
}
