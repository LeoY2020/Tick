import { Goal } from '../model/Goal';
import { TaskItem } from '../model/TaskItem';
import { TaskStatus, ProgressCountingMode } from '../model/Enums';

/** 进度对 (current, total) */
export interface ProgressPair {
  current: number;
  total: number;
}

/** 目标总进度结果 */
export interface GoalProgress {
  /** 计入总量的任务数（删除态不计） */
  totalItems: number;
  /** 加权完成度（单项完成=1 半完成=0.5；进度=比率） */
  completedWeight: number;
  /** completedWeight / totalItems，无任务时为 0 */
  fraction: number;
}

/**
 * 递归进度计算引擎：自底向上汇总（纯计算，不修改模型数据）。
 * 完整复刻 spec 中的接管 / 折算 / 统计 / 继承链逻辑。
 */
export class ProgressEngine {
  // MARK: - 有效状态与有效进度

  /** 有效状态：有子任务（被接管）时由直接子任务计算，否则用手动状态 */
  static effectiveStatus(task: TaskItem): TaskStatus {
    // 未接管：手动状态
    if (!task.hasSubtasks) {
      return task.status;
    }

    // 被接管：由直接子任务折算（删除态子任务跳过）
    let hasDone = false;
    let hasHalf = false;
    let hasNotDone = false;
    for (const sub of task.subtasks) {
      if (ProgressEngine.isDeleted(sub)) {
        continue;
      }
      const s = ProgressEngine.subtaskStatus(sub);
      if (s === 'done') {
        hasDone = true;
      } else if (s === 'halfDone') {
        hasHalf = true;
      } else if (s === 'notDone') {
        hasNotDone = true;
      }
    }
    // 有效子任务全部删除 → 接管解除，回落手动状态
    if (!hasDone && !hasHalf && !hasNotDone) {
      return task.status;
    }
    // 全部完成 → 完成；存在半完成或混合 → 半完成；否则未完成
    if (hasHalf || (hasDone && hasNotDone)) {
      return 'halfDone';
    }
    return hasDone ? 'done' : 'notDone';
  }

  /** 有效进度：有子任务（被接管）时由直接子任务汇总，否则用手动值（clamp 到 0...total） */
  static effectiveProgress(task: TaskItem): ProgressPair {
    // 未接管：手动值
    if (!task.hasSubtasks) {
      return ProgressEngine.manualProgress(task);
    }

    // 被接管：当前=子任务当前之和，总量=子任务总量之和（忽略手动总量）
    let current = 0;
    let total = 0;
    let hasCounting = false;
    for (const sub of task.subtasks) {
      if (ProgressEngine.isDeleted(sub)) {
        continue;
      }
      hasCounting = true;
      const contribution = ProgressEngine.childContribution(sub);
      current += contribution.current;
      total += contribution.total;
    }
    // 有效子任务全部删除 → 接管解除，回落手动值
    if (hasCounting) {
      return { current, total };
    }
    return ProgressEngine.manualProgress(task);
  }

  // MARK: - 目标总进度

  /** 目标总进度：按目标设置的统计模式递归统计整棵任务树，删除态任务整棵子树不计入 */
  static goalProgress(goal: Goal): GoalProgress {
    let totalItems = 0;
    let completedWeight = 0;
    for (const task of goal.tasks) {
      const r = ProgressEngine.accumulate(task, goal.progressCountingMode);
      totalItems += r.total;
      completedWeight += r.current;
    }
    const fraction = totalItems === 0 ? 0 : completedWeight / totalItems;
    return {
      totalItems,
      completedWeight,
      fraction
    };
  }

  // MARK: - 继承链解析

  /** 有效颜色：子任务 → 父任务 → … → 父目标，取最近已设置值；最终回退 "#000000" */
  static effectiveColor(task: TaskItem): string {
    let cursor: TaskItem | undefined = task;
    while (cursor !== undefined) {
      if (cursor.colorHex !== undefined && cursor.colorHex.trim().length > 0) {
        return cursor.colorHex;
      }
      cursor = ProgressEngine.parentOf(cursor);
    }
    const goal = ProgressEngine.rootGoal(task);
    if (goal !== undefined && goal.colorHex !== undefined && goal.colorHex.trim().length > 0) {
      return goal.colorHex;
    }
    return '#000000';
  }

  /** 有效图标：沿父链取最近已设置值，最终回退所属 Goal 的图标 */
  static effectiveIcon(task: TaskItem): string | undefined {
    let cursor: TaskItem | undefined = task;
    while (cursor !== undefined) {
      if (cursor.iconSystemName !== undefined && cursor.iconSystemName.trim().length > 0) {
        return cursor.iconSystemName;
      }
      cursor = ProgressEngine.parentOf(cursor);
    }
    const goal = ProgressEngine.rootGoal(task);
    if (goal !== undefined && goal.iconSystemName !== undefined && goal.iconSystemName.trim().length > 0) {
      return goal.iconSystemName;
    }
    return undefined;
  }

  /** 有效开始日期：沿父链取最近已设置值，最终回退所属 Goal */
  static effectiveStartDate(task: TaskItem): number | undefined {
    let cursor: TaskItem | undefined = task;
    while (cursor !== undefined) {
      if (cursor.startDate !== undefined) {
        return cursor.startDate;
      }
      cursor = ProgressEngine.parentOf(cursor);
    }
    const goal = ProgressEngine.rootGoal(task);
    return goal !== undefined ? goal.startDate : undefined;
  }

  /** 有效截止日期：沿父链取最近已设置值，最终回退所属 Goal */
  static effectiveEndDate(task: TaskItem): number | undefined {
    let cursor: TaskItem | undefined = task;
    while (cursor !== undefined) {
      if (cursor.endDate !== undefined) {
        return cursor.endDate;
      }
      cursor = ProgressEngine.parentOf(cursor);
    }
    const goal = ProgressEngine.rootGoal(task);
    return goal !== undefined ? goal.endDate : undefined;
  }

  /** 沿 parentTaskId 链向上找到所属 Goal */
  static rootGoal(task: TaskItem): Goal | undefined {
    let cursor: TaskItem | undefined = task;
    while (cursor !== undefined) {
      if (cursor.goalId !== undefined) {
        return ProgressEngine.lookupGoal(cursor.goalId);
      }
      cursor = ProgressEngine.parentOf(cursor);
    }
    return undefined;
  }

  // MARK: - 子任务贡献

  /** 单个子任务对父级进度汇总的贡献：单项 → (状态权重, 1)；进度 → 有效 (current, total) */
  static childContribution(task: TaskItem): ProgressPair {
    if (ProgressEngine.isDeleted(task)) {
      return { current: 0, total: 0 };
    }
    if (task.type === 'single') {
      return { current: ProgressEngine.statusWeight(ProgressEngine.effectiveStatus(task)), total: 1 };
    }
    return ProgressEngine.effectiveProgress(task);
  }

  /** 有效比率：current / total（total ≤ 0 时为 0，上限 1） */
  static effectiveRatio(task: TaskItem): number {
    const p = ProgressEngine.effectiveProgress(task);
    if (p.total <= 0) {
      return 0;
    }
    return Math.min(p.current / p.total, 1);
  }

  // MARK: - 私有辅助

  /** 按统计模式递归累计任务树（返回 [completedWeight, totalItems]） */
  private static accumulate(task: TaskItem, mode: ProgressCountingMode): ProgressPair {
    if (ProgressEngine.isDeleted(task)) {
      return { current: 0, total: 0 };
    }

    if (mode === 'allTasks') {
      let current = ProgressEngine.taskWeight(task);
      let total = 1;
      for (const sub of task.subtasks) {
        const r = ProgressEngine.accumulate(sub, mode);
        current += r.current;
        total += r.total;
      }
      return { current, total };
    }

    // leafTasks：有效（非删除）子任务为空 → 叶子节点计入；否则只递归子任务
    const active: TaskItem[] = [];
    for (const sub of task.subtasks) {
      if (!ProgressEngine.isDeleted(sub)) {
        active.push(sub);
      }
    }
    if (active.length === 0) {
      return { current: ProgressEngine.taskWeight(task), total: 1 };
    }
    let current = 0;
    let total = 0;
    for (const sub of active) {
      const r = ProgressEngine.accumulate(sub, mode);
      current += r.current;
      total += r.total;
    }
    return { current, total };
  }

  /** 单个任务节点的权重：单项 → 有效状态权重；进度 → 有效比率 */
  private static taskWeight(task: TaskItem): number {
    return task.type === 'single'
      ? ProgressEngine.statusWeight(ProgressEngine.effectiveStatus(task))
      : ProgressEngine.effectiveRatio(task);
  }

  /** 删除态判定：单项且状态为删除 */
  private static isDeleted(task: TaskItem): boolean {
    return task.type === 'single' && task.status === 'deleted';
  }

  /** 手动进度：current clamp 到 0...total，total 取非负 */
  private static manualProgress(task: TaskItem): ProgressPair {
    const total = Math.max(0, task.totalAmount);
    const current = Math.min(Math.max(task.currentAmount, 0), total);
    return { current, total };
  }

  /** 单项状态权重：完成=1 半完成=0.5 未完成/删除=0 */
  private static statusWeight(status: TaskStatus): number {
    switch (status) {
      case 'done':
        return 1;
      case 'halfDone':
        return 0.5;
      case 'notDone':
      case 'deleted':
        return 0;
    }
  }

  /** 子任务折算状态：单项用有效状态；进度按有效比率折算（1→完成，0<比率<1→半完成，0→未完成） */
  private static subtaskStatus(sub: TaskItem): TaskStatus {
    if (sub.type !== 'progress') {
      return ProgressEngine.effectiveStatus(sub);
    }
    const ratio = ProgressEngine.effectiveRatio(sub);
    if (ratio >= 1) {
      return 'done';
    }
    if (ratio > 0) {
      return 'halfDone';
    }
    return 'notDone';
  }

  // 任务/目标索引：供继承链回溯（避免 domain 依赖 data 层造成循环依赖）。
  private static taskRegistry: Map<string, TaskItem> | undefined = undefined;
  private static goalRegistry: Map<string, Goal> | undefined = undefined;

  /** 注册整棵任务树索引（供继承链按 parentTaskId 回溯父任务） */
  static registerTasks(tasks: TaskItem[]): void {
    ProgressEngine.taskRegistry = new Map<string, TaskItem>();
    for (const t of tasks) {
      ProgressEngine.indexTask(t);
    }
  }

  private static indexTask(task: TaskItem): void {
    if (ProgressEngine.taskRegistry !== undefined) {
      ProgressEngine.taskRegistry.set(task.id, task);
    }
    for (const sub of task.subtasks) {
      ProgressEngine.indexTask(sub);
    }
  }

  /** 注册目标索引（供继承链 rootGoal 反查） */
  static registerGoals(goals: Goal[]): void {
    ProgressEngine.goalRegistry = new Map<string, Goal>();
    for (const g of goals) {
      ProgressEngine.goalRegistry.set(g.id, g);
    }
  }

  /** 沿 parentTaskId 找到父任务实体 */
  private static parentOf(task: TaskItem): TaskItem | undefined {
    if (task.parentTaskId === undefined || ProgressEngine.taskRegistry === undefined) {
      return undefined;
    }
    return ProgressEngine.taskRegistry.get(task.parentTaskId);
  }

  private static lookupGoal(id: string): Goal | undefined {
    return ProgressEngine.goalRegistry !== undefined ? ProgressEngine.goalRegistry.get(id) : undefined;
  }
}