import { AppTheme } from '../../common/constants/AppTheme';

@Component
export struct AppFrame {
  @BuilderParam content: () => void;
  @StorageLink('APP_DEVICE_ANGLE') @Watch('onOrient') private deviceAngle: number = 0;
  @StorageLink('APP_ROTATION_HELD') @Watch('onOrient') private rotationHeld: boolean = false;
  @StorageLink('APP_FROZEN_ANGLE') @Watch('onOrient') private frozenAngle: number = 0;
  @State private baseW: number = 0;
  @State private baseH: number = 0;
  @State private boxW: number = 0;
  @State private boxH: number = 0;
  @State private shownAngle: number = 0;
  @StorageLink('APP_TOAST_SEQ') @Watch('onToast') private toastSeq: number = 0;
  @State private toastText: string = '';
  @State private toastOn: boolean = false;
  private settleTimer: number = -1;
  private toastTimer: number = -1;
  private rebaseTimer: number = -1;
  private snapOnce: boolean = false;

  private targetAngle(): number {
    if (this.rotationHeld) {
      return this.frozenAngle;
    }
    return this.deviceAngle;
  }

  private onOrient(): void {
    if (this.baseW <= 0 || this.baseH <= 0) {
      return;
    }
    const instant = this.rotationHeld || this.snapOnce || this.boxW <= 0 || this.boxH <= 0;
    if (this.rotationHeld) {
      this.snapOnce = true;
    } else if (this.snapOnce) {
      this.snapOnce = false;
    }
    const angle = this.targetAngle();
    if (instant) {
      this.place(angle);
      return;
    }
    const canonical = this.norm(this.shownAngle);
    if (canonical !== this.shownAngle) {
      this.place(canonical);
      this.rebaseTimer = setTimeout(() => {
        this.rebaseTimer = -1;
        if (this.rotationHeld) {
          return;
        }
        this.animateOrient(this.targetAngle(), this.norm(this.shownAngle));
      }, 0);
      return;
    }
    this.animateOrient(angle, canonical);
  }

  private animateOrient(angle: number, from: number): void {
    if (this.baseW <= 0 || this.baseH <= 0 || this.rotationHeld) {
      return;
    }
    const turned = angle !== 0;
    const nextW = turned ? this.baseH : this.baseW;
    const nextH = turned ? this.baseW : this.baseH;
    const nextAngle = this.animTarget(from, angle);
    if (nextAngle === from && nextW === this.boxW && nextH === this.boxH) {
      return;
    }
    const settled = angle;
    try {
      this.getUIContext().animateTo({ duration: 280, curve: Curve.EaseInOut }, () => {
        this.shownAngle = nextAngle;
        this.boxW = nextW;
        this.boxH = nextH;
      });
    } catch (_e) {
      this.shownAngle = settled;
      this.boxW = nextW;
      this.boxH = nextH;
      return;
    }
    if (nextAngle === settled) {
      return;
    }
    if (this.settleTimer !== -1) {
      clearTimeout(this.settleTimer);
    }
    this.settleTimer = setTimeout(() => {
      this.settleTimer = -1;
      if (this.shownAngle !== nextAngle) {
        return;
      }
      try {
        this.getUIContext().animateTo({ duration: 0 }, () => {
          this.shownAngle = settled;
        });
      } catch (_e) {
        this.shownAngle = settled;
      }
    }, 300);
  }

  private animTarget(from: number, to: number): number {
    const start = this.norm(from);
    const end = this.norm(to);
    if (start > 0 && end < 0) {
      return end + 360;
    }
    if (start < 0 && end > 0) {
      return end - 360;
    }
    return end;
  }

  private norm(angle: number): number {
    let value = angle % 360;
    if (value > 180) {
      value -= 360;
    }
    if (value < -180) {
      value += 360;
    }
    return value;
  }

  aboutToDisappear(): void {
    this.clearRebase();
    if (this.settleTimer !== -1) {
      clearTimeout(this.settleTimer);
      this.settleTimer = -1;
    }
    if (this.toastTimer !== -1) {
      clearTimeout(this.toastTimer);
      this.toastTimer = -1;
    }
  }

  private clearRebase(): void {
    if (this.rebaseTimer !== -1) {
      clearTimeout(this.rebaseTimer);
      this.rebaseTimer = -1;
    }
  }

  private onToast(): void {
    if (this.toastSeq <= 0) {
      return;
    }
    const message = AppStorage.get<string>('APP_TOAST') ?? '';
    if (!message) {
      return;
    }
    this.toastText = message;
    this.toastOn = true;
    if (this.toastTimer !== -1) {
      clearTimeout(this.toastTimer);
    }
    this.toastTimer = setTimeout(() => {
      this.toastTimer = -1;
      this.toastOn = false;
    }, 1600);
  }

  private place(angle: number): void {
    this.clearRebase();
    if (this.settleTimer !== -1) {
      clearTimeout(this.settleTimer);
      this.settleTimer = -1;
    }
    const turned = angle !== 0;
    const nextW = turned ? this.baseH : this.baseW;
    const nextH = turned ? this.baseW : this.baseH;
    try {
      this.getUIContext().animateTo({ duration: 0 }, () => {
        this.shownAngle = angle;
        this.boxW = nextW;
        this.boxH = nextH;
      });
    } catch (_e) {
      this.shownAngle = angle;
      this.boxW = nextW;
      this.boxH = nextH;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          this.content()
        }
        .width('100%')
        .height('100%')

        if (this.toastOn) {
          Text(this.toastText)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .backgroundColor('rgba(0, 0, 0, 0.78)')
            .borderRadius(20)
            .margin({ bottom: 48 })
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .width(this.boxW > 0 ? this.boxW : '100%')
      .height(this.boxH > 0 ? this.boxH : '100%')
      .rotate({
        x: 0,
        y: 0,
        z: 1,
        angle: this.shownAngle,
        centerX: '50%',
        centerY: '50%'
      })
      .renderGroup(true)
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor(AppTheme.BG)
    .onAreaChange((_old: Area, area: Area) => {
      const w = Number(area.width);
      const h = Number(area.height);
      if (w <= 0 || h <= 0) {
        return;
      }
      const first = this.baseW <= 0 || this.baseH <= 0;
      this.baseW = w;
      this.baseH = h;
      if (this.rotationHeld || this.targetAngle() !== 0) {
        this.place(this.targetAngle());
        return;
      }
      this.boxW = w;
      this.boxH = h;
      if (first) {
        this.onOrient();
      }
    })
  }
}
