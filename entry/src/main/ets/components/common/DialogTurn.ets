@Component
export struct DialogTurn {
  @BuilderParam content: () => void;
  @Prop atBottom: boolean = true;
  onBlank: () => void = () => {};
  @StorageLink('APP_DEVICE_ANGLE') @Watch('syncAngle') private deviceAngle: number = 0;
  @StorageLink('APP_ROTATION_HELD') @Watch('syncAngle') private rotationHeld: boolean = false;
  @StorageLink('APP_FROZEN_ANGLE') @Watch('syncAngle') private frozenAngle: number = 0;
  @StorageLink('WINDOW_RAW_W') private rawW: number = 0;
  @StorageLink('WINDOW_RAW_H') private rawH: number = 0;
  @State private angle: number = 0;

  aboutToAppear(): void {
    this.syncAngle();
  }

  private syncAngle(): void {
    this.angle = this.rotationHeld ? this.frozenAngle : this.deviceAngle;
  }

  private turned(): boolean {
    const angle = this.angle;
    return angle === 90 || angle === -90 || angle === 270 || angle === -270;
  }

  private closeBlank(): void {
    this.onBlank();
  }

  private holdSheet(): void {
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Stack({ alignContent: this.atBottom ? Alignment.Bottom : Alignment.Center }) {
        Column()
          .width('100%')
          .height('100%')
          .onClick(() => {
            this.closeBlank();
          })
        Column() {
          this.content()
        }
        .width('100%')
        .onClick(() => {
          this.holdSheet();
        })
      }
      .width(this.rawW > 0 ? (this.turned() ? this.rawH : this.rawW) : '100%')
      .height(this.rawH > 0 ? (this.turned() ? this.rawW : this.rawH) : '100%')
      .rotate({
        x: 0,
        y: 0,
        z: 1,
        angle: this.angle,
        centerX: '50%',
        centerY: '50%'
      })
      .renderGroup(true)
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}
