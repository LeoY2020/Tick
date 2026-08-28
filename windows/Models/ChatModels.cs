namespace Tick.Models;

/// <summary>聊天消息角色</summary>
public enum ChatRole
{
    User,
    Assistant,
}

/// <summary>一条对话消息（AI 聊天 / 生成任务共用）</summary>
public class ChatMessage
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public ChatRole Role { get; set; }

    public string Text { get; set; } = "";

    public DateTime CreatedAt { get; set; } = DateTime.Now;

    public ChatMessage() { }

    public ChatMessage(ChatRole role, string text)
    {
        Role = role;
        Text = text;
    }
}

/// <summary>
/// AI 生成的任务树节点（宽容解码：缺字段不失败）。
/// </summary>
public class TaskNode
{
    public string Name { get; set; } = "";

    public List<TaskNode>? Children { get; set; } = new();
}

/// <summary>
/// 一次聊天回复的结构化结果：是否生成任务、生成的任务树、以及展示给用户看的文字。
/// 由模型输出 JSON envelope 解析而来：generate=true 时 tasks 写入当前目标（不展示），message 展示。
/// </summary>
public class ChatReply
{
    public bool ShouldGenerateTasks { get; set; }

    public List<TaskNode> Tasks { get; set; } = new();

    public string Message { get; set; } = "";
}