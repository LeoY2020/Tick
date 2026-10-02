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

    /// <summary>预设色板（含 "auto"；显示名随当前语言本地化）</summary>
    public IReadOnlyList<(string Name, string Hex)> Palette { get; } =
        new[] { (Localization.Tr("task.color.auto"), HexColor.AutoHex) }
            .Concat(HexColor.Palette.Select(p => (Localization.Tr(p.Key), p.Hex)))
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
            Error = Localization.Tr("validation.goal.nameEmpty");
            return false;
        }
        Error = "";
        return true;
    }
}