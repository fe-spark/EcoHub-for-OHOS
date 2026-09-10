import { AppTheme } from '../../common/constants/AppTheme';
import { BackIcon } from '../common/BackIcon';

export interface FilterSelectedTag {
  key: string;
  label: string;
}

@Component
export struct FilterNavHeader {
  @Prop total: number = 0;
  @Prop tags: FilterSelectedTag[] = [];
  onBack: () => void = () => {};

  build() {
    Row() {
      Row() {
        BackIcon({ color: AppTheme.TEXT_PRIMARY, iconSize: 24 })
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.onBack();
      })

      List({ space: AppTheme.SPACE_SM }) {
        ForEach(this.tags, (tag: FilterSelectedTag) => {
          ListItem() {
            Text(tag.label)
              .fontSize(12)
              .fontColor(AppTheme.ACCENT)
              .height(28)
              .padding({ left: AppTheme.SPACE_MD, right: AppTheme.SPACE_MD })
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: AppTheme.ACCENT })
              .borderRadius(AppTheme.RADIUS_PILL)
          }
        }, (tag: FilterSelectedTag) => `nav_tag_${tag.key}`)
      }
      .listDirection(Axis.Horizontal)
      .layoutWeight(1)
      .constraintSize({ minWidth: 0 })
      .height(28)
      .contentEndOffset(AppTheme.SPACE_SM)
      .scrollBar(BarState.Off)
      .nestedScroll({
        scrollForward: NestedScrollMode.SELF_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })
      .alignListItem(ListItemAlign.Center)
      .margin({ left: AppTheme.SPACE_XS })

      if (this.total > 0) {
        Text(`共 ${this.total} 部`)
          .fontSize(12)
          .fontColor(AppTheme.TEXT_MUTED)
          .margin({ left: AppTheme.SPACE_SM })
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: AppTheme.SPACE_SM, right: AppTheme.SPACE_LG })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.BG)
  }
}
