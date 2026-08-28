import { PlayerSkin } from './PlayerSkin';

export interface PlayerSkinEvents {
  onBack: () => void;
  onPlay: () => void;
  onFull: () => void;
  onMute: () => void;
  onPrev: () => void;
  onNext: () => void;
  onSpeed: () => void;
  onRetry: () => void;
  onErrorDetail: () => void;
  onSeekBack: () => void;
  onSeekForward: () => void;
  onSeekStart: (val: number) => void;
  onSeekUpdate: (val: number) => void;
  onSeekEnd: (val: number) => void;
  onToggleHud: () => void;
  onLongPress: () => void;
  onLongPressEnd: () => void;
  onPanStart: (event: GestureEvent) => void;
  onPanMove: (event: GestureEvent) => void;
  onPanEnd: () => void;
  onPanCancel: () => void;
}

@Component
export struct PlayerSkinView {
  @Prop isFull: boolean = false;
  @Prop showHud: boolean = true;
  @Prop showBack: boolean = false;
  @Prop title: string = '';
  @Prop playRequested: boolean = true;
  @Prop isPlaying: boolean = false;
  @Prop completed: boolean = false;
  @Prop opening: boolean = true;
  @Prop seeking: boolean = false;
  @Prop stalled: boolean = false;
  @Prop errorText: string = '';
  @Prop currentTime: number = 0;
  @Prop duration: number = 0;
  @Prop muted: boolean = false;
  @Prop speedLabel: string = '1.0x';
  @Prop hasPrev: boolean = false;
  @Prop hasNext: boolean = false;
  @Prop longPressing: boolean = false;
  @Prop feedback: string = '';
  @Prop feedbackKind: number = 0;
  @Prop topInset: number = 0;
  @Prop leftInset: number = 0;
  @Prop rightInset: number = 0;
  @Prop bottomInset: number = 0;
  @Prop ready: boolean = false;

  events?: PlayerSkinEvents;

  build() {
    PlayerSkin({
      isFull: this.isFull,
      showHud: this.showHud,
      showBack: this.showBack,
      title: this.title,
      playRequested: this.playRequested,
      isPlaying: this.isPlaying,
      completed: this.completed,
      opening: this.opening,
      seeking: this.seeking,
      stalled: this.stalled,
      errorText: this.errorText,
      currentTime: this.currentTime,
      duration: this.duration,
      muted: this.muted,
      speedLabel: this.speedLabel,
      hasPrev: this.hasPrev,
      hasNext: this.hasNext,
      longPressing: this.longPressing,
      feedback: this.feedback,
      feedbackKind: this.feedbackKind,
      topInset: this.topInset,
      leftInset: this.leftInset,
      rightInset: this.rightInset,
      bottomInset: this.bottomInset,
      ready: this.ready,
      onBack: () => { if (this.events) this.events.onBack(); },
      onPlay: () => { if (this.events) this.events.onPlay(); },
      onFull: () => { if (this.events) this.events.onFull(); },
      onMute: () => { if (this.events) this.events.onMute(); },
      onPrev: () => { if (this.events) this.events.onPrev(); },
      onNext: () => { if (this.events) this.events.onNext(); },
      onSpeed: () => { if (this.events) this.events.onSpeed(); },
      onRetry: () => { if (this.events) this.events.onRetry(); },
      onErrorDetail: () => { if (this.events) this.events.onErrorDetail(); },
      onSeekBack: () => { if (this.events) this.events.onSeekBack(); },
      onSeekForward: () => { if (this.events) this.events.onSeekForward(); },
      onSeekStart: (val: number) => { if (this.events) this.events.onSeekStart(val); },
      onSeekUpdate: (val: number) => { if (this.events) this.events.onSeekUpdate(val); },
      onSeekEnd: (val: number) => { if (this.events) this.events.onSeekEnd(val); },
      onToggleHud: () => { if (this.events) this.events.onToggleHud(); },
      onLongPress: () => { if (this.events) this.events.onLongPress(); },
      onLongPressEnd: () => { if (this.events) this.events.onLongPressEnd(); },
      onPanStart: (e: GestureEvent) => { if (this.events) this.events.onPanStart(e); },
      onPanMove: (e: GestureEvent) => { if (this.events) this.events.onPanMove(e); },
      onPanEnd: () => { if (this.events) this.events.onPanEnd(); },
      onPanCancel: () => { if (this.events) this.events.onPanCancel(); }
    })
      .width('100%')
      .height('100%')
  }
}
