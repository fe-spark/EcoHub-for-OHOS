export enum PlayerScaleMode {
  FIT = 0,
  COVER = 1,
  STRETCH = 2
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

  static readonly LABEL_FIT: string = '适应';
  static readonly LABEL_COVER: string = '填充';
  static readonly LABEL_STRETCH: string = '拉伸';

  static readonly DESC_FIT: string = '保持比例';
  static readonly DESC_COVER: string = '裁剪铺满';
  static readonly DESC_STRETCH: string = '全屏拉伸';

  static items(_isPortrait: boolean = false): PlayerScaleItem[] {
    return [
      { mode: PlayerScaleMode.FIT, label: PlayerScale.LABEL_FIT, desc: PlayerScale.DESC_FIT },
      { mode: PlayerScaleMode.COVER, label: PlayerScale.LABEL_COVER, desc: PlayerScale.DESC_COVER },
      { mode: PlayerScaleMode.STRETCH, label: PlayerScale.LABEL_STRETCH, desc: PlayerScale.DESC_STRETCH }
    ];
  }

  static label(mode: PlayerScaleMode, _isPortrait: boolean = false): string {
    if (mode === PlayerScaleMode.COVER) {
      return PlayerScale.LABEL_COVER;
    }
    if (mode === PlayerScaleMode.STRETCH) {
      return PlayerScale.LABEL_STRETCH;
    }
    return PlayerScale.LABEL_FIT;
  }

  static desc(mode: PlayerScaleMode, _isPortrait: boolean = false): string {
    if (mode === PlayerScaleMode.COVER) {
      return PlayerScale.DESC_COVER;
    }
    if (mode === PlayerScaleMode.STRETCH) {
      return PlayerScale.DESC_STRETCH;
    }
    return PlayerScale.DESC_FIT;
  }

  static next(mode: PlayerScaleMode): PlayerScaleMode {
    if (mode === PlayerScaleMode.FIT) {
      return PlayerScaleMode.COVER;
    }
    if (mode === PlayerScaleMode.COVER) {
      return PlayerScaleMode.STRETCH;
    }
    return PlayerScaleMode.FIT;
  }
}
