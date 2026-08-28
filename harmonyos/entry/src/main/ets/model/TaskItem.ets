import { TaskType, TaskStatus, RepeatRule, parseWeekdays } from './Enums';
import { genId, now, clamp } from './Util';

/**
 * 任务：支持无限层级嵌套（自引用 subtasks）。
 * goalId 与 parentTaskId 互斥：一级任务存 goalId，子任务存 parentTaskId。
 */
export class TaskItem {
  id: string = '';
  name: string = '';
  /** 颜色 HEX（undefined = 继承父级） */
  colorHex: string | undefined = undefined;
  /** 图标名（undefined = 继承父级） */
  iconSystemName: string | undefined = undefined;
  /** 任务类型（默认 single） */
  type: TaskType = 'single';
  /** 任务状态（默认 notDone） */
  status: TaskStatus = 'notDone';
  /** 进度类型总量 */
  totalAmount: number = 0;
  /** 进度类型当前值（约束 0 ≤ 当前 ≤ 总量） */
  currentAmount: number = 0;
  /** 开始时间戳（undefined = 继承父级） */
  startDate: number | undefined = undefined;
  /** 截止时间戳（undefined = 继承父级） */
  endDate: number | undefined = undefined;
  /** 提醒时间戳（undefined = 不提醒） */
  reminderDate: number | undefined = undefined;
  /** 重复规则（undefined = 不重复） */
  repeatRule: RepeatRule | undefined = undefined;
  /** 自定义重复的星期，逗号分隔（如 "1,3,5"，1=周日…7=周六） */
  customWeekdaysRaw: string | undefined = undefined;
  createdAt: number = 0;
  /** 排序值 */
  sortOrder: number = 0;
  /** 父任务 id（undefined = 一级任务，与 goalId 互斥） */
  parentTaskId: string | undefined = undefined;
  /** 归属目标 id（一级任务，与 parentTaskId 互斥） */
  goalId: string | undefined = undefined;
  /** 子任务（删除任务时级联删除全部后代） */
  subtasks: TaskItem[] = [];

  constructor(name: string = '') {
    this.id = genId();
    this.name = name;
    this.createdAt = now();
  }

  /** 是否拥有子任务（接管机制判定依据） */
  get hasSubtasks(): boolean {
    return this.subtasks.length > 0;
  }

  /** 作为一级任务挂到目标（goalId 与 parentTaskId 互斥） */
  attachToGoal(goalId: string): void {
    this.parentTaskId = undefined;
    this.goalId = goalId;
  }

  /** 作为子任务挂到父任务（通过父链继承目标属性） */
  attachToParent(parentId: string): void {
    this.goalId = undefined;
    this.parentTaskId = parentId;
  }

  /** 设置进度并 clamp 到 0...totalAmount */
  setProgress(value: number): void {
    this.currentAmount = clamp(value, 0, this.totalAmount);
  }

  /** 解析自定义重复的星期（1=周日…7=周六），过滤非法值 */
  effectiveWeekdays(): number[] {
    return parseWeekdays(this.customWeekdaysRaw);
  }
}