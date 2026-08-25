import { FilmApi } from '../../api/FilmApi';
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
    }
    return SiteHeartbeat.instance;
  }

  /**
   * 启动前台心跳探活（仅在前台活跃时运行）
   */
  public start(): void {
    if (this.running) {
      return;
    }
    this.running = true;
    this.consecutiveFailures = 0;
    this.runProbe();
  }

  /**
   * 暂停心跳探活（切后台/锁屏时调用，彻底消除后台耗电）
   */
  public stop(): void {
    this.running = false;
    this.clearTimer();
  }

  /**
   * 重置连续故障计数（如手动刷新成功或重新连接成功时）
   */
  public resetFailures(): void {
    this.consecutiveFailures = 0;
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
      this.runProbe();
    }, delay);
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

    this.probing = true;
    try {
      // 探活请求：获取最新站点状态，自动触发 FilmApi.onConfigChange 广播
      await FilmApi.getSiteConfig(true);
      // 明确成功：重置连续故障计数
      this.consecutiveFailures = 0;
    } catch (_err) {
      // 明确失败：累加连续故障计数
      this.consecutiveFailures++;
      // 只有连续 3 次探活全部失败（持续约 30s 彻底失联），才判定源失效并引导重新配置
      if (this.consecutiveFailures >= MAX_FAILURES) {
        SourceGuard.intercept();
      }
    } finally {
      this.probing = false;
      // 只有本次请求完全结束后，若当前仍处于前台运行状态，才开启下一次 10s 倒计时
      if (this.running) {
        this.scheduleNext(HEARTBEAT_INTERVAL_MS);
      }
    }
  }
}
