namespace Tick.Models;

/// <summary>
/// 目标：顶层组织单元。
/// 所有字段使用可空或带默认值，保证数据库迁移与旧数据兼容。
/// </summary>
public class Goal
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string Name { get; set; } = "";

    /// <summary>颜色 HEX 字符串（如 "#000000"；"auto" = 自动：深色模式白 / 浅色模式黑）</summary>
    public string ColorHex { get; set; } = "auto";

    /// <summary>图标名（Segoe Fluent Icons 字形；null = 未设置）</summary>
    public string? IconSystemName { get; set; }

    /// <summary>开始日期（null = 未设置）</summary>
    public DateTime? StartDate { get; set; }

    /// <summary>截止日期（null = 未设置）</summary>
    public DateTime? EndDate { get; set; }

    /// <summary>开始时间是否精确到小时</summary>
    public bool StartDatePreciseToHour { get; set; }

    /// <summary>截止时间是否精确到小时（影响倒计时是否显示「时」）</summary>
    public bool EndDatePreciseToHour { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.Now;

    /// <summary>进度统计模式原始字符串（枚举存 raw string）</summary>
    public string ProgressCountingModeRaw { get; set; } = ProgressCountingMode.AllTasks.ToString();

    /// <summary>进度统计模式（读写映射枚举，未知／未设置回退 allTasks）</summary>
    public ProgressCountingMode ProgressCountingMode
    {
        get => Enum.TryParse<ProgressCountingMode>(ProgressCountingModeRaw, out var mode) ? mode : ProgressCountingMode.AllTasks;
        set => ProgressCountingModeRaw = value.ToString();
    }

    /// <summary>目标下的一级任务（删除目标时级联删除全部任务）</summary>
    public List<TaskItem> Tasks { get; set; } = new();

    public Goal() { }

    public Goal(string name,
                string colorHex = "auto",
                string? iconSystemName = null,
                DateTime? startDate = null,
                DateTime? endDate = null,
                bool startDatePreciseToHour = false,
                bool endDatePreciseToHour = false,
                ProgressCountingMode progressCountingMode = ProgressCountingMode.AllTasks)
    {
        Name = name;
        ColorHex = colorHex;
        IconSystemName = iconSystemName;
        StartDate = startDate;
        EndDate = endDate;
        StartDatePreciseToHour = startDatePreciseToHour;
        EndDatePreciseToHour = endDatePreciseToHour;
        ProgressCountingMode = progressCountingMode;
    }
}