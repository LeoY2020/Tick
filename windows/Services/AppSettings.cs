using System.Security.Cryptography;
using System.Text;
using Tick.Data;
using Tick.Models;

namespace Tick.Services;

/// <summary>
/// 应用设置（主题 / AI 模型 / API Key / Base URL / 模型名）。
/// API Key 使用 Windows DPAPI（CurrentUser）加密后存储，避免明文落盘。
/// </summary>
public sealed class AppSettings
{
    private const string KeyColorScheme = "settings.colorScheme";
    private const string KeyAiModel = "settings.aiModel";
    private const string KeyApiKey = "settings.apiKey";
    private const string KeyBaseUrl = "settings.baseUrl";
    private const string KeyModelId = "settings.modelId";
    private const string KeyLanguage = "settings.language";

    /// <summary>键名快照：所有当前已知设置键（用于重置 / 清理）</summary>
    public static readonly string[] AllKeys = { KeyColorScheme, KeyAiModel, KeyApiKey, KeyBaseUrl, KeyModelId, KeyLanguage };

    private readonly SettingsRepository _repo;

    public ColorSchemeSetting ColorScheme { get; set; } = ColorSchemeSetting.System;

    public AIModel AiModel { get; set; } = AIModel.DeepSeek;

    public string ApiKey { get; set; } = "";

    /// <summary>自定义 / 覆盖的 Base URL（空 = 用模型默认）</summary>
    public string BaseUrl { get; set; } = "";

    /// <summary>自定义 / 覆盖的模型名（空 = 用模型默认）</summary>
    public string ModelId { get; set; } = "";

    /// <summary>界面语言（"zh" / "en"）</summary>
    public string Language { get; set; } = "zh";

    private AppSettings(SettingsRepository repo) => _repo = repo;

    public static AppSettings Load(SettingsRepository repo)
    {
        var s = new AppSettings(repo);
        s.ColorScheme = Enum.TryParse<ColorSchemeSetting>(repo.Get(KeyColorScheme), out var cs) ? cs : ColorSchemeSetting.System;
        s.AiModel = Enum.TryParse<AIModel>(repo.Get(KeyAiModel), out var m) ? m : AIModel.DeepSeek;
        s.ApiKey = Decrypt(repo.Get(KeyApiKey));
        s.BaseUrl = repo.Get(KeyBaseUrl) ?? "";
        s.ModelId = repo.Get(KeyModelId) ?? "";
        s.Language = repo.Get(KeyLanguage) ?? "zh";
        return s;
    }

    public void Save()
    {
        _repo.Set(KeyColorScheme, ColorScheme.ToString());
        _repo.Set(KeyAiModel, AiModel.ToString());
        _repo.Set(KeyApiKey, Encrypt(ApiKey));
        _repo.Set(KeyBaseUrl, BaseUrl);
        _repo.Set(KeyModelId, ModelId);
        _repo.Set(KeyLanguage, Language);
    }

    /// <summary>是否已配置可用的 AI（API Key 与模型名非空）</summary>
    public bool IsAiConfigured() => !string.IsNullOrWhiteSpace(ApiKey);

    private static string Encrypt(string plain)
    {
        if (string.IsNullOrEmpty(plain))
            return "";
        var bytes = ProtectedData.Protect(Encoding.UTF8.GetBytes(plain), null, DataProtectionScope.CurrentUser);
        return Convert.ToBase64String(bytes);
    }

    private static string Decrypt(string? cipher)
    {
        if (string.IsNullOrEmpty(cipher))
            return "";
        try
        {
            var bytes = ProtectedData.Unprotect(Convert.FromBase64String(cipher), null, DataProtectionScope.CurrentUser);
            return Encoding.UTF8.GetString(bytes);
        }
        catch (CryptographicException)
        {
            return "";
        }
    }
}