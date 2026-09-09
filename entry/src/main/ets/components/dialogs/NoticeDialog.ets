import { curves } from '@kit.ArkUI';
import { AppTheme } from '../../common/constants/AppTheme';
import { AppIcon } from '../common/AppIcon';
import { WindowBar } from '../../common/utils/WindowBar';

@Component
export struct NoticeDialog {
  @Prop title: string = '站点公告';
  @Prop content: string = '';
  onClose: () => void = () => {};

  @State private maskOpacity: number = 0;
  @State private cardScale: number = 0.72;
  @State private cardOpacity: number = 0;
  private isClosing: boolean = false;

  @StorageLink('SAFE_INSET_TOP') private topInset: number = 0;
  @StorageLink('SAFE_INSET_BOTTOM') private bottomInset: number = 16;
  @StorageLink('SAFE_INSET_LEFT') private leftInset: number = 0;
  @StorageLink('SAFE_INSET_RIGHT') private rightInset: number = 0;
  @StorageLink('WINDOW_WIDTH') private windowWidth: number = 360;
  @StorageLink('WINDOW_HEIGHT') private windowHeight: number = 640;

  private isLandscape(): boolean {
    return this.windowWidth > this.windowHeight && this.windowHeight > 0;
  }

  // 正文随内容收紧；仅在超出上限时滚动，避免短公告被 layoutWeight 撑高
  private contentMaxHeight(): number {
    const pad = this.isLandscape() ? 14 : AppTheme.SPACE_LG;
    const headerGap = this.isLandscape() ? 8 : AppTheme.SPACE_MD;
    const btnGap = this.isLandscape() ? 10 : AppTheme.SPACE_LG;
    const btnH = this.isLandscape() ? 36 : 42;
    const chrome = pad * 2 + 32 + headerGap + btnGap + btnH;
    const available = this.windowHeight - this.topInset - this.bottomInset - 24 - chrome;
    return Math.max(48, Math.min(this.isLandscape() ? 160 : 260, available));
  }

  aboutToAppear(): void {
    WindowBar.setImmersiveOverlay(true);
    setTimeout(() => {
      this.maskOpacity = 1;
      this.cardScale = 1;
      this.cardOpacity = 1;
    }, 16);
  }

  aboutToDisappear(): void {
    WindowBar.setImmersiveOverlay(false);
  }

  private handleConfirm(): void {
    if (this.isClosing) {
      return;
    }
    this.isClosing = true;
    this.maskOpacity = 0;
    this.cardScale = 0.85;
    this.cardOpacity = 0;
    setTimeout(() => {
      this.onClose();
    }, 200);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.72)')
        .opacity(this.maskOpacity)
        .animation({ duration: 200, curve: Curve.EaseOut })
        .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
        .onClick(() => {
          this.handleConfirm();
        })

      Column() {
        Column() {
          Row() {
            Stack({ alignContent: Alignment.Center }) {
              Column()
                .width(32)
                .height(32)
                .borderRadius(16)
                .backgroundColor(AppTheme.ACCENT_SOFT)
              AppIcon({
                src: $r('sys.symbol.bell_fill'),
                iconSize: 16,
                color: AppTheme.ACCENT
              })
            }
            .margin({ right: AppTheme.SPACE_SM })

            Text(this.title || '站点公告')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT_PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            Row() {
              AppIcon({
                src: $r('sys.symbol.xmark'),
                iconSize: 14,
                color: AppTheme.TEXT_MUTED
              })
            }
            .width(28)
            .height(28)
            .justifyContent(FlexAlign.Center)
            .borderRadius(14)
            .onClick(() => {
              this.handleConfirm();
            })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: this.isLandscape() ? 8 : AppTheme.SPACE_MD })

          Scroll() {
            Column() {
              Text(this.content)
                .fontSize(14)
                .lineHeight(22)
                .fontColor(AppTheme.TEXT_SECONDARY)
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)
          .constraintSize({ maxHeight: this.contentMaxHeight() })
          .width('100%')
          .padding(AppTheme.SPACE_MD)
          .backgroundColor(AppTheme.BG_CARD)
          .borderRadius(AppTheme.RADIUS_MD)
          .margin({ bottom: this.isLandscape() ? 10 : AppTheme.SPACE_LG })

          Button('我知道了')
            .width('100%')
            .height(this.isLandscape() ? 36 : 42)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .backgroundColor(AppTheme.ACCENT)
            .borderRadius(AppTheme.RADIUS_PILL)
            .onClick(() => {
              this.handleConfirm();
            })
        }
        .width('86%')
        .constraintSize({ maxWidth: 380, maxHeight: '100%' })
        .padding(this.isLandscape() ? 14 : AppTheme.SPACE_LG)
        .backgroundColor(AppTheme.BG_ELEVATED)
        .borderRadius(AppTheme.RADIUS_LG)
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.08)' })
        .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.5)', offsetY: 8 })
        .scale({ x: this.cardScale, y: this.cardScale })
        .opacity(this.cardOpacity)
        .animation({
          curve: curves.springMotion(0.38, 0.65, 0)
        })
        .onClick(() => {})
      }
      .width('100%')
      .height('100%')
      .padding({
        top: Math.max(8, this.topInset),
        bottom: Math.max(8, this.bottomInset),
        left: Math.max(16, this.leftInset),
        right: Math.max(16, this.rightInset)
      })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT],
      [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
    .zIndex(999)
  }
}
