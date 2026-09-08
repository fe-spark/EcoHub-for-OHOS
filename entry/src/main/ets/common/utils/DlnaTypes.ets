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
