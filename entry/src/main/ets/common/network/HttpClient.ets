import { http } from '@kit.NetworkKit';
import { ServerConfigManager } from '../utils/ServerConfigManager';
import { QueryParams } from '../utils/QueryParams';
import { SourceGuard } from '../utils/SourceGuard';

export interface ApiResponse {
  code: number;
  msg: string;
  data: Object | Object[] | string | number | boolean | null;
}

export class HttpClient {
  private static instance: HttpClient;

  private constructor() {
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
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
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
      SourceGuard.intercept();
      if (err instanceof Error) {
        throw err;
      }
      throw new Error('网络请求失败');
    }
  }
}
