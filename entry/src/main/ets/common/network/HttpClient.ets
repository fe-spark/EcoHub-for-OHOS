import { http } from '@kit.NetworkKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { ServerConfigManager } from '../../services/ServerConfigManager';
import { QueryParams } from '../utils/QueryParams';
import { SourceGuard } from '../../services/SourceGuard';
import { SiteHeartbeat } from '../../services/SiteHeartbeat';
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
  resource_cat?: string;
  resource_title?: string;
  app_version?: string;
  device_model?: string;
  device_id?: string;
}

export interface ConnectionResult {
  ok: boolean;
  message?: string;
  isPrivate?: boolean;
}

interface ThrownLike {
  name?: string;
  message?: string;
  code?: number | string;
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
      throw HttpClient.wrapError(err);
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
      throw HttpClient.wrapError(err);
    }
  }

  public trackView(action: string, resource: string = '', page: string = '', deviceModel: string = '', resourceCat: string = '', resourceTitle: string = ''): void {
    this.sendTrack(action, resource, page, deviceModel, resourceCat, resourceTitle).catch(() => {});
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

  private async sendTrack(action: string, resource: string, page: string, deviceModel: string, resourceCat: string = '', resourceTitle: string = ''): Promise<void> {
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
      resource_cat: resourceCat,
      resource_title: resourceTitle,
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
        extraData: JSON.stringify(payload),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 5000,
        readTimeout: 5000
      });
    } catch (_err) {
    } finally {
      httpRequest.destroy();
    }
  }

  private formatConnectionError(error: Object): string {
    const msg = (error instanceof Error) ? error.message : `${error}`;
    const lower = msg.toLowerCase();

    // 1. 服务未启动、网关异常或拒绝连接，统一归为服务错误
    if (lower.indexOf('502') >= 0 ||
        lower.indexOf('503') >= 0 ||
        lower.indexOf('504') >= 0 ||
        lower.indexOf('bad gateway') >= 0 ||
        lower.indexOf('gateway timeout') >= 0 ||
        lower.indexOf('service unavailable') >= 0 ||
        lower.indexOf('connection refused') >= 0 ||
        lower.indexOf('connection reset') >= 0 ||
        lower.indexOf('failed to connect') >= 0 ||
        lower.indexOf('connection failed') >= 0) {
      return '服务未启动或网关异常 (服务错误)';
    }

    // 2. 超时
    if (lower.indexOf('timeout') >= 0 || lower.indexOf('timed out') >= 0) {
      return '连接超时，服务可能未启动或网络不可达';
    }

    // 3. 域名解析失败
    if (lower.indexOf('resolve') >= 0 || lower.indexOf('dns') >= 0 || lower.indexOf('host') >= 0) {
      return '无法解析软件源地址，请检查域名或网络';
    }

    return msg ? msg : '服务未启动或网关异常 (服务错误)';
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
        const lower = msg.toLowerCase();

        // 优先拦截 502/503/504 与拒绝连接等服务错误，防止误判为私有化
        if (lower.indexOf('502') >= 0 ||
            lower.indexOf('503') >= 0 ||
            lower.indexOf('504') >= 0 ||
            lower.indexOf('bad gateway') >= 0 ||
            lower.indexOf('gateway timeout') >= 0 ||
            lower.indexOf('service unavailable') >= 0 ||
            lower.indexOf('connection refused') >= 0 ||
            lower.indexOf('connection reset') >= 0) {
          return { ok: false, message: this.formatConnectionError(appErr as Object) };
        }

        // 若服务端明确返回私有化相关报错，向用户明确反馈
        if (msg.indexOf('私有化') >= 0 || msg.indexOf('订阅密钥') >= 0) {
          return { ok: false, isPrivate: true, message: msg };
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
      return { ok: false, message: this.formatConnectionError(err as Object) };
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
      throw HttpClient.wrapError(err);
    }
  }

  /** 保留网络层原始异常文案，避免被收成「网络请求失败」 */
  private static wrapError(err: Object): Error {
    if (err instanceof Error) {
      return err;
    }
    const thrown = err as ThrownLike;
    const bits: string[] = [];
    if (thrown && thrown.name) {
      bits.push(`${thrown.name}`);
    }
    if (thrown && thrown.message) {
      bits.push(`${thrown.message}`);
    }
    if (thrown && thrown.code !== undefined && thrown.code !== null) {
      bits.push(`code: ${thrown.code}`);
    }
    if (bits.length > 0) {
      return new Error(bits.join(' '));
    }
    try {
      const rawJson = JSON.stringify(err);
      if (rawJson && rawJson !== '{}' && rawJson !== 'null') {
        return new Error(rawJson);
      }
    } catch (_e) {}
    const raw = `${err}`;
    return new Error(raw && raw !== '[object Object]' ? raw : '网络请求失败');
  }
}
