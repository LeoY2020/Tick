import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import { Database } from '../data/Database';
import { SettingsStore } from '../data/Repositories';
import { Theme } from '../theme/DesignTokens';

const DOMAIN = 0x0000;
const TAG = 'Tick';

/**
 * 应用入口：初始化 RDB 与偏好存储后，加载主页面。
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
    Theme.systemDark = this.isSystemDark();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(DOMAIN, TAG, 'onConfigurationUpdate');
    Theme.systemDark = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  private isSystemDark(): boolean {
    try {
      return this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } catch (e) {
      return false;
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 设置状态栏可沉浸样式（跟随浅色背景）
    const init = async (): Promise<void> => {
      try {
        await Database.init(this.context);
        await SettingsStore.init(this.context);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'initialize failed: %{public}s', JSON.stringify(e));
      }
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, TAG, 'loadContent succeeded');
      });
    };
    init();
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}