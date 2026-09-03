export enum PlayerScaleMode {
  FIT = 0,
  COVER = 1,
  STRETCH = 2,
  RATIO_16_9 = 3,
  RATIO_4_3 = 4
}

export interface PlayerScaleItem {
  mode: PlayerScaleMode;
  label: string;
  desc: string;
}

export class PlayerScale {
  static readonly DEFAULT_MODE: PlayerScaleMode = PlayerScaleMode.FIT;

  static readonly RATIO_16_9: number = 16 / 9;
  static readonly RATIO_9_16: number = 9 / 16;
  static readonly RATIO_4_3: number = 4 / 3;
  static readonly RATIO_3_4: number = 3 / 4;

  static readonly LABEL_FIT: string = '适应';
  static readonly LABEL_COVER: string = '填充';
  static readonly LABEL_STRETCH: string = '拉伸';
  static readonly LABEL_16_9: string = '16:9';
  static readonly LABEL_9_16: string = '9:16';
  static readonly LABEL_4_3: string = '4:3';
  static readonly LABEL_3_4: string = '3:4';

  static readonly DESC_FIT: string = '保持比例';
  static readonly DESC_COVER: string = '裁剪铺满';
  static readonly DESC_STRETCH: string = '全屏拉伸';
  static readonly DESC_16_9: string = '标准宽屏';
  static readonly DESC_9_16: string = '标准竖屏';
  static readonly DESC_4_3: string = '经典画幅';
  static readonly DESC_3_4: string = '经典竖幅';

  static items(isPortrait: boolean = false): PlayerScaleItem[] {
    return [
      { mode: PlayerScaleMode.FIT, label: PlayerScale.LABEL_FIT, desc: PlayerScale.DESC_FIT },
      { mode: PlayerScaleMode.COVER, label: PlayerScale.LABEL_COVER, desc: PlayerScale.DESC_COVER },
      { mode: PlayerScaleMode.STRETCH, label: PlayerScale.LABEL_STRETCH, desc: PlayerScale.DESC_STRETCH },
      {
        mode: PlayerScaleMode.RATIO_16_9,
        label: isPortrait ? PlayerScale.LABEL_9_16 : PlayerScale.LABEL_16_9,
        desc: isPortrait ? PlayerScale.DESC_9_16 : PlayerScale.DESC_16_9
      },
      {
        mode: PlayerScaleMode.RATIO_4_3,
        label: isPortrait ? PlayerScale.LABEL_3_4 : PlayerScale.LABEL_4_3,
        desc: isPortrait ? PlayerScale.DESC_3_4 : PlayerScale.DESC_4_3
      }
    ];
  }

  static label(mode: PlayerScaleMode, isPortrait: boolean = false): string {
    if (mode === PlayerScaleMode.RATIO_16_9) {
      return isPortrait ? PlayerScale.LABEL_9_16 : PlayerScale.LABEL_16_9;
    }
    if (mode === PlayerScaleMode.RATIO_4_3) {
      return isPortrait ? PlayerScale.LABEL_3_4 : PlayerScale.LABEL_4_3;
    }
    if (mode === PlayerScaleMode.COVER) {
      return PlayerScale.LABEL_COVER;
    }
    if (mode === PlayerScaleMode.STRETCH) {
      return PlayerScale.LABEL_STRETCH;
    }
    return PlayerScale.LABEL_FIT;
  }

  static desc(mode: PlayerScaleMode, isPortrait: boolean = false): string {
    if (mode === PlayerScaleMode.RATIO_16_9) {
      return isPortrait ? PlayerScale.DESC_9_16 : PlayerScale.DESC_16_9;
    }
    if (mode === PlayerScaleMode.RATIO_4_3) {
      return isPortrait ? PlayerScale.DESC_3_4 : PlayerScale.DESC_4_3;
    }
    if (mode === PlayerScaleMode.COVER) {
      return PlayerScale.DESC_COVER;
    }
    if (mode === PlayerScaleMode.STRETCH) {
      return PlayerScale.DESC_STRETCH;
    }
    return PlayerScale.DESC_FIT;
  }
}
