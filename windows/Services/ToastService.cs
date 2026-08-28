using Tick.Models;
using Windows.Data.Xml.Dom;
using Windows.UI.Notifications;

namespace Tick.Services;

/// <summary>一次计划提醒的触发描述</summary>
public readonly record struct TriggerPlacement(string Identifier, DateTimeOffset DeliveryTime);

/// <summary>
/// 本地通知服务：提醒注册 / 取消、重复规则（不重复 / 每天 / 每周 / 每月 / 自定义周几），
/// 以及点击通知后的跳转目标解析。
/// </summary>
public sealed class ToastService
{
    /// <summary>计算各重复规则下一次触发时间（异步注册前的纯逻辑）</summary>
    public static List<TriggerPlacement> ComputeTriggers(
        RepeatRule rule, DateTime baseTime, IReadOnlyList<int> weekdays, string taskId)
    {
        var now = DateTime.Now;
        switch (rule)
        {
            case RepeatRule.Never:
                return new List<TriggerPlacement> { new(taskId, new DateTimeOffset(baseTime)) };

            case RepeatRule.Daily:
                return new List<TriggerPlacement> { new(taskId, new DateTimeOffset(NextDaily(baseTime, now))) };

            case RepeatRule.Weekly:
            {
                int weekday = (int)baseTime.DayOfWeek; // 0=周日…6=周六
                return new List<TriggerPlacement> { new(taskId, new DateTimeOffset(NextWeekly(baseTime, weekday, now))) };
            }

            case RepeatRule.Monthly:
                return new List<TriggerPlacement> { new(taskId, new DateTimeOffset(NextMonthly(baseTime, now))) };

            case RepeatRule.Custom:
            {
                var seen = new HashSet<int>();
                var valid = new List<int>();
                foreach (var w in weekdays)
                    if (w is >= 1 and <= 7 && seen.Add(w))
                        valid.Add(w);

                // 未选择周几时回退为每天
                if (valid.Count == 0)
                    return new List<TriggerPlacement> { new(taskId, new DateTimeOffset(NextDaily(baseTime, now))) };

                return valid
                    .Select(w => new TriggerPlacement($"{taskId}-w{w}", new DateTimeOffset(NextWeekly(baseTime, w - 1, now))))
                    .ToList();
            }

            default:
                return new List<TriggerPlacement> { new(taskId, new DateTimeOffset(baseTime)) };
        }
    }

    /// <summary>为任务注册提醒：先移除旧提醒，再按重复规则逐个注册计划通知</summary>
    public bool ScheduleReminder(TaskItem task, string goalName)
    {
        try
        {
            RemoveAllFor(task.Id);

            if (task.ReminderDate is not DateTime date)
                return false;

            var weekdays = task.EffectiveWeekdays();
            var rule = task.RepeatRule ?? RepeatRule.Never;
            var placements = ComputeTriggers(rule, date, weekdays, task.Id.ToString());

            var notifier = ToastNotificationManager.CreateToastNotifier();
            foreach (var p in placements)
            {
                var xml = ToastNotificationManager.GetTemplateContent(ToastTemplateType.ToastText02);
                var textNodes = xml.GetElementsByTagName("text");
                textNodes[0].AppendChild(xml.CreateTextNode(task.Name));
                textNodes[1].AppendChild(xml.CreateTextNode($"目标：{goalName}"));
                xml.DocumentElement.SetAttribute("launch", $"{task.Id}|{TaskGoalId(task) ?? Guid.Empty}");

                var scheduled = new ScheduledToastNotification(xml, p.DeliveryTime);
                notifier.AddToSchedule(scheduled);
            }
            return true;
        }
        catch
        {
            // 非打包 / 无 AppUserModelID 等环境下计划通知不可用，静默降级（不崩溃）
            return false;
        }
    }

    /// <summary>取消任务全部提醒</summary>
    public void RemoveAllFor(Guid taskId)
    {
        try
        {
            var notifier = ToastNotificationManager.CreateToastNotifier();
            foreach (var scheduled in notifier.GetScheduledToastNotifications())
            {
                string? launch = scheduled.Content?.DocumentElement?.GetAttribute("launch");
                if (launch is not null && launch.StartsWith(taskId + "|"))
                    notifier.RemoveFromSchedule(scheduled);
            }
        }
        catch
        {
            // 忽略取消失败
        }
    }

    /// <summary>从通知 launch 载荷解析跳转目标（taskId | goalId）</summary>
    public static (Guid taskId, Guid goalId)? ParseLaunch(string? launch)
    {
        if (string.IsNullOrEmpty(launch))
            return null;
        var parts = launch.Split('|');
        if (parts.Length < 2 || !Guid.TryParse(parts[0], out var taskId) || !Guid.TryParse(parts[1], out var goalId))
            return null;
        return (taskId, goalId);
    }

    /// <summary>沿父链向上定位任务所属目标 Id</summary>
    private static Guid? TaskGoalId(TaskItem task)
    {
        TaskItem? cursor = task;
        while (cursor is not null)
        {
            if (cursor.GoalId is Guid g)
                return g;
            cursor = cursor.ParentTask;
        }
        return null;
    }

    // ---- 下次触发时间计算 ----

    private static DateTime NextDaily(DateTime baseTime, DateTime now)
    {
        var candidate = now.Date.Add(baseTime.TimeOfDay);
        return candidate <= now ? candidate.AddDays(1) : candidate;
    }

    /// <param name="weekday">0=周日…6=周六</param>
    private static DateTime NextWeekly(DateTime baseTime, int weekday, DateTime now)
    {
        int target = ((weekday % 7) + 7) % 7;
        int diff = (target - (int)now.DayOfWeek + 7) % 7;
        var candidate = now.Date.AddDays(diff).Add(baseTime.TimeOfDay);
        return candidate <= now ? candidate.AddDays(7) : candidate;
    }

    private static DateTime NextMonthly(DateTime baseTime, DateTime now)
    {
        DateTime InMonth(int year, int month, int day, TimeSpan time)
        {
            int d = Math.Min(day, DateTime.DaysInMonth(year, month));
            return new DateTime(year, month, d).Add(time);
        }

        var candidate = InMonth(now.Year, now.Month, baseTime.Day, baseTime.TimeOfDay);
        if (candidate <= now)
        {
            var next = now.AddMonths(1);
            candidate = InMonth(next.Year, next.Month, baseTime.Day, baseTime.TimeOfDay);
        }
        return candidate;
    }
}