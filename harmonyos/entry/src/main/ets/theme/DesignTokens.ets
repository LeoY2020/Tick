/**
 * 设计令牌（Design Tokens）：配色 / 圆角 / 字体 / 间距，
 * 对齐 HarmonyOS Design 系统（4px 间距网格、0.5 透明度步进、HarmonyOS Sans）。
 * ArkUI 颜色字符串支持 "#RRGGBB" 与 "#AARRGGBB"（AA=alpha 十六进制）。
 */
export class DesignTokens {
  // ---- 配色（HarmonyOS Design 色板）----
  /** 主色（蓝） */
  static readonly colorPrimary: string = '#0A59F7';
  /** 成功（绿） */
  static readonly colorSuccess: string = '#00A47C';
  /** 警告（橙） */
  static readonly colorWarning: string = '#FA9841';
  /** 危险 / 错误（红） */
  static readonly colorDanger: string = '#E84026';

  /** 主文本（HarmonyOS 文本主色：90% 黑） */
  static readonly colorTextPrimary: string = '#182431';
  /** 次文本（60%） */
  static readonly colorTextSecondary: string = '#99182431';
  /** 三级文本（40%） */
  static readonly colorTextTertiary: string = '#66182431';
  /** 反色文本（深色背景上） */
  static readonly colorTextInverse: string = '#FFFFFF';

  /** 页面背景 */
  static readonly colorBgPage: string = '#F1F3F5';
  /** 卡片 / 控件背景 */
  static readonly colorBgCard: string = '#FFFFFF';
  /** 分割线（10% 黑） */
  static readonly colorDivider: string = '#1A000000';
  /** 按压态蒙层（5% 黑） */
  static readonly colorPressed: string = '#0D000000';

  // ---- 圆角 ----
  static readonly radiusS: number = 8;
  static readonly radiusM: number = 12;
  static readonly radiusL: number = 16;
  static readonly radiusXl: number = 24;
  /** 胶囊 / 圆形 */
  static readonly radiusPill: number = 999;

  // ---- 间距（4px 网格）----
  static readonly spaceXs: number = 4;
  static readonly spaceSm: number = 8;
  static readonly spaceMd: number = 12;
  static readonly spaceLg: number = 16;
  static readonly spaceXl: number = 24;
  static readonly spaceXxl: number = 32;

  // ---- 字体（HarmonyOS Sans）----
  static readonly fontFamily: string = 'HarmonyOS Sans';
  /** 大标题 */
  static readonly fontSizeDisplay: number = 30;
  /** 标题 */
  static readonly fontSizeTitle: number = 20;
  /** 正文 */
  static readonly fontSizeBody: number = 16;
  /** 次级正文 */
  static readonly fontSizeBody2: number = 14;
  /** 说明 / 辅助 */
  static readonly fontSizeCaption: number = 12;
}

/** 目标/任务预设色板（12 色，与 iOS 版保持一致） */
export interface PaletteColor {
  name: string;
  hex: string;
}

export const COLOR_PALETTE: PaletteColor[] = [
  { name: '黑色', hex: '#000000' },
  { name: '红色', hex: '#FF3B30' },
  { name: '橙色', hex: '#FF9500' },
  { name: '黄色', hex: '#FFCC00' },
  { name: '绿色', hex: '#34C759' },
  { name: '薄荷绿', hex: '#00C7BE' },
  { name: '青色', hex: '#30B0C7' },
  { name: '蓝色', hex: '#007AFF' },
  { name: '靛蓝', hex: '#5856D6' },
  { name: '紫色', hex: '#AF52DE' },
  { name: '粉色', hex: '#FF2D55' },
  { name: '棕色', hex: '#A2845E' }
];

/** 深浅色面板（用于「跟随系统/亮/暗」配色设置） */
export interface ThemePalette {
  bg: string;
  card: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  divider: string;
}

/**
 * 主题解析：依据设置的颜色方案返回深浅色面板。
 * system 时读取系统深色标记（由 EntryAbility 在配置变更时写入 Theme.systemDark）。
 */
export class Theme {
  /** 系统是否为深色模式（由 EntryAbility 写入） */
  static systemDark: boolean = false;

  static dark(scheme: 'system' | 'light' | 'dark'): boolean {
    if (scheme === 'dark') {
      return true;
    }
    if (scheme === 'light') {
      return false;
    }
    return Theme.systemDark;
  }

  static palette(dark: boolean): ThemePalette {
    if (dark) {
      return {
        bg: '#0F0F14',
        card: '#1C1C22',
        textPrimary: '#E6E6E9',
        textSecondary: '#B3B3BC',
        textTertiary: '#80808C',
        divider: '#26FFFFFF'
      };
    }
    return {
      bg: DesignTokens.colorBgPage,
      card: '#FFFFFF',
      textPrimary: '#182431',
      textSecondary: '#99182431',
      textTertiary: '#66182431',
      divider: DesignTokens.colorDivider
    };
  }
}