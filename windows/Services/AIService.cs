using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Tick.Models;

namespace Tick.Services;

/// <summary>AI 服务异常（中文提示）</summary>
public class AIServiceException : Exception
{
    public AIServiceException(string message) : base(message) { }
}

/// <summary>
/// AI 服务：统一走用户自配的 OpenAI 兼容 API（HttpClient 实现，非流式），
/// 支持多轮对话与任务树生成。系统提示词要求输出 JSON envelope，
/// 由 AI 自行判断是否生成任务（generate=true 时 tasks 写入目标、message 展示）。
/// </summary>
public sealed class AIService
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(60) };

    /// <summary>聊天系统提示词：要求输出 JSON envelope（任务入库 + 展示文字），由 AI 自行判断是否生成任务。</summary>
    internal const string ChatSystemPrompt = """
        你是一个严谨的中文任务规划助手。你可以依据以下两类信息来生成具体、可执行、有信息量的分层任务清单：
        1. 文档附件内容（通常在用户消息的"附件内容："之后）：从中提炼真实要点建任务，按章节、核心观点、待办事项拆分。
        2. 用户在对话中描述的任务与计划：即使没有附件，也依据对话上下文，把用户提出的需求、事项、时间安排等整理成分层任务树。

        硬性要求：
        1. 任务名要具体明确（如"核对第三章数据""完成市场分析草稿"），严禁生成"了解xxx""阅读附件""整理要点"这类空泛无信息的任务。
        2. 一级任务概括主题，二级任务给出具体动作或子步骤，层级嵌套。
        3. 只要用户明确要求"生成/整理任务"（无论仅提供附件、还是仅在对话中描述需求），都应 generate=true 并基于可用信息生成任务树。
        4. 仅当既没有附件正文、也没有明确的对话需求、实在无法提炼时，才返回 generate=false 并说明原因。

        你必须严格只输出一个 JSON 对象，不要输出 markdown 代码块，也不要输出 JSON 以外的任何文字：
        1. 用户要求生成/整理任务且能提炼要点时，输出：
        {"generate": true, "tasks": [{"name":"一级任务","children":[{"name":"二级任务"}]}], "message": "给用户看的一句话中文说明"}
        2. 用户要求生成任务、但既无附件正文也无明确对话需求、无法生成有意义任务时，输出：
        {"generate": false, "message": "我目前还缺少足够的信息来生成有意义的任务。你可以上传带文字的 PDF / Word / 文本，或在对话里描述你想规划的事项。"}
        3. 其他普通闲聊（未要求生成任务）时，输出：
        {"generate": false, "message": "你的回复文字"}
        """;

    /// <summary>
    /// 与 AI 聊天，返回结构化结果（AI 自行判断是否生成任务）。
    /// </summary>
    public async Task<ChatReply> ChatReplyAsync(
        IReadOnlyList<ChatMessage> history,
        string? attachmentText,
        AIModel model,
        string? apiKey,
        string? baseUrl,
        string? modelId,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(apiKey))
            throw new AIServiceException("请先在 设置 → AI 模型 中填写该模型的 API Key");

        var (url, id) = ResolveEndpoint(model, baseUrl, modelId);
        if (model == AIModel.Custom && string.IsNullOrWhiteSpace(url))
            throw new AIServiceException("自定义模型需要在设置中填写 Base URL");

        var merged = MergeHistory(history, attachmentText);
        if (merged.Count == 0)
            throw new AIServiceException("请先输入内容");

        var raw = await RequestTextAsync(url, id, apiKey, merged, cancellationToken);
        return ParseChatReply(raw);
    }

    // ---- 请求构造 / 发送 ----

    private static (string url, string modelId) ResolveEndpoint(AIModel model, string? baseUrl, string? modelId)
    {
        string url = model == AIModel.Custom
            ? (baseUrl ?? "")
            : model.DefaultBaseUrl();

        url = url.Trim().Replace("\r", "").Replace("\n", "");
        if (!string.IsNullOrEmpty(url))
        {
            url = url.TrimEnd('/');
            if (!url.EndsWith("/chat/completions", StringComparison.OrdinalIgnoreCase))
                url += "/chat/completions";
        }

        string id = model == AIModel.Custom
            ? (modelId ?? "").Trim()
            : (string.IsNullOrWhiteSpace(modelId) ? model.DefaultModelId() : modelId!.Trim());

        return (url, id);
    }

    private static async Task<string> RequestTextAsync(
        string url, string modelId, string apiKey,
        List<ChatMessage> history, CancellationToken cancellationToken)
    {
        if (string.IsNullOrEmpty(url))
            throw new AIServiceException("模型服务地址无效");

        var messages = new List<object> { new { role = "system", content = ChatSystemPrompt } };
        foreach (var m in history)
            messages.Add(new { role = m.Role == ChatRole.User ? "user" : "assistant", content = m.Text });

        var body = new { model = modelId, messages };
        string json = JsonSerializer.Serialize(body);

        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
        request.Content = new StringContent(json, Encoding.UTF8, "application/json");

        using var response = await Http.SendAsync(request, cancellationToken);
        string content = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
            throw new AIServiceException($"模型服务返回异常：HTTP {(int)response.StatusCode}");

        return ParseCloudResponse(content);
    }

    private static string ParseCloudResponse(string content)
    {
        using var doc = JsonDocument.Parse(content);
        var root = doc.RootElement;
        if (root.TryGetProperty("choices", out var choices) &&
            choices.ValueKind == JsonValueKind.Array &&
            choices.GetArrayLength() > 0)
        {
            var first = choices[0];
            if (first.TryGetProperty("message", out var message) &&
                message.TryGetProperty("content", out var text) &&
                text.ValueKind == JsonValueKind.String)
            {
                return text.GetString() ?? "";
            }
        }
        throw new AIServiceException("模型服务返回了异常响应");
    }

    // ---- 提示词注入 / 解析 ----

    /// <summary>把附件内容注入为对话首条"用户"消息</summary>
    private static List<ChatMessage> MergeHistory(IReadOnlyList<ChatMessage> history, string? attachmentText)
    {
        var result = new List<ChatMessage>(history);
        if (!string.IsNullOrWhiteSpace(attachmentText))
        {
            var trimmed = attachmentText.Trim();
            result.Insert(0, new ChatMessage(ChatRole.User, "附件内容：\n" + trimmed));
        }
        return result;
    }

    /// <summary>
    /// 解析 chatReply 的 JSON envelope。
    /// 解析失败或非 generate 时，把原文当普通文字回复展示（宽容回退）。
    /// </summary>
    internal static ChatReply ParseChatReply(string raw)
    {
        string cleaned = StripCodeFences(raw).Trim();
        if (TryExtractEnvelope(cleaned, out var generate, out var tasks, out var message))
        {
            if (generate)
            {
                var nodes = tasks.Where(t => !string.IsNullOrWhiteSpace(t.Name)).ToList();
                return new ChatReply
                {
                    ShouldGenerateTasks = true,
                    Tasks = nodes,
                    Message = string.IsNullOrEmpty(message) ? $"已为你生成 {nodes.Count} 个任务。" : message,
                };
            }
            if (!string.IsNullOrEmpty(message))
                return new ChatReply { Message = message };
        }
        return new ChatReply { Message = raw };
    }

    private static bool TryExtractEnvelope(
        string cleaned, out bool generate, out List<TaskNode> tasks, out string message)
    {
        generate = false;
        tasks = new List<TaskNode>();
        message = "";

        int start = cleaned.IndexOf('{');
        int end = cleaned.LastIndexOf('}');
        if (start < 0 || end <= start)
            return false;

        try
        {
            using var doc = JsonDocument.Parse(cleaned.Substring(start, end - start + 1));
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Object)
                return false;

            if (root.TryGetProperty("generate", out var g) && g.ValueKind == JsonValueKind.True)
                generate = true;
            if (root.TryGetProperty("message", out var m) && m.ValueKind == JsonValueKind.String)
                message = m.GetString() ?? "";
            if (root.TryGetProperty("tasks", out var t) && t.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in t.EnumerateArray())
                    tasks.Add(ParseTaskNode(item));
            }
            return true;
        }
        catch (JsonException)
        {
            return false;
        }
    }

    private static TaskNode ParseTaskNode(JsonElement item)
    {
        var node = new TaskNode();
        if (item.ValueKind != JsonValueKind.Object)
            return node;

        if (item.TryGetProperty("name", out var n) && n.ValueKind == JsonValueKind.String)
            node.Name = n.GetString() ?? "";
        if (item.TryGetProperty("children", out var c) && c.ValueKind == JsonValueKind.Array)
        {
            node.Children = new List<TaskNode>();
            foreach (var child in c.EnumerateArray())
                node.Children.Add(ParseTaskNode(child));
        }
        return node;
    }

    /// <summary>去掉 ``` 代码围栏（模型有时会把 JSON 包进 Markdown 代码块）</summary>
    internal static string StripCodeFences(string text)
    {
        var lines = text.Split('\n').ToList();
        if (lines.Count > 0 && lines[0].Contains("```"))
            lines.RemoveAt(0);
        if (lines.Count > 0 && lines[^1].Contains("```"))
            lines.RemoveAt(lines.Count - 1);
        return string.Join("\n", lines);
    }
}