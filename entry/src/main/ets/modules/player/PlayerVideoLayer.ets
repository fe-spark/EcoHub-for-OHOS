import { PlayerScaleMode } from './PlayerScale';

@Component
export struct PlayerVideoLayer {
  private static readonly SURFACE_ID: string = 'eco_player_surface';
  private static readonly FULL_PERCENT: string = '100%';
  private static readonly BG_COLOR: string = '#000000';

  @Prop poster: string = '';
  @Prop ready: boolean = false;
  @Prop opening: boolean = true;
  @Prop videoWidth: number = 0;
  @Prop videoHeight: number = 0;
  @Prop scaleMode: number = PlayerScaleMode.FIT;
  @Prop isFull: boolean = false;
  onXComponentLoad?: (context: object, surfaceId: string) => void;
  xComponentController: XComponentController = new XComponentController();
  @State private containerW: number = 0;
  @State private containerH: number = 0;

  private isPortraitVideo(): boolean {
    return this.videoHeight > 0 && this.videoWidth > 0 && this.videoHeight > this.videoWidth;
  }

  private getVideoRatio(): number {
    if (this.videoWidth > 0 && this.videoHeight > 0) {
      return this.videoWidth / this.videoHeight;
    }
    return this.isPortraitVideo() ? (9 / 16) : (16 / 9);
  }

  private isWideContainer(): boolean {
    if (this.containerW > 0 && this.containerH > 0) {
      return (this.containerW / this.containerH) > this.getVideoRatio();
    }
    return this.isFull;
  }

  private getTargetWidth(): Length | undefined {
    if (this.scaleMode === PlayerScaleMode.STRETCH) {
      return PlayerVideoLayer.FULL_PERCENT;
    }
    if (this.scaleMode === PlayerScaleMode.COVER) {
      // 填充 (COVER)：
      // 1. 全屏时（容器比 16:9 视频更宽）：必须锁宽 100%，高度等比放大超出上下裁切，消灭左右黑边！
      // 2. 分栏时（容器比 16:9 视频更窄）：锁高 100%，宽度等比放大超出左右裁切，消灭上下黑边（当前确认正确）
      return this.isWideContainer() ? PlayerVideoLayer.FULL_PERCENT : undefined;
    }
    // 适应 (FIT)：全屏下锁高 100% 居中，左右留黑边；分栏下锁宽 100% 居中，上下留黑边
    return this.isWideContainer() ? undefined : PlayerVideoLayer.FULL_PERCENT;
  }

  private getTargetHeight(): Length | undefined {
    if (this.scaleMode === PlayerScaleMode.STRETCH) {
      return PlayerVideoLayer.FULL_PERCENT;
    }
    if (this.scaleMode === PlayerScaleMode.COVER) {
      // 填充 (COVER)：全屏下高度等比放大超出裁切；分栏下高度锁满 100%
      return this.isWideContainer() ? undefined : PlayerVideoLayer.FULL_PERCENT;
    }
    // 适应 (FIT)：全屏下高度锁 100%；分栏下由宽高比自适应
    return this.isWideContainer() ? PlayerVideoLayer.FULL_PERCENT : undefined;
  }
  build() {
    Stack({ alignContent: Alignment.Center }) {
      XComponent({
        id: PlayerVideoLayer.SURFACE_ID,
        type: XComponentType.SURFACE,
        libraryname: 'ijkplayer_napi',
        controller: this.xComponentController
      })
        .width(this.getTargetWidth())
        .height(this.getTargetHeight())
        .aspectRatio(
          this.scaleMode === PlayerScaleMode.STRETCH
            ? undefined
            : (this.videoWidth > 0 && this.videoHeight > 0
                ? (this.videoWidth / this.videoHeight)
                : (this.isPortraitVideo() ? (9 / 16) : (16 / 9)))
        )
        .constraintSize(
          this.scaleMode === PlayerScaleMode.COVER
            ? { minWidth: PlayerVideoLayer.FULL_PERCENT, minHeight: PlayerVideoLayer.FULL_PERCENT }
            : { maxWidth: PlayerVideoLayer.FULL_PERCENT, maxHeight: PlayerVideoLayer.FULL_PERCENT }
        )
        .hitTestBehavior(HitTestMode.None)
        .onLoad((context) => {
          console.info(`[PlayerVideoLayer] XComponent onLoad, context=${!!context}`);
          if (this.onXComponentLoad && context) {
            this.onXComponentLoad(context, PlayerVideoLayer.SURFACE_ID);
          }
        })

      if (!this.ready || this.opening) {
        if (this.poster) {
          Image(this.poster)
            .width(PlayerVideoLayer.FULL_PERCENT)
            .height(PlayerVideoLayer.FULL_PERCENT)
            .objectFit(ImageFit.Contain)
            .backgroundColor(PlayerVideoLayer.BG_COLOR)
            .hitTestBehavior(HitTestMode.None)
        } else {
          Stack()
            .width(PlayerVideoLayer.FULL_PERCENT)
            .height(PlayerVideoLayer.FULL_PERCENT)
            .backgroundColor(PlayerVideoLayer.BG_COLOR)
            .hitTestBehavior(HitTestMode.None)
        }
      }
    }
    .width(PlayerVideoLayer.FULL_PERCENT)
    .height(PlayerVideoLayer.FULL_PERCENT)
    .backgroundColor(PlayerVideoLayer.BG_COLOR)
    .clip(true)
    .onAreaChange((_old: Area, area: Area) => {
      const w = Number(area.width);
      const h = Number(area.height);
      if (w > 0 && h > 0 && (this.containerW !== w || this.containerH !== h)) {
        this.containerW = w;
        this.containerH = h;
      }
    })
  }
}
