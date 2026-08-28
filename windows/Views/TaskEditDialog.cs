using System;
using System.Globalization;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Tick.Models;
using Tick.Services;
using Tick.ViewModels;

namespace Tick.Views;

/// <summary>任务编辑器 ContentDialog（新建 / 编辑复用）。确定后写库并按需安排提醒。</summary>
public static class TaskEditDialog
{
    public static Task<bool> ShowNewAsync(Window window, TaskItem? parent = null)
        => ShowAsync(window, new TaskEditorViewModel(), parent);

    public static Task<bool> ShowEditAsync(Window window, TaskItem task, bool canEditType)
        => ShowAsync(window, new TaskEditorViewModel(task, canEditType), null);

    private static async Task<bool> ShowAsync(Window window, TaskEditorViewModel vm, TaskItem? parent)
    {
        var name = new TextBox
        {
            Header = Localization.Tr("task.name"),
            Text = vm.Task.Name,
            PlaceholderText = Localization.Tr("common.name"),
        };

        var typeCombo = new ComboBox
        {
            Header = Localization.Tr("task.type"),
            HorizontalAlignment = HorizontalAlignment.Stretch,
            IsEnabled = vm.CanEditType,
        };
        foreach (var t in vm.Types)
            typeCombo.Items.Add(new ComboBoxItem { Content = t.ToDisplayName(), Tag = t });
        typeCombo.SelectedIndex = IndexOfTag(typeCombo, vm.Task.Type);

        var statusCombo = new ComboBox
        {
            Header = Localization.Tr("task.status"),
            HorizontalAlignment = HorizontalAlignment.Stretch,
        };
        foreach (var s in vm.Statuses)
            statusCombo.Items.Add(new ComboBoxItem { Content = s.ToDisplayName(), Tag = s });
        statusCombo.SelectedIndex = IndexOfTag(statusCombo, vm.Task.Status);

        var totalBox = new TextBox { Header = Localization.Tr("task.total"), Text = FormatNum(vm.Task.TotalAmount) };
        var currentBox = new TextBox { Header = Localization.Tr("task.current"), Text = FormatNum(vm.Task.CurrentAmount) };

        var reminderToggle = new ToggleSwitch
        {
            Header = Localization.Tr("task.reminder"),
            OnContent = "", OffContent = "",
            IsOn = vm.HasReminder,
        };
        var datePicker = new DatePicker { Header = Localization.Tr("task.reminderDate") };
        var timePicker = new TimePicker { Header = Localization.Tr("task.reminderTime") };
        ApplyReminder(vm, datePicker, timePicker);

        var repeatCombo = new ComboBox
        {
            Header = Localization.Tr("task.repeat"),
            HorizontalAlignment = HorizontalAlignment.Stretch,
        };
        foreach (var r in vm.RepeatRules)
            repeatCombo.Items.Add(new ComboBoxItem { Content = r.ToDisplayName(), Tag = r });
        repeatCombo.SelectedIndex = IndexOfTag(repeatCombo, vm.Task.RepeatRule ?? RepeatRule.Never);

        var weekdaysPanel = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4 };
        var weekdayButtons = new ToggleButton[8];
        for (int w = 1; w <= 7; w++)
        {
            var tb = new ToggleButton
            {
                Content = Localization.Tr($"weekday.{w}"),
                IsChecked = vm.WeekdayChecked[w],
                Padding = new Thickness(6, 2, 6, 2),
            };
            weekdayButtons[w] = tb;
            weekdaysPanel.Children.Add(tb);
        }

        UpdateVisibilities(vm, statusCombo, totalBox, currentBox, weekdaysPanel, datePicker, timePicker);

        typeCombo.SelectionChanged += (_, _) =>
        {
            vm.Task.Type = SelectedType(typeCombo);
            UpdateVisibilities(vm, statusCombo, totalBox, currentBox, weekdaysPanel, datePicker, timePicker);
        };
        repeatCombo.SelectionChanged += (_, _) =>
        {
            vm.Task.RepeatRule = SelectedRepeat(repeatCombo);
            UpdateVisibilities(vm, statusCombo, totalBox, currentBox, weekdaysPanel, datePicker, timePicker);
        };
        reminderToggle.Toggled += (_, _) =>
        {
            datePicker.Visibility = reminderToggle.IsOn ? Visibility.Visible : Visibility.Collapsed;
            timePicker.Visibility = reminderToggle.IsOn ? Visibility.Visible : Visibility.Collapsed;
        };

        var layout = new StackPanel { Spacing = 10, MinWidth = 320 };
        layout.Children.Add(name);
        layout.Children.Add(typeCombo);
        layout.Children.Add(statusCombo);
        layout.Children.Add(totalBox);
        layout.Children.Add(currentBox);
        layout.Children.Add(reminderToggle);
        layout.Children.Add(datePicker);
        layout.Children.Add(timePicker);
        layout.Children.Add(repeatCombo);
        layout.Children.Add(weekdaysPanel);

        var dialog = GoalEditDialog.BuildDialog(
            window,
            vm.IsNew ? Localization.Tr("tasks.add") : Localization.Tr("tasks.edit"),
            layout);
        if (await dialog.ShowAsync() != ContentDialogResult.Primary)
            return false;

        vm.Task.Name = name.Text.Trim();
        vm.Task.Type = SelectedType(typeCombo);
        if (vm.Task.Type == TaskType.Single)
        {
            vm.Task.Status = SelectedStatus(statusCombo);
        }
        else
        {
            if (!TryParseNumber(totalBox.Text, out var total) || !TryParseNumber(currentBox.Text, out var current))
            {
                await Dialogs.ShowErrorAsync(window, Localization.Tr("common.error"), Localization.Tr("task.invalidNumber"));
                return false;
            }
            vm.Task.TotalAmount = Math.Max(0, total);
            vm.Task.SetProgress(current);
        }

        vm.Task.ReminderDate = reminderToggle.IsOn
            ? (datePicker.Date is DateTimeOffset dto ? dto.LocalDateTime.Date : DateTime.Today).Add(timePicker.Time)
            : null;
        vm.Task.RepeatRule = SelectedRepeat(repeatCombo);

        for (int w = 1; w <= 7; w++)
            vm.WeekdayChecked[w] = weekdayButtons[w].IsChecked == true;
        vm.SyncWeekdaysFromChecked();

        if (!vm.Validate())
        {
            await Dialogs.ShowErrorAsync(window, Localization.Tr("common.error"), vm.Error);
            return false;
        }

        if (vm.IsNew)
        {
            if (parent is null)
                AppServices.Main.AddRootTask(vm.Task);
            else
                AppServices.Main.AddSubtask(vm.Task, parent);
        }
        else
        {
            AppServices.Main.UpdateTask(vm.Task);
        }

        if (vm.Task.ReminderDate is not null)
            AppServices.Toasts.ScheduleReminder(vm.Task, AppServices.Main.SelectedGoal?.Name ?? "");
        else
            AppServices.Toasts.RemoveAllFor(vm.Task.Id);

        return true;
    }

    private static void UpdateVisibilities(
        TaskEditorViewModel vm,
        ComboBox statusCombo,
        TextBox totalBox,
        TextBox currentBox,
        StackPanel weekdaysPanel,
        DatePicker datePicker,
        TimePicker timePicker)
    {
        bool isProgress = vm.Task.Type == TaskType.Progress;
        statusCombo.Visibility = isProgress ? Visibility.Collapsed : Visibility.Visible;
        totalBox.Visibility = isProgress ? Visibility.Visible : Visibility.Collapsed;
        currentBox.Visibility = isProgress ? Visibility.Visible : Visibility.Collapsed;
        weekdaysPanel.Visibility = vm.Task.RepeatRule == RepeatRule.Custom ? Visibility.Visible : Visibility.Collapsed;

        bool hasReminder = vm.Task.ReminderDate is not null;
        datePicker.Visibility = hasReminder ? Visibility.Visible : Visibility.Collapsed;
        timePicker.Visibility = hasReminder ? Visibility.Visible : Visibility.Collapsed;
    }

    private static void ApplyReminder(TaskEditorViewModel vm, DatePicker datePicker, TimePicker timePicker)
    {
        if (vm.Task.ReminderDate is DateTime dt)
        {
            datePicker.Date = new DateTimeOffset(dt);
            timePicker.Time = dt.TimeOfDay;
        }
        else
        {
            datePicker.Date = DateTimeOffset.Now;
            timePicker.Time = new TimeSpan(9, 0, 0);
        }
    }

    private static int IndexOfTag(ComboBox combo, object tag)
    {
        for (int i = 0; i < combo.Items.Count; i++)
            if (((ComboBoxItem)combo.Items[i]).Tag?.Equals(tag) == true)
                return i;
        return combo.Items.Count > 0 ? 0 : -1;
    }

    private static TaskType SelectedType(ComboBox combo)
        => combo.SelectedItem is ComboBoxItem ci && ci.Tag is TaskType t ? t : TaskType.Single;

    private static TaskStatus SelectedStatus(ComboBox combo)
        => combo.SelectedItem is ComboBoxItem ci && ci.Tag is TaskStatus s ? s : TaskStatus.NotDone;

    private static RepeatRule SelectedRepeat(ComboBox combo)
        => combo.SelectedItem is ComboBoxItem ci && ci.Tag is RepeatRule r ? r : RepeatRule.Never;

    private static bool TryParseNumber(string? text, out double value)
        => double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out value);

    private static string FormatNum(double v)
        => Math.Abs(v - Math.Round(v)) < 1e-6 ? ((long)Math.Round(v)).ToString() : v.ToString("0.##", CultureInfo.InvariantCulture);
}