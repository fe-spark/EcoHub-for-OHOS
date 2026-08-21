@Component
export struct PlayerGestureLayer {
  onPlay?: () => void;
  onToggleHud?: () => void;
  onLongPress?: () => void;
  onLongPressEnd?: () => void;
  onPanStart?: (event: GestureEvent) => void;
  onPanMove?: (event: GestureEvent) => void;
  onPanEnd?: () => void;
  onPanCancel?: () => void;

  build() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(HitTestMode.Default)
      .gesture(
        GestureGroup(GestureMode.Exclusive,
          TapGesture({ count: 2 })
            .onAction(() => {
              if (this.onPlay) {
                this.onPlay();
              }
            }),
          TapGesture({ count: 1 })
            .onAction(() => {
              if (this.onToggleHud) {
                this.onToggleHud();
              }
            }),
          LongPressGesture({ repeat: false, duration: 500 })
            .onAction(() => {
              if (this.onLongPress) {
                this.onLongPress();
              }
            })
            .onActionEnd(() => {
              if (this.onLongPressEnd) {
                this.onLongPressEnd();
              }
            })
            .onActionCancel(() => {
              if (this.onLongPressEnd) {
                this.onLongPressEnd();
              }
            }),
          PanGesture({ fingers: 1, direction: PanDirection.All, distance: 18 })
            .onActionStart((event: GestureEvent) => {
              if (this.onPanStart) {
                this.onPanStart(event);
              }
            })
            .onActionUpdate((event: GestureEvent) => {
              if (this.onPanMove) {
                this.onPanMove(event);
              }
            })
            .onActionEnd(() => {
              if (this.onPanEnd) {
                this.onPanEnd();
              }
            })
            .onActionCancel(() => {
              if (this.onPanCancel) {
                this.onPanCancel();
              }
            })
        )
      )
  }
}
