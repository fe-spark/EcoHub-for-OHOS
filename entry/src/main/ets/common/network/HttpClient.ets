import { http } from '@kit.NetworkKit';
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
  action: string;
  resource: string;
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

  public trackView(action: string, resource: string = ''): void {
    this.sendTrack(action, resource).catch(() => {});
  }

  private async sendTrack(action: string, resource: string): Promise<void> {
    const manager = ServerConfigManager.getInstance();
    let url = '';
    try {
      url = manager.buildApiUrl('/stat/view');
    } catch (_err) {
      return;
    }
    const httpRequest = http.createHttp();
    const userAgent = await this.resolveUserAgent();
    const payload: TrackViewPayload = {
      action: action,
      resource: resource
    };
    try {
      await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': userAgent
        },
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
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': userAgent
        },
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
