import { BackIcon } from './BackIcon';

@Component
export struct PlayerIconBtn {
  private static readonly TAP_DEBOUNCE_MS: number = 120;
  @Prop src: Resource = $r('sys.symbol.play_fill');
  @Prop iconSize: number = 18;
  @Prop boxSize: number = 36;
  @Prop circle: boolean = false;
  @Prop prominent: boolean = false;
  @Prop canTap: boolean = true;
  onTap?: () => void;
  private lastTapAt: number = 0;

  private handleTap(): void {
    if (!this.canTap) {
      return;
    }
    const now = Date.now();
    if (now - this.lastTapAt < PlayerIconBtn.TAP_DEBOUNCE_MS) {
      return;
    }
    this.lastTapAt = now;
    if (this.onTap) {
      this.onTap();
    }
  }

  private bgColor(): string {
    if (!this.circle) {
      return '#01000000';
    }
    return this.prominent ? 'rgba(0,0,0,0.34)' : 'rgba(0,0,0,0.20)';
  }

  build() {
    Column() {
      SymbolGlyph(this.src)
        .fontSize(this.iconSize)
        .fontColor(['#FFFFFF'])
        .fontWeight(FontWeight.Medium)
        .hitTestBehavior(HitTestMode.None)
    }
    .width(this.boxSize)
    .height(this.boxSize)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .opacity(this.canTap ? 1 : 0.28)
    .backgroundColor(this.bgColor())
    .borderRadius(this.circle ? this.boxSize / 2 : 4)
    .borderWidth(this.circle ? 1 : 0)
    .borderColor(this.circle ? (this.prominent ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.12)') :
      Color.Transparent)
    .responseRegion({ x: 0, y: 0, width: '100%', height: '100%' })
    .priorityGesture(
      TapGesture({ count: 1 })
        .onAction(() => this.handleTap())
    )
  }
}

@Component
export struct PlayerLabelBtn {
  private static readonly TAP_DEBOUNCE_MS: number = 120;
  @Prop src: Resource = $r('sys.symbol.play_fill');
  @Prop label: string = '';
  @Prop canTap: boolean = true;
  onTap?: () => void;
  private lastTapAt: number = 0;

  private handleTap(): void {
    if (!this.canTap) {
      return;
    }
    const now = Date.now();
    if (now - this.lastTapAt < PlayerLabelBtn.TAP_DEBOUNCE_MS) {
      return;
    }
    this.lastTapAt = now;
    if (this.onTap) {
      this.onTap();
    }
  }

  build() {
    Row({ space: 4 }) {
      SymbolGlyph(this.src)
        .fontSize(16)
        .fontColor(['#FFFFFF'])
        .hitTestBehavior(HitTestMode.None)
      Text(this.label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .hitTestBehavior(HitTestMode.None)
    }
    .height(44)
    .padding({ left: 8, right: 10 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .opacity(this.canTap ? 1 : 0.28)
    .responseRegion({ x: 0, y: 0, width: '100%', height: '100%' })
    .priorityGesture(
      TapGesture({ count: 1 })
        .onAction(() => this.handleTap())
    )
  }
}

@Component
export struct PlayerTextBtn {
  private static readonly TAP_DEBOUNCE_MS: number = 120;
  @Prop label: string = '';
  @Prop boxSize: number = 52;
  onTap?: () => void;
  private lastTapAt: number = 0;

  private handleTap(): void {
    const now = Date.now();
    if (now - this.lastTapAt < PlayerTextBtn.TAP_DEBOUNCE_MS) {
      return;
    }
    this.lastTapAt = now;
    if (this.onTap) {
      this.onTap();
    }
  }

  build() {
    Column() {
      Text(this.label)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .hitTestBehavior(HitTestMode.None)
    }
    .width(this.boxSize)
    .height(this.boxSize)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('rgba(0,0,0,0.45)')
    .borderRadius(this.boxSize / 2)
    .responseRegion({ x: 0, y: 0, width: '100%', height: '100%' })
    .priorityGesture(
      TapGesture({ count: 1 })
        .onAction(() => this.handleTap())
    )
  }
}

@Component
export struct PlayerChip {
  private static readonly TAP_DEBOUNCE_MS: number = 120;
  @Prop label: string = '';
  @Prop canTap: boolean = true;
  onTap?: () => void;
  private lastTapAt: number = 0;

  private handleTap(): void {
    if (!this.canTap) {
      return;
    }
    const now = Date.now();
    if (now - this.lastTapAt < PlayerChip.TAP_DEBOUNCE_MS) {
      return;
    }
    this.lastTapAt = now;
    if (this.onTap) {
      this.onTap();
    }
  }

  build() {
    Text(this.label)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.canTap ? '#FFFFFF' : 'rgba(255,255,255,0.35)')
      .height(44)
      .padding({ left: 8, right: 8 })
      .textAlign(TextAlign.Center)
      .priorityGesture(
        TapGesture({ count: 1 })
          .onAction(() => this.handleTap())
      )
  }
}

@Component
export struct PlayerBackBtn {
  private static readonly TAP_DEBOUNCE_MS: number = 120;
  onTap?: () => void;
  private lastTapAt: number = 0;

  private handleTap(): void {
    const now = Date.now();
    if (now - this.lastTapAt < PlayerBackBtn.TAP_DEBOUNCE_MS) {
      return;
    }
    this.lastTapAt = now;
    if (this.onTap) {
      this.onTap();
    }
  }

  build() {
    Column() {
      BackIcon({ color: '#FFFFFF' })
        .hitTestBehavior(HitTestMode.None)
    }
    .width(40)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#01000000')
    .responseRegion({ x: 0, y: 0, width: '100%', height: '100%' })
    .priorityGesture(
      TapGesture({ count: 1 })
        .onAction(() => this.handleTap())
    )
  }
}
