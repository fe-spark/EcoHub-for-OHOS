import { pasteboard } from '@kit.BasicServicesKit';
import { AppTheme } from '../../common/constants/AppTheme';
import { AppToast } from '../../common/utils/AppToast';

export class PlayerDialogHelper {
  static showErrorDetail(uiContext: UIContext, errorText: string): void {
    uiContext.showAlertDialog({
      title: '播放异常详情',
      message: errorText,
      primaryButton: {
        value: '复制',
        fontColor: AppTheme.ACCENT,
        action: () => {
          if (errorText) {
            try {
              const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, errorText);
              pasteboard.getSystemPasteboard().setDataSync(data);
              AppToast.show('已复制报错信息');
            } catch (_e) {}
          }
        }
      },
      secondaryButton: {
        value: '知道了',
        action: () => {}
      }
    });
  }
}
