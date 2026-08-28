using Tick.Models;
using Tick.Services;

namespace Tick.ViewModels;

/// <summary>
/// 目标编辑器 ViewModel：持有可编辑的工作副本（取消时丢弃），提供校验与色板。
/// </summary>
public sealed class GoalEditorViewModel : ViewModelBase
{
    /// <summary>工作副本：确认时写回数据库，取消时丢弃（不污染原对象）</summary>
    public Goal Goal { get; }

    public bool IsNew { get; }

    /// <summary>预设色板（含 "auto"）</summary>
    public IReadOnlyList<(string Name, string Hex)> Palette { get; } = new[] { ("自动", HexColor.AutoHex) }
        .Concat(HexColor.Palette)
        .ToArray();

    public IReadOnlyList<ProgressCountingMode> CountingModes { get; } =
        Enum.GetValues<ProgressCountingMode>();

    public string Error { get; private set; } = "";

    public GoalEditorViewModel(Goal? goal = null)
    {
        IsNew = goal is null;
        Goal = goal is null ? new Goal() : new Goal
        {
            Id = goal.Id,
            Name = goal.Name,
            ColorHex = goal.ColorHex,
            IconSystemName = goal.IconSystemName,
            StartDate = goal.StartDate,
            EndDate = goal.EndDate,
            StartDatePreciseToHour = goal.StartDatePreciseToHour,
            EndDatePreciseToHour = goal.EndDatePreciseToHour,
            CreatedAt = goal.CreatedAt,
            ProgressCountingMode = goal.ProgressCountingMode,
        };
    }

    public bool Validate()
    {
        if (string.IsNullOrWhiteSpace(Goal.Name))
        {
            Error = "目标名称不能为空";
            return false;
        }
        Error = "";
        return true;
    }
}