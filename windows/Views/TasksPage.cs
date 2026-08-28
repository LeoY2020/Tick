using System;
using System.Collections.Generic;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Tick.Domain;
using Tick.Models;
using Tick.Services;
using Windows.Storage.Pickers;

namespace Tick.Views;

/// <summary>目标任务页：头部（标题 / 倒计时 / AI 导入）、总进度、任务树与新增任务。</summary>
public sealed class TasksPage : Page, ITaskRowHost
{
    private readonly Dictionary<Guid, bool> _expanded = new();
    private readonly Dictionary<TreeViewNode, TaskItem> _nodeTask = new();
    private bool _rebuildQueued;

    public TasksPage()
    {
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
        Rebuild();
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
        => AppServices.Main.DataChanged += OnDataChanged;

    private void OnUnloaded(object sender, RoutedEventArgs e)
        => AppServices.Main.DataChanged -= OnDataChanged;

    private void OnDataChanged()
    {
        if (_rebuildQueued)
            return;
        _rebuildQueued = true;
        DispatcherQueue.TryEnqueue(() =>
        {
            _rebuildQueued = false;
            Rebuild();
        });
    }

    private void Rebuild()
    {
        var goal = AppServices.Main.SelectedGoal;
        if (goal is null)
        {
            Content = BuildEmptyState();
            return;
        }

        _nodeTask.Clear();
        Content = BuildPage(goal);
    }

    /// <summary>无选中目标时的空状态：提示 + 新建目标入口</summary>
    private static UIElement BuildEmptyState()
    {
        var panel = new StackPanel
        {
            Spacing = 12,
            Margin = new Thickness(24),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };
        panel.Children.Add(new TextBlock
        {
            Text = Localization.Tr("goals.empty"),
            HorizontalAlignment = HorizontalAlignment.Center,
        });
        panel.Children.Add(BuildNewGoalButton());
        return panel;
    }

    private UIElement BuildPage(Goal goal)
    {
        var panel = new StackPanel { Spacing = 16, Padding = new Thickness(20) };
        panel.Children.Add(BuildHeader(goal));
        panel.Children.Add(BuildProgress(goal));
        panel.Children.Add(BuildTaskTree(goal));
        panel.Children.Add(BuildAddButton());
        return new ScrollViewer { Content = panel };
    }

    // ---- 头部 ----

    private UIElement BuildHeader(Goal goal)
    {
        var grid = new Grid { ColumnSpacing = 16 };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var left = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10, VerticalAlignment = VerticalAlignment.Center };
        var dot = new Microsoft.UI.Xaml.Shapes.Ellipse
        {
            Width = 14,
            Height = 14,
            Fill = HexColor.Brush(goal.ColorHex, isDark: false),
            VerticalAlignment = VerticalAlignment.Center,
        };
        var name = new TextBlock
        {
            Text = goal.Name,
            FontSize = 22,
            FontWeight = Microsoft.UI.Text.FontWeights.Bold,
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
        };
        left.Children.Add(dot);
        left.Children.Add(name);
        Grid.SetColumn(left, 0);

        var right = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 16, VerticalAlignment = VerticalAlignment.Center };
        if (goal.EndDate is DateTime end)
            right.Children.Add(BuildCountdown(goal, end));
        right.Children.Add(BuildAiImportButton());
        Grid.SetColumn(right, 1);

        grid.Children.Add(left);
        grid.Children.Add(right);
        return grid;
    }

    private static UIElement BuildCountdown(Goal goal, DateTime end)
    {
        var panel = new StackPanel { Spacing = 2 };

        panel.Children.Add(new TextBlock
        {
            Text = Localization.Tr("tasks.remaining"),
            FontSize = 12,
            Foreground = new SolidColorBrush(Windows.UI.Color.FromArgb(255, 142, 142, 147)),
        });

        string countdown = CountdownFormatter.Countdown(end, goal.EndDatePreciseToHour) ?? "—";
        panel.Children.Add(new TextBlock
        {
            Text = countdown,
            FontSize = 20,
            FontFamily = new FontFamily("Consolas"),
        });

        string due = goal.EndDatePreciseToHour ? end.ToString("yyyy-MM-dd HH:mm") : end.ToString("yyyy-MM-dd");
        panel.Children.Add(new TextBlock
        {
            Text = $"{Localization.Tr("task.endDate")} {due}",
            FontSize = 12,
            Foreground = new SolidColorBrush(Windows.UI.Color.FromArgb(255, 142, 142, 147)),
        });

        return panel;
    }

    private Button BuildAiImportButton()
    {
        var content = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        content.Children.Add(new FontIcon { Glyph = "\uE7BF", FontFamily = new FontFamily("Segoe Fluent Icons") });
        content.Children.Add(new TextBlock { Text = Localization.Tr("tasks.aiImport") });

        var btn = new Button { Content = content, VerticalAlignment = VerticalAlignment.Center };
        btn.Click += OnAiImportClick;
        return btn;
    }

    private async void OnAiImportClick(object sender, RoutedEventArgs e)
    {
        try
        {
            var picker = new FileOpenPicker();
            picker.FileTypeFilter.Add(".txt");
            picker.FileTypeFilter.Add(".md");
            picker.FileTypeFilter.Add(".pdf");
            picker.FileTypeFilter.Add(".docx");
            var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(App.MainWindow);
            WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);
            var file = await picker.PickSingleFileAsync();
            if (file is null)
                return;

            string text = DocumentTextExtractor.ExtractText(file.Path);

            var history = new List<ChatMessage> { new(ChatRole.User, "请根据附件内容生成任务清单") };
            var reply = await AppServices.AI.ChatReplyAsync(
                history,
                text,
                AppServices.AppSettings.AiModel,
                AppServices.AppSettings.ApiKey,
                AppServices.AppSettings.BaseUrl,
                AppServices.AppSettings.ModelId);

            if (reply.ShouldGenerateTasks)
            {
                var goal = AppServices.Main.SelectedGoal;
                if (goal is not null)
                {
                    var roots = new List<TaskItem>();
                    foreach (var node in reply.Tasks)
                    {
                        var root = BuildTask(node);
                        root.AttachTo(goal);
                        roots.Add(root);
                    }
                    AppServices.Main.ImportGeneratedTasks(roots);
                }
            }

            await Dialogs.ShowInfoAsync(App.MainWindow, Localization.Tr("common.notice"), reply.Message);
        }
        catch (Exception ex)
        {
            await Dialogs.ShowErrorAsync(App.MainWindow, Localization.Tr("common.error"), ex.Message);
        }
    }

    /// <summary>把 AI 生成的任务节点递归转为 <see cref="TaskItem"/>（仅挂父子关系，目标由调用方挂接）。</summary>
    private static TaskItem BuildTask(TaskNode node)
    {
        var task = new TaskItem
        {
            Name = string.IsNullOrWhiteSpace(node.Name) ? Localization.Tr("task.name") : node.Name.Trim(),
        };
        if (node.Children is not null)
        {
            foreach (var child in node.Children)
                BuildTask(child).AttachTo(task);
        }
        return task;
    }

    // ---- 总进度 ----

    private static UIElement BuildProgress(Goal goal)
    {
        var progress = ProgressEngine.GoalProgressOf(goal);

        var panel = new StackPanel { Spacing = 6 };
        panel.Children.Add(new ProgressBar
        {
            Minimum = 0,
            Maximum = 100,
            Value = progress.Fraction * 100,
        });
        panel.Children.Add(new TextBlock
        {
            Text = string.Format(
                Localization.Tr("tasks.completed"),
                FormatNum(progress.CompletedWeight),
                progress.TotalItems),
        });
        return panel;
    }

    // ---- 任务树 ----

    private UIElement BuildTaskTree(Goal goal)
    {
        var tree = new TreeView();
        foreach (var task in goal.Tasks)
            tree.RootNodes.Add(BuildNode(task, 0));

        tree.Expanding += (_, args) =>
        {
            if (_nodeTask.TryGetValue(args.Node, out var t))
                _expanded[t.Id] = true;
        };
        tree.Collapsed += (_, args) =>
        {
            if (_nodeTask.TryGetValue(args.Node, out var t))
                _expanded[t.Id] = false;
        };
        return tree;
    }

    private TreeViewNode BuildNode(TaskItem task, int depth)
    {
        var node = new TreeViewNode
        {
            Content = new TaskNodeView(task, this),
            IsExpanded = _expanded.TryGetValue(task.Id, out var expanded) ? expanded : depth == 0,
        };
        _nodeTask[node] = task;
        foreach (var sub in task.Subtasks)
            node.Children.Add(BuildNode(sub, depth + 1));
        return node;
    }

    private static Button BuildAddButton()
    {
        var btn = new Button
        {
            Content = new TextBlock { Text = Localization.Tr("tasks.add") },
            HorizontalAlignment = HorizontalAlignment.Stretch,
        };
        btn.Click += async (_, _) => await TaskEditDialog.ShowNewAsync(App.MainWindow);
        return btn;
    }

    /// <summary>「新建目标」按钮（空状态入口）；有目标时位于侧栏顶部的 PaneHeader。</summary>
    private static Button BuildNewGoalButton()
    {
        var content = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, HorizontalAlignment = HorizontalAlignment.Center };
        content.Children.Add(new FontIcon { Glyph = "\uE710", FontSize = 14, VerticalAlignment = VerticalAlignment.Center });
        content.Children.Add(new TextBlock { Text = Localization.Tr("goals.add"), VerticalAlignment = VerticalAlignment.Center });
        var btn = new Button { Content = content, HorizontalAlignment = HorizontalAlignment.Stretch };
        btn.Click += (_, _) => App.MainWindow.RequestNewGoal();
        return btn;
    }

    // ---- ITaskRowHost ----

    public void RequestToggle(TaskItem task) => AppServices.Main.ToggleTask(task);

    public void RequestSetStatus(TaskItem task, TaskStatus status)
    {
        task.Status = status;
        AppServices.Main.UpdateTask(task);
    }

    public void RequestAdjustProgress(TaskItem task, double delta)
    {
        task.SetProgress(task.CurrentAmount + delta);
        AppServices.Main.UpdateTask(task);
    }

    public async void RequestAddChild(TaskItem parent)
        => await TaskEditDialog.ShowNewAsync(App.MainWindow, parent);

    public async void RequestEdit(TaskItem task)
        => await TaskEditDialog.ShowEditAsync(App.MainWindow, task, task.Subtasks.Count == 0);

    public async void RequestDelete(TaskItem task)
    {
        var message = task.HasSubtasks
            ? string.Format(Localization.Tr("tasks.deleteConfirm"), task.Name)
            : string.Format(Localization.Tr("tasks.deleteNoSub"), task.Name);
        var ok = await Dialogs.ShowConfirmAsync(App.MainWindow, Localization.Tr("common.warning"), message);
        if (!ok)
            return;

        AppServices.Toasts.RemoveAllFor(task.Id);
        AppServices.Main.DeleteTask(task);
    }

    private static string FormatNum(double v)
        => Math.Abs(v - Math.Round(v)) < 1e-6 ? ((long)Math.Round(v)).ToString() : v.ToString("0.##");
}