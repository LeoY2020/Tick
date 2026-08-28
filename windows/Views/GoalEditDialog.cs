using System;
using System.Threading.Tasks;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Tick.Models;
using Tick.Services;
using Tick.ViewModels;

namespace Tick.Views;

/// <summary>目标编辑器 ContentDialog（新建 / 编辑复用）。确定后写库并返回成功。</summary>
public static class GoalEditDialog
{
    public static Task<bool> ShowNewAsync(Window window)
        => ShowAsync(window, new GoalEditorViewModel());

    public static Task<bool> ShowEditAsync(Window window, Goal goal)
        => ShowAsync(window, new GoalEditorViewModel(goal));

    private static async Task<bool> ShowAsync(Window window, GoalEditorViewModel vm)
    {
        var name = new TextBox
        {
            Header = Localization.Tr("task.name"),
            Text = vm.Goal.Name,
            PlaceholderText = Localization.Tr("common.name"),
        };

        var colorCombo = new ComboBox { Header = Localization.Tr("task.color"), HorizontalAlignment = HorizontalAlignment.Stretch };
        foreach (var (label, hex) in vm.Palette)
            colorCombo.Items.Add(new ComboBoxItem { Content = label, Tag = hex });
        colorCombo.SelectedIndex = IndexOfTag(colorCombo, vm.Goal.ColorHex);

        var startPicker = new CalendarDatePicker { Header = Localization.Tr("task.startDate"), Date = ToNullableDate(vm.Goal.StartDate) };
        var preciseStart = new ToggleSwitch
        {
            Header = Localization.Tr("task.preciseToHour"),
            OnContent = "", OffContent = "",
            IsOn = vm.Goal.StartDatePreciseToHour,
        };
        var endPicker = new CalendarDatePicker { Header = Localization.Tr("task.endDate"), Date = ToNullableDate(vm.Goal.EndDate) };
        var preciseEnd = new ToggleSwitch
        {
            Header = Localization.Tr("task.preciseToHour"),
            OnContent = "", OffContent = "",
            IsOn = vm.Goal.EndDatePreciseToHour,
        };

        var modeCombo = new ComboBox { Header = "统计模式", HorizontalAlignment = HorizontalAlignment.Stretch };
        foreach (var m in vm.CountingModes)
            modeCombo.Items.Add(new ComboBoxItem { Content = m.ToDisplayName(), Tag = m });
        for (int i = 0; i < modeCombo.Items.Count; i++)
            if (((ComboBoxItem)modeCombo.Items[i]).Tag is ProgressCountingMode pm && pm == vm.Goal.ProgressCountingMode)
            { modeCombo.SelectedIndex = i; break; }

        var layout = new StackPanel { Spacing = 10, MinWidth = 320 };
        layout.Children.Add(name);
        layout.Children.Add(colorCombo);
        layout.Children.Add(startPicker);
        layout.Children.Add(preciseStart);
        layout.Children.Add(endPicker);
        layout.Children.Add(preciseEnd);
        layout.Children.Add(modeCombo);

        var dialog = BuildDialog(window, vm.IsNew ? Localization.Tr("goals.add") : Localization.Tr("goals.edit"), layout);
        if (await dialog.ShowAsync() != ContentDialogResult.Primary)
            return false;

        vm.Goal.Name = name.Text.Trim();
        if (colorCombo.SelectedItem is ComboBoxItem ci && ci.Tag is string hex)
            vm.Goal.ColorHex = hex;
        vm.Goal.StartDate = ToDateTime(startPicker.Date);
        vm.Goal.EndDate = ToDateTime(endPicker.Date);
        vm.Goal.StartDatePreciseToHour = preciseStart.IsOn;
        vm.Goal.EndDatePreciseToHour = preciseEnd.IsOn;
        if (modeCombo.SelectedItem is ComboBoxItem mi && mi.Tag is ProgressCountingMode mode)
            vm.Goal.ProgressCountingMode = mode;

        if (!vm.Validate())
        {
            await Dialogs.ShowErrorAsync(window, Localization.Tr("common.error"), vm.Error);
            return false;
        }

        AppServices.Main.SaveGoal(vm.Goal);
        return true;
    }

    internal static ContentDialog BuildDialog(Window window, string title, UIElement content) => new()
    {
        Title = title,
        Content = content,
        PrimaryButtonText = Localization.Tr("common.save"),
        CloseButtonText = Localization.Tr("common.cancel"),
        DefaultButton = ContentDialogButton.Primary,
        XamlRoot = window.Content.XamlRoot,
    };

    private static int IndexOfTag(ComboBox combo, string tag)
    {
        for (int i = 0; i < combo.Items.Count; i++)
            if (((ComboBoxItem)combo.Items[i]).Tag?.ToString() == tag)
                return i;
        return 0;
    }

    private static DateTimeOffset? ToNullableDate(DateTime? dt)
        => dt is null ? null : new DateTimeOffset(dt.Value);

    private static DateTime? ToDateTime(DateTimeOffset? dto)
        => dto is null ? null : (DateTime?)(dto.Value.LocalDateTime);
}