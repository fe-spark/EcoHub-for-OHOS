@Component
export struct PlayerVideoLayer {
  @Prop poster: string = '';
  @Prop ready: boolean = false;
  @Prop opening: boolean = true;
  @Prop videoWidth: number = 0;
  @Prop videoHeight: number = 0;
  onSurfaceCreated?: (surfaceId: string) => void;
  private xComponentController: XComponentController = new XComponentController();

  build() {
    Stack({ alignContent: Alignment.Center }) {
      XComponent({
        id: 'eco_player_surface',
        type: XComponentType.SURFACE,
        controller: this.xComponentController
      })
        .aspectRatio(this.videoWidth > 0 && this.videoHeight > 0 ? this.videoWidth / this.videoHeight : undefined)
        .width(this.videoWidth > 0 && this.videoHeight > 0 ? undefined : '100%')
        .height(this.videoWidth > 0 && this.videoHeight > 0 ? undefined : '100%')
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
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .backgroundColor('#000000')
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}

