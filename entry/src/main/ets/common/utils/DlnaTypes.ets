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
  host: string;
}

export enum DlnaScanState {
  IDLE = 0,
  SCANNING = 1,
  DONE = 2,
  ERROR = 3
}
