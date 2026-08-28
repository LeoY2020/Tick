import { ColorSchemeSetting, AIModelKind, LanguageSetting } from './Enums';

/**
 * 设置数据模型（纯数据，不依赖 ArkOS API）。
 * 持久化双通道：偏好值经 @ohos.data.preferences 存取（见 data/Repositories 中 SettingsStore），
 * 同时以键值形式镜像到 RDB 的 settings 表。
 */
export class SettingsModel {
  /** 主题：跟随系统 / 亮 / 暗 */
  colorScheme: ColorSchemeSetting = 'system';
  /** 语言：跟随系统 / 简体中文 / English */
  language: LanguageSetting = 'system';
  /** AI 模型（默认 DeepSeek，OpenAI 兼容） */
  aiModel: AIModelKind = 'deepseek';
  /** OpenAI 兼容 API Key */
  apiKey: string = '';
  /** OpenAI 兼容 Base URL（默认 https://api.deepseek.com/v1） */
  baseUrl: string = 'https://api.deepseek.com/v1';
  /** OpenAI 兼容模型名（默认 deepseek-chat） */
  modelName: string = 'deepseek-chat';

  constructor() {}
}