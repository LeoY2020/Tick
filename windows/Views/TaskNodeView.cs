using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Tick.Domain;
using Tick.Models;
using Tick.Services;

namespace Tick.Views;

/// <summary>
/// 任务行可交互控件：被 TreeView 节点当作 Content 使用。
/// 接管机制：父任务有子任务时状态 / 进度只读，由子任务折算；全删子任务后回落手动值。
/// </summary>
public sealed class TaskNodeView : UserControl
{
    private readonly TaskItem _task;
    private readonly ITaskRowHost _host;

    public TaskNodeView(TaskItem task, ITaskRowHost host)
    {
        _task = task;
        _host = host;
        Content = BuildRow(task);
    }

    /// <summary>防御性兜底：一旦任何渲染层退回调用 ToString（而非绘制控件），也显示真实任务名而非类型名。</summary>
    public override string ToString() => _task.Name;

    // ---- 行构建 ----

    private Grid BuildRow(TaskItem task)
    {
        var grid = new Grid
        {
            ColumnSpacing = 8,
            Padding = new Thickness(4, 2, 4, 2),
        };
        // 首列：复选框（仅单任务）；随后颜色圆点、名称、右侧交互区
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(12) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        // 整行右键菜单
        var flyout = new MenuFlyout();
        BuildMenu(flyout, task);
        grid.RightTapped += (_, e) =>
        {
            flyout.ShowAt(grid, e.GetPosition(grid));
            e.Handled = true;
        };

        // 复选框：勾选 = 完成，取消 = 未完成。进度任务不显示；被接管任务只读。
        if (task.Type == TaskType.Single)
        {
            var checkBox = BuildCheckBox(task);
            Grid.SetColumn(checkBox, 0);
            grid.Children.Add(checkBox);
        }

        // 颜色圆点（继承链解析）
        var dot = new Microsoft.UI.Xaml.Shapes.Ellipse
        {
            Width = 12,
            Height = 12,
            Fill = HexColor.Brush(ProgressEngine.EffectiveColor(task), isDark: false),
            VerticalAlignment = VerticalAlignment.Center,
        };
        Grid.SetColumn(dot, 1);

        // 名称
        var name = new TextBlock
        {
            Text = task.Name,
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
        };
        Grid.SetColumn(name, 2);

        // 右侧：状态 / 进度（接管则只读）+ 菜单
        var right = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4, VerticalAlignment = VerticalAlignment.Center };
        Grid.SetColumn(right, 3);
        FillInteractionArea(right, task);

        grid.Children.Add(dot);
        grid.Children.Add(name);
        grid.Children.Add(right);
        return grid;
    }

    /// <summary>行首复选框：勾选置为完成、取消置为未完成；有子任务时由子任务折算、只读。</summary>
    private CheckBox BuildCheckBox(TaskItem task)
    {
        bool takenOver = task.HasSubtasks;
        bool done = takenOver
            ? ProgressEngine.EffectiveStatus(task) == TaskStatus.Done
            : task.Status == TaskStatus.Done;

        var cb = new CheckBox
        {
            IsChecked = done,
            IsEnabled = !takenOver,
            VerticalAlignment = VerticalAlignment.Center,
            Padding = new Thickness(0),
            MinWidth = 0,
        };
        if (takenOver)
            ToolTipService.SetToolTip(cb, Localization.Tr("task.takenOver"));
        cb.Checked += (_, _) => _host.RequestSetStatus(task, TaskStatus.Done);
        cb.Unchecked += (_, _) => _host.RequestSetStatus(task, TaskStatus.NotDone);
        return cb;
    }

    private void FillInteractionArea(StackPanel panel, TaskItem task)
    {
        bool takenOver = task.HasSubtasks;

        if (task.Type == TaskType.Single)
        {
            if (takenOver)
            {
                var status = ProgressEngine.EffectiveStatus(task);
                var badge = new TextBlock
                {
                    Text = status.ToDisplayName(),
                    Foreground = StatusBrush(status),
                    VerticalAlignment = VerticalAlignment.Center,
                };
                ToolTipService.SetToolTip(badge, Localization.Tr("task.takenOver"));
                panel.Children.Add(badge);
            }
            else
            {
                // 完成状态由行首复选框控制，这里不再重复放置切换按钮。
            }
        }
        else // progress
        {
            if (takenOver)
            {
                var (cur, tot) = ProgressEngine.EffectiveProgress(task);
                var summary = new TextBlock
                {
                    Text = FormatAmount(cur, tot),
                    VerticalAlignment = VerticalAlignment.Center,
                };
                panel.Children.Add(summary);
            }
            else
            {
                var minus = SmallButton("-");
                minus.Click += (_, _) => _host.RequestAdjustProgress(task, -1);
                var current = new TextBlock
                {
                    Text = FormatAmount(task.CurrentAmount, task.TotalAmount),
                    VerticalAlignment = VerticalAlignment.Center,
                };
                var plus = SmallButton("+");
                plus.Click += (_, _) => _host.RequestAdjustProgress(task, 1);
                panel.Children.Add(minus);
                panel.Children.Add(current);
                panel.Children.Add(plus);
            }
        }

        // 菜单入口（「…」）使用其自身的 flyout，避免与整行右键共用一个 Flyout 导致重设 Target 冲突
        var menu = new Button { Content = new FontIcon { Glyph = "\uE712" }, VerticalAlignment = VerticalAlignment.Center };
        var menuFlyout = new MenuFlyout();
        BuildMenu(menuFlyout, task);
        menu.Flyout = menuFlyout;
        panel.Children.Add(menu);
    }

    private static Button SmallButton(string text) => new()
    {
        Content = new TextBlock { Text = text },
        Padding = new Thickness(6, 2, 6, 2),
        VerticalAlignment = VerticalAlignment.Center,
    };

    private void BuildMenu(MenuFlyout flyout, TaskItem task)
    {
        var addChild = new MenuFlyoutItem { Text = Localization.Tr("tasks.addSubtask") };
        addChild.Click += (_, _) => _host.RequestAddChild(task);
        flyout.Items.Add(addChild);

        var edit = new MenuFlyoutItem { Text = Localization.Tr("tasks.edit") };
        edit.Click += (_, _) => _host.RequestEdit(task);
        flyout.Items.Add(edit);

        if (task.Type == TaskType.Single && !task.HasSubtasks)
        {
            flyout.Items.Add(new MenuFlyoutSeparator());
            var setMy = new MenuFlyoutSubItem { Text = Localization.Tr("task.status") };
            foreach (var s in new[] { TaskStatus.Done, TaskStatus.HalfDone, TaskStatus.NotDone, TaskStatus.Deleted })
            {
                var item = new MenuFlyoutItem { Text = s.ToDisplayName() };
                item.Click += (_, _) => _host.RequestSetStatus(task, s);
                setMy.Items.Add(item);
            }
            flyout.Items.Add(setMy);
        }

        var delete = new MenuFlyoutItem { Text = Localization.Tr("tasks.delete") };
        delete.Click += (_, _) => _host.RequestDelete(task);
        flyout.Items.Add(delete);
    }

    private static string FormatAmount(double cur, double tot) => $"{FormatNum(cur)}/{FormatNum(tot)}";

    private static string FormatNum(double v)
        => Math.Abs(v - Math.Round(v)) < 0.0001 ? ((long)Math.Round(v)).ToString() : v.ToString("0.##");

    private static SolidColorBrush StatusBrush(TaskStatus s) => s switch
    {
        TaskStatus.Done => Res("StatusDoneBrush"),
        TaskStatus.HalfDone => Res("StatusHalfBrush"),
        TaskStatus.Deleted => Res("StatusDeletedBrush"),
        _ => Res("StatusNotDoneBrush"),
    };

    private static SolidColorBrush Res(string key)
        => Application.Current.Resources.TryGetValue(key, out var v) && v is SolidColorBrush b ? b : new SolidColorBrush(Windows.UI.Color.FromArgb(255, 142, 142, 147));
}

/// <summary>任务行与页面之间的操作回调契约。</summary>
public interface ITaskRowHost
{
    void RequestToggle(TaskItem task);
    void RequestSetStatus(TaskItem task, TaskStatus status);
    void RequestAdjustProgress(TaskItem task, double delta);
    void RequestAddChild(TaskItem parent);
    void RequestEdit(TaskItem task);
    void RequestDelete(TaskItem task);
}