import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { HistoryManager } from '../common/utils/HistoryManager';
import { ServerConfigManager } from '../common/utils/ServerConfigManager';
import { SiteHeartbeat } from '../common/utils/SiteHeartbeat';


export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } catch (_e) {
    }
  }

  onForeground(): void {
    if (ServerConfigManager.getInstance().getCachedServerUrl()) {
      SiteHeartbeat.getInstance().start();
    }
  }

  onBackground(): void {
    SiteHeartbeat.getInstance().stop();
  }

  onDestroy(): void {
    SiteHeartbeat.getInstance().stop();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    ServerConfigManager.getInstance().init(this.context).then(() => {
      return HistoryManager.migrateLegacy();
    }).then(() => {
      windowStage.loadContent('pages/SplashPage', (err) => {
        if (err.code) {
          console.error('Failed to load content:', JSON.stringify(err));
          return;
        }
        windowStage.getMainWindow().then((win: window.Window) => {
          AppStorage.setOrCreate('UI_CONTEXT', win.getUIContext());
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
