import { ProgressCountingMode } from './Enums';
import { TaskItem } from './TaskItem';
import { genId, now } from './Util';

/**
 * 目标：顶层组织单元。
 * startDate/endDate 为时间戳（毫秒），undefined 表示未设置。
 */
export class Goal {
  id: string = '';
  name: string = '';
  /** 颜色 HEX（如 "#000000"；"auto" = 自动：深色白 / 浅色黑） */
  colorHex: string = 'auto';
  /** 图标名（undefined = 未设置） */
  iconSystemName: string | undefined = undefined;
  /** 开始时间戳（undefined = 未设置） */
  startDate: number | undefined = undefined;
  /** 截止时间戳（undefined = 未设置） */
  endDate: number | undefined = undefined;
  /** 开始时间是否精确到小时 */
  startDatePreciseToHour: boolean = false;
  /** 截止时间是否精确到小时 */
  endDatePreciseToHour: boolean = false;
  createdAt: number = 0;
  /** 进度统计模式（默认 allTasks） */
  progressCountingMode: ProgressCountingMode = 'allTasks';
  /** 目标下的一级任务（内存树；持久化由 Repository 维护） */
  tasks: TaskItem[] = [];

  constructor(name: string = '') {
    this.id = genId();
    this.name = name;
    this.createdAt = now();
  }
}