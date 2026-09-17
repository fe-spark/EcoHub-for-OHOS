import { http } from '@kit.NetworkKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ServerConfigManager } from '../../services/ServerConfigManager';
import { QueryParams } from '../utils/QueryParams';
import { SourceGuard } from '../../services/SourceGuard';
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

export interface ConnectionResult {
  ok: boolean;
  message?: string;
  isPrivate?: boolean;
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
    if (params) {
      const query: string = params.toQuery();
      if (query.length > 0) {
        url = `${url}?${query}`;
      }
    }
    try {
      return await this.send(url, timeout);
    } catch (err) {
      SourceGuard.intercept();
      if (err instanceof Error) {
        throw err;
      }
      throw new Error('网络请求失败');
    }
  }

  public async post(path: string, payload?: Record<string, Object | string | number | boolean>, timeout: number = 15000): Promise<ApiResponse> {
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
    const provideKey = ServerConfigManager.getInstance().getProvideKey();
    if (provideKey) {
      header['X-Provide-Key'] = provideKey;
    }
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: payload ? JSON.stringify(payload) : undefined,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: timeout,
        readTimeout: timeout
      });
      httpRequest.destroy();
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as ApiResponse;
      }
      let errMsg = `HTTP ${response.responseCode}`;
      try {
        if (response.result) {
          const errBody = JSON.parse(response.result as string) as ApiResponse;
          if (errBody && errBody.msg) {
            errMsg = errBody.msg;
          }
        }
      } catch (_e) {}
      throw new Error(errMsg);
    } catch (err) {
      httpRequest.destroy();
      SourceGuard.intercept();
      if (err instanceof Error) {
        throw err;
      }
      throw new Error('网络请求失败');
    }
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
      url = manager.buildApiUrl('/stats/view');
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
      const provideKey = ServerConfigManager.getInstance().getProvideKey();
      if (provideKey) {
        headers['X-Provide-Key'] = provideKey;
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

  public async testConnection(baseUrl: string): Promise<ConnectionResult> {
    const raw = baseUrl ? baseUrl.trim() : '';
    if (!raw) {
      return { ok: false, message: '请输入有效的软件源地址' };
    }
    const manager = ServerConfigManager.getInstance();
    const origin = ServerConfigManager.stripApiSuffix(manager.normalizeRaw(baseUrl));
    if (!origin || origin === 'https://' || origin === 'http://') {
      return { ok: false, message: '请输入有效的软件源地址' };
    }
    const key = ServerConfigManager.extractProvideKey(baseUrl);
    SourceGuard.beginSkip();
    try {
      const query = key ? `?key=${encodeURIComponent(key)}` : '';
      // 优先探测专有端点 /api/provide/app，可直接检验私有化与订阅密钥
      try {
        const res = await this.send(`${origin}/api/provide/app${query}`, 5000, key);
        if (res.code === 1 || res.code === 0) {
          return { ok: true };
        }
      } catch (appErr) {
        const msg = (appErr instanceof Error) ? appErr.message : '';
        // 若服务端返回私有化相关报错，直接向用户明确反馈
        if (msg.indexOf('私有化') >= 0 || msg.indexOf('订阅密钥') >= 0) {
          return { ok: false, isPrivate: true, message: msg };
        }
        if (msg.indexOf('401') >= 0 || msg.indexOf('403') >= 0) {
          return { ok: false, isPrivate: true, message: '该软件源已开启私有化访问，请在地址后追加 ?key=密钥' };
        }
        // 过渡兼容逻辑：若 404 说明为早期未支持 /api/provide/app 的旧版服务端，尝试兜底探测 /api/health。
        // 注意：服务端 /api/health 未来大版本将废弃移除，届时将仅支持 /api/provide/app 探测。
        if (msg.indexOf('404') >= 0) {
          const healthRes = await this.send(`${origin}/api/health${query}`, 5000, key);
          if (healthRes.code === 0) {
            return { ok: true };
          }
        }
        if (appErr instanceof Error) {
          throw appErr;
        }
        throw new Error(`${appErr}`);
      }
      return { ok: true };
    } catch (err) {
      const msg = (err instanceof Error) ? err.message : '无法连接该源，请检查地址或网络';
      return { ok: false, message: msg };
    } finally {
      SourceGuard.endSkip();
    }
  }

  private async send(url: string, timeout: number, customKey?: string): Promise<ApiResponse> {
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
    const provideKey = customKey !== undefined ? customKey : ServerConfigManager.getInstance().getProvideKey();
    if (provideKey) {
      header['X-Provide-Key'] = provideKey;
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
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as ApiResponse;
      }
      let errMsg = `HTTP ${response.responseCode}`;
      try {
        if (response.result) {
          const errBody = JSON.parse(response.result as string) as ApiResponse;
          if (errBody && errBody.msg) {
            errMsg = errBody.msg;
          }
        }
      } catch (_e) {}
      throw new Error(errMsg);
    } catch (err) {
      httpRequest.destroy();
      if (err instanceof Error) {
        throw err;
      }
      throw new Error('网络请求失败');
    }
  }
}
