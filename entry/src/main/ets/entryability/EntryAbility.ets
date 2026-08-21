import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { HistoryManager } from '../common/utils/HistoryManager';
import { ServerConfigManager } from '../common/utils/ServerConfigManager';


export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    ServerConfigManager.getInstance().init(this.context).then(() => {
      return HistoryManager.migrateLegacy();
    }).then(() => {
      return ServerConfigManager.getInstance().getServerUrl();
    }).then((url: string) => {
      const targetPage = url ? 'pages/Index' : 'pages/ServerConfigPage';
      windowStage.loadContent(targetPage, (err) => {
        if (err.code) {
          console.error('Failed to load content:', JSON.stringify(err));
          return;
        }
        windowStage.getMainWindow().then((win: window.Window) => {
          win.setWindowSystemBarEnable(['status', 'navigation']);
          win.setWindowLayoutFullScreen(true);
          win.setWindowSystemBarProperties({
            statusBarColor: '#0A0B10',
            statusBarContentColor: '#FFFFFF',
            navigationBarColor: '#12141C',
            navigationBarContentColor: '#FFFFFF'
          });
        });

      });
    }).catch((err: Error) => {
      console.error('Failed to init server config:', JSON.stringify(err));
      windowStage.loadContent('pages/ServerConfigPage', (loadErr) => {
        if (loadErr.code) {
          console.error('Failed to load content:', JSON.stringify(loadErr));
        }
      });
    });
  }
}
