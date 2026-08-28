/**
 * 领域枚举：以字符串字面量联合类型表达（ArkTS 子集兼容），
 * 并提供显示名、归一化、星期解析等纯函数工具。
 */

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

/** 语言设置 */
export type LanguageSetting = 'system' | 'zh' | 'en';

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
  return type === 'single' ? '单项' : '进度';
}

export function taskStatusDisplayName(status: TaskStatus): string {
  switch (status) {
    case 'notDone':
      return '未完成';
    case 'halfDone':
      return '半完成';
    case 'done':
      return '完成';
    case 'deleted':
      return '删除';
  }
}

export function progressCountingModeDisplayName(mode: ProgressCountingMode): string {
  return mode === 'allTasks' ? '全部任务' : '仅叶子任务';
}

export function repeatRuleDisplayName(rule: RepeatRule): string {
  switch (rule) {
    case 'never':
      return '不重复';
    case 'daily':
      return '每天';
    case 'weekly':
      return '每周';
    case 'monthly':
      return '每月';
    case 'custom':
      return '自定义';
  }
}

export function colorSchemeDisplayName(scheme: ColorSchemeSetting): string {
  switch (scheme) {
    case 'system':
      return '跟随系统';
    case 'light':
      return '亮色';
    case 'dark':
      return '暗色';
  }
}

export function aiModelDisplayName(model: AIModelKind): string {
  switch (model) {
    case 'xiaoyi':
      return '小艺（盘古，需授权）';
    case 'qwen':
      return '千问';
    case 'deepseek':
      return 'DeepSeek';
    case 'chatgpt':
      return 'ChatGPT';
    case 'yuanbao':
      return '元宝';
    case 'glm':
      return 'GLM';
    case 'kimi':
      return 'Kimi';
    case 'ernie':
      return '文心';
    case 'custom':
      return '自定义';
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