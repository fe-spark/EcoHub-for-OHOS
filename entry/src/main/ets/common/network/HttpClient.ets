import { http } from '@kit.NetworkKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ServerConfigManager } from '../utils/ServerConfigManager';
import { QueryParams } from '../utils/QueryParams';
import { SourceGuard } from '../utils/SourceGuard';
import { AppVersionUtil } from '../utils/AppVersionUtil';

export interface ApiResponse {
  code: number;
  msg: string;
  data: Object | Object[] | string | number | boolean | null;
}

interface TrackViewPayload {
  source: string;
  action: string;
  resource: string;
  page: string;
  app_version?: string;
  device_model?: string;
  device_id?: string;
}

export class HttpClient {
  private static instance: HttpClient;
  private userAgent: string = '';

  private constructor() {
  }

  private async resolveUserAgent(): Promise<string> {
    if (this.userAgent) {
      return this.userAgent;
    }
    try {
      const version = await AppVersionUtil.getVersionName();
      this.userAgent = version ? `EcoHub-OHOS/${version}` : 'EcoHub-OHOS';
    } catch (_err) {
      this.userAgent = 'EcoHub-OHOS';
    }
    return this.userAgent;
  }

  public static getInstance(): HttpClient {
    if (!HttpClient.instance) {
      HttpClient.instance = new HttpClient();
    }
    return HttpClient.instance;
  }

  public async get(path: string, params?: QueryParams, timeout: number = 15000): Promise<ApiResponse> {
    const manager = ServerConfigManager.getInstance();
    let url = '';
    try {
      url = manager.buildApiUrl(path);
    } catch (err) {
      SourceGuard.intercept();
      if (err instanceof Error) {
        throw err;
      }
      throw new Error('未配置软件源');
    }
    if (params && !params.isEmpty()) {
      url += (url.includes('?') ? '&' : '?') + params.toQuery();
    }
    return this.send(url, timeout);
  }

  public trackView(action: string, resource: string = '', page: string = '', deviceModel: string = ''): void {
    this.sendTrack(action, resource, page, deviceModel).catch(() => {});
  }

  private resolveDeviceModel(customModel: string = ''): string {
    if (customModel && customModel.trim().length > 0) {
      return customModel.trim();
    }
    try {
      const market = (deviceInfo.marketName || '').trim();
      const product = (deviceInfo.productModel || '').trim();
      if (market && product && market !== product) {
        return `${market} (${product})`;
      }
      return market || product || '';
    } catch (_err) {
      return '';
    }
  }

  private async sendTrack(action: string, resource: string, page: string, deviceModel: string): Promise<void> {
    const manager = ServerConfigManager.getInstance();
    let url = '';
    try {
      url = manager.buildApiUrl('/stat/view');
    } catch (_err) {
      return;
    }
    const httpRequest = http.createHttp();
    const userAgent = await this.resolveUserAgent();
    let version = '';
    try {
      version = await AppVersionUtil.getVersionName();
    } catch (_err) {}

    let deviceId = '';
    try {
      deviceId = await manager.getDeviceId();
    } catch (_err) {}

    const resolvedModel = this.resolveDeviceModel(deviceModel);

    const payload: TrackViewPayload = {
      source: 'harmony',
      action: action,
      resource: resource,
      page: page || action,
      app_version: version,
      device_model: resolvedModel,
      device_id: deviceId
    };
    try {
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': userAgent
      };
      if (deviceId) {
        headers['X-Device-Id'] = deviceId;
        headers['Device-Id'] = deviceId;
      }
      await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: payload,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 5000,
        readTimeout: 5000
      });
    } catch (_err) {
    } finally {
      httpRequest.destroy();
    }
  }

  public async testConnection(baseUrl: string): Promise<boolean> {
    const manager = ServerConfigManager.getInstance();
    const origin = ServerConfigManager.stripApiSuffix(manager.normalizeRaw(baseUrl));
    if (!origin) {
      return false;
    }
    SourceGuard.beginSkip();
    try {
      const response = await this.send(`${origin}/api/health`, 5000);
      return response.code === 0;
    } catch (err) {
      return false;
    } finally {
      SourceGuard.endSkip();
    }
  }

  private async send(url: string, timeout: number): Promise<ApiResponse> {
    const httpRequest = http.createHttp();
    const userAgent = await this.resolveUserAgent();
    let deviceId = '';
    try {
      deviceId = await ServerConfigManager.getInstance().getDeviceId();
    } catch (_err) {}
    const header: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': userAgent
    };
    if (deviceId) {
      header['X-Device-Id'] = deviceId;
      header['Device-Id'] = deviceId;
    }
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: header,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: timeout,
        readTimeout: timeout
      });
      httpRequest.destroy();
      if (response.responseCode !== 200) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      const body = JSON.parse(response.result as string) as ApiResponse;
      return body;
    } catch (err) {
      httpRequest.destroy();
      if (err instanceof Error) {
        throw err;
      }
      throw new Error('网络请求失败');
    }
  }
}
