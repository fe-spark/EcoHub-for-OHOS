import { AppTheme } from '../common/constants/AppTheme';
import { AppIcon } from './AppIcon';
import { PlayerTipKind } from '../common/utils/PlayerPan';

@Component
export struct PlayerTip {
  @Prop message: string = '';
  @Prop kind: number = PlayerTipKind.NONE;
  @Prop speedTick: number = 0;

  private iconSrc(): Resource {
    if (this.kind === PlayerTipKind.SEEK_BACK) {
      return $r('sys.symbol.chevron_left');
    }
    if (this.kind === PlayerTipKind.SEEK_FWD) {
      return $r('sys.symbol.chevron_right');
    }
    if (this.kind === PlayerTipKind.BRIGHT) {
      return $r('sys.symbol.sun_max');
    }
    if (this.kind === PlayerTipKind.VOLUME) {
      return this.message === '0%' ? $r('sys.symbol.speaker_slash') : $r('sys.symbol.speaker_wave_2');
    }
    return $r('sys.symbol.play_fill');
  }

  @Builder
  speedIcons() {
    Row() {
      AppIcon({ src: $r('sys.symbol.play_fill'), iconSize: 16, color: '#FFFFFF' })
        .opacity(this.speedTick === 0 ? 1 : 0.28)
      AppIcon({ src: $r('sys.symbol.play_fill'), iconSize: 16, color: '#FFFFFF' })
        .opacity(this.speedTick === 1 ? 1 : 0.28)
        .margin({ left: 1 })
      AppIcon({ src: $r('sys.symbol.play_fill'), iconSize: 16, color: '#FFFFFF' })
        .opacity(this.speedTick === 2 ? 1 : 0.28)
        .margin({ left: 1 })
    }
  }

  build() {
    Row({ space: 8 }) {
      if (this.kind === PlayerTipKind.SPEED) {
        this.speedIcons()
      } else if (this.kind !== PlayerTipKind.NONE) {
        AppIcon({ src: this.iconSrc(), iconSize: 18, color: 'rgba(255,255,255,0.9)' })
          .key(`${this.kind}_${this.message}`)
      }
      Text(this.message)
        .fontSize(this.kind === PlayerTipKind.SPEED ? 13 : 16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
    }
    .constraintSize({ minHeight: 38 })
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor('rgba(0,0,0,0.74)')
    .borderRadius(999)
    .shadow({
      radius: 14,
      color: 'rgba(0,0,0,0.22)',
      offsetX: 0,
      offsetY: 8
    })
    .hitTestBehavior(HitTestMode.None)
  }
}

@Component
export struct PlayerLoadingCard {
  @Prop opening: boolean = false;

  build() {
    Row({ space: 12 }) {
      LoadingProgress().width(20).height(20).color('#FFFFFF')
      Text(this.opening ? '正在打开...' : '加载中...')
        .fontSize(14)
        .fontColor('#FFFFFF')
    }
    .padding({ left: 18, right: 18, top: 14, bottom: 14 })
    .backgroundColor('rgba(0,0,0,0.78)')
    .borderRadius(16)
    .hitTestBehavior(HitTestMode.None)
  }
}

@Component
export struct PlayerErrorPad {
  onRetry?: () => void;
  onErrorDetail?: () => void;

  build() {
    Column() {
      Text('播放异常')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
      Text('视频无法播放，请重试！')
        .fontSize(13)
        .fontColor('rgba(255,255,255,0.82)')
        .margin({ top: 8 })
      Row({ space: 10 }) {
        Text('重新播放')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .height(36)
          .padding({ left: 16, right: 16 })
          .backgroundColor(AppTheme.ACCENT)
          .borderRadius(18)
          .onClick(() => {
            if (this.onRetry) {
              this.onRetry();
            }
          })
        Text('查看详情')
          .fontSize(13)
          .fontColor('#FFFFFF')
          .height(36)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: 'rgba(255,255,255,0.16)' })
          .borderRadius(18)
          .onClick(() => {
            if (this.onErrorDetail) {
              this.onErrorDetail();
            }
          })
      }
      .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(20)
  }
}

@Component
export struct PlayerSpeedSheet {
  @Prop speedLabel: string = '1.0x';
  onCloseSpeed?: () => void;
  onPickSpeed?: (index: number) => void;

  build() {
    Column() {
      Column()
        .width('100%')
        .layoutWeight(1)
        .onClick(() => {
          if (this.onCloseSpeed) {
            this.onCloseSpeed();
          }
        })
      Column() {
        Row() {
          Text('播放速度')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Blank()
          Text(`当前 ${this.speedLabel}`)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ACCENT)
        }
        .width('100%')
        Text('点击后立即生效')
          .fontSize(12)
          .fontColor('rgba(255,255,255,0.55)')
          .margin({ top: 6, bottom: 12 })
          .width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(['0.75x', '1.0x', '1.25x', '1.75x', '2.0x'], (label: string, index: number) => {
            Text(label)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .width(80)
              .height(40)
              .textAlign(TextAlign.Center)
              .margin({ right: 8, bottom: 8 })
              .backgroundColor(this.speedLabel === label ? AppTheme.ACCENT : 'rgba(255,255,255,0.08)')
              .borderRadius(12)
              .onClick(() => {
                if (this.onPickSpeed) {
                  this.onPickSpeed(index);
                }
              })
          }, (label: string) => `spd_${label}`)
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#191B20')
      .borderRadius(20)
      .margin({ left: 12, right: 12, bottom: 12 })
    }
    .width('100%')
    .height('100%')
  }
}