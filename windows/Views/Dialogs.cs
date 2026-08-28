using System;
using System.Threading.Tasks;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Tick.Models;

namespace Tick.Views;

/// <summary>通用信息 / 错误对话框。</summary>
public static class Dialogs
{
    public static async Task ShowErrorAsync(Window window, string title, string message)
        => await ShowAsync(window, title, message, MessageBoxKind.Error);

    public static async Task ShowInfoAsync(Window window, string title, string message)
        => await ShowAsync(window, title, message, MessageBoxKind.Info);

    public static async Task<bool> ShowConfirmAsync(Window window, string title, string message)
    {
        var dialog = new ContentDialog
        {
            Title = title,
            PrimaryButtonText = LocalizationTr("common.ok"),
            CloseButtonText = LocalizationTr("common.cancel"),
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = window.Content.XamlRoot,
        };
        dialog.Content = new TextBlock { Text = message, TextWrapping = TextWrapping.Wrap };
        return await dialog.ShowAsync() == ContentDialogResult.Primary;
    }

    private enum MessageBoxKind { Info, Error }

    private static async Task ShowAsync(Window window, string title, string message, MessageBoxKind kind)
    {
        var dialog = new ContentDialog
        {
            Title = title,
            CloseButtonText = LocalizationTr("common.ok"),
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = window.Content.XamlRoot,
        };
        var glyph = kind == MessageBoxKind.Error ? "\uE783" : "\uE946";
        var stack = new StackPanel { Spacing = 8 };
        stack.Children.Add(new TextBlock
        {
            Text = message,
            TextWrapping = TextWrapping.Wrap,
            FontSize = 14,
        });
        dialog.Content = stack;
        await dialog.ShowAsync();
    }

    private static string LocalizationTr(string key) => Services.Localization.Tr(key);
}