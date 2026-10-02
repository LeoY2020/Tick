/**
 * 领域枚举：以字符串字面量联合类型表达（ArkTS 子集兼容），
 * 并提供显示名、归一化、星期解析等纯函数工具。
 */

import { I18n } from './I18n';

/** 任务类型：单项 / 进度 */
export type TaskType = 'single' | 'progress';

/** 任务状态：未完成 → 半完成 → 完成 / 删除 */
export type TaskStatus = 'notDone' | 'halfDone' | 'done' | 'deleted';

/** 目标进度统计模式 */
export type ProgressCountingMode = 'allTasks' | 'leafTasks';

/** 提醒重复规则 */
export type RepeatRule = 'never' | 'daily' | 'weekly' | 'monthly' | 'custom';

/** 配色方案设置 */
export type ColorSchemeSetting = 'system' | 'light' | 'dark';

/**
 * 语言设置：system=跟随系统，其余为显式语言。
 * 保持既有 'system' | 'zh' | 'en' 编码兼容（持久化值不变）。
 */
export type LanguageSetting =
  | 'system'
  | 'zh'
  | 'zh-Hant'
  | 'ja'
  | 'ko'
  | 'en'
  | 'fr'
  | 'de'
  | 'es';

/** AI 模型选择：小艺（盘古，可选/需授权）优先，其余为 OpenAI 兼容云模型 */
export type AIModelKind =
  | 'xiaoyi'
  | 'qwen'
  | 'deepseek'
  | 'chatgpt'
  | 'yuanbao'
  | 'glm'
  | 'kimi'
  | 'ernie'
  | 'custom';

export function taskTypeDisplayName(type: TaskType): string {
  return type === 'single' ? I18n.t('task.single') : I18n.t('task.progress');
}

export function taskStatusDisplayName(status: TaskStatus): string {
  switch (status) {
    case 'notDone':
      return I18n.t('task.notDone');
    case 'halfDone':
      return I18n.t('task.halfDone');
    case 'done':
      return I18n.t('task.done');
    case 'deleted':
      return I18n.t('task.deleted');
  }
}

export function progressCountingModeDisplayName(mode: ProgressCountingMode): string {
  return mode === 'allTasks' ? I18n.t('goals.countAllTasks') : I18n.t('goals.countLeafTasks');
}

export function repeatRuleDisplayName(rule: RepeatRule): string {
  switch (rule) {
    case 'never':
      return I18n.t('repeat.never');
    case 'daily':
      return I18n.t('repeat.daily');
    case 'weekly':
      return I18n.t('repeat.weekly');
    case 'monthly':
      return I18n.t('repeat.monthly');
    case 'custom':
      return I18n.t('repeat.custom');
  }
}

export function colorSchemeDisplayName(scheme: ColorSchemeSetting): string {
  switch (scheme) {
    case 'system':
      return I18n.t('theme.system');
    case 'light':
      return I18n.t('theme.light');
    case 'dark':
      return I18n.t('theme.dark');
  }
}

export function aiModelDisplayName(model: AIModelKind): string {
  switch (model) {
    case 'xiaoyi':
      return I18n.t('ai.model.xiaoyi');
    case 'qwen':
      return I18n.t('ai.model.qwen');
    case 'deepseek':
      return I18n.t('ai.model.deepseek');
    case 'chatgpt':
      return I18n.t('ai.model.chatgpt');
    case 'yuanbao':
      return I18n.t('ai.model.yuanbao');
    case 'glm':
      return I18n.t('ai.model.glm');
    case 'kimi':
      return I18n.t('ai.model.kimi');
    case 'ernie':
      return I18n.t('ai.model.ernie');
    case 'custom':
      return I18n.t('common.custom');
  }
}

/** 未知原始值回退 single */
export function normalizeTaskType(raw: string | undefined): TaskType {
  return raw === 'progress' ? 'progress' : 'single';
}

/** 未知原始值回退 notDone */
export function normalizeTaskStatus(raw: string | undefined): TaskStatus {
  if (raw === 'halfDone' || raw === 'done' || raw === 'deleted') {
    return raw;
  }
  return 'notDone';
}

/** 未知原始值回退 allTasks */
export function normalizeProgressCountingMode(raw: string | undefined): ProgressCountingMode {
  return raw === 'leafTasks' ? 'leafTasks' : 'allTasks';
}

/** 未知/空回退 never */
export function normalizeRepeatRule(raw: string | undefined): RepeatRule {
  if (raw !== undefined && raw !== null && raw.length > 0) {
    if (raw === 'daily' || raw === 'weekly' || raw === 'monthly' || raw === 'custom') {
      return raw;
    }
  }
  return 'never';
}

/**
 * 解析自定义重复的星期（"1,3,5"，1=周日…7=周六），过滤非法值并有序去重。
 */
export function parseWeekdays(raw: string | undefined): number[] {
  if (raw === undefined || raw === null || raw.trim().length === 0) {
    return [];
  }
  const parts: string[] = raw.split(',');
  const seen: number[] = [];
  for (const p of parts) {
    const t = p.trim();
    if (t.length === 0) {
      continue;
    }
    const n = Number.parseInt(t);
    if (!Number.isNaN(n) && n >= 1 && n <= 7 && seen.indexOf(n) < 0) {
      seen.push(n);
    }
  }
  return seen;
}