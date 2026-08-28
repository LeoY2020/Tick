using System.ComponentModel;
using System.Runtime.CompilerServices;
using Tick.Models;
using Tick.Services;

namespace Tick.ViewModels;

/// <summary>
/// 设置页 ViewModel：包装 <see cref="AppSettings"/>（配色 / 语言 / AI 配置）。
/// 保存由视图调用 <see cref="Save"/>，保存后触发主题与语言变更通知。
/// </summary>
public sealed class SettingsViewModel : INotifyPropertyChanged
{
    private readonly AppSettings _settings;

    public event PropertyChangedEventHandler? PropertyChanged;

    public SettingsViewModel(AppSettings settings)
    {
        _settings = settings;
        SelectedColorScheme = settings.ColorScheme;
        SelectedLanguage = settings.Language == "en" ? "en" : "zh";
        SelectedModel = settings.AiModel;
        ApiKey = settings.ApiKey;
        BaseUrl = settings.BaseUrl;
        ModelId = settings.ModelId;
    }

    public ColorSchemeSetting SelectedColorScheme { get; set; }

    public string SelectedLanguage { get; set; }

    public AIModel SelectedModel { get; set; }

    public string ApiKey { get; set; }

    public string BaseUrl { get; set; }

    public string ModelId { get; set; }

    public IReadOnlyList<ColorSchemeSetting> ColorSchemes { get; } =
        new[] { ColorSchemeSetting.System, ColorSchemeSetting.Light, ColorSchemeSetting.Dark };

    public IReadOnlyList<string> Languages { get; } = new[] { "zh", "en" };

    public IReadOnlyList<AIModel> Models { get; } = new[]
    {
        AIModel.DeepSeek, AIModel.Qwen, AIModel.ChatGPT, AIModel.GLM, AIModel.Kimi,
        AIModel.Ernie, AIModel.Grok, AIModel.StepFun, AIModel.MiniMax, AIModel.Custom,
    };

    /// <summary>当前模型的默认 OpenAI 兼容 Base URL（不含 /chat/completions）</summary>
    public string CurrentModelDefaultBaseUrl => SelectedModel.DefaultBaseUrl();

    public string CurrentModelDefaultId => SelectedModel.DefaultModelId();

    /// <summary>保存设置到数据库，并通知主题 / 语言变更。</summary>
    public void Save()
    {
        _settings.ColorScheme = SelectedColorScheme;
        _settings.AiModel = SelectedModel;
        _settings.ApiKey = ApiKey ?? "";
        _settings.BaseUrl = BaseUrl ?? "";
        _settings.ModelId = ModelId ?? "";
        _settings.Language = SelectedLanguage;
        _settings.Save();
        Localization.SetLanguage(SelectedLanguage);
    }

    private void Raise([CallerMemberName] string? name = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}