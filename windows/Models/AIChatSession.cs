namespace Tick.Models;

/// <summary>
/// AI 聊天历史记录：持久化一次会话的消息与附件快照，供「AI 历史」恢复。
/// </summary>
public class AIChatSession
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>会话标题（取首条用户消息摘要）</summary>
    public string Title { get; set; } = "";

    public DateTime CreatedAt { get; set; } = DateTime.Now;

    public DateTime UpdatedAt { get; set; } = DateTime.Now;

    /// <summary>消息列表的 JSON 编码（[ChatMessage]）</summary>
    public string MessagesJson { get; set; } = "";

    public int MessageCount { get; set; }

    public string? AttachmentName { get; set; }

    public string? AttachmentText { get; set; }
}