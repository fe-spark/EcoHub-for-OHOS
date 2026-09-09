@Component
export struct AppIcon {
  @Prop src: Resource = $r('sys.symbol.film');
  @Prop iconSize: number = 20;
  @Prop color: string = '#FFFFFF';

  build() {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph(this.src)
        .fontSize(this.iconSize)
        .fontColor([this.color])
        .fontWeight(FontWeight.Medium)
        .hitTestBehavior(HitTestMode.None)
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }
}
