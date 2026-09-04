import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from './AppIcon';

@CustomDialog
export struct FilmDetailDialog {
  controller?: CustomDialogController;
  name: string = '';
  scoreText: string = '';
  tags: string[] = [];
  director: string = '';
  actor: string = '';
  plot: string = '';
  @StorageLink('SAFE_INSET_BOTTOM') private bottomInset: number = 16;
  @StorageLink('WINDOW_HEIGHT') private windowHeight: number = 640;

  private isLandscape(): boolean {
    return this.windowHeight > 0 && this.windowHeight < 500;
  }

  build() {
    Column() {
      // 顶部拖拽指示把手
      Column()
        .width(36)
        .height(4)
        .borderRadius(2)
        .backgroundColor('rgba(255, 255, 255, 0.22)')
        .margin({ top: 8, bottom: 12 })
        .alignSelf(ItemAlign.Center)

      // 标题栏：详细信息 + 关闭按钮
      Row() {
        Row({ space: 6 }) {
          AppIcon({
            src: $r('sys.symbol.doc_plaintext'),
            iconSize: 18,
            color: AppTheme.ACCENT
          })
          Text('详细信息')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT_PRIMARY)
        }
        .alignItems(VerticalAlign.Center)

        Blank()

        Row() {
          AppIcon({
            src: $r('sys.symbol.xmark'),
            iconSize: 14,
            color: AppTheme.TEXT_SECONDARY
          })
        }
        .width(30)
        .height(30)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(255, 255, 255, 0.08)')
        .borderRadius(15)
        .onClick(() => {
          if (this.controller) {
            this.controller.close();
          }
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 12 })

      // 影片简要信息卡片
      Column() {
        // 标题与评分行
        Row() {
          Text(this.name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .layoutWeight(1)

          if (this.scoreText !== '') {
            Row({ space: 2 }) {
              Text('★')
                .fontSize(10)
                .fontColor(AppTheme.ACCENT)
              Text(this.scoreText)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.ACCENT)
              Text('分')
                .fontSize(9)
                .fontColor(AppTheme.ACCENT)
            }
            .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .backgroundColor(AppTheme.ACCENT_SOFT)
            .borderRadius(AppTheme.RADIUS_SM)
            .margin({ left: 8 })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: this.tags.length > 0 ? 8 : 0 })

        // 影视标签组（独立排版，自动折行）
        if (this.tags.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.tags, (tag: string) => {
              Text(tag)
                .fontSize(11)
                .fontColor(AppTheme.TEXT_SECONDARY)
                .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                .backgroundColor(AppTheme.BG_CHIP)
                .borderRadius(AppTheme.RADIUS_SM)
                .margin({ right: 6, bottom: 6 })
            }, (tag: string) => tag)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: this.tags.length > 0 ? 6 : 12 })
      .backgroundColor(AppTheme.BG_CARD)
      .borderRadius(AppTheme.RADIUS_MD)
      .margin({ bottom: 12 })

      // 详细内容区域：Scroll 内部不裁切、不省略、自由滚动
      Scroll() {
        Column({ space: 14 }) {
          if (this.director !== '') {
            Column({ space: 6 }) {
              Row({ space: 5 }) {
                Column()
                  .width(3)
                  .height(12)
                  .backgroundColor(AppTheme.ACCENT)
                  .borderRadius(1.5)
                Text('导演')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.TEXT_PRIMARY)
              }
              .alignItems(VerticalAlign.Center)

              Text(this.director)
                .fontSize(13)
                .fontColor(AppTheme.TEXT_PRIMARY)
                .lineHeight(20)
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(10)
            .backgroundColor(AppTheme.BG_CARD)
            .borderRadius(AppTheme.RADIUS_MD)
          }

          if (this.actor !== '') {
            Column({ space: 6 }) {
              Row({ space: 5 }) {
                Column()
                  .width(3)
                  .height(12)
                  .backgroundColor(AppTheme.ACCENT)
                  .borderRadius(1.5)
                Text('主演')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.TEXT_PRIMARY)
              }
              .alignItems(VerticalAlign.Center)

              Text(this.actor)
                .fontSize(13)
                .fontColor(AppTheme.TEXT_PRIMARY)
                .lineHeight(20)
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(10)
            .backgroundColor(AppTheme.BG_CARD)
            .borderRadius(AppTheme.RADIUS_MD)
          }

          if (this.plot !== '') {
            Column({ space: 6 }) {
              Row({ space: 5 }) {
                Column()
                  .width(3)
                  .height(12)
                  .backgroundColor(AppTheme.ACCENT)
                  .borderRadius(1.5)
                Text('剧情简介')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.TEXT_PRIMARY)
              }
              .alignItems(VerticalAlign.Center)

              Text(this.plot)
                .fontSize(13)
                .fontColor(AppTheme.TEXT_SECONDARY)
                .lineHeight(22)
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(10)
            .backgroundColor(AppTheme.BG_CARD)
            .borderRadius(AppTheme.RADIUS_MD)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ bottom: 4 })
      }
      .layoutWeight(1)
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .constraintSize({ minHeight: 60, maxHeight: this.isLandscape() ? 150 : '56%' })

      // 底部确认关闭主按钮
      Button('我知道了')
        .width('100%')
        .height(this.isLandscape() ? 36 : 40)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT_PRIMARY)
        .backgroundColor(AppTheme.ACCENT)
        .borderRadius(AppTheme.RADIUS_PILL)
        .margin({ top: this.isLandscape() ? 8 : 12 })
        .onClick(() => {
          if (this.controller) {
            this.controller.close();
          }
        })
    }
    .width('100%')
    .constraintSize({ maxWidth: 600, maxHeight: '88%' })
    .padding({ left: 16, right: 16, top: 4, bottom: Math.max(16, this.bottomInset) })
    .backgroundColor('#181A22')
    .borderRadius({ topLeft: 20, topRight: 20 })
    .alignItems(HorizontalAlign.Start)
  }
}
