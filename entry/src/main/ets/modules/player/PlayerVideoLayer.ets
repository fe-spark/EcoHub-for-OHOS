import { PlayerScale, PlayerScaleMode } from './PlayerScale';

interface VideoDimensions {
  W: number;
  H: number;
  hasLayer: boolean;
  isPortrait: boolean;
  videoRatio: number;
  containerRatio: number;
}

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
  @Prop containerWidth: number = 0;
  @Prop containerHeight: number = 0;
  onXComponentLoad?: (context: object, surfaceId: string) => void;
  xComponentController: XComponentController = new XComponentController();


  private isPortraitMode(hasVideo: boolean, hasLayer: boolean, W: number, H: number): boolean {
    if (hasVideo) {
      return this.videoHeight > this.videoWidth;
    }
    if (hasLayer && H > W) {
      return true;
    }
    return false;
  }

  private getDimensions(): VideoDimensions {
    const W = this.containerWidth;
    const H = this.containerHeight;
    const hasLayer = W > 0 && H > 0;
    const hasVideo = this.videoWidth > 0 && this.videoHeight > 0;
    const isPortrait = this.isPortraitMode(hasVideo, hasLayer, W, H);
    const fallbackRatio: number = isPortrait ? PlayerScale.RATIO_9_16 : PlayerScale.RATIO_16_9;
    const videoRatio: number = hasVideo ? (this.videoWidth / this.videoHeight) : fallbackRatio;
    const containerRatio: number = hasLayer ? (W / H) : fallbackRatio;
    return { W, H, hasLayer, isPortrait, videoRatio, containerRatio };
  }

  private getTargetWidth(): string {
    if (this.scaleMode === PlayerScaleMode.STRETCH) {
      return PlayerVideoLayer.FULL_PERCENT;
    }
    const d = this.getDimensions();
    if (!d.hasLayer || d.videoRatio <= 0 || d.containerRatio <= 0) {
      return PlayerVideoLayer.FULL_PERCENT;
    }
    if (this.scaleMode === PlayerScaleMode.COVER) {
      if (d.videoRatio > d.containerRatio) {
        const pct = (d.videoRatio / d.containerRatio) * 100;
        return `${pct}%`;
      }
      return PlayerVideoLayer.FULL_PERCENT;
    }
    // FIT 适应保持比例
    if (d.videoRatio < d.containerRatio) {
      const pct = Math.min(100, (d.videoRatio / d.containerRatio) * 100);
      return `${pct}%`;
    }
    return PlayerVideoLayer.FULL_PERCENT;
  }

  private getTargetHeight(): string {
    if (this.scaleMode === PlayerScaleMode.STRETCH) {
      return PlayerVideoLayer.FULL_PERCENT;
    }
    const d = this.getDimensions();
    if (!d.hasLayer || d.videoRatio <= 0 || d.containerRatio <= 0) {
      return PlayerVideoLayer.FULL_PERCENT;
    }
    if (this.scaleMode === PlayerScaleMode.COVER) {
      if (d.videoRatio < d.containerRatio) {
        const pct = (d.containerRatio / d.videoRatio) * 100;
        return `${pct}%`;
      }
      return PlayerVideoLayer.FULL_PERCENT;
    }
    // FIT 适应保持比例
    if (d.videoRatio > d.containerRatio) {
      const pct = Math.min(100, (d.containerRatio / d.videoRatio) * 100);
      return `${pct}%`;
    }
    return PlayerVideoLayer.FULL_PERCENT;
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
  }
}
