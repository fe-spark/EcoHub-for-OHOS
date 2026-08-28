import { PlayerSpeed } from '../common/utils/PlayerSpeed';

@Component
export struct PlayerVideoLayer {
  @Prop playSrc: string = '';
  @Prop poster: string = '';
  @Prop speedIndex: number = 1;
  @Prop autoPlay: boolean = true;
  @Prop muted: boolean = false;
  @Prop nonce: number = 0;
  controller: VideoController = new VideoController();
  onPreparedCallback?: (info: PreparedInfo) => void;
  onStartCallback?: () => void;
  onPauseCallback?: () => void;
  onUpdateCallback?: (info: PlaybackInfo) => void;
  onSeekingCallback?: () => void;
  onSeekedCallback?: () => void;
  onFinishCallback?: () => void;
  onErrorCallback?: () => void;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.playSrc) {
        Video({
          src: this.playSrc,
          previewUri: this.poster,
          controller: this.controller,
          currentProgressRate: PlayerSpeed.of(this.speedIndex)
        })
          .id(`eco_player_${this.nonce}`)
          .width('100%')
          .height('100%')
          .autoPlay(this.autoPlay)
          .controls(false)
          .muted(this.muted)
          .objectFit(ImageFit.Contain)
          .backgroundColor('#000000')
          .hitTestBehavior(HitTestMode.None)
          .onPrepared((info: PreparedInfo) => {
            if (this.onPreparedCallback) {
              this.onPreparedCallback(info);
            }
          })
          .onStart(() => {
            if (this.onStartCallback) {
              this.onStartCallback();
            }
          })
          .onPause(() => {
            if (this.onPauseCallback) {
              this.onPauseCallback();
            }
          })
          .onUpdate((info: PlaybackInfo) => {
            if (this.onUpdateCallback) {
              this.onUpdateCallback(info);
            }
          })
          .onSeeking(() => {
            if (this.onSeekingCallback) {
              this.onSeekingCallback();
            }
          })
          .onSeeked(() => {
            if (this.onSeekedCallback) {
              this.onSeekedCallback();
            }
          })
          .onFinish(() => {
            if (this.onFinishCallback) {
              this.onFinishCallback();
            }
          })
          .onError(() => {
            if (this.onErrorCallback) {
              this.onErrorCallback();
            }
          })
      } else if (this.poster) {
        Image(this.poster)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .opacity(0.35)
      } else {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
      }
    }
    .width('100%')
    .height('100%')
  }
}
