using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using Tick.Models;

namespace Tick.Services;

/// <summary>导出/导入备份页面选择文件后的 JSON 序列化器。</summary>
public sealed class JsonBackup
{
    /// <summary>JSON 序列化选项（宽松、保留缩进便于阅读）</summary>
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
    };

    /// <summary>导出全部目标（含任务树）为 JSON 字符串。</summary>
    public static string Serialize(IEnumerable<Goal> goals)
    {
        var doc = new BackupDocument { Goals = new List<GoalDto>() };
        foreach (var g in goals)
            doc.Goals.Add(GoalDto.From(g));
        return JsonSerializer.Serialize(doc, Options);
    }

    /// <summary>从 JSON 字符串还原目标列表（含任务树）。失败抛 <see cref="JsonException"/>。</summary>
    public static List<Goal> DeserializeIntoGoals(string json)
    {
        var doc = JsonSerializer.Deserialize<BackupDocument>(json, Options)
                  ?? throw new JsonException("备份文件格式无效");
        var result = new List<Goal>();
        foreach (var dto in doc.Goals ?? new List<GoalDto>())
            result.Add(dto.ToGoal());
        return result;
    }

    // ---- 备份文档模型 ----

    private sealed class BackupDocument
    {
        public string App { get; set; } = "Tick";
        public int Version { get; set; } = 1;
        public List<GoalDto>? Goals { get; set; }
    }

    private sealed class GoalDto
    {
        public Guid Id { get; set; }
        public string Name { get; set; } = "";
        public string ColorHex { get; set; } = "auto";
        public string? IconSystemName { get; set; }
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public bool StartDatePreciseToHour { get; set; }
        public bool EndDatePreciseToHour { get; set; }
        public DateTime CreatedAt { get; set; }
        public string ProgressCountingModeRaw { get; set; } = ProgressCountingMode.AllTasks.ToString();
        public List<TaskDto>? Tasks { get; set; }

        public static GoalDto From(Goal g) => new()
        {
            Id = g.Id,
            Name = g.Name,
            ColorHex = g.ColorHex,
            IconSystemName = g.IconSystemName,
            StartDate = g.StartDate,
            EndDate = g.EndDate,
            StartDatePreciseToHour = g.StartDatePreciseToHour,
            EndDatePreciseToHour = g.EndDatePreciseToHour,
            CreatedAt = g.CreatedAt,
            ProgressCountingModeRaw = g.ProgressCountingModeRaw,
            Tasks = TaskDto.FromList(g.Tasks),
        };

        public Goal ToGoal()
        {
            var goal = new Goal
            {
                Id = Id,
                Name = Name,
                ColorHex = ColorHex,
                IconSystemName = IconSystemName,
                StartDate = StartDate,
                EndDate = EndDate,
                StartDatePreciseToHour = StartDatePreciseToHour,
                EndDatePreciseToHour = EndDatePreciseToHour,
                CreatedAt = CreatedAt,
                ProgressCountingModeRaw = ProgressCountingModeRaw,
            };
            goal.Tasks.AddRange(TaskDto.TreeOf(Tasks));
            foreach (var task in goal.Tasks)
                task.Goal = goal;
            return goal;
        }
    }

    private sealed class TaskDto
    {
        public Guid Id { get; set; }
        public string Name { get; set; } = "";
        public string? ColorHex { get; set; }
        public string? IconSystemName { get; set; }
        public string TypeRaw { get; set; } = TaskType.Single.ToString();
        public string StatusRaw { get; set; } = TaskStatus.NotDone.ToString();
        public double TotalAmount { get; set; }
        public double CurrentAmount { get; set; }
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public DateTime? ReminderDate { get; set; }
        public string? RepeatRuleRaw { get; set; }
        public string? CustomWeekdaysRaw { get; set; }
        public DateTime CreatedAt { get; set; }
        public int SortOrder { get; set; }
        public List<TaskDto>? Subtasks { get; set; }

        public static List<TaskDto> FromList(IEnumerable<TaskItem> tasks)
        {
            var list = new List<TaskDto>();
            foreach (var t in tasks)
                list.Add(From(t));
            return list;
        }

        private static TaskDto From(TaskItem t) => new()
        {
            Id = t.Id,
            Name = t.Name,
            ColorHex = t.ColorHex,
            IconSystemName = t.IconSystemName,
            TypeRaw = t.TypeRaw,
            StatusRaw = t.StatusRaw,
            TotalAmount = t.TotalAmount,
            CurrentAmount = t.CurrentAmount,
            StartDate = t.StartDate,
            EndDate = t.EndDate,
            ReminderDate = t.ReminderDate,
            RepeatRuleRaw = t.RepeatRuleRaw,
            CustomWeekdaysRaw = t.CustomWeekdaysRaw,
            CreatedAt = t.CreatedAt,
            SortOrder = t.SortOrder,
            Subtasks = t.Subtasks.Count > 0 ? FromList(t.Subtasks) : null,
        };

        /// <summary>把 DTO 树还原为 TaskItem 对象图（重建父链，Goal 由外层填充）。</summary>
        public static List<TaskItem> TreeOf(List<TaskDto>? dtos)
        {
            var result = new List<TaskItem>();
            if (dtos is null)
                return result;
            foreach (var dto in dtos)
                result.Add(ToTask(dto));
            Link(result);
            return result;
        }

        private static TaskItem ToTask(TaskDto d) => new()
        {
            Id = d.Id,
            Name = d.Name,
            ColorHex = d.ColorHex,
            IconSystemName = d.IconSystemName,
            TypeRaw = d.TypeRaw,
            StatusRaw = d.StatusRaw,
            TotalAmount = d.TotalAmount,
            CurrentAmount = d.CurrentAmount,
            StartDate = d.StartDate,
            EndDate = d.EndDate,
            ReminderDate = d.ReminderDate,
            RepeatRuleRaw = d.RepeatRuleRaw,
            CustomWeekdaysRaw = d.CustomWeekdaysRaw,
            CreatedAt = d.CreatedAt,
            SortOrder = d.SortOrder,
        };

        /// <summary>单遍关联父子（DTO 有序，父在前，子已展开为当前根列表的子树）。</summary>
        private static void Link(List<TaskItem> roots)
        {
            var stack = new Stack<TaskItem>();
            foreach (var root in roots)
            {
                LinkSubtree(root, stack);
            }
            foreach (var root in roots)
            {
                if (root.ParentTask is not null)
                    root.ParentTask.Subtasks.Add(root);
            }
        }

        private static void LinkSubtree(TaskItem item, Stack<TaskItem> stack)
        {
            foreach (var maybeChild in item.Subtasks)
            {
                maybeChild.ParentTask = item;
                LinkSubtree(maybeChild, stack);
            }
        }
    }
}