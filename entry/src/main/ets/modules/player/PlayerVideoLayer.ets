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
  onXComponentLoad?: (context: object, surfaceId: string) => void;
  xComponentController: XComponentController = new XComponentController();

  private isPortraitVideo(): boolean {
    return this.videoHeight > 0 && this.videoWidth > 0 && this.videoHeight > this.videoWidth;
  }

  private getTargetWidth(): Length | undefined {
    if (this.scaleMode === PlayerScaleMode.STRETCH) {
      return PlayerVideoLayer.FULL_PERCENT;
    }
    if (this.scaleMode === PlayerScaleMode.COVER) {
      // 填充 (COVER)：竖屏视频锁定宽度为 100%，高度等比放大超出裁剪；横屏视频由高度决定
      return this.isPortraitVideo() ? PlayerVideoLayer.FULL_PERCENT : undefined;
    }
    // 适应 (FIT)：横屏视频锁宽 100%，竖屏视频留黑边
    return this.isPortraitVideo() ? undefined : PlayerVideoLayer.FULL_PERCENT;
  }

  private getTargetHeight(): Length | undefined {
    if (this.scaleMode === PlayerScaleMode.STRETCH) {
      return PlayerVideoLayer.FULL_PERCENT;
    }
    if (this.scaleMode === PlayerScaleMode.COVER) {
      // 填充 (COVER)：横屏视频锁定高度为 100%，宽度等比放大超出裁剪；竖屏视频由宽度决定
      return this.isPortraitVideo() ? undefined : PlayerVideoLayer.FULL_PERCENT;
    }
    // 适应 (FIT)：竖屏视频锁高 100%，横屏视频留黑边
    return this.isPortraitVideo() ? PlayerVideoLayer.FULL_PERCENT : undefined;
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
                : undefined)
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
  }
}
