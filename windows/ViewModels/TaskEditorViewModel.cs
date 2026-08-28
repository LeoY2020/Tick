using System.Collections.Generic;
using Tick.Models;
using Tick.Services;

namespace Tick.ViewModels;

/// <summary>
/// 任务编辑器 ViewModel：持有可编辑的工作副本（取消时丢弃），提供类型 / 状态 / 重复规则选项。
/// </summary>
public sealed class TaskEditorViewModel : ViewModelBase
{
    /// <summary>工作副本：确认时写回数据库，取消时丢弃。</summary>
    public TaskItem Task { get; }

    public bool IsNew { get; }

    public IReadOnlyList<TaskType> Types { get; } = new[] { TaskType.Single, TaskType.Progress };

    public IReadOnlyList<TaskStatus> Statuses { get; } = new[] { TaskStatus.NotDone, TaskStatus.HalfDone, TaskStatus.Done, TaskStatus.Deleted };

    public IReadOnlyList<RepeatRule> RepeatRules { get; } =
        new[] { RepeatRule.Never, RepeatRule.Daily, RepeatRule.Weekly, RepeatRule.Monthly, RepeatRule.Custom };

    /// <summary>自定义重复的星期（1=周日…7=周六）是否勾选</summary>
    public bool[] WeekdayChecked { get; } = new bool[8];

    /// <summary>是否可编辑类型（已有子任务被接管后类型不允许再改：会破坏归纳语义；新建或叶子任务可改）</summary>
    public bool CanEditType { get; }

    public string Error { get; private set; } = "";

    public TaskEditorViewModel(TaskItem? task = null, bool canEditType = true)
    {
        IsNew = task is null;
        CanEditType = canEditType;
        Task = task is null ? new TaskItem() : Clone(task);
        foreach (var w in Task.EffectiveWeekdays())
            if (w is >= 1 and <= 7)
                WeekdayChecked[w] = true;
    }

    public bool HasReminder => Task.ReminderDate is not null;

    /// <summary>从工作副本写回星期多选</summary>
    public void SyncWeekdaysFromChecked()
    {
        var list = new List<string>();
        for (int w = 1; w <= 7; w++)
            if (WeekdayChecked[w])
                list.Add(w.ToString());
        Task.CustomWeekdaysRaw = list.Count > 0 ? string.Join(",", list) : null;
    }

    public bool Validate()
    {
        if (string.IsNullOrWhiteSpace(Task.Name))
        {
            Error = "任务名称不能为空";
            return false;
        }
        Error = "";
        return true;
    }

    /// <summary>复制一份任务对象（避免直接改到原对象 / 原对象已存库）。带子任务时仅复制头信息。</summary>
    private static TaskItem Clone(TaskItem t) => new()
    {
        Id = t.Id,
        Name = t.Name,
        ColorHex = t.ColorHex,
        IconSystemName = t.IconSystemName,
        Type = t.Type,
        Status = t.Status,
        TotalAmount = t.TotalAmount,
        CurrentAmount = t.CurrentAmount,
        StartDate = t.StartDate,
        EndDate = t.EndDate,
        ReminderDate = t.ReminderDate,
        RepeatRule = t.RepeatRule,
        CustomWeekdaysRaw = t.CustomWeekdaysRaw,
        CreatedAt = t.CreatedAt,
        SortOrder = t.SortOrder,
        GoalId = t.GoalId,
        ParentTaskId = t.ParentTaskId,
        Goal = t.Goal,
        ParentTask = t.ParentTask,
        Subtasks = t.Subtasks,
    };
}