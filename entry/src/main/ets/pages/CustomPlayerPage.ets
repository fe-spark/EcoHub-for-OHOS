import { AppTheme } from '../common/constants/AppTheme';
import { VideoPlayer } from '../components/VideoPlayer';
import { PageHeader } from '../components/PageHeader';
import { AppIcon } from '../components/AppIcon';
import { WindowBar } from '../common/utils/WindowBar';
import { PlayerWindow } from '../common/utils/PlayerWindow';
import { ClipboardSniffer } from '../common/utils/ClipboardSniffer';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct CustomPlayerPage {
  @State private inputUrl: string = '';
  @State private playUrl: string = '';
  @State private topInset: number = 0;
  @State private bottomInset: number = 16;
  @State private leftInset: number = 0;
  @State private rightInset: number = 0;
  @State private viewW: number = 16;
  @State private viewH: number = 9;
  @State private playerFull: boolean = false;
  @State private playerActive: boolean = true;
  private inputController: TextInputController = new TextInputController();

  private applyWindowBar(): void {
    WindowBar.apply(this.getUIContext().getHostContext() as common.UIAbilityContext, (top: number, bottom: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
    }, (left: number, right: number, width: number, height: number) => {
      this.leftInset = left;
      this.rightInset = right;
      this.viewW = width;
      this.viewH = height;
    });
  }

  aboutToAppear() {
    this.applyWindowBar();
    this.checkParams();
  }

  onPageShow(): void {
    this.applyWindowBar();
    this.playerActive = true;
    this.checkParams();
  }

  private checkParams(): void {
    const params = this.getUIContext().getRouter().getParams() as Record<string, Object> | undefined;
    if (params && params['url']) {
      const url = `${params['url']}`.trim();
      if (url && url !== this.playUrl) {
        this.inputUrl = url;
        this.playUrl = url;
      }
    }
  }

  onPageHide(): void {
    this.playerActive = false;
  }

  onBackPress(): boolean {
    if (this.playerFull) {
      this.setPlayerFull(false);
      return true;
    }
    return false;
  }

  aboutToDisappear(): void {
    if (this.playerFull) {
      this.setPlayerFull(false);
    }
  }

  private setPlayerFull(full: boolean): void {
    if (this.playerFull === full) {
      return;
    }
    this.playerFull = full;
    PlayerWindow.setFullscreen(this.getUIContext().getHostContext() as common.UIAbilityContext, full);
  }

  private play(): void {
    try {
      this.inputController.stopEditing();
    } catch (_e) {
    }
    const url = this.inputUrl.trim();
    if (!url || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '请输入正确的 mp4 或 m3u8 地址' });
      } catch (_e) {
      }
      return;
    }
    this.playUrl = url;
  }

  build() {
    Column() {
      if (!this.playerFull) {
        PageHeader({ title: '自定义播放' })

        Row() {
          Row() {
            AppIcon({ src: $r('sys.symbol.link'), iconSize: 16, color: AppTheme.TEXT_MUTED })
            TextInput({ text: this.inputUrl, placeholder: '输入 mp4 或 m3u8 播放地址', controller: this.inputController })
              .layoutWeight(1)
              .height(44)
              .fontSize(13)
              .fontColor(AppTheme.TEXT_PRIMARY)
              .placeholderColor(AppTheme.TEXT_MUTED)
              .caretColor(AppTheme.ACCENT)
              .backgroundColor(Color.Transparent)
              .padding({ left: 8, right: 8 })
              .enterKeyType(EnterKeyType.Go)
              .onChange((val: string) => {
                this.inputUrl = val;
              })
              .onSubmit(() => this.play())
          }
          .layoutWeight(1)
          .height(44)
          .padding({ left: 12, right: 8 })
          .backgroundColor(AppTheme.BG_CARD)
          .borderRadius(AppTheme.RADIUS_MD)

          Row() {
            PasteButton()
              .height(44)
              .padding({ left: 14, right: 14 })
              .backgroundColor(AppTheme.BG_CARD)
              .borderRadius(AppTheme.RADIUS_MD)
              .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => {
                if (result === PasteButtonOnClickResult.SUCCESS) {
                  const res = await ClipboardSniffer.sniff();
                  if (res.url) {
                    ClipboardSniffer.markHandled(res.raw);
                    this.inputUrl = res.url;
                    this.playUrl = res.url;
                    try {
                      this.getUIContext().getPromptAction().showToast({ message: '已提取剪贴板链接并开始播放' });
                    } catch (_e) {
                    }
                  } else if (res.raw) {
                    ClipboardSniffer.markHandled(res.raw);
                    this.inputUrl = res.raw;
                    this.play();
                  } else {
                    try {
                      this.getUIContext().getPromptAction().showToast({ message: '未在剪贴板中检测到有效链接' });
                    } catch (_e) {
                    }
                  }
                }
              })
          }
          .margin({ left: 8 })

          Row() {
            AppIcon({ src: $r('sys.symbol.play_fill'), iconSize: 16, color: AppTheme.TEXT_PRIMARY })
            Text('播放')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT_PRIMARY)
              .margin({ left: 4 })
          }
          .height(44)
          .padding({ left: 14, right: 16 })
          .backgroundColor(AppTheme.ACCENT)
          .borderRadius(AppTheme.RADIUS_MD)
          .margin({ left: 8 })
          .onClick(() => this.play())
        }
        .width('100%')
        .padding(16)
      }

      VideoPlayer({
        videoUrl: this.playUrl,
        title: '自定义播放',
        showBack: this.playerFull,
        isFull: this.playerFull,
        pageActive: this.playerActive,
        topInset: this.playerFull ? this.topInset : 0,
        leftInset: this.playerFull ? this.leftInset : 0,
        rightInset: this.playerFull ? this.rightInset : 0,
        bottomInset: this.playerFull ? this.bottomInset : 0,
        onBack: () => this.setPlayerFull(false),
        onFullscreenChange: (full: boolean) => this.setPlayerFull(full)
      })
        .width('100%')
        .aspectRatio(this.playerFull ? this.viewW / Math.max(this.viewH, 1) : 16 / 9)
        .layoutWeight(this.playerFull ? 1 : 0)
        .constraintSize(this.playerFull ?
          { minWidth: '100%', maxWidth: '100%', minHeight: '100%', maxHeight: '100%' } :
          { minHeight: 0 })

      if (!this.playerFull) {
        Text('仅支持直链 mp4 / m3u8，不会写入观看历史。')
          .fontSize(12)
          .fontColor(AppTheme.TEXT_MUTED)
          .margin({ top: 16 })
          .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.playerFull ? 0 : this.topInset,
      bottom: this.playerFull ? 0 : this.bottomInset
    })
    .backgroundColor(this.playerFull ? '#000000' : AppTheme.BG)
  }
}
