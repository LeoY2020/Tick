import i18n from '@ohos.i18n';
import { LanguageSetting } from './Enums';

/**
 * 轻量多语言：简体中文 + English。
 * 使用 I18n.L(中文, English) 在界面内联注册文案，运行时按当前语言返回。
 * 语言优先级：设置显式语言 > 跟随系统（读取系统 locale）。
 */
export class I18n {
  private static language: LanguageSetting = 'system';

  /** 应用启动 / 设置变更时调用 */
  static setLanguage(lang: LanguageSetting): void {
    I18n.language = lang;
  }

  static currentLanguage(): LanguageSetting {
    return I18n.language;
  }

  /** 是否应显示英文文案 */
  static isEnglish(): boolean {
    if (I18n.language === 'en') {
      return true;
    }
    if (I18n.language === 'zh') {
      return false;
    }
    // 跟随系统：读取系统语言
    try {
      const sys = i18n.System.getSystemLanguage();
      return sys.startsWith('en');
    } catch (e) {
      return false;
    }
  }

  /** 获取文案：en 时返回英文，否则返回中文 */
  static L(zh: string, en: string): string {
    return I18n.isEnglish() ? en : zh;
  }
}