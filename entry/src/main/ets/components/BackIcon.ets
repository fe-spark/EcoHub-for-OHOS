@Component
export struct BackIcon {
  @Prop color: string = '#FFFFFF';
  @Prop iconSize: number = 32;

  build() {
    Stack() {
      Line()
        .width(this.iconSize)
        .height(this.iconSize)
        .startPoint([this.iconSize * 20 / 32, this.iconSize * 8 / 32])
        .endPoint([this.iconSize * 11 / 32, this.iconSize * 16 / 32])
        .stroke(this.color)
        .strokeWidth(this.iconSize >= 28 ? 2.2 : 1.8)
        .strokeLineCap(LineCapStyle.Round)
      Line()
        .width(this.iconSize)
        .height(this.iconSize)
        .startPoint([this.iconSize * 11 / 32, this.iconSize * 16 / 32])
        .endPoint([this.iconSize * 20 / 32, this.iconSize * 24 / 32])
        .stroke(this.color)
        .strokeWidth(this.iconSize >= 28 ? 2.2 : 1.8)
        .strokeLineCap(LineCapStyle.Round)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }
}
