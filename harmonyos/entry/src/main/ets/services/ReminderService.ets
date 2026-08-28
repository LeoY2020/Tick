import reminderAgentManager from '@ohos.reminderAgentManager';
import notificationManager from '@ohos.notificationManager';
import common from '@ohos.app.ability.common';
import { TaskItem } from '../model/TaskItem';
import { RepeatRule } from '../model/Enums';
import { toWeekdayCode } from '../model/Util';

/** 提醒触发配置（纯逻辑，可测试） */
export interface TriggerPlacement {
  identifier: string;
  year: number | undefined;
  month: number | undefined;
  day: number | undefined;
  hour: number;
  minute: number;
  /** 星期（1=周日…7=周六，与 spec 一致） */
  weekday: number | undefined;
}

/**
 * 本地通知提醒服务：
 * 请求通知权限 → 按重复规则生成触发配置 → 通过 reminderAgentManager 发布日历提醒。
 * 幂等：每次 schedule 前先取消该任务已发布的提醒。
 */
export class ReminderService {
  /** 运行期记录已发布的提醒 id（按任务聚合，用于取消） */
  private static activeReminders: Map<string, number[]> = new Map<string, number[]>();

  /** 请求通知权限（reminder 的 PUBLISH_AGENT_REMINDER 为 normal 级，已在 module.json5 声明） */
  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      await notificationManager.requestEnableNotification(context);
      return true;
    } catch (e) {
      return false;
    }
  }

  /** 为任务注册提醒：先取消旧请求，再按重复规则逐条发布 */
  static async schedule(task: TaskItem, goalName: string): Promise<void> {
    if (task.reminderDate === undefined) {
      return;
    }
    await ReminderService.cancel(task.id);

    const rule: RepeatRule = task.repeatRule === undefined ? 'never' : task.repeatRule;
    const placements = ReminderService.triggerPlacements(rule, task.reminderDate, task.effectiveWeekdays(), task.id);

    const ids: number[] = [];
    for (const p of placements) {
      const reminderId = await ReminderService.publishPlacement(p, task.name, goalName);
      if (reminderId >= 0) {
        ids.push(reminderId);
      }
    }
    ReminderService.activeReminders.set(task.id, ids);
  }

  /** 取消任务全部提醒 */
  static async cancel(taskId: string): Promise<void> {
    const ids = ReminderService.activeReminders.get(taskId);
    if (ids !== undefined) {
      for (const rid of ids) {
        try {
          await reminderAgentManager.cancelReminder(rid);
        } catch (e) {
          // 忽略：可能已被系统移除
        }
      }
    }
    ReminderService.activeReminders.delete(taskId);
  }

  /** 根据重复规则生成触发器配置与标识符（纯逻辑） */
  static triggerPlacements(rule: RepeatRule, dateMs: number, weekdays: number[], taskId: string): TriggerPlacement[] {
    const d = new Date(dateMs);
    const hour = d.getHours();
    const minute = d.getMinutes();

    switch (rule) {
      case 'never':
        return [{
          identifier: taskId,
          year: d.getFullYear(),
          month: d.getMonth() + 1,
          day: d.getDate(),
          hour: hour,
          minute: minute,
          weekday: undefined
        }];
      case 'daily':
        return [{
          identifier: taskId,
          year: undefined,
          month: undefined,
          day: undefined,
          hour: hour,
          minute: minute,
          weekday: undefined
        }];
      case 'weekly':
        return [{
          identifier: taskId,
          year: undefined,
          month: undefined,
          day: undefined,
          hour: hour,
          minute: minute,
          weekday: toWeekdayCode(d.getDay())
        }];
      case 'monthly':
        return [{
          identifier: taskId,
          year: undefined,
          month: undefined,
          day: d.getDate(),
          hour: hour,
          minute: minute,
          weekday: undefined
        }];
      case 'custom': {
        const valid: number[] = [];
        for (const w of weekdays) {
          if (w >= 1 && w <= 7 && valid.indexOf(w) < 0) {
            valid.push(w);
          }
        }
        if (valid.length === 0) {
          // 未选择周几时回退为每天
          return [{
            identifier: taskId,
            year: undefined,
            month: undefined,
            day: undefined,
            hour: hour,
            minute: minute,
            weekday: undefined
          }];
        }
        const placements: TriggerPlacement[] = [];
        for (const w of valid) {
          placements.push({
            identifier: taskId + '-w' + w.toString(),
            year: undefined,
            month: undefined,
            day: undefined,
            hour: hour,
            minute: minute,
            weekday: w
          });
        }
        return placements;
      }
    }
  }

  private static async publishPlacement(p: TriggerPlacement, title: string, goalName: string): Promise<number> {
    const dateTime: reminderAgentManager.LocalDateTime = {
      year: p.year === undefined ? 2000 : p.year,
      month: p.month === undefined ? 1 : p.month,
      day: p.day === undefined ? 1 : p.day,
      hour: p.hour,
      minute: p.minute,
      second: 0
    };
    const req: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: dateTime,
      title: title,
      content: '目标：' + goalName
    };
    if (p.year === undefined) {
      if (p.weekday !== undefined) {
        req.repeatDaysOfWeek = [p.weekday];
      } else if (p.day !== undefined) {
        req.daysOfMonth = [p.day];
      } else {
        req.repeatDaysOfWeek = [1, 2, 3, 4, 5, 6, 7];
      }
    }
    return await reminderAgentManager.publishReminder(req);
  }
}