namespace Tick.Models;

/// <summary>
/// 任务：支持无限层级嵌套（自引用 ParentTask / Subtasks 关系）。
/// 顶层任务挂 Goal；子任务挂父任务，通过父链继承目标属性（与 Goal 互斥）。
/// 枚举均以 raw string 存储，避免迁移 / 解码崩溃。
/// </summary>
public class TaskItem
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string Name { get; set; } = "";

    /// <summary>颜色 HEX（null = 继承父级）</summary>
    public string? ColorHex { get; set; }

    /// <summary>图标名（null = 继承父级）</summary>
    public string? IconSystemName { get; set; }

    /// <summary>任务类型（枚举存 raw string）</summary>
    public string TypeRaw { get; set; } = TaskType.Single.ToString();

    /// <summary>任务状态（枚举存 raw string）</summary>
    public string StatusRaw { get; set; } = TaskStatus.NotDone.ToString();

    /// <summary>进度类型总量</summary>
    public double TotalAmount { get; set; }

    /// <summary>进度类型当前值（约束 0 ≤ 当前 ≤ 总量）</summary>
    public double CurrentAmount { get; set; }

    /// <summary>开始日期（null = 继承父级）</summary>
    public DateTime? StartDate { get; set; }

    /// <summary>截止日期（null = 继承父级）</summary>
    public DateTime? EndDate { get; set; }

    /// <summary>提醒时间（null = 不提醒）</summary>
    public DateTime? ReminderDate { get; set; }

    /// <summary>重复规则（null / never = 不重复，枚举存 raw string）</summary>
    public string? RepeatRuleRaw { get; set; }

    /// <summary>自定义重复的星期，逗号分隔（如 "1,3,5"，1=周日…7=周六）</summary>
    public string? CustomWeekdaysRaw { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.Now;

    /// <summary>排序值</summary>
    public int SortOrder { get; set; }

    // ---- 关系（持久化用 Id，内存对象图维护引用）----

    /// <summary>一级任务归属的目标 Id（与 ParentTaskId 互斥）</summary>
    public Guid? GoalId { get; set; }

    /// <summary>父任务 Id（null = 一级任务，与 GoalId 互斥）</summary>
    public Guid? ParentTaskId { get; set; }

    /// <summary>内存对象图：所属目标（一级任务）</summary>
    public Goal? Goal { get; set; }

    /// <summary>内存对象图：父任务（子任务）</summary>
    public TaskItem? ParentTask { get; set; }

    /// <summary>子任务（删除任务时级联删除全部后代）</summary>
    public List<TaskItem> Subtasks { get; set; } = new();

    // ---- 计算属性 ----

    /// <summary>任务类型（未知原始值回退 single）</summary>
    public TaskType Type
    {
        get => Enum.TryParse<TaskType>(TypeRaw, out var t) ? t : TaskType.Single;
        set => TypeRaw = value.ToString();
    }

    /// <summary>任务状态（未知原始值回退 notDone）</summary>
    public TaskStatus Status
    {
        get => Enum.TryParse<TaskStatus>(StatusRaw, out var s) ? s : TaskStatus.NotDone;
        set => StatusRaw = value.ToString();
    }

    /// <summary>重复规则（可选读写映射）</summary>
    public RepeatRule? RepeatRule
    {
        get => string.IsNullOrEmpty(RepeatRuleRaw) ? null : (Enum.TryParse<RepeatRule>(RepeatRuleRaw, out var r) ? r : null);
        set => RepeatRuleRaw = value?.ToString();
    }

    /// <summary>是否拥有子任务（接管机制判定依据）</summary>
    public bool HasSubtasks => Subtasks.Count > 0;

    // ---- 便捷方法 ----

    /// <summary>设置进度并 clamp 到 0...totalAmount</summary>
    public void SetProgress(double value)
    {
        CurrentAmount = Math.Clamp(value, 0, Math.Max(0, TotalAmount));
    }

    /// <summary>解析自定义重复的星期（1=周日…7=周六），过滤非法值</summary>
    public List<int> EffectiveWeekdays()
    {
        if (string.IsNullOrWhiteSpace(CustomWeekdaysRaw))
            return new List<int>();

        var result = new List<int>();
        foreach (var part in CustomWeekdaysRaw.Split(',', StringSplitOptions.RemoveEmptyEntries))
        {
            if (int.TryParse(part.Trim(), out var w) && w is >= 1 and <= 7)
                result.Add(w);
        }
        return result;
    }

    // ---- 关系维护（goal 与 parentTask 互斥）----

    /// <summary>脱离来源（并从父 / 目标集合中移除）</summary>
    private void Detach()
    {
        if (ParentTask is not null)
        {
            ParentTask.Subtasks.Remove(this);
            ParentTask = null;
            ParentTaskId = null;
        }
        if (Goal is not null)
        {
            Goal.Tasks.Remove(this);
            Goal = null;
            GoalId = null;
        }
    }

    /// <summary>作为一级任务挂到目标</summary>
    public void AttachTo(Goal goal)
    {
        Detach();
        Goal = goal;
        GoalId = goal.Id;
        goal.Tasks.Add(this);
    }

    /// <summary>作为子任务挂到父任务（通过父链继承目标属性）</summary>
    public void AttachTo(TaskItem parent)
    {
        Detach();
        ParentTask = parent;
        ParentTaskId = parent.Id;
        parent.Subtasks.Add(this);
    }

    // ---- 初始化 ----

    public TaskItem() { }

    public TaskItem(string name,
                    TaskType type = TaskType.Single,
                    string? colorHex = null,
                    string? iconSystemName = null,
                    TaskStatus status = TaskStatus.NotDone,
                    double totalAmount = 0,
                    double currentAmount = 0,
                    DateTime? startDate = null,
                    DateTime? endDate = null,
                    DateTime? reminderDate = null,
                    RepeatRule? repeatRule = null,
                    string? customWeekdaysRaw = null,
                    int sortOrder = 0)
    {
        Name = name;
        ColorHex = colorHex;
        IconSystemName = iconSystemName;
        Type = type;
        Status = status;
        var total = Math.Max(0, totalAmount);
        TotalAmount = total;
        CurrentAmount = Math.Clamp(currentAmount, 0, total);
        StartDate = startDate;
        EndDate = endDate;
        ReminderDate = reminderDate;
        RepeatRule = repeatRule;
        CustomWeekdaysRaw = customWeekdaysRaw;
        SortOrder = sortOrder;
    }
}