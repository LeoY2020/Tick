using Windows.System;

namespace Tick.Services;

/// <summary>
/// Windows Copilot 入口：提供 Fluent 风格快捷按钮的打开逻辑。
/// 仅为可选快捷入口；实际聊天 / 任务生成统一走用户自配的 OpenAI 兼容 API（见 AIService）。
/// </summary>
public static class CopilotService
{
    /// <summary>打开 Windows Copilot（优先 ms-copilot 协议，失败回退网页版）</summary>
    public static async Task<bool> OpenAsync()
    {
        try
        {
            if (await Launcher.LaunchUriAsync(new Uri("ms-copilot:")))
                return true;
        }
        catch
        {
            // ms-copilot 协议不存在时回退
        }

        try
        {
            return await Launcher.LaunchUriAsync(new Uri("https://copilot.microsoft.com"));
        }
        catch
        {
            return false;
        }
    }
}