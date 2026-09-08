import { DlnaClient } from './DlnaClient';
import { DlnaDevice, DlnaPositionInfo } from './DlnaTypes';

/**
 * Lightweight cast session that outlives the cast dialog.
 * Keeps device state + optional background GetPositionInfo poll so
 * screen-off / brief background does not tear down TV playback, and
 * progress stays fresh when the sheet reopens.
 *
 * Also watches transport / poll health: when the TV stops or drops off
 * the network, clearLocal() only (never Stop SOAP) and notify UI.
 */
export class CastSession {
  device: DlnaDevice | null = null;
  positionSec: number = 0;
  durationSec: number = 0;
  volume: number = 50;
  volumeSupported: boolean = false;
  transportState: string = '';

  /** Fired after clearLocal on remote STOPPED / poll-fail disconnect. */
  onRemoteDisconnected: (() => void) | null = null;

  private client: DlnaClient = new DlnaClient();
  private pollTimer: number = -1;
  private pollToken: number = 0;

  /** True once we have seen PLAYING or TRANSITIONING after attach. */
  private everPlayed: boolean = false;
  private stoppedStreak: number = 0;
  private failStreak: number = 0;

  /** Consecutive STOPPED / NO_MEDIA_PRESENT polls after everPlayed. */
  private static readonly STOPPED_THRESHOLD: number = 3;
  /** Consecutive failed GetPositionInfo+GetTransportInfo polls while active. */
  private static readonly FAIL_THRESHOLD: number = 3;

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
    this.resetHealthCounters();
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
    this.resetHealthCounters();
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

  /** Reset fail/STOPPED counters (e.g. after successful cast attach). */
  resetHealthCounters(): void {
    this.everPlayed = false;
    this.stoppedStreak = 0;
    this.failStreak = 0;
  }

  /** Reset fail streak after a successful position/transport poll. */
  notePollSuccess(): void {
    this.failStreak = 0;
  }

  /**
   * Record a failed GetPositionInfo / GetTransportInfo tick while session active.
   * @returns true if remote disconnect was triggered (clearLocal already ran).
   */
  notePollFailure(): boolean {
    if (!this.device) {
      return false;
    }
    this.failStreak += 1;
    if (this.failStreak >= CastSession.FAIL_THRESHOLD) {
      console.info(`[CastSession] remote disconnect: poll fail x${this.failStreak}`);
      this.handleRemoteDisconnect();
      return true;
    }
    return false;
  }

  /**
   * Observe CurrentTransportState from GetTransportInfo (or sheet poll).
   * STOPPED / NO_MEDIA_PRESENT for N polls after ever PLAYING/TRANSITIONING → disconnect.
   * @returns true if remote disconnect was triggered (clearLocal already ran).
   */
  noteTransportState(state: string): boolean {
    this.transportState = state ? state : '';
    const upper: string = (state || '').toUpperCase();
    if (upper === 'PLAYING' || upper === 'TRANSITIONING') {
      this.everPlayed = true;
      this.stoppedStreak = 0;
      this.failStreak = 0;
      return false;
    }
    if (!this.device || !this.everPlayed) {
      this.stoppedStreak = 0;
      return false;
    }
    if (upper === 'STOPPED' || upper === 'NO_MEDIA_PRESENT') {
      this.stoppedStreak += 1;
      if (this.stoppedStreak >= CastSession.STOPPED_THRESHOLD) {
        console.info(`[CastSession] remote disconnect: ${upper} x${this.stoppedStreak}`);
        this.handleRemoteDisconnect();
        return true;
      }
      return false;
    }
    // PAUSED_PLAYBACK and other states: not a remote stop.
    this.stoppedStreak = 0;
    return false;
  }

  private handleRemoteDisconnect(): void {
    const cb: (() => void) | null = this.onRemoteDisconnected;
    this.clearLocal();
    if (cb) {
      cb();
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

    let positionOk: boolean = false;
    let transportOk: boolean = false;

    try {
      const info: DlnaPositionInfo = await this.client.getPositionInfo(device);
      if (token !== this.pollToken) {
        return;
      }
      positionOk = true;
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
      transportOk = true;
      if (this.noteTransportState(state)) {
        return;
      }
    } catch (_e) {
      // Optional; counted toward fail streak with position below.
    }

    if (token !== this.pollToken || !this.device) {
      return;
    }

    if (positionOk || transportOk) {
      this.notePollSuccess();
    } else if (this.notePollFailure()) {
      return;
    }
  }
}
