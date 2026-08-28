using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Tick.Models;
using Tick.Services;

namespace Tick.Views;

public sealed partial class MainWindow : Window
{
    private Type _currentPage = typeof(TasksPage);

    public MainWindow()
    {
        InitializeComponent();
        Title = Localization.Tr("app.title");
        AppServices.Main.DataChanged += OnDataChanged;
        Localization.LanguageChanged += OnLanguageChanged;
        RebuildNavigation();
        SelectInitialGoal();
    }

    /// <summary>应用配色方案到窗口内容根节点（亮 / 暗 / 跟随系统）</summary>
    public void ApplyTheme(ColorSchemeSetting scheme)
    {
        var root = Content as FrameworkElement;
        if (root is null)
            return;
        root.RequestedTheme = scheme switch
        {
            ColorSchemeSetting.Light => ElementTheme.Light,
            ColorSchemeSetting.Dark => ElementTheme.Dark,
            _ => ElementTheme.Default,
        };
    }

    /// <summary>目标增删后由页面调用，重建侧栏目标列表</summary>
    public void RebuildNavigation()
    {
        var itemToSelect = NavView.SelectedItem as NavigationViewItem;
        Guid? selectedGoalId = itemToSelect?.Tag is Goal g ? g.Id : null;

        NavView.MenuItems.Clear();
        foreach (var goal in AppServices.Main.Goals)
        {
            var item = new NavigationViewItem
            {
                Tag = goal,
                IsSelectable = true,
                Content = GoalHeader(goal),
            };
            NavView.MenuItems.Add(item);
        }

        NavView.FooterMenuItems.Clear();
        NavView.FooterMenuItems.Add(FooterItem("nav.ai", "\uE8BD", "ai"));
        NavView.FooterMenuItems.Add(FooterItem("nav.settings", "\uE713", "settings"));

        // 保留当前目标选中（若仍存在）
        if (selectedGoalId is Guid id)
        {
            foreach (var item in NavView.MenuItems)
                if (item is NavigationViewItem nvi && nvi.Tag is Goal gg && gg.Id == id)
                {
                    NavView.SelectedItem = nvi;
                    break;
                }
        }
    }

    /// <summary>重新导航到当前页（语言 / 数据变更后重建界面）</summary>
    public void RefreshContent() => ContentFrame.Navigate(_currentPage);

    private void SelectInitialGoal()
    {
        AppServices.Main.Reload();
        if (NavView.MenuItems.Count > 0)
        {
            NavView.SelectedItem = NavView.MenuItems[0];
        }
        else
        {
            _currentPage = typeof(TasksPage);
            ContentFrame.Navigate(_currentPage);
        }
    }

    private void OnLanguageChanged()
    {
        Title = Localization.Tr("app.title");
        RebuildNavigation();
        RefreshContent();
    }

    private void OnDataChanged()
    {
        // 目标增删或重命名后重建侧栏
        var selected = (NavView.SelectedItem as NavigationViewItem)?.Tag;
        RebuildNavigation();
    }

    private void SelectGoal(Goal goal)
    {
        AppServices.Main.SelectGoal(goal);
        _currentPage = typeof(TasksPage);
        RefreshContent();
    }

    private void OnNavSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        var item = args.SelectedItem as NavigationViewItem;
        var tag = item?.Tag;
        if (tag is Goal goal)
        {
            SelectGoal(goal);
        }
        else if (tag is string s)
        {
            _currentPage = s switch
            {
                "ai" => typeof(AIChatPage),
                "settings" => typeof(SettingsPage),
                _ => typeof(TasksPage),
            };
            RefreshContent();
        }
    }

    private async void OnNewGoalClick(object sender, RoutedEventArgs e)
    {
        var ok = await GoalEditDialog.ShowNewAsync(App.MainWindow);
        if (ok)
        {
            RebuildNavigation();
            if (NavView.MenuItems.Count > 0)
                NavView.SelectedItem = NavView.MenuItems[^1];
        }
    }

    /// <summary>侧栏目标项头部：颜色圆点 + 名称</summary>
    private static UIElement GoalHeader(Goal goal)
    {
        var panel = new Grid { ColumnSpacing = 8 };
        var dot = new Microsoft.UI.Xaml.Shapes.Ellipse
        {
            Width = 12,
            Height = 12,
            Fill = HexColor.Brush(goal.ColorHex, isDark: false),
            VerticalAlignment = VerticalAlignment.Center,
        };
        var name = new TextBlock
        {
            Text = goal.Name,
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
            Margin = new Thickness(14, 0, 0, 0),
        };
        panel.Children.Add(dot);
        panel.Children.Add(name);
        return panel;
    }

    private static NavigationViewItem FooterItem(string labelKey, string glyph, string tag)
    {
        var item = new NavigationViewItem
        {
            Tag = tag,
            Icon = new FontIcon
            {
                Glyph = glyph,
                FontFamily = new FontFamily("Segoe Fluent Icons"),
            },
        };
        item.Content = new TextBlock { Text = Localization.Tr(labelKey) };
        return item;
    }
}