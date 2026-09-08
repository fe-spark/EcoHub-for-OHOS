import { http, socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { DlnaDevice, DlnaPositionInfo } from './DlnaTypes';

interface SsdpMessageInfo {
  message: ArrayBuffer;
  remoteInfo: socket.SocketRemoteInfo;
}

/**
 * DLNA MediaRenderer client: SSDP discovery + AVTransport + RenderingControl.
 * Supports SetURI/Play/Stop/Seek/GetPositionInfo and Master volume Get/Set.
 */
export class DlnaClient {
  private static readonly TAG: string = '[DlnaClient]';
  private static readonly SSDP_ADDR: string = '239.255.255.250';
  private static readonly SSDP_PORT: number = 1900;
  private static readonly SCAN_MS: number = 4000;
  private static readonly AVT: string = 'urn:schemas-upnp-org:service:AVTransport:1';
  private static readonly RCS: string = 'urn:schemas-upnp-org:service:RenderingControl:1';
  private static readonly RENDERER: string = 'urn:schemas-upnp-org:device:MediaRenderer:1';

  private udp: socket.UDPSocket | null = null;
  private multicast: socket.MulticastSocket | null = null;
  private scanToken: number = 0;
  private devices: Map<string, DlnaDevice> = new Map();

  public async discover(onUpdate?: (list: DlnaDevice[]) => void): Promise<DlnaDevice[]> {
    this.scanToken += 1;
    const token: number = this.scanToken;
    this.devices.clear();
    this.closeSockets();

    const msearch: string =
      'M-SEARCH * HTTP/1.1\r\n' +
      `HOST: ${DlnaClient.SSDP_ADDR}:${DlnaClient.SSDP_PORT}\r\n` +
      'MAN: "ssdp:discover"\r\n' +
      'MX: 3\r\n' +
      `ST: ${DlnaClient.RENDERER}\r\n` +
      '\r\n';

    try {
      await this.startUdpListener(token, onUpdate);
      await this.sendMSearch(msearch);
      // Multicast membership helps some LANs deliver replies / NOTIFY.
      await this.tryMulticastListen(token, msearch, onUpdate);
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : JSON.stringify(err);
      console.error(`${DlnaClient.TAG} discover start failed: ${msg}`);
      this.closeSockets();
      throw new Error(msg || 'SSDP 扫描失败');
    }

    await this.sleep(DlnaClient.SCAN_MS);
    if (token !== this.scanToken) {
      return [];
    }
    this.closeSockets();
    const list: DlnaDevice[] = this.listDevices();
    console.info(`${DlnaClient.TAG} discover done, count=${list.length}`);
    return list;
  }

  public cancelDiscover(): void {
    this.scanToken += 1;
    this.closeSockets();
  }

  public async cast(device: DlnaDevice, mediaUrl: string, title: string = 'EcoHub',
    startSec: number = 0, durationSec: number = 0): Promise<void> {
    if (!mediaUrl) {
      throw new Error('当前没有可投屏的地址');
    }
    console.info(`${DlnaClient.TAG} cast -> ${device.friendlyName} start=${startSec} dur=${durationSec}`);
    await this.soapAction(device.controlURL, DlnaClient.AVT, 'SetAVTransportURI',
      this.buildSetUriBody(mediaUrl, title, durationSec));
    // One REL_TIME try while STOPPED. Do not run padded/ABS fallbacks here — those extra
    // Faults would stall the picker. HUD retries after TrackDuration is known.
    if (startSec >= 2) {
      try {
        const hms: string = DlnaClient.formatRelTime(startSec);
        console.info(`${DlnaClient.TAG} pre-play seek REL_TIME ${hms}`);
        await this.soapAction(device.controlURL, DlnaClient.AVT, 'Seek',
          this.buildSeekBody(hms, 'REL_TIME'));
      } catch (err) {
        console.info(`${DlnaClient.TAG} pre-play seek ignored: ${JSON.stringify(err)}`);
      }
    }
    await this.play(device);
  }

  public async play(device: DlnaDevice): Promise<void> {
    console.info(`${DlnaClient.TAG} play -> ${device.friendlyName}`);
    await this.soapAction(device.controlURL, DlnaClient.AVT, 'Play', this.buildPlayBody());
  }

  public async pause(device: DlnaDevice): Promise<void> {
    console.info(`${DlnaClient.TAG} pause -> ${device.friendlyName}`);
    await this.soapAction(device.controlURL, DlnaClient.AVT, 'Pause', this.buildPauseBody());
  }

  public async stop(device: DlnaDevice): Promise<void> {
    console.info(`${DlnaClient.TAG} stop -> ${device.friendlyName}`);
    await this.soapAction(device.controlURL, DlnaClient.AVT, 'Stop', this.buildStopBody());
  }

  public async seek(device: DlnaDevice, positionSec: number): Promise<void> {
    const hms: string = DlnaClient.formatRelTime(positionSec);
    const padded: string = DlnaClient.formatRelTimePadded(positionSec);
    try {
      console.info(`${DlnaClient.TAG} seek REL_TIME -> ${device.friendlyName} ${hms}`);
      await this.soapAction(device.controlURL, DlnaClient.AVT, 'Seek', this.buildSeekBody(hms, 'REL_TIME'));
      return;
    } catch (_rel) {
      try {
        console.info(`${DlnaClient.TAG} seek REL_TIME padded -> ${device.friendlyName} ${padded}`);
        await this.soapAction(device.controlURL, DlnaClient.AVT, 'Seek', this.buildSeekBody(padded, 'REL_TIME'));
        return;
      } catch (_pad) {
        console.info(`${DlnaClient.TAG} seek ABS_TIME -> ${device.friendlyName} ${hms}`);
        await this.soapAction(device.controlURL, DlnaClient.AVT, 'Seek', this.buildSeekBody(hms, 'ABS_TIME'));
      }
    }
  }

  public async getPositionInfo(device: DlnaDevice): Promise<DlnaPositionInfo> {
    const xml: string = await this.soapAction(device.controlURL, DlnaClient.AVT, 'GetPositionInfo',
      this.buildGetPositionInfoBody());
    const relTime: string = this.extractTag(xml, 'RelTime');
    let trackDuration: string = this.extractTag(xml, 'TrackDuration');
    let durationSec: number = DlnaClient.parseRelTime(trackDuration);
    if (durationSec <= 0) {
      const fromMeta: string = this.extractAttr(xml, 'duration');
      if (fromMeta) {
        trackDuration = fromMeta;
        durationSec = DlnaClient.parseRelTime(fromMeta);
      }
    }
    return {
      positionSec: DlnaClient.parseRelTime(relTime),
      durationSec: durationSec,
      relTime: relTime,
      trackDuration: trackDuration
    };
  }

  /** Optional transport state: PLAYING / PAUSED_PLAYBACK / STOPPED / … */
  public async getTransportInfo(device: DlnaDevice): Promise<string> {
    const xml: string = await this.soapAction(device.controlURL, DlnaClient.AVT, 'GetTransportInfo',
      this.buildGetTransportInfoBody());
    return this.extractTag(xml, 'CurrentTransportState');
  }

  public async getVolume(device: DlnaDevice): Promise<number> {
    if (!device.renderingControlURL) {
      throw new Error('设备不支持音量控制');
    }
    const xml: string = await this.soapAction(device.renderingControlURL, DlnaClient.RCS, 'GetVolume',
      this.buildGetVolumeBody());
    const raw: string = this.extractTag(xml, 'CurrentVolume');
    const vol: number = parseInt(raw, 10);
    if (isNaN(vol)) {
      return 0;
    }
    return Math.max(0, Math.min(100, vol));
  }

  public async setVolume(device: DlnaDevice, volume: number): Promise<void> {
    if (!device.renderingControlURL) {
      throw new Error('设备不支持音量控制');
    }
    const clamped: number = Math.max(0, Math.min(100, Math.round(volume)));
    await this.soapAction(device.renderingControlURL, DlnaClient.RCS, 'SetVolume',
      this.buildSetVolumeBody(clamped));
  }

  /** Parse UPnP RelTime / TrackDuration (H:MM:SS or HH:MM:SS). */
  public static parseRelTime(value: string): number {
    if (!value) {
      return 0;
    }
    const trimmed: string = value.trim();
    if (!trimmed || trimmed === 'NOT_IMPLEMENTED' || trimmed === '*' || trimmed === '-' ||
      trimmed.indexOf(':') < 0) {
      return 0;
    }
    const parts: string[] = trimmed.split(':');
    if (parts.length < 2) {
      return 0;
    }
    let hours: number = 0;
    let minutes: number = 0;
    let seconds: number = 0;
    if (parts.length === 2) {
      minutes = parseInt(parts[0], 10);
      seconds = parseInt(parts[1], 10);
    } else {
      hours = parseInt(parts[0], 10);
      minutes = parseInt(parts[1], 10);
      seconds = parseInt(parts[2], 10);
    }
    if (isNaN(hours) || isNaN(minutes) || isNaN(seconds)) {
      return 0;
    }
    return Math.max(0, hours * 3600 + minutes * 60 + seconds);
  }

  /** UPnP RelTime is H+:MM:SS — unpadded hours. Many renderers reject 00:MM:SS. */
  public static formatRelTime(totalSec: number): string {
    const parts: number[] = DlnaClient.splitHms(totalSec);
    const mm: string = parts[1] < 10 ? `0${parts[1]}` : `${parts[1]}`;
    const ss: string = parts[2] < 10 ? `0${parts[2]}` : `${parts[2]}`;
    return `${parts[0]}:${mm}:${ss}`;
  }

  public static formatRelTimePadded(totalSec: number): string {
    const parts: number[] = DlnaClient.splitHms(totalSec);
    const hh: string = parts[0] < 10 ? `0${parts[0]}` : `${parts[0]}`;
    const mm: string = parts[1] < 10 ? `0${parts[1]}` : `${parts[1]}`;
    const ss: string = parts[2] < 10 ? `0${parts[2]}` : `${parts[2]}`;
    return `${hh}:${mm}:${ss}`;
  }

  private static splitHms(totalSec: number): number[] {
    let sec: number = Math.max(0, Math.floor(totalSec));
    const hours: number = Math.floor(sec / 3600);
    sec = sec % 3600;
    return [hours, Math.floor(sec / 60), sec % 60];
  }

  private async startUdpListener(token: number, onUpdate?: (list: DlnaDevice[]) => void): Promise<void> {
    const udp: socket.UDPSocket = socket.constructUDPSocketInstance();
    this.udp = udp;
    udp.on('message', (info: SsdpMessageInfo) => {
      if (token !== this.scanToken) {
        return;
      }
      const text: string = this.bufferToString(info.message);
      this.handleSsdpText(text, token, onUpdate);
    });
    udp.on('error', (err: BusinessError) => {
      console.error(`${DlnaClient.TAG} udp error: ${JSON.stringify(err)}`);
    });
    const local: socket.NetAddress = {
      address: '0.0.0.0',
      port: 0,
      family: 1
    };
    await udp.bind(local);
    console.info(`${DlnaClient.TAG} udp bound`);
  }

  private async sendMSearch(msearch: string): Promise<void> {
    if (!this.udp) {
      return;
    }
    const remote: socket.NetAddress = {
      address: DlnaClient.SSDP_ADDR,
      port: DlnaClient.SSDP_PORT,
      family: 1
    };
    await this.udp.send({ data: msearch, address: remote });
    // A second burst improves hit rate on busy LANs.
    await this.sleep(300);
    if (this.udp) {
      await this.udp.send({ data: msearch, address: remote });
    }
    console.info(`${DlnaClient.TAG} M-SEARCH sent`);
  }

  private async tryMulticastListen(
    token: number,
    msearch: string,
    onUpdate?: (list: DlnaDevice[]) => void
  ): Promise<void> {
    try {
      const mc: socket.MulticastSocket = socket.constructMulticastSocketInstance();
      this.multicast = mc;
      const addr: socket.NetAddress = {
        address: DlnaClient.SSDP_ADDR,
        port: DlnaClient.SSDP_PORT,
        family: 1
      };
      await mc.addMembership(addr);
      mc.on('message', (info: SsdpMessageInfo) => {
        if (token !== this.scanToken) {
          return;
        }
        const text: string = this.bufferToString(info.message);
        this.handleSsdpText(text, token, onUpdate);
      });
      await mc.send({ data: msearch, address: addr });
      console.info(`${DlnaClient.TAG} multicast membership ok`);
    } catch (err) {
      // Multicast is best-effort; UDP unicast replies are enough on many LANs.
      console.info(`${DlnaClient.TAG} multicast optional failed: ${JSON.stringify(err)}`);
    }
  }

  private handleSsdpText(text: string, token: number, onUpdate?: (list: DlnaDevice[]) => void): void {
    const location: string = this.headerValue(text, 'LOCATION');
    if (!location) {
      return;
    }
    const rawUsn: string = this.headerValue(text, 'USN') || location;
    const st: string = this.headerValue(text, 'ST');
    const nt: string = this.headerValue(text, 'NT');
    // UPnP 同一台设备会为 root/MediaRenderer/AVTransport/RCS 各发一条，USN 后缀不同。
    if (`${st} ${nt} ${rawUsn}`.indexOf('MediaRenderer') < 0) {
      return;
    }
    const usn: string = this.deviceId(rawUsn, location);
    if (this.devices.has(usn) || this.hasLocation(location)) {
      return;
    }
    this.devices.set(usn, {
      usn: usn,
      friendlyName: this.guessName(usn, location),
      manufacturer: '',
      location: location,
      controlURL: '',
      renderingControlURL: '',
      host: this.hostOf(location)
    });
    this.fetchDescription(usn, location, token, onUpdate);
  }

  private fetchDescription(
    usn: string,
    location: string,
    token: number,
    onUpdate?: (list: DlnaDevice[]) => void
  ): void {
    this.httpGet(location).then((xml: string) => {
      if (token !== this.scanToken) {
        return;
      }
      const controlURL: string = this.findServiceControlUrl(xml, location, 'AVTransport');
      if (!controlURL) {
        console.info(`${DlnaClient.TAG} no AVTransport at ${location}`);
        this.devices.delete(usn);
        if (onUpdate) {
          onUpdate(this.listDevices().filter((d: DlnaDevice) => !!d.controlURL));
        }
        return;
      }
      const rcsURL: string = this.findServiceControlUrl(xml, location, 'RenderingControl');
      const device: DlnaDevice = {
        usn: usn,
        friendlyName: this.extractTag(xml, 'friendlyName') || this.guessName(usn, location),
        manufacturer: this.extractTag(xml, 'manufacturer'),
        location: location,
        controlURL: controlURL,
        renderingControlURL: rcsURL,
        host: this.hostOf(location)
      };
      this.devices.set(usn, device);
      console.info(`${DlnaClient.TAG} found ${device.friendlyName} @ ${device.host}` +
        ` rcs=${rcsURL ? 'yes' : 'no'}`);
      if (onUpdate) {
        onUpdate(this.listDevices().filter((d: DlnaDevice) => !!d.controlURL));
      }
    }).catch((err: Object) => {
      console.error(`${DlnaClient.TAG} desc fetch fail ${location}: ${JSON.stringify(err)}`);
      this.devices.delete(usn);
    });
  }

  private findServiceControlUrl(xml: string, baseLocation: string, serviceName: string): string {
    const serviceRe: RegExp = /<service\b[\s\S]*?<\/service>/gi;
    let match: RegExpExecArray | null = serviceRe.exec(xml);
    while (match) {
      const block: string = match[0];
      const serviceType: string = this.extractTag(block, 'serviceType');
      if (serviceType.indexOf(serviceName) >= 0) {
        const control: string = this.extractTag(block, 'controlURL');
        if (control) {
          return this.resolveUrl(baseLocation, control);
        }
      }
      match = serviceRe.exec(xml);
    }
    return '';
  }

  private async soapAction(
    controlURL: string,
    serviceType: string,
    action: string,
    bodyInner: string
  ): Promise<string> {
    const envelope: string =
      '<?xml version="1.0" encoding="utf-8"?>' +
      '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" ' +
      's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">' +
      `<s:Body>${bodyInner}</s:Body></s:Envelope>`;
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await httpRequest.request(controlURL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'text/xml; charset="utf-8"',
          'SOAPAction': `"${serviceType}#${action}"`
        },
        extraData: envelope,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 8000
      });
      const code: number = response.responseCode;
      const resultText: string = typeof response.result === 'string' ? response.result : '';
      if (code < 200 || code >= 300 || /<\w*:?Fault[\s>]/i.test(resultText)) {
        console.error(`${DlnaClient.TAG} SOAP ${action} HTTP ${code}: ${resultText.substring(0, 200)}`);
        throw new Error(`投屏指令失败 (${action}, HTTP ${code})`);
      }
      console.info(`${DlnaClient.TAG} SOAP ${action} ok`);
      return resultText;
    } finally {
      httpRequest.destroy();
    }
  }

  private buildSetUriBody(mediaUrl: string, title: string, durationSec: number = 0): string {
    const safeUrl: string = this.xmlEscape(mediaUrl);
    const meta: string = this.xmlEscape(this.buildDidl(mediaUrl, title, durationSec));
    return `<u:SetAVTransportURI xmlns:u="${DlnaClient.AVT}">` +
      '<InstanceID>0</InstanceID>' +
      `<CurrentURI>${safeUrl}</CurrentURI>` +
      `<CurrentURIMetaData>${meta}</CurrentURIMetaData>` +
      '</u:SetAVTransportURI>';
  }

  private buildPlayBody(): string {
    return `<u:Play xmlns:u="${DlnaClient.AVT}">` +
      '<InstanceID>0</InstanceID><Speed>1</Speed></u:Play>';
  }

  private buildPauseBody(): string {
    return `<u:Pause xmlns:u="${DlnaClient.AVT}"><InstanceID>0</InstanceID></u:Pause>`;
  }

  private buildStopBody(): string {
    return `<u:Stop xmlns:u="${DlnaClient.AVT}"><InstanceID>0</InstanceID></u:Stop>`;
  }

  private buildSeekBody(target: string, unit: string = 'REL_TIME'): string {
    return `<u:Seek xmlns:u="${DlnaClient.AVT}">` +
      '<InstanceID>0</InstanceID>' +
      `<Unit>${unit}</Unit>` +
      `<Target>${this.xmlEscape(target)}</Target>` +
      '</u:Seek>';
  }

  private buildGetPositionInfoBody(): string {
    return `<u:GetPositionInfo xmlns:u="${DlnaClient.AVT}">` +
      '<InstanceID>0</InstanceID></u:GetPositionInfo>';
  }

  private buildGetTransportInfoBody(): string {
    return `<u:GetTransportInfo xmlns:u="${DlnaClient.AVT}">` +
      '<InstanceID>0</InstanceID></u:GetTransportInfo>';
  }

  private buildGetVolumeBody(): string {
    return `<u:GetVolume xmlns:u="${DlnaClient.RCS}">` +
      '<InstanceID>0</InstanceID><Channel>Master</Channel></u:GetVolume>';
  }

  private buildSetVolumeBody(volume: number): string {
    return `<u:SetVolume xmlns:u="${DlnaClient.RCS}">` +
      '<InstanceID>0</InstanceID><Channel>Master</Channel>' +
      `<DesiredVolume>${volume}</DesiredVolume></u:SetVolume>`;
  }

  private buildDidl(mediaUrl: string, title: string, durationSec: number = 0): string {
    const safeTitle: string = this.xmlEscape(title || 'EcoHub');
    const safeUrl: string = this.xmlEscape(mediaUrl);
    const durAttr: string = durationSec > 1 ?
      ` duration="${DlnaClient.formatRelTime(durationSec)}"` : '';
    return '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" ' +
      'xmlns:dc="http://purl.org/dc/elements/1.1/" ' +
      'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">' +
      '<item id="0" parentID="-1" restricted="1">' +
      `<dc:title>${safeTitle}</dc:title>` +
      '<upnp:class>object.item.videoItem</upnp:class>' +
      `<res protocolInfo="http-get:*:*:*"${durAttr}>${safeUrl}</res>` +
      '</item></DIDL-Lite>';
  }

  private async httpGet(url: string): Promise<string> {
    const httpRequest: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 5000,
        readTimeout: 5000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      return typeof response.result === 'string' ? response.result : '';
    } finally {
      httpRequest.destroy();
    }
  }

  private headerValue(text: string, name: string): string {
    const lines: string[] = text.split(/\r?\n/);
    const prefix: string = name.toUpperCase() + ':';
    for (let i = 0; i < lines.length; i++) {
      const line: string = lines[i];
      if (line.toUpperCase().indexOf(prefix) === 0) {
        return line.substring(line.indexOf(':') + 1).trim();
      }
    }
    return '';
  }

  private extractTag(xml: string, tag: string): string {
    const plain: RegExp = new RegExp(`<${tag}(?:\\s[^>]*)?>([\\s\\S]*?)</${tag}>`, 'i');
    const pm: RegExpMatchArray | null = xml.match(plain);
    if (pm && pm[1]) {
      return this.stripCdata(pm[1]);
    }
    const ns: RegExp = new RegExp(
      `<([A-Za-z_][\\w.-]*):${tag}(?:\\s[^>]*)?>([\\s\\S]*?)</\\1:${tag}>`, 'i');
    const nm: RegExpMatchArray | null = xml.match(ns);
    if (nm && nm[2]) {
      return this.stripCdata(nm[2]);
    }
    return '';
  }

  private stripCdata(raw: string): string {
    return raw.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim();
  }

  /** Unescaped or entity-escaped XML attribute, e.g. DIDL res duration. */
  private extractAttr(xml: string, name: string): string {
    const q: RegExp = new RegExp(`${name}="([^"]+)"`, 'i');
    const m1: RegExpMatchArray | null = xml.match(q);
    if (m1 && m1[1]) {
      return m1[1].trim();
    }
    const e: RegExp = new RegExp(`${name}=&quot;([^&]+)&quot;`, 'i');
    const m2: RegExpMatchArray | null = xml.match(e);
    if (m2 && m2[1]) {
      return m2[1].trim();
    }
    return '';
  }

  private resolveUrl(location: string, path: string): string {
    const trimmed: string = path.trim();
    if (trimmed.indexOf('http://') === 0 || trimmed.indexOf('https://') === 0) {
      return trimmed;
    }
    const schemeIdx: number = location.indexOf('://');
    if (schemeIdx < 0) {
      return trimmed;
    }
    const afterScheme: string = location.substring(schemeIdx + 3);
    const slash: number = afterScheme.indexOf('/');
    const origin: string = slash >= 0 ? location.substring(0, schemeIdx + 3 + slash) : location;
    if (trimmed.indexOf('/') === 0) {
      return origin + trimmed;
    }
    const lastSlash: number = location.lastIndexOf('/');
    const dir: string = lastSlash > schemeIdx + 2 ? location.substring(0, lastSlash + 1) : origin + '/';
    return dir + trimmed;
  }

  private hostOf(location: string): string {
    const schemeIdx: number = location.indexOf('://');
    if (schemeIdx < 0) {
      return location;
    }
    const after: string = location.substring(schemeIdx + 3);
    const slash: number = after.indexOf('/');
    return slash >= 0 ? after.substring(0, slash) : after;
  }

  private guessName(usn: string, location: string): string {
    if (usn) {
      const parts: string[] = usn.split(':');
      if (parts.length > 1) {
        return parts[parts.length - 1].substring(0, 24) || this.hostOf(location);
      }
    }
    return this.hostOf(location) || 'DLNA 设备';
  }

  private xmlEscape(value: string): string {
    let out: string = '';
    for (let i = 0; i < value.length; i++) {
      const ch: string = value.charAt(i);
      if (ch === '&') {
        out += '&amp;';
      } else if (ch === '<') {
        out += '&lt;';
      } else if (ch === '>') {
        out += '&gt;';
      } else if (ch === '"') {
        out += '&quot;';
      } else if (ch === '\'') {
        out += '&apos;';
      } else {
        out += ch;
      }
    }
    return out;
  }

  private bufferToString(buf: ArrayBuffer): string {
    const bytes: Uint8Array = new Uint8Array(buf);
    let str: string = '';
    for (let i = 0; i < bytes.length; i++) {
      str += String.fromCharCode(bytes[i]);
    }
    return str;
  }

  private listDevices(): DlnaDevice[] {
    const list: DlnaDevice[] = [];
    this.devices.forEach((d: DlnaDevice) => {
      list.push(d);
    });
    return list;
  }

  /** uuid:xxx::urn:... → uuid:xxx，同一物理设备只留一条。 */
  private deviceId(usn: string, location: string): string {
    if (usn.indexOf('uuid:') === 0) {
      const cut: number = usn.indexOf('::');
      return cut >= 0 ? usn.substring(0, cut) : usn;
    }
    return location;
  }

  private hasLocation(location: string): boolean {
    const loc: string = location.trim();
    let found: boolean = false;
    this.devices.forEach((d: DlnaDevice) => {
      if (d.location === loc) {
        found = true;
      }
    });
    return found;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }

  private closeSockets(): void {
    if (this.udp) {
      try {
        this.udp.off('message');
        this.udp.off('error');
        this.udp.close();
      } catch (_e) {
      }
      this.udp = null;
    }
    if (this.multicast) {
      try {
        this.multicast.off('message');
        const addr: socket.NetAddress = {
          address: DlnaClient.SSDP_ADDR,
          port: DlnaClient.SSDP_PORT,
          family: 1
        };
        this.multicast.dropMembership(addr).catch(() => {});
      } catch (_e) {
      }
      this.multicast = null;
    }
  }
}
