import { AppToast } from '../../common/utils/AppToast';
import { DlnaDevice } from '../../types/DlnaTypes';
import { PlayerCastController, PlayerCastHost } from '../cast/PlayerCastController';

/**
 * 播放器 DLNA 投屏桥接层
 * 统一管理投屏会话、UI 状态与本地播放器暂停/恢复协同
 */
export class PlayerCastBridge {
  private castCtrl: PlayerCastController = new PlayerCastController();

  init(host: PlayerCastHost): void {
    this.castCtrl.updateHost(host);
    this.castCtrl.bindCallbacks();
  }

  updateHost(host: PlayerCastHost): void {
    this.castCtrl.updateHost(host);
  }

  get ctrl(): PlayerCastController {
    return this.castCtrl;
  }

  get device(): DlnaDevice | null {
    return this.castCtrl.device;
  }

  get deviceName(): string {
    return this.castCtrl.deviceName;
  }

  get connectedUsn(): string {
    return this.castCtrl.connectedUsn;
  }

  get startSec(): number {
    return this.castCtrl.startSec;
  }

  get phase(): string {
    return this.castCtrl.session.phase;
  }

  get transportState(): string {
    return this.castCtrl.session.transportState;
  }

  get positionSec(): number {
    return this.castCtrl.session.positionSec;
  }

  get durationSec(): number {
    return this.castCtrl.session.durationSec;
  }

  get session() {
    return this.castCtrl.session;
  }

  isCasting(): boolean {
    return this.castCtrl.isCasting();
  }

  openCastDialog(): void {
    this.castCtrl.openCastDialog();
  }

  closeCastDialog(): void {
    this.castCtrl.resumeAfterPickerCancel();
  }

  pushCastVolume(): void {
    this.castCtrl.pushCastVolume();
  }

  endCastByUser(): void {
    this.castCtrl.endCastByUser();
  }

  bindCastDevice(device: DlnaDevice): void {
    this.castCtrl.bindCastDevice(device);
  }

  handleSourceChange(): boolean {
    return this.castCtrl.handleSourceChange();
  }

  resumeCastSync(): void {
    this.castCtrl.resumeCastSync();
  }

  stopSession(): void {
    this.castCtrl.stopSession();
  }

  syncCastProgressToState(): void {
    this.castCtrl.syncCastProgressToState();
  }
}
