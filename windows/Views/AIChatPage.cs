using System;
using System.Collections.Generic;
using System.Text.Json;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Tick.Data;
using Tick.Models;
using Tick.Services;
using Windows.Storage.Pickers;

namespace Tick.Views;

/// <summary>AI 聊天页：多轮对话、附件解析、任务写入当前目标与会话历史。</summary>
public sealed class AIChatPage : Page
{
    private readonly ChatRepository _repo = new(AppServices.Db.Connection);
    private readonly List<ChatMessage> _messages = new();

    private readonly ScrollViewer _messageScroll = new() { VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
    private readonly StackPanel _messagePanel = new() { Spacing = 8, Padding = new Thickness(16) };
    private readonly TextBox _inputBox = new() { TextWrapping = TextWrapping.Wrap };
    private readonly Button _sendButton = new();
    private readonly TextBlock _attachmentLabel = new() { VerticalAlignment = VerticalAlignment.Center, TextWrapping = TextWrapping.Wrap };

    private AIChatSession? _currentSession;
    private string? _attachmentName;
    private string? _attachmentText;
    private bool _isSending;

    public AIChatPage()
    {
        _messageScroll.Content = _messagePanel;
        Content = BuildLayout();
        RenderMessages();
    }

    // ---- 布局 ----

    private UIElement BuildLayout()
    {
        var root = new Grid();
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var toolbar = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Padding = new Thickness(16, 12, 16, 4) };
        toolbar.Children.Add(IconButton("\uE710", Localization.Tr("ai.newChat"), OnNewChatClick));
        toolbar.Children.Add(IconButton("\uE81C", Localization.Tr("ai.history"), OnHistoryClick));
        Grid.SetRow(toolbar, 0);

        _inputBox.PlaceholderText = Localization.Tr("ai.input");
        _inputBox.AcceptsReturn = true;
        _sendButton.Content = new TextBlock { Text = Localization.Tr("ai.send") };
        _sendButton.Click += OnSendClick;

        var inputArea = BuildInputArea();
        Grid.SetRow(_messageScroll, 1);
        Grid.SetRow(inputArea, 2);

        root.Children.Add(toolbar);
        root.Children.Add(_messageScroll);
        root.Children.Add(inputArea);
        return root;
    }

    private FrameworkElement BuildInputArea()
    {
        var panel = new StackPanel { Spacing = 8, Padding = new Thickness(16, 4, 16, 16) };

        var attachRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        var attachBtn = new Button { Content = new TextBlock { Text = Localization.Tr("ai.attach") } };
        attachBtn.Click += OnAttachClick;
        attachRow.Children.Add(attachBtn);
        attachRow.Children.Add(_attachmentLabel);
        panel.Children.Add(attachRow);

        var inputRow = new Grid { ColumnSpacing = 8 };
        inputRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        inputRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        Grid.SetColumn(_inputBox, 0);
        Grid.SetColumn(_sendButton, 1);
        inputRow.Children.Add(_inputBox);
        inputRow.Children.Add(_sendButton);
        panel.Children.Add(inputRow);

        return panel;
    }

    private static Button IconButton(string glyph, string label, RoutedEventHandler handler)
    {
        var content = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        content.Children.Add(new FontIcon { Glyph = glyph, FontFamily = new FontFamily("Segoe Fluent Icons") });
        content.Children.Add(new TextBlock { Text = label });
        var btn = new Button { Content = content };
        btn.Click += handler;
        return btn;
    }

    // ---- 消息渲染 ----

    private void RenderMessages()
    {
        _messagePanel.Children.Clear();

        if (_messages.Count == 0 && !_isSending)
        {
            _messagePanel.Children.Add(new TextBlock
            {
                Text = Localization.Tr("ai.welcome"),
                TextWrapping = TextWrapping.Wrap,
                Foreground = new SolidColorBrush(Windows.UI.Color.FromArgb(255, 142, 142, 147)),
                HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(0, 24, 0, 0),
            });
        }
        else
        {
            foreach (var message in _messages)
                _messagePanel.Children.Add(BuildBubble(message));
            if (_isSending)
                _messagePanel.Children.Add(TypingIndicator());
        }

        _messageScroll.UpdateLayout();
        _messageScroll.ChangeView(null, _messageScroll.ScrollableHeight, null);
    }

    private static UIElement BuildBubble(ChatMessage message)
    {
        bool isUser = message.Role == ChatRole.User;
        return new Border
        {
            Background = new SolidColorBrush(
                isUser ? Windows.UI.Color.FromArgb(255, 0, 122, 255) : Windows.UI.Color.FromArgb(255, 229, 229, 234)),
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(12, 8, 12, 8),
            MaxWidth = 480,
            HorizontalAlignment = isUser ? HorizontalAlignment.Right : HorizontalAlignment.Left,
            Child = new TextBlock
            {
                Text = message.Text,
                TextWrapping = TextWrapping.Wrap,
                Foreground = new SolidColorBrush(isUser ? Colors.White : Colors.Black),
            },
        };
    }

    private static UIElement TypingIndicator() => new Border
    {
        Background = new SolidColorBrush(Windows.UI.Color.FromArgb(255, 229, 229, 234)),
        CornerRadius = new CornerRadius(8),
        Padding = new Thickness(12, 8, 12, 8),
        HorizontalAlignment = HorizontalAlignment.Left,
        Child = new TextBlock { Text = Localization.Tr("ai.sending") },
    };

    // ---- 交互 ----

    private void OnNewChatClick(object sender, RoutedEventArgs e)
    {
        _messages.Clear();
        _currentSession = null;
        _attachmentName = null;
        _attachmentText = null;
        _inputBox.Text = "";
        UpdateAttachmentLabel();
        RenderMessages();
    }

    private async void OnAttachClick(object sender, RoutedEventArgs e)
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

            _attachmentName = file.Name;
            _attachmentText = DocumentTextExtractor.ExtractText(file.Path);
            UpdateAttachmentLabel();
        }
        catch (Exception ex)
        {
            await Dialogs.ShowErrorAsync(App.MainWindow, Localization.Tr("common.error"), ex.Message);
        }
    }

    private async void OnSendClick(object sender, RoutedEventArgs e) => await SendAsync();

    private async System.Threading.Tasks.Task SendAsync()
    {
        var text = _inputBox.Text.Trim();
        if (text.Length == 0)
            return;
        _inputBox.Text = "";

        _messages.Add(new ChatMessage(ChatRole.User, text));

        _isSending = true;
        _sendButton.IsEnabled = false;
        RenderMessages();

        try
        {
            var reply = await AppServices.AI.ChatReplyAsync(
                _messages,
                _attachmentText,
                AppServices.AppSettings.AiModel,
                AppServices.AppSettings.ApiKey,
                AppServices.AppSettings.BaseUrl,
                AppServices.AppSettings.ModelId);

            string assistantText = reply.Message;
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
                    assistantText += $"\n\n{Localization.Tr("ai.generated")}";
                }
            }

            _messages.Add(new ChatMessage(ChatRole.Assistant, assistantText));
            SaveSession();
        }
        catch (Exception ex)
        {
            await Dialogs.ShowErrorAsync(App.MainWindow, Localization.Tr("common.error"), ex.Message);
        }
        finally
        {
            _isSending = false;
            _sendButton.IsEnabled = true;
            RenderMessages();
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

    // ---- 会话持久化 ----

    private void SaveSession()
    {
        if (_messages.Count == 0)
            return;

        _currentSession ??= new AIChatSession();
        _currentSession.Title = TitleOf(_messages);
        _currentSession.MessageCount = _messages.Count;
        _currentSession.MessagesJson = JsonSerializer.Serialize(_messages);
        _currentSession.AttachmentName = _attachmentName;
        _currentSession.AttachmentText = _attachmentText;
        _currentSession.UpdatedAt = DateTime.Now;
        _repo.Save(_currentSession);
    }

    private static string TitleOf(List<ChatMessage> messages)
    {
        var first = messages.Find(m => m.Role == ChatRole.User);
        var text = (first?.Text ?? "").Replace('\n', ' ').Trim();
        return text.Length <= 20 ? text : text.Substring(0, 20);
    }

    private static List<ChatMessage> DeserializeMessages(string json)
    {
        if (string.IsNullOrWhiteSpace(json))
            return new List<ChatMessage>();
        try
        {
            return JsonSerializer.Deserialize<List<ChatMessage>>(json) ?? new List<ChatMessage>();
        }
        catch (JsonException)
        {
            return new List<ChatMessage>();
        }
    }

    private void LoadSession(AIChatSession session)
    {
        _currentSession = session;
        _messages.Clear();
        _messages.AddRange(DeserializeMessages(session.MessagesJson));
        _attachmentName = session.AttachmentName;
        _attachmentText = session.AttachmentText;
        _inputBox.Text = "";
        UpdateAttachmentLabel();
        RenderMessages();
    }

    private void UpdateAttachmentLabel()
        => _attachmentLabel.Text = _attachmentName is null
            ? ""
            : $"{Localization.Tr("ai.attach")}: {_attachmentName}";

    // ---- 历史会话 ----

    private async void OnHistoryClick(object sender, RoutedEventArgs e) => await ShowHistoryAsync();

    private async System.Threading.Tasks.Task ShowHistoryAsync()
    {
        var sessions = _repo.LoadAll();

        var dialog = new ContentDialog
        {
            Title = Localization.Tr("ai.history"),
            CloseButtonText = Localization.Tr("common.cancel"),
            XamlRoot = App.MainWindow.Content.XamlRoot,
        };

        var listPanel = new StackPanel { Spacing = 8, MinWidth = 360 };
        if (sessions.Count == 0)
        {
            listPanel.Children.Add(new TextBlock
            {
                Text = Localization.Tr("ai.noHistory"),
                TextWrapping = TextWrapping.Wrap,
            });
        }
        else
        {
            foreach (var session in sessions)
            {
                listPanel.Children.Add(BuildSessionRow(
                    session,
                    onOpen: () =>
                    {
                        dialog.Hide();
                        LoadSession(session);
                    },
                    onDelete: () =>
                    {
                        dialog.Hide();
                        _ = DeleteAndRefreshAsync(session);
                    }));
            }
        }

        dialog.Content = new ScrollViewer { Content = listPanel, MaxHeight = 480 };
        await dialog.ShowAsync();
    }

    private UIElement BuildSessionRow(AIChatSession session, Action onOpen, Action onDelete)
    {
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var open = new Button
        {
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Left,
            Padding = new Thickness(8),
        };
        var content = new StackPanel { Spacing = 2 };
        content.Children.Add(new TextBlock
        {
            Text = string.IsNullOrEmpty(session.Title) ? Localization.Tr("ai.newChat") : session.Title,
            TextWrapping = TextWrapping.Wrap,
        });
        content.Children.Add(new TextBlock
        {
            Text = session.UpdatedAt.ToString("yyyy-MM-dd HH:mm"),
            FontSize = 12,
            Foreground = new SolidColorBrush(Windows.UI.Color.FromArgb(255, 142, 142, 147)),
        });
        open.Content = content;
        open.Click += (_, _) => onOpen();
        Grid.SetColumn(open, 0);

        var delete = new Button
        {
            Content = new FontIcon { Glyph = "\uE74D", FontFamily = new FontFamily("Segoe Fluent Icons") },
            VerticalAlignment = VerticalAlignment.Center,
        };
        delete.Click += (_, _) => onDelete();
        Grid.SetColumn(delete, 1);

        grid.Children.Add(open);
        grid.Children.Add(delete);
        return grid;
    }

    private async System.Threading.Tasks.Task DeleteAndRefreshAsync(AIChatSession session)
    {
        var ok = await Dialogs.ShowConfirmAsync(App.MainWindow, Localization.Tr("common.warning"), Localization.Tr("ai.deleteSession"));
        if (!ok)
        {
            await ShowHistoryAsync();
            return;
        }
        _repo.Delete(session.Id);
        await ShowHistoryAsync();
    }
}