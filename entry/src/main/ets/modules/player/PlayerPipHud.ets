import { AppIcon } from '../../components/common/AppIcon';
import { PlayerBackBtn } from './PlayerControl';

@Component
export struct PlayerPipHud {
  @Prop poster: string = '';
  @Prop showBack: boolean = false;
  @Prop topInset: number = 0;
  @Prop leftInset: number = 0;
  @Prop rightInset: number = 0;
  onBack?: () => void;
  onRestore?: () => void;

  private edge(base: number, inset: number): number {
    return Math.max(base, inset);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 底层：模糊封面背景
      if (this.poster && this.poster.trim().length > 0) {
        Image(this.poster)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .blur(20)
          .opacity(0.38)
      }

      // 暗色底色
      Rect()
        .width('100%')
        .height('100%')
        .fill('rgba(0, 0, 0, 0.62)')

      // 2. 中间提示与恢复控制卡片
      Column({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 54, height: 54 })
            .fill('rgba(255, 255, 255, 0.10)')
            .stroke('rgba(255, 255, 255, 0.18)')
            .strokeWidth(1)

          AppIcon({
            src: $r('sys.symbol.smal_window_playback'),
            iconSize: 28,
            color: '#FFFFFF'
          })
        }

        Text('正在画中画播放中')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255, 255, 255, 0.90)')

        Button({ type: ButtonType.Capsule }) {
          Row({ space: 6 }) {
            AppIcon({
              src: $r('sys.symbol.arrow_down_right_and_arrow_up_left'),
              iconSize: 13,
              color: '#FFFFFF'
            })
            Text('恢复原位播放')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
          }
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        }
        .backgroundColor('rgba(255, 255, 255, 0.16)')
        .borderWidth(0.5)
        .borderColor('rgba(255, 255, 255, 0.28)')
        .onClick(() => {
          if (this.onRestore) {
            this.onRestore();
          }
        })
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 3. 顶栏返回按钮
      if (this.showBack) {
        Row() {
          PlayerBackBtn({ onTap: this.onBack })
          Blank()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({
          left: this.edge(4, this.leftInset),
          right: this.edge(4, this.rightInset),
          top: this.edge(4, this.topInset)
        })
        .position({ x: 0, y: 0 })
        .zIndex(100)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .clip(true)
    .onClick(() => {
      if (this.onRestore) {
        this.onRestore();
      }
    })
  }
}
