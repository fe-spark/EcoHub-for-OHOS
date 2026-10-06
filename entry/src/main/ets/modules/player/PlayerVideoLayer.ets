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
  onSurfaceCreated?: (surfaceId: string) => void;
  xComponentController: XComponentController = new XComponentController();
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

  private calcTargetWidth(): string {
    const d = this.getDimensions();
    if (!d.hasLayer || d.videoRatio <= 0 || d.containerRatio <= 0 || d.videoRatio >= d.containerRatio) {
      return PlayerVideoLayer.FULL_PERCENT;
    }
    const pct = Math.min(100, (d.videoRatio / d.containerRatio) * 100);
    return `${pct}%`;
  }

  private calcTargetHeight(): string {
    const d = this.getDimensions();
    if (!d.hasLayer || d.videoRatio <= 0 || d.containerRatio <= 0 || d.videoRatio < d.containerRatio) {
      return PlayerVideoLayer.FULL_PERCENT;
    }
    const pct = Math.min(100, (d.containerRatio / d.videoRatio) * 100);
    return `${pct}%`;
  }

  private letterbox(): boolean {
    return this.scaleMode === PlayerScaleMode.FIT && !PlayerScale.useNativeAspect();
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      XComponent({
        id: PlayerVideoLayer.SURFACE_ID,
        type: XComponentType.SURFACE,
        controller: this.xComponentController
      })
        .width(this.letterbox() ? this.calcTargetWidth() : PlayerVideoLayer.FULL_PERCENT)
        .height(this.letterbox() ? this.calcTargetHeight() : PlayerVideoLayer.FULL_PERCENT)
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
