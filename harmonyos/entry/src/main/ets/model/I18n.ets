import i18n from '@ohos.i18n';
import { LanguageSetting } from './Enums';

/**
 * 8 语言文案对象：新取词接口 I18n.all(...) 使用。
 * 顺序与国家级设置页语言选项一一对应。
 */
export interface LocalizedText {
  zh: string;      // 简体中文
  zhHant: string;  // 繁體中文
  ja: string;      // 日本語
  ko: string;      // 한국어
  en: string;      // English
  fr: string;      // Français
  de: string;      // Deutsch
  es: string;      // Español
}

/**
 * 轻量多语言：简体中文 / 繁體中文 / 日本語 / 한국어 / English / Français / Deutsch / Español。
 * - 新 UI 用 I18n.all({...8 语言对象}) 取词。
 * - 存量调用 I18n.L(中文, English) 保持兼容；L 仅含中英两语，其他语言回退中文原文。
 * 语言优先级：设置显式语言 > 跟随系统（读取 @ohos.i18n 系统 locale）。
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

  /** 跟随系统时读取系统 locale，未显式设置时判断当前语言 */
  static detectSystemLang(): LanguageSetting {
    try {
      const sys = i18n.System.getSystemLanguage().toLowerCase();
      if (sys.startsWith('zh')) {
        // 繁体：脚本 hant 或地区 tw/hk/mo；其余按简体
        if (sys.indexOf('hant') >= 0 || sys.indexOf('-tw') >= 0 ||
            sys.indexOf('-hk') >= 0 || sys.indexOf('-mo') >= 0) {
          return 'zh-Hant';
        }
        return 'zh';
      }
      if (sys.startsWith('ja')) {
        return 'ja';
      }
      if (sys.startsWith('ko')) {
        return 'ko';
      }
      if (sys.startsWith('fr')) {
        return 'fr';
      }
      if (sys.startsWith('de')) {
        return 'de';
      }
      if (sys.startsWith('es')) {
        return 'es';
      }
      if (sys.startsWith('en')) {
        return 'en';
      }
      return 'zh';
    } catch (e) {
      return 'zh';
    }
  }

  /** 实际生效语言：显式设置优先，否则取跟随系统的判定结果 */
  static resolvedLang(): LanguageSetting {
    if (I18n.language !== 'system') {
      return I18n.language;
    }
    return I18n.detectSystemLang();
  }

  /** 是否应显示英文文案（向后兼容旧接口） */
  static isEnglish(): boolean {
    return I18n.resolvedLang() === 'en';
  }

  /** 新取词接口：给定 8 语言对象，按当前语言返回对应译文，未知回退英文 */
  static all(t: LocalizedText): string {
    switch (I18n.resolvedLang()) {
      case 'zh':
        return t.zh;
      case 'zh-Hant':
        return t.zhHant;
      case 'ja':
        return t.ja;
      case 'ko':
        return t.ko;
      case 'fr':
        return t.fr;
      case 'de':
        return t.de;
      case 'es':
        return t.es;
      case 'en':
      default:
        return t.en;
    }
  }

  /**
   * 旧取词接口（仅含中英）：en 时返回英文，其余（含中/日/韩/法/德/西）回退中文原文。
   * 保持既有调用不报错，不破坏行为。
   */
  static L(zh: string, en: string): string {
    return I18n.resolvedLang() === 'en' ? en : zh;
  }
}