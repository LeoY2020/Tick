import relationalStore from '@ohos.data.relationalStore';
import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { Goal } from '../model/Goal';
import { TaskItem } from '../model/TaskItem';
import { AIChatSession } from '../model/ChatModels';
import { SettingsModel } from '../model/Settings';
import {
  normalizeTaskType,
  normalizeTaskStatus,
  normalizeProgressCountingMode,
  normalizeRepeatRule,
  ColorSchemeSetting,
  AIModelKind,
  LanguageSetting
} from '../model/Enums';
import { Database } from './Database';

const T_GOAL = 'goal';
const T_TASK = 'task';
const T_CHAT = 'ai_chat_session';
const T_SETTINGS = 'settings';

// MARK: - 列值读取辅助（NULL 安全）

function optionalString(rs: relationalStore.ResultSet, col: string): string | undefined {
  const idx = rs.getColumnIndex(col);
  return rs.isColumnNull(idx) ? undefined : rs.getString(idx);
}

function optionalLong(rs: relationalStore.ResultSet, col: string): number | undefined {
  const idx = rs.getColumnIndex(col);
  return rs.isColumnNull(idx) ? undefined : rs.getLong(idx);
}

function nullOrString(v: string | undefined): string | null {
  return v === undefined ? null : v;
}

function nullOrLong(v: number | undefined): number | null {
  return v === undefined ? null : v;
}

// MARK: - GoalRepository

export class GoalRepository {
  static async list(): Promise<Goal[]> {
    const store = Database.getStore();
    const rs = await store.querySql('SELECT * FROM goal ORDER BY createdAt ASC');
    const goals: Goal[] = [];
    try {
      while (rs.goToNextRow()) {
        goals.push(GoalRepository.rowToGoal(rs));
      }
    } finally {
      rs.close();
    }
    return goals;
  }

  static async find(id: string): Promise<Goal | undefined> {
    const store = Database.getStore();
    const rs = await store.querySql('SELECT * FROM goal WHERE id = ?', [id]);
    try {
      if (rs.goToNextRow()) {
        return GoalRepository.rowToGoal(rs);
      }
    } finally {
      rs.close();
    }
    return undefined;
  }

  static async save(goal: Goal): Promise<void> {
    const store = Database.getStore();
    const existing = await GoalRepository.find(goal.id);
    if (existing === undefined) {
      await store.insert(T_GOAL, GoalRepository.toBucket(goal));
    } else {
      const predicates = new relationalStore.RdbPredicates(T_GOAL);
      predicates.equalTo('id', goal.id);
      await store.update(GoalRepository.toBucket(goal), predicates);
    }
  }

  /** 删除目标：级联删除其下全部任务 */
  static async deleteCascade(id: string): Promise<void> {
    const store = Database.getStore();
    const tasks = await store.querySql('SELECT id FROM task WHERE goalId = ?', [id]);
    const ids: string[] = [];
    try {
      while (tasks.goToNextRow()) {
        ids.push(tasks.getString(tasks.getColumnIndex('id')));
      }
    } finally {
      tasks.close();
    }
    for (const tid of ids) {
      await TaskRepository.deleteCascade(tid);
    }
    const p = new relationalStore.RdbPredicates(T_GOAL);
    p.equalTo('id', id);
    await store.delete(p);
  }

  private static rowToGoal(rs: relationalStore.ResultSet): Goal {
    const g = new Goal();
    g.id = rs.getString(rs.getColumnIndex('id'));
    g.name = rs.getString(rs.getColumnIndex('name'));
    g.colorHex = rs.getString(rs.getColumnIndex('colorHex'));
    g.iconSystemName = optionalString(rs, 'iconSystemName');
    g.startDate = optionalLong(rs, 'startDate');
    g.endDate = optionalLong(rs, 'endDate');
    g.startDatePreciseToHour = rs.getLong(rs.getColumnIndex('startDatePreciseToHour')) === 1;
    g.endDatePreciseToHour = rs.getLong(rs.getColumnIndex('endDatePreciseToHour')) === 1;
    g.createdAt = rs.getLong(rs.getColumnIndex('createdAt'));
    g.progressCountingMode = normalizeProgressCountingMode(rs.getString(rs.getColumnIndex('progressCountingMode')));
    return g;
  }

  private static toBucket(g: Goal): relationalStore.ValuesBucket {
    const b: relationalStore.ValuesBucket = {};
    b['id'] = g.id;
    b['name'] = g.name;
    b['colorHex'] = g.colorHex;
    b['iconSystemName'] = nullOrString(g.iconSystemName);
    b['startDate'] = nullOrLong(g.startDate);
    b['endDate'] = nullOrLong(g.endDate);
    b['startDatePreciseToHour'] = g.startDatePreciseToHour ? 1 : 0;
    b['endDatePreciseToHour'] = g.endDatePreciseToHour ? 1 : 0;
    b['createdAt'] = g.createdAt;
    b['progressCountingMode'] = g.progressCountingMode;
    return b;
  }
}

// MARK: - TaskRepository

export class TaskRepository {
  /** 一级任务（goalId 匹配） */
  static async listTopTasks(goalId: string): Promise<TaskItem[]> {
    const store = Database.getStore();
    const rs = await store.querySql('SELECT * FROM task WHERE goalId = ? ORDER BY sortOrder ASC, createdAt ASC', [goalId]);
    const list: TaskItem[] = [];
    try {
      while (rs.goToNextRow()) {
        list.push(TaskRepository.rowToTask(rs));
      }
    } finally {
      rs.close();
    }
    return list;
  }

  /** 直接子任务 */
  static async listChildren(parentId: string): Promise<TaskItem[]> {
    const store = Database.getStore();
    const rs = await store.querySql('SELECT * FROM task WHERE parentTaskId = ? ORDER BY sortOrder ASC, createdAt ASC', [parentId]);
    const list: TaskItem[] = [];
    try {
      while (rs.goToNextRow()) {
        list.push(TaskRepository.rowToTask(rs));
      }
    } finally {
      rs.close();
    }
    return list;
  }

  /** 构建目标下的完整任务树（自引用级联加载） */
  static async buildTree(goalId: string): Promise<TaskItem[]> {
    const tops = await TaskRepository.listTopTasks(goalId);
    for (const t of tops) {
      await TaskRepository.loadDescendants(t);
    }
    return tops;
  }

  private static async loadDescendants(node: TaskItem): Promise<void> {
    const children = await TaskRepository.listChildren(node.id);
    node.subtasks = children;
    for (const c of children) {
      await TaskRepository.loadDescendants(c);
    }
  }

  static async find(id: string): Promise<TaskItem | undefined> {
    const store = Database.getStore();
    const rs = await store.querySql('SELECT * FROM task WHERE id = ?', [id]);
    try {
      if (rs.goToNextRow()) {
        return TaskRepository.rowToTask(rs);
      }
    } finally {
      rs.close();
    }
    return undefined;
  }

  static async save(task: TaskItem): Promise<void> {
    const store = Database.getStore();
    const existing = await TaskRepository.find(task.id);
    if (existing === undefined) {
      await store.insert(T_TASK, TaskRepository.toBucket(task));
    } else {
      const predicates = new relationalStore.RdbPredicates(T_TASK);
      predicates.equalTo('id', task.id);
      await store.update(TaskRepository.toBucket(task), predicates);
    }
  }

  /** 采集后代 id（深度优先） */
  private static async collectDescendants(id: string, acc: string[]): Promise<void> {
    const children = await TaskRepository.listChildren(id);
    for (const c of children) {
      acc.push(c.id);
      await TaskRepository.collectDescendants(c.id, acc);
    }
  }

  /** 返回任务自身及全部后代 id（供级联取消提醒 / 级联删除） */
  static async descendantIds(id: string): Promise<string[]> {
    const acc: string[] = [id];
    await TaskRepository.collectDescendants(id, acc);
    return acc;
  }

  /** 删除任务：级联删除全部后代 */
  static async deleteCascade(id: string): Promise<void> {
    const store = Database.getStore();
    const ids: string[] = [id];
    await TaskRepository.collectDescendants(id, ids);
    for (const tid of ids) {
      const p = new relationalStore.RdbPredicates(T_TASK);
      p.equalTo('id', tid);
      await store.delete(p);
    }
  }

  /** AI 生成任务树写入：递归持久化 TaskNode（此处以 TaskItem 表示） */
  static async insertTree(tasks: TaskItem[], goalId: string, parentTaskId: string | undefined): Promise<void> {
    for (const t of tasks) {
      if (parentTaskId !== undefined) {
        t.attachToParent(parentTaskId);
      } else {
        t.attachToGoal(goalId);
      }
      await TaskRepository.save(t);
      if (t.subtasks.length > 0) {
        await TaskRepository.insertTree(t.subtasks, goalId, t.id);
      }
    }
  }

  private static rowToTask(rs: relationalStore.ResultSet): TaskItem {
    const t = new TaskItem();
    t.id = rs.getString(rs.getColumnIndex('id'));
    t.name = rs.getString(rs.getColumnIndex('name'));
    t.colorHex = optionalString(rs, 'colorHex');
    t.iconSystemName = optionalString(rs, 'iconSystemName');
    t.type = normalizeTaskType(rs.getString(rs.getColumnIndex('type')));
    t.status = normalizeTaskStatus(rs.getString(rs.getColumnIndex('status')));
    t.totalAmount = rs.getDouble(rs.getColumnIndex('totalAmount'));
    t.currentAmount = rs.getDouble(rs.getColumnIndex('currentAmount'));
    t.startDate = optionalLong(rs, 'startDate');
    t.endDate = optionalLong(rs, 'endDate');
    t.reminderDate = optionalLong(rs, 'reminderDate');
    t.repeatRule = normalizeRepeatRule(optionalString(rs, 'repeatRule'));
    t.customWeekdaysRaw = optionalString(rs, 'customWeekdaysRaw');
    t.createdAt = rs.getLong(rs.getColumnIndex('createdAt'));
    t.sortOrder = rs.getLong(rs.getColumnIndex('sortOrder'));
    t.parentTaskId = optionalString(rs, 'parentTaskId');
    t.goalId = optionalString(rs, 'goalId');
    return t;
  }

  private static toBucket(t: TaskItem): relationalStore.ValuesBucket {
    const b: relationalStore.ValuesBucket = {};
    b['id'] = t.id;
    b['name'] = t.name;
    b['colorHex'] = nullOrString(t.colorHex);
    b['iconSystemName'] = nullOrString(t.iconSystemName);
    b['type'] = t.type;
    b['status'] = t.status;
    b['totalAmount'] = t.totalAmount;
    b['currentAmount'] = t.currentAmount;
    b['startDate'] = nullOrLong(t.startDate);
    b['endDate'] = nullOrLong(t.endDate);
    b['reminderDate'] = nullOrLong(t.reminderDate);
    b['repeatRule'] = nullOrString(t.repeatRule);
    b['customWeekdaysRaw'] = nullOrString(t.customWeekdaysRaw);
    b['createdAt'] = t.createdAt;
    b['sortOrder'] = t.sortOrder;
    b['parentTaskId'] = nullOrString(t.parentTaskId);
    b['goalId'] = nullOrString(t.goalId);
    return b;
  }
}

// MARK: - ChatRepository

export class ChatRepository {
  static async list(): Promise<AIChatSession[]> {
    const store = Database.getStore();
    const rs = await store.querySql('SELECT * FROM ai_chat_session ORDER BY updatedAt DESC');
    const list: AIChatSession[] = [];
    try {
      while (rs.goToNextRow()) {
        list.push(ChatRepository.rowToSession(rs));
      }
    } finally {
      rs.close();
    }
    return list;
  }

  static async save(session: AIChatSession): Promise<void> {
    const store = Database.getStore();
    const predicates = new relationalStore.RdbPredicates(T_CHAT);
    predicates.equalTo('id', session.id);
    const count = await store.count(predicates);
    if (count > 0) {
      await store.update(ChatRepository.toBucket(session), predicates);
    } else {
      await store.insert(T_CHAT, ChatRepository.toBucket(session));
    }
  }

  static async delete(id: string): Promise<void> {
    const store = Database.getStore();
    const p = new relationalStore.RdbPredicates(T_CHAT);
    p.equalTo('id', id);
    await store.delete(p);
  }

  private static rowToSession(rs: relationalStore.ResultSet): AIChatSession {
    const s = new AIChatSession();
    s.id = rs.getString(rs.getColumnIndex('id'));
    s.title = rs.getString(rs.getColumnIndex('title'));
    s.createdAt = rs.getLong(rs.getColumnIndex('createdAt'));
    s.updatedAt = rs.getLong(rs.getColumnIndex('updatedAt'));
    s.messagesData = rs.getString(rs.getColumnIndex('messagesData'));
    s.messageCount = rs.getLong(rs.getColumnIndex('messageCount'));
    s.attachmentName = optionalString(rs, 'attachmentName');
    s.attachmentText = optionalString(rs, 'attachmentText');
    return s;
  }

  private static toBucket(s: AIChatSession): relationalStore.ValuesBucket {
    const b: relationalStore.ValuesBucket = {};
    b['id'] = s.id;
    b['title'] = s.title;
    b['createdAt'] = s.createdAt;
    b['updatedAt'] = s.updatedAt;
    b['messagesData'] = s.messagesData;
    b['messageCount'] = s.messageCount;
    b['attachmentName'] = nullOrString(s.attachmentName);
    b['attachmentText'] = nullOrString(s.attachmentText);
    return b;
  }
}

// MARK: - SettingsRepository（RDB 键值镜像）

export class SettingsRepository {
  static async set(key: string, value: string): Promise<void> {
    const store = Database.getStore();
    const b: relationalStore.ValuesBucket = {};
    b['key'] = key;
    b['value'] = value;
    const predicates = new relationalStore.RdbPredicates(T_SETTINGS);
    predicates.equalTo('key', key);
    const count = await store.count(predicates);
    if (count > 0) {
      await store.update(b, predicates);
    } else {
      await store.insert(T_SETTINGS, b);
    }
  }

  static async get(key: string): Promise<string | undefined> {
    const store = Database.getStore();
    const rs = await store.querySql('SELECT value FROM settings WHERE key = ?', [key]);
    try {
      if (rs.goToNextRow()) {
        return rs.getString(rs.getColumnIndex('value'));
      }
    } finally {
      rs.close();
    }
    return undefined;
  }
}

// MARK: - SettingsStore（偏好存储 @ohos.data.preferences，主通道）

export class SettingsStore {
  private static pref: preferences.Preferences | undefined = undefined;

  static async init(context: common.Context): Promise<void> {
    SettingsStore.pref = await preferences.getPreferences(context, 'tick_settings');
  }

  static async load(): Promise<SettingsModel> {
    const m = new SettingsModel();
    if (SettingsStore.pref === undefined) {
      return m;
    }
    const cs = (await SettingsStore.pref.get('colorScheme', 'system')) as string;
    m.colorScheme = (cs === 'light' || cs === 'dark' || cs === 'system') ? (cs as ColorSchemeSetting) : 'system';
    const lang = (await SettingsStore.pref.get('language', 'system')) as string;
    m.language = (lang === 'zh' || lang === 'en' || lang === 'system') ? (lang as LanguageSetting) : 'system';
    const ai = (await SettingsStore.pref.get('aiModel', 'deepseek')) as string;
    m.aiModel = (ai === 'xiaoyi' || ai === 'qwen' || ai === 'deepseek' || ai === 'chatgpt' ||
      ai === 'yuanbao' || ai === 'glm' || ai === 'kimi' || ai === 'ernie' || ai === 'custom')
      ? (ai as AIModelKind)
      : 'deepseek';
    m.apiKey = (await SettingsStore.pref.get('apiKey', '')) as string;
    m.baseUrl = (await SettingsStore.pref.get('baseUrl', 'https://api.deepseek.com/v1')) as string;
    m.modelName = (await SettingsStore.pref.get('modelName', 'deepseek-chat')) as string;
    return m;
  }

  static async save(m: SettingsModel): Promise<void> {
    if (SettingsStore.pref === undefined) {
      return;
    }
    await SettingsStore.pref.put('colorScheme', m.colorScheme);
    await SettingsStore.pref.put('language', m.language);
    await SettingsStore.pref.put('aiModel', m.aiModel);
    await SettingsStore.pref.put('apiKey', m.apiKey);
    await SettingsStore.pref.put('baseUrl', m.baseUrl);
    await SettingsStore.pref.put('modelName', m.modelName);
    await SettingsStore.pref.flush();

    // 同时镜像到 RDB settings 表（快照）
    await SettingsRepository.set('colorScheme', m.colorScheme);
    await SettingsRepository.set('language', m.language);
    await SettingsRepository.set('aiModel', m.aiModel);
    await SettingsRepository.set('apiKey', m.apiKey);
    await SettingsRepository.set('baseUrl', m.baseUrl);
    await SettingsRepository.set('modelName', m.modelName);
  }
}