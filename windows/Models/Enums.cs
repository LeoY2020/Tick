using Tick.Services;

namespace Tick.Models;

/// <summary>任务类型：单项 / 进度</summary>
public enum TaskType
{
    /// <summary>单项任务</summary>
    Single,

    /// <summary>进度任务（总量 / 当前值）</summary>
    Progress,
}

/// <summary>任务状态：未完成 → 半完成 → 完成 / 删除</summary>
public enum TaskStatus
{
    /// <summary>未完成</summary>
    NotDone,

    /// <summary>半完成</summary>
    HalfDone,

    /// <summary>完成</summary>
    Done,

    /// <summary>删除（不计入进度）</summary>
    Deleted,
}

/// <summary>目标进度统计模式</summary>
public enum ProgressCountingMode
{
    /// <summary>统计父任务：所有层级任务均计入总量与进度（父任务按有效状态 / 进度折算）</summary>
    AllTasks,

    /// <summary>统计叶子任务：只统计任务树末端（无有效子任务）的节点</summary>
    LeafTasks,
}

/// <summary>提醒重复规则</summary>
public enum RepeatRule
{
    /// <summary>不重复</summary>
    Never,

    /// <summary>每天</summary>
    Daily,

    /// <summary>每周</summary>
    Weekly,

    /// <summary>每月</summary>
    Monthly,

    /// <summary>自定义（周几多选）</summary>
    Custom,
}

/// <summary>AI 服务模型（OpenAI 兼容协议，需用户自配 API Key；Custom 需额外配置 Base URL / 模型名）</summary>
public enum AIModel
{
    Qwen,
    DeepSeek,
    ChatGPT,
    Yuanbao,
    GLM,
    Kimi,
    Ernie,
    Grok,
    StepFun,
    MiniMax,
    Custom,
}

/// <summary>主题（配色方案）设置</summary>
public enum ColorSchemeSetting
{
    System,
    Light,
    Dark,
}

/// <summary>枚举显示名映射扩展（经 <see cref="Localization"/> 输出当前语言文本）</summary>
public static class EnumDisplay
{
    public static string ToDisplayName(this TaskType value) => value switch
    {
        TaskType.Single => Localization.Tr("task.single"),
        TaskType.Progress => Localization.Tr("task.progress"),
        _ => Localization.Tr("task.single"),
    };

    public static string ToDisplayName(this TaskStatus value) => value switch
    {
        TaskStatus.NotDone => Localization.Tr("task.notDone"),
        TaskStatus.HalfDone => Localization.Tr("task.halfDone"),
        TaskStatus.Done => Localization.Tr("task.done"),
        TaskStatus.Deleted => Localization.Tr("task.deleted"),
        _ => Localization.Tr("task.notDone"),
    };

    public static string ToDisplayName(this ProgressCountingMode value) => value switch
    {
        ProgressCountingMode.AllTasks => Localization.Tr("task.counting.all"),
        ProgressCountingMode.LeafTasks => Localization.Tr("task.counting.leaf"),
        _ => Localization.Tr("task.counting.all"),
    };

    public static string ToDisplayName(this RepeatRule value) => value switch
    {
        RepeatRule.Never => Localization.Tr("repeat.never"),
        RepeatRule.Daily => Localization.Tr("repeat.daily"),
        RepeatRule.Weekly => Localization.Tr("repeat.weekly"),
        RepeatRule.Monthly => Localization.Tr("repeat.monthly"),
        RepeatRule.Custom => Localization.Tr("repeat.custom"),
        _ => Localization.Tr("repeat.never"),
    };

    public static string ToDisplayName(this ColorSchemeSetting value) => value switch
    {
        ColorSchemeSetting.System => Localization.Tr("theme.system"),
        ColorSchemeSetting.Light => Localization.Tr("theme.light"),
        ColorSchemeSetting.Dark => Localization.Tr("theme.dark"),
        _ => Localization.Tr("theme.system"),
    };

    public static string ToDisplayName(this AIModel value) => value switch
    {
        AIModel.Qwen => Localization.Tr("ai.model.qwen"),
        AIModel.DeepSeek => Localization.Tr("ai.model.deepseek"),
        AIModel.ChatGPT => Localization.Tr("ai.model.chatgpt"),
        AIModel.Yuanbao => Localization.Tr("ai.model.yuanbao"),
        AIModel.GLM => Localization.Tr("ai.model.glm"),
        AIModel.Kimi => Localization.Tr("ai.model.kimi"),
        AIModel.Ernie => Localization.Tr("ai.model.ernie"),
        AIModel.Grok => Localization.Tr("ai.model.grok"),
        AIModel.StepFun => Localization.Tr("ai.model.stepfun"),
        AIModel.MiniMax => Localization.Tr("ai.model.minimax"),
        AIModel.Custom => Localization.Tr("ai.model.custom"),
        _ => Localization.Tr("ai.model.custom"),
    };

    /// <summary>模型默认 OpenAI 兼容 Base URL（不含 /chat/completions）</summary>
    public static string DefaultBaseUrl(this AIModel value) => value switch
    {
        AIModel.Qwen => "https://dashscope.aliyuncs.com/compatible-mode/v1",
        AIModel.DeepSeek => "https://api.deepseek.com/v1",
        AIModel.ChatGPT => "https://api.openai.com/v1",
        AIModel.Yuanbao => "https://api.hunyuan.cloud.tencent.com/v1",
        AIModel.GLM => "https://open.bigmodel.cn/api/paas/v4",
        AIModel.Kimi => "https://api.moonshot.cn/v1",
        AIModel.Ernie => "https://qianfan.baidubce.com/v2",
        AIModel.Grok => "https://api.x.ai/v1",
        AIModel.StepFun => "https://api.stepfun.com/v1",
        AIModel.MiniMax => "https://api.minimax.chat/v1",
        _ => "",
    };

    /// <summary>模型默认 ID</summary>
    public static string DefaultModelId(this AIModel value) => value switch
    {
        AIModel.Qwen => "qwen-plus",
        AIModel.DeepSeek => "deepseek-chat",
        AIModel.ChatGPT => "gpt-4o-mini",
        AIModel.Yuanbao => "hunyuan-turbo",
        AIModel.GLM => "glm-4-flash",
        AIModel.Kimi => "moonshot-v1-8k",
        AIModel.Ernie => "ernie-4.0-turbo-8k",
        AIModel.Grok => "grok-2-latest",
        AIModel.StepFun => "step-1-8k",
        AIModel.MiniMax => "abab6.5s-chat",
        _ => "",
    };
}