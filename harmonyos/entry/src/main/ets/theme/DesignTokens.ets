/**
 * 设计令牌（Design Tokens）：配色 / 圆角 / 字体 / 间距，
 * 对齐 HarmonyOS Design 系统（4px 间距网格、0.5 透明度步进、HarmonyOS Sans）。
 * ArkUI 颜色字符串支持 "#RRGGBB" 与 "#AARRGGBB"（AA=alpha 十六进制）。
 */
export class DesignTokens {
  // ---- 配色（HarmonyOS Design 色板）----
  /** 主色（蓝） */
  static readonly colorPrimary: string = '#0A59F7';
  /** 主色浅调（用于渐变高光） */
  static readonly colorPrimaryLight: string = '#4F8CFF';
  /** 主色深调 */
  static readonly colorPrimaryDeep: string = '#0B3ED1';
  /** 强调色（紫，用于光感渐变） */
  static readonly colorAccent: string = '#7B61FF';
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

  // ---- 动效（HarmonyOS 光感动效） ----
  /** 按压反馈时长 */
  static readonly animFast: number = 160;
  /** 常规过渡时长 */
  static readonly animNormal: number = 320;
  /** 光感流动周期 */
  static readonly animSweep: number = 2600;
  /** 环境光漂移周期 */
  static readonly animAmbient: number = 9000;

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

/**
 * 连续自适应度量（无断点跳变）：
 * 随窗口宽高平滑插值，适配手机 / 折叠屏 / 平板 / 2in1 的各种比例与分辨率。
 * 所有值均为 vp，随屏幕密度自动换算。
 */
export class Adaptive {
  /** 内容最大宽度：超宽窗口时内容居中，避免长行难以阅读 */
  static readonly contentMaxWidth: number = 720;
  /** 宽屏（常驻导航栏 + 内容区）时的内容最大宽度 */
  static readonly contentMaxWidthWide: number = 1080;
  /** 宽屏阈值：平板横屏 / 2in1 / 三折叠展开 */
  static readonly breakpointExpanded: number = 840;
  /** 半模态最小可用高度 */
  private static readonly sheetMinHeight: number = 320;

  /** 内容宽度 */
  static contentWidth(winW: number): number {
    return Math.min(winW, Adaptive.contentMaxWidth);
  }

  /** 内容居中时的左右留白 */
  static sideInset(winW: number): number {
    return Math.max(0, (winW - Adaptive.contentWidth(winW)) / 2);
  }

  /** 页面水平内边距：宽屏连续增大（12 → 32） */
  static gutter(winW: number): number {
    return Math.min(32, Math.max(12, winW * 0.04));
  }

  /** 主操作按钮直径（52 → 64） */
  static fabSize(winW: number, winH: number): number {
    return Math.min(64, Math.max(52, Math.min(winW, winH) * 0.14));
  }

  /** 半模态高度：不超过可用高度的 85% */
  static sheetHeight(winH: number, preferred: number): number {
    return Math.min(preferred, Math.max(Adaptive.sheetMinHeight, winH * 0.85));
  }

  /** 抽屉宽度：240 → 320，且不超过内容宽度 */
  static sidebarWidth(winW: number): number {
    return Math.min(Adaptive.contentWidth(winW), Math.min(320, Math.max(240, winW * 0.78)));
  }
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
  bgTop: string;
  bgBottom: string;
  card: string;
  cardSoft: string;
  border: string;
  track: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  divider: string;
  /** 光感渐变主色 */
  heroA: string;
  /** 光感渐变副色 */
  heroB: string;
  /** 环境光斑 A（带透明度） */
  glowA: string;
  /** 环境光斑 B（带透明度） */
  glowB: string;
  /** 卡片阴影色 */
  shadow: string;
  /** 选中态浅底 */
  accentSoft: string;
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
        bg: '#0A0B10',
        bgTop: '#151933',
        bgBottom: '#07080D',
        card: '#171A24',
        cardSoft: '#1E2231',
        border: '#24FFFFFF',
        track: '#2A2F3D',
        textPrimary: '#ECEDF2',
        textSecondary: '#B0B4C2',
        textTertiary: '#7B8093',
        divider: '#26FFFFFF',
        heroA: '#5B8DFF',
        heroB: '#9B7BFF',
        glowA: '#4D5B8DFF',
        glowB: '#337B61FF',
        shadow: '#66000000',
        accentSoft: '#2E2F4D'
      };
    }
    return {
      bg: '#F3F5FA',
      bgTop: '#FBFCFE',
      bgBottom: '#E9EEF8',
      card: '#FFFFFF',
      cardSoft: '#F5F7FC',
      border: '#14000000',
      track: '#E7EBF4',
      textPrimary: '#101420',
      textSecondary: '#667085',
      textTertiary: '#98A2B3',
      divider: '#12000000',
      heroA: '#0A59F7',
      heroB: '#7B61FF',
      glowA: '#330A59F7',
      glowB: '#267B61FF',
      shadow: '#140A1B3F',
      accentSoft: '#EBF0FF'
    };
  }
}