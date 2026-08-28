using System.Collections.Generic;

namespace Tick.Services;

/// <summary>
/// 语言本地化：简体中文 / English 两套文本表。
/// 静态文本（XAML）经 <see cref="L"/> 标记扩展读取；代码动态字符串用 <see cref="Tr"/>。
/// 切换语言后由 MainWindow 重新导航当前页触发 XAML 重建，从而即时生效。
/// </summary>
public static class Localization
{
    private static string _lang = "zh";

    private static readonly Dictionary<string, string> Zh = new()
    {
        ["app.title"] = "Tick 待办",
        ["nav.goals"] = "目标",
        ["nav.ai"] = "AI 助手",
        ["nav.settings"] = "设置",

        ["goals.add"] = "新建目标",
        ["goals.edit"] = "编辑目标",
        ["goals.delete"] = "删除目标",
        ["goals.deleteConfirm"] = "确定删除目标“{0}”吗？其下全部任务将一并删除。",
        ["goals.empty"] = "还没有目标，点击左侧“+”新建",

        ["tasks.title"] = "任务",
        ["tasks.progress"] = "总进度",
        ["tasks.completed"] = "已完成 {0}/{1}",
        ["tasks.countdown"] = "倒计时",
        ["tasks.add"] = "添加任务",
        ["tasks.addSubtask"] = "添加子任务",
        ["tasks.edit"] = "编辑任务",
        ["tasks.delete"] = "删除任务",
        ["tasks.deleteConfirm"] = "确定删除任务“{0}”吗？其下全部子任务将一并删除。",
        ["tasks.noEndDate"] = "未设置截止日期",

        ["task.name"] = "名称",
        ["task.type"] = "类型",
        ["task.single"] = "单项",
        ["task.progress"] = "进度",
        ["task.status"] = "状态",
        ["task.notDone"] = "未完成",
        ["task.halfDone"] = "半完成",
        ["task.done"] = "完成",
        ["task.deleted"] = "删除",
        ["task.total"] = "总量",
        ["task.current"] = "当前",
        ["task.color"] = "颜色",
        ["task.color.auto"] = "自动",
        ["task.startDate"] = "开始日期",
        ["task.endDate"] = "截止日期",
        ["task.preciseToHour"] = "精确到小时",
        ["task.reminder"] = "提醒",
        ["task.inherited"] = "（继承父级）",
        ["task.takenOver"] = "（由子任务接管）",

        ["repeat.never"] = "不重复",
        ["repeat.daily"] = "每天",
        ["repeat.weekly"] = "每周",
        ["repeat.monthly"] = "每月",
        ["repeat.custom"] = "自定义",
        ["weekday.1"] = "周日",
        ["weekday.2"] = "周一",
        ["weekday.3"] = "周二",
        ["weekday.4"] = "周三",
        ["weekday.5"] = "周四",
        ["weekday.6"] = "周五",
        ["weekday.7"] = "周六",

        ["common.cancel"] = "取消",
        ["common.ok"] = "确定",
        ["common.save"] = "保存",
        ["common.name"] = "名称",
        ["common.error"] = "错误",
        ["common.notice"] = "提示",
        ["common.warning"] = "警告",

        ["settings.title"] = "设置",
        ["settings.theme"] = "配色方案",
        ["theme.system"] = "跟随系统",
        ["theme.light"] = "亮色",
        ["theme.dark"] = "暗色",
        ["settings.language"] = "语言",
        ["lang.zh"] = "简体中文",
        ["lang.en"] = "English",
        ["settings.ai"] = "AI 配置",
        ["settings.copilot"] = "Windows Copilot",
        ["settings.copilotHint"] = "Windows 无公开的第三方本地大模型 API，因此不内嵌 AI。可在下方配置任一 OpenAI 兼容模型的 API Key，聊天 / 生成任务会走该接口。",
        ["settings.copilotOpen"] = "打开 Copilot",
        ["settings.model"] = "模型",
        ["settings.apiKey"] = "API Key（DPAPI 加密存储）",
        ["settings.baseUrl"] = "Base URL",
        ["settings.modelId"] = "模型名称",
        ["settings.backup"] = "备份 / 恢复",
        ["settings.export"] = "导出为 JSON 文件",
        ["settings.import"] = "从 JSON 文件导入",
        ["settings.importConfirm"] = "导入将合并当前数据库（已有目标按 Id 覆盖）。是否继续？",
        ["settings.documents"] = "附件解析",
        ["settings.documentsHint"] = "支持 .txt / .md / Markdown / .docx；.pdf 需第三方库，本版本未内置。",

        ["ai.title"] = "AI 助手",
        ["ai.hint"] = "描述你想规划的事项，或上传附件让 AI 提炼任务。AI 会输出 JSON：generate=true 时任务树直接写入当前目标。",
        ["ai.input"] = "输入消息…",
        ["ai.send"] = "发送",
        ["ai.attach"] = "附件",
        ["ai.clear"] = "清空对话",
        ["ai.noAttachText"] = "该附件暂无法解析（仅支持 .txt/.md/.docx）",
        ["ai.notConfigured"] = "尚未配置 API Key，请在 设置 → AI 模型 中填写。",
        ["ai.sending"] = "正在思考…",
        ["ai.generated"] = "已将生成的任务写入当前目标。",
        ["ai.history"] = "历史会话",
    };

    private static readonly Dictionary<string, string> En = new()
    {
        ["app.title"] = "Tick Todo",
        ["nav.goals"] = "Goals",
        ["nav.ai"] = "AI Assistant",
        ["nav.settings"] = "Settings",

        ["goals.add"] = "New Goal",
        ["goals.edit"] = "Edit Goal",
        ["goals.delete"] = "Delete Goal",
        ["goals.deleteConfirm"] = "Delete goal \"{0}\"? All its tasks will be removed.",
        ["goals.empty"] = "No goals yet. Tap the \"+\" on the left to add one.",

        ["tasks.title"] = "Tasks",
        ["tasks.progress"] = "Progress",
        ["tasks.completed"] = "Done {0}/{1}",
        ["tasks.countdown"] = "Countdown",
        ["tasks.add"] = "Add Task",
        ["tasks.addSubtask"] = "Add Subtask",
        ["tasks.edit"] = "Edit Task",
        ["tasks.delete"] = "Delete Task",
        ["tasks.deleteConfirm"] = "Delete task \"{0}\"? All its subtasks will be removed.",
        ["tasks.noEndDate"] = "No due date",

        ["task.name"] = "Name",
        ["task.type"] = "Type",
        ["task.single"] = "Single",
        ["task.progress"] = "Progress",
        ["task.status"] = "Status",
        ["task.notDone"] = "Not done",
        ["task.halfDone"] = "Half done",
        ["task.done"] = "Done",
        ["task.deleted"] = "Deleted",
        ["task.total"] = "Total",
        ["task.current"] = "Current",
        ["task.color"] = "Color",
        ["task.color.auto"] = "Auto",
        ["task.startDate"] = "Start date",
        ["task.endDate"] = "Due date",
        ["task.preciseToHour"] = "Precise to hour",
        ["task.reminder"] = "Reminder",
        ["task.inherited"] = "(inherit)",
        ["task.takenOver"] = "(taken over by subtasks)",

        ["repeat.never"] = "Never",
        ["repeat.daily"] = "Daily",
        ["repeat.weekly"] = "Weekly",
        ["repeat.monthly"] = "Monthly",
        ["repeat.custom"] = "Custom",
        ["weekday.1"] = "Sun",
        ["weekday.2"] = "Mon",
        ["weekday.3"] = "Tue",
        ["weekday.4"] = "Wed",
        ["weekday.5"] = "Thu",
        ["weekday.6"] = "Fri",
        ["weekday.7"] = "Sat",

        ["common.cancel"] = "Cancel",
        ["common.ok"] = "OK",
        ["common.save"] = "Save",
        ["common.name"] = "Name",
        ["common.error"] = "Error",
        ["common.notice"] = "Notice",
        ["common.warning"] = "Warning",

        ["settings.title"] = "Settings",
        ["settings.theme"] = "Color scheme",
        ["theme.system"] = "Follow system",
        ["theme.light"] = "Light",
        ["theme.dark"] = "Dark",
        ["settings.language"] = "Language",
        ["lang.zh"] = "简体中文",
        ["lang.en"] = "English",
        ["settings.ai"] = "AI Configuration",
        ["settings.copilot"] = "Windows Copilot",
        ["settings.copilotHint"] = "Windows has no public third-party on-device LLM API, so no AI is embedded here. Configure any OpenAI-compatible API below; chat / task generation uses it.",
        ["settings.copilotOpen"] = "Open Copilot",
        ["settings.model"] = "Model",
        ["settings.apiKey"] = "API Key (encrypted with DPAPI)",
        ["settings.baseUrl"] = "Base URL",
        ["settings.modelId"] = "Model name",
        ["settings.backup"] = "Backup / Restore",
        ["settings.export"] = "Export to JSON file",
        ["settings.import"] = "Import from JSON file",
        ["settings.importConfirm"] = "Import will merge into the current database (existing goals are overwritten by Id). Continue?",
        ["settings.documents"] = "Attachment parsing",
        ["settings.documentsHint"] = "Supports .txt / .md / Markdown / .docx; .pdf requires a third-party library and is not built in.",

        ["ai.title"] = "AI Assistant",
        ["ai.hint"] = "Describe what you want to plan, or attach a document to extract tasks. AI returns JSON: when generate=true, the task tree is written into the current goal.",
        ["ai.input"] = "Type a message…",
        ["ai.send"] = "Send",
        ["ai.attach"] = "Attach",
        ["ai.clear"] = "Clear chat",
        ["ai.noAttachText"] = "Cannot parse this attachment (only .txt/.md/.docx supported).",
        ["ai.notConfigured"] = "API Key not configured. Go to Settings → AI Model to set it.",
        ["ai.sending"] = "Thinking…",
        ["ai.generated"] = "Generated tasks written into the current goal.",
        ["ai.history"] = "History",
    };

    public static string Language => _lang;

    public static bool IsEnglish => _lang == "en";

    /// <summary>语言切换事件（MainWindow 据此重新导航 / 重建界面）</summary>
    public static event System.Action? LanguageChanged;

    public static void SetLanguage(string lang)
    {
        lang = lang == "en" ? "en" : "zh";
        if (_lang == lang)
            return;
        _lang = lang;
        LanguageChanged?.Invoke();
    }

    public static string Tr(string key)
    {
        var table = IsEnglish ? En : Zh;
        if (table.TryGetValue(key, out var v))
            return v;
        return Zh.TryGetValue(key, out var fallback) ? fallback : key;
    }
}

/// <summary>XAML 静态文本的本地化标记扩展：Text="{local:L Key=...}"</summary>
[Microsoft.UI.Xaml.Markup.MarkupExtensionReturnType(ReturnType = typeof(string))]
public sealed class L : Microsoft.UI.Xaml.Markup.MarkupExtension
{
    public string Key { get; set; } = "";

    protected override object ProvideValue() => Localization.Tr(Key);
}