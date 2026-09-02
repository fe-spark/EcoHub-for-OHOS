import { connection } from '@kit.NetworkKit';
import { UIContext } from '@kit.ArkUI';
import { FilmApi } from '../../api/FilmApi';
import { BasicConfig } from '../../model/FilmModels';
import { ServerConfigManager } from './ServerConfigManager';
import { SourceGuard } from './SourceGuard';

const HEARTBEAT_INTERVAL_MS = 10000;
const MAX_FAILURES = 3;

export class SiteHeartbeat {
  private static instance: SiteHeartbeat;
  private running: boolean = false;
  private probing: boolean = false;
  private timerId: number = -1;
  private consecutiveFailures: number = 0;

  private constructor() {}

  public static getInstance(): SiteHeartbeat {
    if (!SiteHeartbeat.instance) {
      SiteHeartbeat.instance = new SiteHeartbeat();
      FilmApi.onConfigChange((config: BasicConfig) => {
        SiteHeartbeat.instance.checkSiteClosedState(config);
      });
    }
    return SiteHeartbeat.instance;
  }

  /**
   * 启动前台心跳探活（仅在前台活跃时运行）
   */
  public start(): void {
    this.consecutiveFailures = 0;
    this.running = true;
    if (this.timerId === -1 && !this.probing) {
      this.scheduleNext(HEARTBEAT_INTERVAL_MS);
    }
  }

  /**
   * 暂停心跳探活（切后台/锁屏时调用，彻底消除后台耗电）
   */
  public stop(): void {
    this.running = false;
    this.clearTimer();
  }

  /**
   * 重置连续故障计数（如手动刷新成功或重新连接成功时）并恢复调度
   */
  public resetFailures(): void {
    this.consecutiveFailures = 0;
    if (this.running && this.timerId === -1 && !this.probing) {
      this.scheduleNext(HEARTBEAT_INTERVAL_MS);
    }
  }

  private clearTimer(): void {
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
  }

  private scheduleNext(delay: number = HEARTBEAT_INTERVAL_MS): void {
    this.clearTimer();
    if (!this.running) {
      return;
    }
    this.timerId = setTimeout(() => {
      this.timerId = -1;
      this.runProbe();
    }, delay);
  }

  /**
   * 核查设备当前是否具备有效外网访问能力
   */
  private static async hasInternetConnection(): Promise<boolean> {
    try {
      const hasNet = await connection.hasDefaultNet();
      if (!hasNet) {
        return false;
      }
      const defaultNet = await connection.getDefaultNet();
      if (!defaultNet || defaultNet.netId === 0) {
        return false;
      }
      const netCap = await connection.getNetCapabilities(defaultNet);
      if (!netCap || !netCap.networkCap) {
        return false;
      }
      const hasInternet = netCap.networkCap.indexOf(connection.NetCap.NET_CAPABILITY_INTERNET) >= 0;
      if (!hasInternet) {
        return false;
      }
      if (netCap.networkCap.indexOf(connection.NetCap.NET_CAPABILITY_PORTAL) >= 0) {
        return false;
      }
      return true;
    } catch (_err) {
      try {
        return connection.hasDefaultNetSync();
      } catch (_e) {
        return false;
      }
    }
  }

  /**
   * 严格串行探活：等上一次请求明确成功/失败后，才开启下一次 10s 调度，防止请求堆积
   */
  private async runProbe(): Promise<void> {
    if (!this.running || this.probing) {
      return;
    }
    const serverUrl = ServerConfigManager.getInstance().getCachedServerUrl();
    if (!serverUrl) {
      return;
    }

    // 处于配置页时跳过探活，避免打扰用户配置
    const ctx = AppStorage.get<UIContext>('UI_CONTEXT');
    if (ctx) {
      const r = ctx.getRouter();
      if (r) {
        try {
          const state = r.getState();
          if (state && ((state.path && state.path.indexOf('ServerConfigPage') >= 0) || (state.name && state.name.indexOf('ServerConfigPage') >= 0))) {
            if (this.running) {
              this.scheduleNext(HEARTBEAT_INTERVAL_MS);
            }
            return;
          }
        } catch (_e) {
        }
      }
    }

    // 前置连通性检测：若本地无外网（如进电梯/飞行模式/Portal 认证），不盲发网络请求，重置连续故障计数
    const isNetAvailable = await SiteHeartbeat.hasInternetConnection();
    if (!isNetAvailable) {
      this.consecutiveFailures = 0;
      if (this.running) {
        this.scheduleNext(HEARTBEAT_INTERVAL_MS);
      }
      return;
    }

    this.probing = true;
    try {
      // 探活请求：获取最新站点状态，自动触发 FilmApi.onConfigChange 广播，单次探活超时限制为 8000ms
      const config = await FilmApi.getSiteConfig(true, 8000);
      // 明确成功：重置连续故障计数
      this.consecutiveFailures = 0;
      // 站点关闭运行状态检测
      this.checkSiteClosedState(config);
    } catch (_err) {
      // 探活请求异常时二次核验本地网络状态，若本地网络中断或异常，清零故障计数，不计入软件源故障
      const hasNetAfterErr = await SiteHeartbeat.hasInternetConnection();
      if (!hasNetAfterErr) {
        this.consecutiveFailures = 0;
        return;
      }
      // 确认设备联网状态下请求仍失败，累加连续故障计数
      this.consecutiveFailures++;
      // 只有连续 3 次探活全部失败（持续约 30s 彻底失联），才判定源失效并引导重新配置
      if (this.consecutiveFailures >= MAX_FAILURES) {
        SourceGuard.intercept(undefined, () => {
          // 用户在播放页面选择继续观看，重置连续故障计数并退避，避免弹窗频繁死循环打扰观影
          this.consecutiveFailures = 0;
          if (this.running) {
            this.scheduleNext(60000);
          }
        });
        return;
      }
    } finally {
      this.probing = false;
      // 只有本次请求完全结束后，若当前仍处于前台运行状态且未触发失效拦截，才开启下一次 10s 倒计时
      if (this.running && this.consecutiveFailures < MAX_FAILURES) {
        this.scheduleNext(HEARTBEAT_INTERVAL_MS);
      }
    }
  }

  /**
   * 检查站点是否处于关闭运行维护状态 (state === false)
   * 若站点关闭运行，直接强切路由回主页 (pages/Index) 展示内置维护视图，无需各页面分别弹窗
   */
  public checkSiteClosedState(config: BasicConfig): void {
    if (config.state !== false) {
      return;
    }
    const ctx = AppStorage.get<UIContext>('UI_CONTEXT');
    if (!ctx) {
      return;
    }
    const r = ctx.getRouter();
    if (!r) {
      return;
    }
    try {
      const state = r.getState();
      if (state) {
        const p = state.path || '';
        const n = state.name || '';
        // 处于配置源页面或开屏引导页时，不强行打断操作
        if (p.indexOf('ServerConfigPage') >= 0 || n.indexOf('ServerConfigPage') >= 0 ||
            p.indexOf('SplashPage') >= 0 || n.indexOf('SplashPage') >= 0) {
          return;
        }
        // 已经在主页时无需强跳，主页会自适应显示维护占位视图
        if (p.indexOf('Index') >= 0 || n.indexOf('Index') >= 0) {
          return;
        }
      }
      // 在播放页、搜索页、筛选页等其他所有页面，直接清空历史栈并强切路由回主页
      try {
        r.clear();
      } catch (_e) {
      }
      r.replaceUrl({ url: 'pages/Index' });
    } catch (_e) {
    }
  }
}
