import { PlayerScale, PlayerScaleMode } from '../common/utils/PlayerScale';

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
  onSurfaceCreated?: (surfaceId: string) => void;
  private xComponentController: XComponentController = new XComponentController();
  @State private layerW: number = 0;
  @State private layerH: number = 0;

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
    const W = this.layerW > 0 ? this.layerW : this.containerWidth;
    const H = this.layerH > 0 ? this.layerH : this.containerHeight;
    const hasLayer = W > 0 && H > 0;
    const hasVideo = this.videoWidth > 0 && this.videoHeight > 0;
    const isPortrait = this.isPortraitMode(hasVideo, hasLayer, W, H);
    const fallbackRatio: number = isPortrait ? PlayerScale.RATIO_9_16 : PlayerScale.RATIO_16_9;
    const videoRatio: number = hasVideo ? (this.videoWidth / this.videoHeight) : fallbackRatio;
    const containerRatio: number = hasLayer ? (W / H) : fallbackRatio;
    return { W, H, hasLayer, isPortrait, videoRatio, containerRatio };
  }

  private calcTargetWidth(): Length {
    const d = this.getDimensions();
    if (!d.hasLayer) {
      return PlayerVideoLayer.FULL_PERCENT;
    }
    if (d.videoRatio >= d.containerRatio) {
      return d.W;
    }
    return d.H * d.videoRatio;
  }

  private calcTargetHeight(): Length {
    const d = this.getDimensions();
    if (!d.hasLayer) {
      return PlayerVideoLayer.FULL_PERCENT;
    }
    if (d.videoRatio >= d.containerRatio) {
      return d.W / d.videoRatio;
    }
    return d.H;
  }

  private calcScaleX(): number {
    const d = this.getDimensions();
    if (!d.hasLayer || this.scaleMode === PlayerScaleMode.FIT) {
      return 1;
    }
    const baseW = d.videoRatio >= d.containerRatio ? d.W : d.H * d.videoRatio;
    if (baseW <= 0) {
      return 1;
    }
    if (this.scaleMode === PlayerScaleMode.COVER) {
      const baseH = d.videoRatio >= d.containerRatio ? d.W / d.videoRatio : d.H;
      if (baseH <= 0) {
        return 1;
      }
      return d.videoRatio >= d.containerRatio ? (d.H / baseH) : (d.W / baseW);
    }
    if (this.scaleMode === PlayerScaleMode.STRETCH) {
      return d.W / baseW;
    }
    return 1;
  }

  private calcScaleY(): number {
    const d = this.getDimensions();
    if (!d.hasLayer || this.scaleMode === PlayerScaleMode.FIT) {
      return 1;
    }
    const baseH = d.videoRatio >= d.containerRatio ? d.W / d.videoRatio : d.H;
    if (baseH <= 0) {
      return 1;
    }
    if (this.scaleMode === PlayerScaleMode.COVER) {
      const baseW = d.videoRatio >= d.containerRatio ? d.W : d.H * d.videoRatio;
      if (baseW <= 0) {
        return 1;
      }
      return d.videoRatio >= d.containerRatio ? (d.H / baseH) : (d.W / baseW);
    }
    if (this.scaleMode === PlayerScaleMode.STRETCH) {
      return d.H / baseH;
    }
    return 1;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      XComponent({
        id: PlayerVideoLayer.SURFACE_ID,
        type: XComponentType.SURFACE,
        controller: this.xComponentController
      })
        .width(this.calcTargetWidth())
        .height(this.calcTargetHeight())
        .scale({
          x: this.calcScaleX(),
          y: this.calcScaleY()
        })
        .hitTestBehavior(HitTestMode.None)
        .onLoad(() => {
          try {
            const sId = this.xComponentController.getXComponentSurfaceId();
            console.info(`[PlayerVideoLayer] XComponent onLoad 成功获取 surfaceId: ${sId}`);
            if (sId && this.onSurfaceCreated) {
              this.onSurfaceCreated(sId);
            }
          } catch (e) {
            console.error(`[PlayerVideoLayer] 获取 surfaceId 异常: ${JSON.stringify(e)}`);
          }
        })

      if (this.poster && (!this.ready || this.opening)) {
        Image(this.poster)
          .width(PlayerVideoLayer.FULL_PERCENT)
          .height(PlayerVideoLayer.FULL_PERCENT)
          .objectFit(ImageFit.Contain)
          .backgroundColor(PlayerVideoLayer.BG_COLOR)
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width(PlayerVideoLayer.FULL_PERCENT)
    .height(PlayerVideoLayer.FULL_PERCENT)
    .backgroundColor(PlayerVideoLayer.BG_COLOR)
    .clip(true)
    .onAreaChange((_old: Area, area: Area) => {
      this.layerW = Number(area.width);
      this.layerH = Number(area.height);
    })
  }
}
