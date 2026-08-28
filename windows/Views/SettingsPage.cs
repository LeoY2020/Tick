using System;
using System.Collections.Generic;
using System.IO;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Tick.Models;
using Tick.Services;
using Tick.ViewModels;
using Windows.Storage.Pickers;

namespace Tick.Views;

/// <summary>设置页：外观（配色 / 语言）、AI 模型配置与数据备份 / 恢复。</summary>
public sealed class SettingsPage : Page
{
    private readonly SettingsViewModel _vm = new(AppServices.AppSettings);

    private ComboBox _colorCombo = null!;
    private ComboBox _languageCombo = null!;
    private ComboBox _modelCombo = null!;
    private PasswordBox _apiKeyBox = null!;
    private TextBox _baseUrlBox = null!;
    private TextBox _modelIdBox = null!;

    public SettingsPage()
    {
        Content = BuildLayout();
    }

    private UIElement BuildLayout()
    {
        var panel = new StackPanel { Spacing = 12, Padding = new Thickness(20) };
        panel.Children.Add(BuildAppearanceSection());
        panel.Children.Add(BuildAiSection());
        panel.Children.Add(BuildDataSection());
        panel.Children.Add(BuildSaveButton());
        return new ScrollViewer { Content = panel };
    }

    // ---- 外观 ----

    private UIElement BuildAppearanceSection()
    {
        var panel = new StackPanel { Spacing = 8 };
        panel.Children.Add(SectionTitle(Localization.Tr("settings.theme")));

        _colorCombo = new ComboBox
        {
            Header = Localization.Tr("settings.theme"),
            HorizontalAlignment = HorizontalAlignment.Stretch,
        };
        foreach (var scheme in _vm.ColorSchemes)
            _colorCombo.Items.Add(new ComboBoxItem { Content = scheme.ToDisplayName(), Tag = scheme });
        _colorCombo.SelectedIndex = IndexOf(_colorCombo, _vm.SelectedColorScheme);

        _languageCombo = new ComboBox
        {
            Header = Localization.Tr("settings.language"),
            HorizontalAlignment = HorizontalAlignment.Stretch,
        };
        foreach (var lang in _vm.Languages)
            _languageCombo.Items.Add(new ComboBoxItem { Content = LangLabel(lang), Tag = lang });
        _languageCombo.SelectedIndex = IndexOf(_languageCombo, _vm.SelectedLanguage);

        panel.Children.Add(_colorCombo);
        panel.Children.Add(_languageCombo);
        return panel;
    }

    private static string LangLabel(string lang)
        => lang == "en" ? Localization.Tr("lang.en") : Localization.Tr("lang.zh");

    // ---- AI 模型 ----

    private UIElement BuildAiSection()
    {
        var panel = new StackPanel { Spacing = 8 };
        panel.Children.Add(SectionTitle(Localization.Tr("settings.ai")));
        panel.Children.Add(new TextBlock
        {
            Text = Localization.Tr("settings.copilotHint"),
            TextWrapping = TextWrapping.Wrap,
            FontSize = 12,
            Foreground = new Microsoft.UI.Xaml.Media.SolidColorBrush(Windows.UI.Color.FromArgb(255, 142, 142, 147)),
        });

        _modelCombo = new ComboBox
        {
            Header = Localization.Tr("settings.model"),
            HorizontalAlignment = HorizontalAlignment.Stretch,
        };
        foreach (var model in _vm.Models)
            _modelCombo.Items.Add(new ComboBoxItem { Content = model.ToDisplayName(), Tag = model });
        _modelCombo.SelectedIndex = IndexOf(_modelCombo, _vm.SelectedModel);

        _apiKeyBox = new PasswordBox
        {
            Header = Localization.Tr("settings.apiKey"),
            Password = _vm.ApiKey,
        };

        _baseUrlBox = new TextBox
        {
            Header = Localization.Tr("settings.baseUrl"),
            PlaceholderText = _vm.CurrentModelDefaultBaseUrl,
            Text = _vm.BaseUrl,
        };
        _modelIdBox = new TextBox
        {
            Header = Localization.Tr("settings.modelId"),
            PlaceholderText = _vm.CurrentModelDefaultId,
            Text = _vm.ModelId,
        };

        _modelCombo.SelectionChanged += (_, _) =>
        {
            _vm.SelectedModel = SelectedModel(_modelCombo);
            _baseUrlBox.PlaceholderText = _vm.CurrentModelDefaultBaseUrl;
            _modelIdBox.PlaceholderText = _vm.CurrentModelDefaultId;
            UpdateCustomVisibility();
        };

        panel.Children.Add(_modelCombo);
        panel.Children.Add(_apiKeyBox);
        panel.Children.Add(_baseUrlBox);
        panel.Children.Add(_modelIdBox);

        UpdateCustomVisibility();
        return panel;
    }

    private void UpdateCustomVisibility()
    {
        bool isCustom = SelectedModel(_modelCombo) == AIModel.Custom;
        _baseUrlBox.Visibility = isCustom ? Visibility.Visible : Visibility.Collapsed;
        _modelIdBox.Visibility = isCustom ? Visibility.Visible : Visibility.Collapsed;
    }

    // ---- 数据备份 / 恢复 ----

    private UIElement BuildDataSection()
    {
        var panel = new StackPanel { Spacing = 8 };
        panel.Children.Add(SectionTitle(Localization.Tr("settings.backup")));

        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        var export = new Button { Content = new TextBlock { Text = Localization.Tr("settings.export") } };
        export.Click += OnExportClick;
        var import = new Button { Content = new TextBlock { Text = Localization.Tr("settings.import") } };
        import.Click += OnImportClick;
        row.Children.Add(export);
        row.Children.Add(import);

        panel.Children.Add(row);
        return panel;
    }

    private async void OnExportClick(object sender, RoutedEventArgs e)
    {
        try
        {
            var picker = new FileSavePicker
            {
                SuggestedFileName = "tick-backup",
            };
            picker.FileTypeChoices.Add("JSON", new List<string> { ".json" });
            var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(App.MainWindow);
            WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);

            var file = await picker.PickSaveFileAsync();
            if (file is null)
                return;

            File.WriteAllText(file.Path, JsonBackup.Serialize(AppServices.Main.Goals));
            await Dialogs.ShowInfoAsync(App.MainWindow, Localization.Tr("common.notice"), Localization.Tr("settings.exportOk"));
        }
        catch (Exception ex)
        {
            await Dialogs.ShowErrorAsync(App.MainWindow, Localization.Tr("common.error"), ex.Message);
        }
    }

    private async void OnImportClick(object sender, RoutedEventArgs e)
    {
        try
        {
            var ok = await Dialogs.ShowConfirmAsync(
                App.MainWindow,
                Localization.Tr("common.warning"),
                Localization.Tr("settings.importConfirm"));
            if (!ok)
                return;

            var picker = new FileOpenPicker();
            picker.FileTypeFilter.Add(".json");
            var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(App.MainWindow);
            WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);

            var file = await picker.PickSingleFileAsync();
            if (file is null)
                return;

            string json = File.ReadAllText(file.Path);
            var goals = JsonBackup.DeserializeIntoGoals(json);

            foreach (var goal in goals)
            {
                AppServices.Goals.Save(goal);
                foreach (var task in goal.Tasks)
                    AppServices.Tasks.Save(task);
            }

            AppServices.Main.Reload();
            await Dialogs.ShowInfoAsync(
                App.MainWindow,
                Localization.Tr("common.notice"),
                string.Format(Localization.Tr("settings.importOk"), goals.Count));
        }
        catch (Exception ex)
        {
            await Dialogs.ShowErrorAsync(App.MainWindow, Localization.Tr("common.error"), ex.Message);
        }
    }

    // ---- 保存 ----

    private UIElement BuildSaveButton()
    {
        var btn = new Button
        {
            Content = new TextBlock { Text = Localization.Tr("common.save") },
            HorizontalAlignment = HorizontalAlignment.Stretch,
        };
        btn.Click += OnSaveClick;
        return btn;
    }

    private async void OnSaveClick(object sender, RoutedEventArgs e)
    {
        try
        {
            _vm.SelectedColorScheme = SelectedScheme(_colorCombo);
            _vm.SelectedLanguage = SelectedLang(_languageCombo);
            _vm.SelectedModel = SelectedModel(_modelCombo);
            _vm.ApiKey = _apiKeyBox.Password;
            _vm.BaseUrl = _baseUrlBox.Text.Trim();
            _vm.ModelId = _modelIdBox.Text.Trim();

            _vm.Save();
            App.MainWindow.ApplyTheme(_vm.SelectedColorScheme);
            await Dialogs.ShowInfoAsync(App.MainWindow, Localization.Tr("common.notice"), Localization.Tr("settings.saved"));
        }
        catch (Exception ex)
        {
            await Dialogs.ShowErrorAsync(App.MainWindow, Localization.Tr("common.error"), ex.Message);
        }
    }

    // ---- 辅助 ----

    private static TextBlock SectionTitle(string text) => new()
    {
        Text = text,
        FontSize = 16,
        FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
        Margin = new Thickness(0, 8, 0, 4),
    };

    private static int IndexOf(ComboBox combo, object tag)
    {
        for (int i = 0; i < combo.Items.Count; i++)
            if (((ComboBoxItem)combo.Items[i]).Tag?.Equals(tag) == true)
                return i;
        return combo.Items.Count > 0 ? 0 : -1;
    }

    private static ColorSchemeSetting SelectedScheme(ComboBox combo)
        => combo.SelectedItem is ComboBoxItem ci && ci.Tag is ColorSchemeSetting v ? v : ColorSchemeSetting.System;

    private static string SelectedLang(ComboBox combo)
        => combo.SelectedItem is ComboBoxItem ci && ci.Tag is string v ? v : "zh";

    private static AIModel SelectedModel(ComboBox combo)
        => combo.SelectedItem is ComboBoxItem ci && ci.Tag is AIModel v ? v : AIModel.Custom;
}