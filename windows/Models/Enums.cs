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

/// <summary>枚举与中文显示名的映射扩展</summary>
public static class EnumDisplay
{
    public static string ToDisplayName(this TaskType value) => value switch
    {
        TaskType.Single => "单项",
        TaskType.Progress => "进度",
        _ => "单项",
    };

    public static string ToDisplayName(this TaskStatus value) => value switch
    {
        TaskStatus.NotDone => "未完成",
        TaskStatus.HalfDone => "半完成",
        TaskStatus.Done => "完成",
        TaskStatus.Deleted => "删除",
        _ => "未完成",
    };

    public static string ToDisplayName(this ProgressCountingMode value) => value switch
    {
        ProgressCountingMode.AllTasks => "全部任务",
        ProgressCountingMode.LeafTasks => "仅叶子任务",
        _ => "全部任务",
    };

    public static string ToDisplayName(this RepeatRule value) => value switch
    {
        RepeatRule.Never => "不重复",
        RepeatRule.Daily => "每天",
        RepeatRule.Weekly => "每周",
        RepeatRule.Monthly => "每月",
        RepeatRule.Custom => "自定义",
        _ => "不重复",
    };

    public static string ToDisplayName(this ColorSchemeSetting value) => value switch
    {
        ColorSchemeSetting.System => "跟随系统",
        ColorSchemeSetting.Light => "亮色",
        ColorSchemeSetting.Dark => "暗色",
        _ => "跟随系统",
    };

    public static string ToDisplayName(this AIModel value) => value switch
    {
        AIModel.Qwen => "千问",
        AIModel.DeepSeek => "DeepSeek",
        AIModel.ChatGPT => "ChatGPT",
        AIModel.Yuanbao => "元宝",
        AIModel.GLM => "GLM",
        AIModel.Kimi => "Kimi",
        AIModel.Ernie => "文心",
        AIModel.Grok => "Grok",
        AIModel.StepFun => "阶跃星辰",
        AIModel.MiniMax => "MiniMax",
        AIModel.Custom => "自定义",
        _ => "自定义",
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