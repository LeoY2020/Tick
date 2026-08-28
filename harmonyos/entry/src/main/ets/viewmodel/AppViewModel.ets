import { Goal } from '../model/Goal';
import { TaskItem } from '../model/TaskItem';
import { GoalRepository, TaskRepository } from '../data/Repositories';
import { ProgressEngine, GoalProgress } from '../domain/ProgressEngine';
import { TaskStatus, TaskType, RepeatRule } from '../model/Enums';
import { ReminderService } from '../services/ReminderService';

/** 任务树的扁平化行（用于 List 渲染无限层级） */
export interface TaskRow {
  task: TaskItem;
  depth: number;
  hasChildren: boolean;
  expanded: boolean;
}

/** 目标总进度展示数据 */
export interface GoalProgressView {
  totalItems: number;
  completedWeight: number;
  fraction: number;
}

function taskCompare(a: TaskItem, b: TaskItem): number {
  if (a.sortOrder !== b.sortOrder) {
    return a.sortOrder - b.sortOrder;
  }
  return a.createdAt - b.createdAt;
}

/**
 * View Model：负责数据协调、任务树扁平化、进度计算与持久化编排。
 * 页面持有自己的 @State，通过调用本类方法读写 RDB 并重建视图数据。
 */
export class AppViewModel {

  // MARK: - 目标 / 任务加载

  static async loadGoals(): Promise<Goal[]> {
    const goals = await GoalRepository.list();
    ProgressEngine.registerGoals(goals);
    return goals;
  }

  /** 加载指定目标的完整任务树（自引用级联），并注册继承链索引 */
  static async loadGoalTree(goalId: string): Promise<TaskItem[]> {
    const tree = await TaskRepository.buildTree(goalId);
    ProgressEngine.registerTasks(tree);
    return tree;
  }

  // MARK: - 持久化

  static async createGoal(name: string, colorHex: string, iconSystemName: string | undefined,
    startDate: number | undefined, endDate: number | undefined,
    startPrecise: boolean, endPrecise: boolean, mode: 'allTasks' | 'leafTasks'): Promise<Goal> {
    const g = new Goal(name);
    g.colorHex = colorHex;
    g.iconSystemName = iconSystemName;
    g.startDate = startDate;
    g.endDate = endDate;
    g.startDatePreciseToHour = startPrecise;
    g.endDatePreciseToHour = endPrecise;
    g.progressCountingMode = mode;
    await GoalRepository.save(g);
    return g;
  }

  static async updateGoal(goal: Goal): Promise<void> {
    await GoalRepository.save(goal);
  }

  /** 删除目标（级联删除其下全部任务，并取消相关提醒） */
  static async deleteGoal(id: string): Promise<void> {
    const tree = await TaskRepository.buildTree(id);
    const all: TaskItem[] = [];
    AppViewModel.collectTasks(tree, all);
    for (const t of all) {
      if (t.reminderDate !== undefined) {
        await ReminderService.cancel(t.id);
      }
    }
    await GoalRepository.deleteCascade(id);
  }

  static async saveTask(task: TaskItem): Promise<void> {
    await TaskRepository.save(task);
  }

  /** 级联删除任务：取消该任务及其后代全部提醒后再删除 */
  static async deleteTask(id: string): Promise<void> {
    const ids = await TaskRepository.descendantIds(id);
    for (const tid of ids) {
      await ReminderService.cancel(tid);
    }
    await TaskRepository.deleteCascade(id);
  }

  /** 新增一级任务或子任务 */
  static async addTask(name: string, type: TaskType, goalId: string | undefined, parentId: string | undefined,
    status: TaskStatus = 'notDone', totalAmount = 0, currentAmount = 0,
    reminderDate: number | undefined = undefined, repeatRule: RepeatRule | undefined = undefined,
    customWeekdays: string | undefined = undefined, sortOrder = 0): Promise<TaskItem> {
    const t = new TaskItem(name);
    t.type = type;
    t.status = status;
    t.totalAmount = Math.max(0, totalAmount);
    t.currentAmount = Math.min(Math.max(currentAmount, 0), t.totalAmount);
    t.reminderDate = reminderDate;
    t.repeatRule = repeatRule;
    t.customWeekdaysRaw = customWeekdays;
    t.sortOrder = sortOrder;
    if (parentId !== undefined) {
      t.attachToParent(parentId);
    } else if (goalId !== undefined) {
      t.attachToGoal(goalId);
    }
    await TaskRepository.save(t);
    if (reminderDate !== undefined) {
      const goalName = await AppViewModel.goalNameOf(goalId);
      await ReminderService.schedule(t, goalName);
    }
    return t;
  }

  static async goalNameOf(goalId: string | undefined): Promise<string> {
    if (goalId === undefined) {
      return '';
    }
    const g = await GoalRepository.find(goalId);
    return (g === undefined || g === null) ? '' : g.name;
  }

  // MARK: - 任务树操作

  /** 把新建/编辑后的任务合并进现有树（同步更新内存树） */
  static upsertInTree(tree: TaskItem[], task: TaskItem): TaskItem[] {
    const target = AppViewModel.findInTree(tree, task.id);
    if (target !== undefined) {
      Object.assign(target, task);
      return tree;
    }
    if (task.parentTaskId === undefined) {
      tree.push(Object.assign(new TaskItem(), task));
      return tree;
    }
    const parent = AppViewModel.findInTree(tree, task.parentTaskId);
    if (parent !== undefined) {
      parent.subtasks.push(Object.assign(new TaskItem(), task));
    } else {
      tree.push(Object.assign(new TaskItem(), task));
    }
    return tree;
  }

  static findInTree(tree: TaskItem[], id: string): TaskItem | undefined {
    for (const t of tree) {
      if (t.id === id) {
        return t;
      }
      const found = AppViewModel.findInTree(t.subtasks, id);
      if (found !== undefined) {
        return found;
      }
    }
    return undefined;
  }

  /** 展示即将新增子任务的最小可用 sortOrder */
  static nextSortOrderOfDirectChildren(children: TaskItem[]): number {
    let max = 0;
    for (const c of children) {
      if (c.sortOrder > max) {
        max = c.sortOrder;
      }
    }
    return max + 1;
  }

  // MARK: - 扁平化渲染

  static sortChildren(children: TaskItem[]): TaskItem[] {
    const copy: TaskItem[] = [];
    for (const c of children) {
      copy.push(c);
    }
    copy.sort(taskCompare);
    return copy;
  }

  static flatten(tree: TaskItem[], expanded: ReadonlySet<string>): TaskRow[] {
    const out: TaskRow[] = [];
    AppViewModel.flattenInto(AppViewModel.sortChildren(tree), expanded, 0, out);
    return out;
  }

  private static flattenInto(list: TaskItem[], expanded: ReadonlySet<string>, depth: number, out: TaskRow[]): void {
    for (const t of list) {
      const hasChildren = t.subtasks.length > 0;
      out.push({ task: t, depth: depth, hasChildren: hasChildren, expanded: expanded.has(t.id) });
      if (hasChildren && expanded.has(t.id)) {
        AppViewModel.flattenInto(AppViewModel.sortChildren(t.subtasks), expanded, depth + 1, out);
      }
    }
  }

  // MARK: - 进度计算（委托引擎，含继承链）

  static goalProgress(goal: Goal): GoalProgressView {
    const p: GoalProgress = ProgressEngine.goalProgress(goal);
    return { totalItems: p.totalItems, completedWeight: p.completedWeight, fraction: p.fraction };
  }

  static effectiveStatus(task: TaskItem): TaskStatus {
    return ProgressEngine.effectiveStatus(task);
  }

  static effectiveProgress(task: TaskItem): { current: number; total: number } {
    return ProgressEngine.effectiveProgress(task);
  }

  static effectiveColor(task: TaskItem): string {
    return ProgressEngine.effectiveColor(task);
  }

  static isDeleted(task: TaskItem): boolean {
    return task.type === 'single' && task.status === 'deleted';
  }

  // MARK: - 私有

  private static collectTasks(tree: TaskItem[], acc: TaskItem[]): void {
    for (const t of tree) {
      acc.push(t);
      AppViewModel.collectTasks(t.subtasks, acc);
    }
  }
}