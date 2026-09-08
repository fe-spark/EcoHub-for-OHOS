/**
 * DLNA / UPnP MediaRenderer types for casting.
 */
export interface DlnaDevice {
  /** Unique Service Name from SSDP (stable id). */
  usn: string;
  friendlyName: string;
  manufacturer: string;
  /** Device description LOCATION URL. */
  location: string;
  /** Absolute AVTransport controlURL. */
  controlURL: string;
  /** Absolute RenderingControl controlURL (may be empty). */
  renderingControlURL: string;
  host: string;
}

/** Parsed AVTransport GetPositionInfo. Times are seconds. */
export interface DlnaPositionInfo {
  positionSec: number;
  durationSec: number;
  relTime: string;
  trackDuration: string;
}

export enum DlnaScanState {
  IDLE = 0,
  SCANNING = 1,
  DONE = 2,
  ERROR = 3
}

/** SOAP Fault / HTTP error. Plain class — ArkTS does not like `extends Error`. */
export class DlnaSoapError {
  action: string = '';
  httpCode: number = 0;
  errorCode: number = 0;
  errorDescription: string = '';
  message: string = '';

  /** Fatal only for SetAVTransportURI / Play. Seek/Pause/Stop/Get* never fail the session. */
  fatalForLaunch(): boolean {
    if (this.action !== 'SetAVTransportURI' && this.action !== 'Play') {
      return false;
    }
    const c: number = this.errorCode;
    if (c === 714 || c === 716 || c === 401 || c === 402 || c === 701) {
      return true;
    }
    return c === 0 && this.httpCode >= 400;
  }
}

export function asDlnaSoapError(err: Object): DlnaSoapError | null {
  if (err instanceof DlnaSoapError) {
    return err;
  }
  if (!(err instanceof Error) || !err.message) {
    return null;
  }
  const m: RegExpMatchArray | null = err.message.match(/\(([^,]+), ([^)]+)\)\s*$/);
  if (!m) {
    return null;
  }
  const soap: DlnaSoapError = new DlnaSoapError();
  soap.action = m[1];
  soap.message = err.message;
  soap.errorDescription = err.message;
  if (m[2].indexOf('HTTP') === 0) {
    soap.httpCode = parseInt(m[2].replace('HTTP ', ''), 10);
    soap.errorCode = 0;
  } else {
    const n: number = parseInt(m[2], 10);
    soap.errorCode = isNaN(n) ? 0 : n;
  }
  return soap;
}

export function soapErrorMessage(err: Object): string {
  const soap: DlnaSoapError | null = asDlnaSoapError(err);
  if (soap) {
    return soap.errorDescription || soap.message || '投屏失败';
  }
  if (err instanceof Error) {
    return err.message || '投屏失败';
  }
  return '投屏失败';
}

/** RelTime empty / NOT_IMPLEMENTED / NOT_IMPLEMENTED. */
export function isRelTimeUnavailable(raw: string): boolean {
  const t: string = (raw ? raw : '').trim().toUpperCase();
  if (!t) {
    return true;
  }
  return t.indexOf('NOT_IMPLEMENTED') === 0;
}

export class CastPhase {
  static readonly IDLE: string = 'idle';
  static readonly LAUNCHING: string = 'launching';
  static readonly PLAYING: string = 'playing';
  static readonly PAUSED: string = 'paused';
  static readonly COMPLETED: string = 'completed';
  static readonly FAILED: string = 'failed';
  static readonly DISCONNECTED: string = 'disconnected';
  static readonly STOPPING: string = 'stopping';
}
