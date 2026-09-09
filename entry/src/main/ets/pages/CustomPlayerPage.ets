import { AppTheme } from '../common/constants/AppTheme';
import { HttpClient } from '../common/network/HttpClient';
import { VideoPlayer } from '../modules/player/VideoPlayer';
import { PageHeader } from '../components/common/PageHeader';
import { AppIcon } from '../components/common/AppIcon';
import { WindowBar } from '../common/utils/WindowBar';
import { PlayerWindow } from '../modules/player/PlayerWindow';
import { Breakpoint } from '../common/utils/Breakpoint';
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
  @StorageLink('WIDTH_BP') private widthBp: string = 'sm';
  private inputController: TextInputController = new TextInputController();

  private applyWindowBar(): void {
    WindowBar.apply(this.getUIContext().getHostContext() as common.UIAbilityContext, (top: number, bottom: number, left: number, right: number) => {
      this.topInset = top;
      this.bottomInset = bottom;
      this.leftInset = left;
      this.rightInset = right;
    }, (left: number, right: number, width: number, height: number) => {
      this.leftInset = left;
      this.rightInset = right;
      this.viewW = width;
      this.viewH = height;
    });
  }

  aboutToAppear() {
    this.applyWindowBar();
    HttpClient.getInstance().trackView('browse', '', 'CustomPlayerPage');
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

  private setPlayerFull(full: boolean, isPortrait: boolean = false): void {
    if (this.playerFull === full) {
      return;
    }
    this.playerFull = full;
    PlayerWindow.setFullscreen(this.getUIContext().getHostContext() as common.UIAbilityContext, full, isPortrait);
  }

  private hasPlayUrl(): boolean {
    return this.playUrl.trim().length > 0;
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

  @Builder
  urlBar() {
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
    .padding(AppTheme.SPACE_LG)
  }

  @Builder
  idlePane() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(76)
          .height(76)
          .borderRadius(38)
          .backgroundColor(AppTheme.ACCENT_SOFT)
        AppIcon({
          src: $r('sys.symbol.play_circle_fill'),
          iconSize: 36,
          color: AppTheme.ACCENT
        })
      }
      .margin({ bottom: 16 })

      Text('粘贴直链即可播放')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT_PRIMARY)

      Text('仅支持 mp4 / m3u8，不会写入观看历史')
        .fontSize(13)
        .lineHeight(20)
        .fontColor(AppTheme.TEXT_MUTED)
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 32, right: 32, bottom: 24 })
  }

  build() {
    Column() {
      if (!this.playerFull) {
        Column() {
          PageHeader({ title: '自定义播放' })
          this.urlBar()
        }
        .width('100%')
      }

      if (this.hasPlayUrl()) {
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
          onFullscreenChange: (full: boolean, isPortrait?: boolean) => this.setPlayerFull(full, isPortrait)
        })
          .width('100%')
          .height(this.playerFull ? '100%' : undefined)
          .aspectRatio(this.playerFull ? undefined : 16 / 9)
          .layoutWeight(this.playerFull || Breakpoint.isWide(this.widthBp) ? 1 : 0)

        if (!this.playerFull) {
          Text('仅支持直链 mp4 / m3u8，不会写入观看历史。')
            .fontSize(12)
            .fontColor(AppTheme.TEXT_MUTED)
            .margin({ top: AppTheme.SPACE_LG })
            .padding({ left: AppTheme.SPACE_LG, right: AppTheme.SPACE_LG })
        }
      } else {
        this.idlePane()
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.playerFull ? 0 : this.topInset,
      bottom: this.playerFull ? 0 : this.bottomInset,
      left: this.playerFull ? 0 : this.leftInset,
      right: this.playerFull ? 0 : this.rightInset
    })
    .backgroundColor(this.playerFull ? '#000000' : AppTheme.BG)
  }
}
