using Tick.Models;

namespace Tick.Domain;

/// <summary>
/// 目标总进度结果
/// </summary>
public readonly struct GoalProgress
{
    /// <summary>计入总量的任务数（删除态不计）</summary>
    public int TotalItems { get; }

    /// <summary>加权完成度（单项完成=1 半完成=0.5；进度=比率）</summary>
    public double CompletedWeight { get; }

    /// <summary>completedWeight / totalItems，无任务时为 0</summary>
    public double Fraction => TotalItems == 0 ? 0 : CompletedWeight / TotalItems;

    public GoalProgress(int totalItems, double completedWeight)
    {
        TotalItems = totalItems;
        CompletedWeight = completedWeight;
    }
}

/// <summary>
/// 递归进度计算引擎：自底向上汇总（纯计算，不修改模型数据）。
/// 精确复刻 iOS 版 ProgressEngine 的语义（接管 / 继承链 / 统计模式 / 删除态）。
/// </summary>
public static class ProgressEngine
{
    // ---- 有效状态与有效进度 ----

    /// <summary>有效状态：有子任务（被接管）时由直接子任务计算，否则用手动状态</summary>
    public static TaskStatus EffectiveStatus(TaskItem task)
    {
        // 未接管：手动状态
        if (!task.HasSubtasks)
            return task.Status;

        // 被接管：由直接子任务折算（删除态子任务跳过）
        bool hasDone = false, hasHalf = false, hasNotDone = false;
        foreach (var sub in task.Subtasks)
        {
            if (IsDeleted(sub))
                continue;
            switch (SubtaskStatus(sub))
            {
                case TaskStatus.Done: hasDone = true; break;
                case TaskStatus.HalfDone: hasHalf = true; break;
                case TaskStatus.NotDone: hasNotDone = true; break;
            }
        }

        // 有效子任务全部删除 → 接管解除，回落手动状态
        if (!hasDone && !hasHalf && !hasNotDone)
            return task.Status;

        // 存在半完成或（完成 + 未完成混合）→ 半完成；否则全完成→完成 / 全未完成→未完成
        if (hasHalf || (hasDone && hasNotDone))
            return TaskStatus.HalfDone;
        return hasDone ? TaskStatus.Done : TaskStatus.NotDone;
    }

    /// <summary>有效进度：有子任务（被接管）时由直接子任务汇总，否则用手动值（clamp 到 0...total）</summary>
    public static (double Current, double Total) EffectiveProgress(TaskItem task)
    {
        // 未接管：手动值
        if (!task.HasSubtasks)
            return ManualProgress(task);

        // 被接管：当前=子任务贡献之和，总量=子任务贡献之和（忽略手动总量）
        double current = 0, total = 0;
        bool hasCounting = false;
        foreach (var sub in task.Subtasks)
        {
            if (IsDeleted(sub))
                continue;
            hasCounting = true;
            var contribution = ChildContribution(sub);
            current += contribution.Current;
            total += contribution.Total;
        }

        // 有效子任务全部删除 → 接管解除，回落手动值
        if (hasCounting)
            return (current, total);
        return ManualProgress(task);
    }

    // ---- 目标总进度 ----

    /// <summary>
    /// 目标总进度：按目标设置的统计模式递归统计整棵任务树，删除态任务整棵子树不计入。
    /// - AllTasks：所有层级任务均计入总量与进度（父任务按有效状态 / 进度折算）
    /// - LeafTasks：仅统计任务树末端节点（无有效子任务的节点）
    /// </summary>
    public static GoalProgress GoalProgressOf(Goal goal)
    {
        int totalItems = 0;
        double completedWeight = 0;
        foreach (var task in goal.Tasks)
            Accumulate(task, goal.ProgressCountingMode, ref totalItems, ref completedWeight);
        return new GoalProgress(totalItems, completedWeight);
    }

    // ---- 继承链解析 ----

    /// <summary>有效颜色：子任务 → 父任务 → … → 目标，取最近已设置值；最终回退 "#000000"</summary>
    public static string EffectiveColor(TaskItem task)
    {
        TaskItem? cursor = task;
        while (cursor is not null)
        {
            if (!string.IsNullOrEmpty(cursor.ColorHex))
                return cursor.ColorHex;
            cursor = cursor.ParentTask;
        }
        return RootGoal(task)?.ColorHex ?? "#000000";
    }

    /// <summary>有效图标：沿父链取最近已设置值，最终回退所属 Goal 的图标</summary>
    public static string? EffectiveIcon(TaskItem task)
    {
        TaskItem? cursor = task;
        while (cursor is not null)
        {
            if (!string.IsNullOrEmpty(cursor.IconSystemName))
                return cursor.IconSystemName;
            cursor = cursor.ParentTask;
        }
        return RootGoal(task)?.IconSystemName;
    }

    /// <summary>有效开始日期：沿父链取最近已设置值，最终回退所属 Goal</summary>
    public static DateTime? EffectiveStartDate(TaskItem task)
    {
        TaskItem? cursor = task;
        while (cursor is not null)
        {
            if (cursor.StartDate is not null)
                return cursor.StartDate;
            cursor = cursor.ParentTask;
        }
        return RootGoal(task)?.StartDate;
    }

    /// <summary>有效截止日期：沿父链取最近已设置值，最终回退所属 Goal</summary>
    public static DateTime? EffectiveEndDate(TaskItem task)
    {
        TaskItem? cursor = task;
        while (cursor is not null)
        {
            if (cursor.EndDate is not null)
                return cursor.EndDate;
            cursor = cursor.ParentTask;
        }
        return RootGoal(task)?.EndDate;
    }

    /// <summary>沿 parentTask 链向上找到所属 Goal</summary>
    public static Goal? RootGoal(TaskItem task)
    {
        TaskItem? cursor = task;
        while (cursor is not null)
        {
            if (cursor.Goal is not null)
                return cursor.Goal;
            cursor = cursor.ParentTask;
        }
        return null;
    }

    // ---- 子任务贡献 ----

    /// <summary>
    /// 单个子任务对父级进度汇总的贡献：单项 → (状态权重, 1)；进度 → 有效 (current, total)。
    /// 删除态单项不计入（返回 (0, 0)）。
    /// </summary>
    public static (double Current, double Total) ChildContribution(TaskItem task)
    {
        if (IsDeleted(task))
            return (0, 0);
        if (task.Type == TaskType.Single)
            return (StatusWeight(EffectiveStatus(task)), 1);
        return EffectiveProgress(task);
    }

    // ---- 私有辅助 ----

    /// <summary>按统计模式递归累计任务树（GoalProgress 的核心递归）</summary>
    private static void Accumulate(TaskItem task, ProgressCountingMode mode, ref int totalItems, ref double completedWeight)
    {
        // 删除态：整棵子树不计入总量与进度
        if (IsDeleted(task))
            return;

        switch (mode)
        {
            case ProgressCountingMode.AllTasks:
                totalItems += 1;
                completedWeight += TaskWeight(task);
                foreach (var sub in task.Subtasks)
                    Accumulate(sub, mode, ref totalItems, ref completedWeight);
                break;

            case ProgressCountingMode.LeafTasks:
                var active = new List<TaskItem>();
                foreach (var sub in task.Subtasks)
                    if (!IsDeleted(sub))
                        active.Add(sub);

                if (active.Count == 0)
                {
                    totalItems += 1;
                    completedWeight += TaskWeight(task);
                }
                else
                {
                    foreach (var sub in active)
                        Accumulate(sub, mode, ref totalItems, ref completedWeight);
                }
                break;
        }
    }

    /// <summary>单个任务节点的权重：单项 → 有效状态权重；进度 → 有效比率</summary>
    private static double TaskWeight(TaskItem task) =>
        task.Type == TaskType.Single
            ? StatusWeight(EffectiveStatus(task))
            : EffectiveRatio(task);

    /// <summary>删除态判定：单项且状态为删除（任何层级均不计入总量和进度）</summary>
    private static bool IsDeleted(TaskItem task) =>
        task.Type == TaskType.Single && task.Status == TaskStatus.Deleted;

    /// <summary>手动进度：current clamp 到 0...total，total 取非负</summary>
    private static (double Current, double Total) ManualProgress(TaskItem task)
    {
        double total = Math.Max(0, task.TotalAmount);
        double current = Math.Clamp(task.CurrentAmount, 0, total);
        return (current, total);
    }

    /// <summary>单项状态权重：完成=1 半完成=0.5 其余=0</summary>
    private static double StatusWeight(TaskStatus status) => status switch
    {
        TaskStatus.Done => 1,
        TaskStatus.HalfDone => 0.5,
        _ => 0,
    };

    /// <summary>子任务折算状态：单项用有效状态；进度按有效比率折算（1→完成，0&lt;比率&lt;1→半完成，0→未完成）</summary>
    private static TaskStatus SubtaskStatus(TaskItem sub)
    {
        if (sub.Type != TaskType.Progress)
            return EffectiveStatus(sub);
        double ratio = EffectiveRatio(sub);
        if (ratio >= 1) return TaskStatus.Done;
        if (ratio > 0) return TaskStatus.HalfDone;
        return TaskStatus.NotDone;
    }

    /// <summary>有效比率：current / total（total ≤ 0 时为 0，上限 1）</summary>
    private static double EffectiveRatio(TaskItem task)
    {
        var progress = EffectiveProgress(task);
        if (progress.Total <= 0)
            return 0;
        return Math.Min(progress.Current / progress.Total, 1);
    }
}