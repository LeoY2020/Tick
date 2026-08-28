#pragma once

#include <QDateTime>
#include <QString>
#include <QUuid>

#include <optional>
#include <string>

namespace tick {

// ---------------------------------------------------------------------------
// 核心枚举。枚举原始值以 lowerCamelCase 字符串入库（与既有数据格式保持一致）。
// ---------------------------------------------------------------------------

enum class TaskType { Single, Progress };

enum class TaskStatus { NotDone, HalfDone, Done, Deleted };

enum class RepeatRule { Never, Daily, Weekly, Monthly, Custom };

enum class ProgressCountingMode { AllTasks, LeafTasks };

// AI 模型供应商（Linux 无系统级 AI，全部走 OpenAI 兼容接口，无设备端模型）
enum class AIProvider {
    Qwen,      // 千问
    DeepSeek,  // DeepSeek
    ChatGPT,   // ChatGPT
    Yuanbao,   // 元宝
    Claude,    // Claude
    Gemini,    // Gemini
    GLM,       // GLM
    Kimi,      // Kimi
    Ernie,     // 文心
    Grok,      // Grok
    StepFun,   // 阶跃星辰
    MiniMax,   // MiniMax
    Custom     // 自定义
};

// ---------------------------------------------------------------------------
// 唯一 ID：UUID，去掉连字符
// ---------------------------------------------------------------------------
inline std::string makeId() {
    return QUuid::createUuid().toString(QUuid::WithoutBraces).toStdString();
}

// ---------------------------------------------------------------------------
// 日期序列化（入库为 ISO 字符串；空 optional 存空串）
// ---------------------------------------------------------------------------
inline QString dateTimeToString(const std::optional<QDateTime>& dt) {
    if (!dt.has_value()) return QString();
    return dt->toString(Qt::ISODateWithMs);
}

inline std::optional<QDateTime> dateTimeFromString(const QString& s) {
    if (s.isEmpty()) return std::nullopt;
    QDateTime d = QDateTime::fromString(s, Qt::ISODateWithMs);
    if (!d.isValid()) d = QDateTime::fromString(s, Qt::ISODate);
    return d.isValid() ? std::optional<QDateTime>(d) : std::nullopt;
}

// ---------------------------------------------------------------------------
// TaskType <-> 字符串
// ---------------------------------------------------------------------------
inline QString taskTypeToString(TaskType t) {
    switch (t) {
        case TaskType::Single: return QStringLiteral("single");
        case TaskType::Progress: return QStringLiteral("progress");
    }
    return QStringLiteral("single");
}

inline TaskType taskTypeFromString(const QString& s, TaskType fallback = TaskType::Single) {
    if (s == QLatin1String("progress")) return TaskType::Progress;
    return fallback;
}

inline QString taskTypeDisplayName(TaskType t) {
    switch (t) {
        case TaskType::Single: return QStringLiteral("单项");
        case TaskType::Progress: return QStringLiteral("进度");
    }
    return QStringLiteral("单项");
}

// ---------------------------------------------------------------------------
// TaskStatus <-> 字符串
// ---------------------------------------------------------------------------
inline QString taskStatusToString(TaskStatus s) {
    switch (s) {
        case TaskStatus::NotDone: return QStringLiteral("notDone");
        case TaskStatus::HalfDone: return QStringLiteral("halfDone");
        case TaskStatus::Done: return QStringLiteral("done");
        case TaskStatus::Deleted: return QStringLiteral("deleted");
    }
    return QStringLiteral("notDone");
}

inline TaskStatus taskStatusFromString(const QString& s, TaskStatus fallback = TaskStatus::NotDone) {
    if (s == QLatin1String("halfDone")) return TaskStatus::HalfDone;
    if (s == QLatin1String("done")) return TaskStatus::Done;
    if (s == QLatin1String("deleted")) return TaskStatus::Deleted;
    return fallback;
}

inline QString taskStatusDisplayName(TaskStatus s) {
    switch (s) {
        case TaskStatus::NotDone: return QStringLiteral("未完成");
        case TaskStatus::HalfDone: return QStringLiteral("半完成");
        case TaskStatus::Done: return QStringLiteral("完成");
        case TaskStatus::Deleted: return QStringLiteral("删除");
    }
    return QStringLiteral("未完成");
}

// ---------------------------------------------------------------------------
// RepeatRule <-> 字符串
// ---------------------------------------------------------------------------
inline QString repeatRuleToString(RepeatRule r) {
    switch (r) {
        case RepeatRule::Never: return QStringLiteral("never");
        case RepeatRule::Daily: return QStringLiteral("daily");
        case RepeatRule::Weekly: return QStringLiteral("weekly");
        case RepeatRule::Monthly: return QStringLiteral("monthly");
        case RepeatRule::Custom: return QStringLiteral("custom");
    }
    return QStringLiteral("never");
}

inline RepeatRule repeatRuleFromString(const QString& s, RepeatRule fallback = RepeatRule::Never) {
    if (s == QLatin1String("daily")) return RepeatRule::Daily;
    if (s == QLatin1String("weekly")) return RepeatRule::Weekly;
    if (s == QLatin1String("monthly")) return RepeatRule::Monthly;
    if (s == QLatin1String("custom")) return RepeatRule::Custom;
    return fallback;
}

inline QString repeatRuleDisplayName(RepeatRule r) {
    switch (r) {
        case RepeatRule::Never: return QStringLiteral("不重复");
        case RepeatRule::Daily: return QStringLiteral("每天");
        case RepeatRule::Weekly: return QStringLiteral("每周");
        case RepeatRule::Monthly: return QStringLiteral("每月");
        case RepeatRule::Custom: return QStringLiteral("自定义");
    }
    return QStringLiteral("不重复");
}

// ---------------------------------------------------------------------------
// ProgressCountingMode <-> 字符串
// ---------------------------------------------------------------------------
inline QString countingModeToString(ProgressCountingMode m) {
    switch (m) {
        case ProgressCountingMode::AllTasks: return QStringLiteral("allTasks");
        case ProgressCountingMode::LeafTasks: return QStringLiteral("leafTasks");
    }
    return QStringLiteral("allTasks");
}

inline ProgressCountingMode countingModeFromString(const QString& s,
                                                   ProgressCountingMode fallback = ProgressCountingMode::AllTasks) {
    if (s == QLatin1String("leafTasks")) return ProgressCountingMode::LeafTasks;
    return fallback;
}

inline QString countingModeDisplayName(ProgressCountingMode m) {
    switch (m) {
        case ProgressCountingMode::AllTasks: return QStringLiteral("全部任务");
        case ProgressCountingMode::LeafTasks: return QStringLiteral("仅叶子任务");
    }
    return QStringLiteral("全部任务");
}

// ---------------------------------------------------------------------------
// AIProvider <-> 字符串 / 显示名 / 预设（OpenAI 兼容 Base URL 与默认模型名）
// ---------------------------------------------------------------------------
inline QString aiProviderToString(AIProvider p) {
    switch (p) {
        case AIProvider::Qwen: return QStringLiteral("qwen");
        case AIProvider::DeepSeek: return QStringLiteral("deepseek");
        case AIProvider::ChatGPT: return QStringLiteral("chatgpt");
        case AIProvider::Yuanbao: return QStringLiteral("yuanbao");
        case AIProvider::Claude: return QStringLiteral("claude");
        case AIProvider::Gemini: return QStringLiteral("gemini");
        case AIProvider::GLM: return QStringLiteral("glm");
        case AIProvider::Kimi: return QStringLiteral("kimi");
        case AIProvider::Ernie: return QStringLiteral("ernie");
        case AIProvider::Grok: return QStringLiteral("grok");
        case AIProvider::StepFun: return QStringLiteral("stepfun");
        case AIProvider::MiniMax: return QStringLiteral("minimax");
        case AIProvider::Custom: return QStringLiteral("custom");
    }
    return QStringLiteral("custom");
}

inline AIProvider aiProviderFromString(const QString& s, AIProvider fallback = AIProvider::Custom) {
    if (s == QLatin1String("qwen")) return AIProvider::Qwen;
    if (s == QLatin1String("deepseek")) return AIProvider::DeepSeek;
    if (s == QLatin1String("chatgpt")) return AIProvider::ChatGPT;
    if (s == QLatin1String("yuanbao")) return AIProvider::Yuanbao;
    if (s == QLatin1String("claude")) return AIProvider::Claude;
    if (s == QLatin1String("gemini")) return AIProvider::Gemini;
    if (s == QLatin1String("glm")) return AIProvider::GLM;
    if (s == QLatin1String("kimi")) return AIProvider::Kimi;
    if (s == QLatin1String("ernie")) return AIProvider::Ernie;
    if (s == QLatin1String("grok")) return AIProvider::Grok;
    if (s == QLatin1String("stepfun")) return AIProvider::StepFun;
    if (s == QLatin1String("minimax")) return AIProvider::MiniMax;
    return fallback;
}

inline QString aiProviderDisplayName(AIProvider p) {
    switch (p) {
        case AIProvider::Qwen: return QStringLiteral("千问");
        case AIProvider::DeepSeek: return QStringLiteral("DeepSeek");
        case AIProvider::ChatGPT: return QStringLiteral("ChatGPT");
        case AIProvider::Yuanbao: return QStringLiteral("元宝");
        case AIProvider::Claude: return QStringLiteral("Claude");
        case AIProvider::Gemini: return QStringLiteral("Gemini");
        case AIProvider::GLM: return QStringLiteral("GLM");
        case AIProvider::Kimi: return QStringLiteral("Kimi");
        case AIProvider::Ernie: return QStringLiteral("文心");
        case AIProvider::Grok: return QStringLiteral("Grok");
        case AIProvider::StepFun: return QStringLiteral("阶跃星辰");
        case AIProvider::MiniMax: return QStringLiteral("MiniMax");
        case AIProvider::Custom: return QStringLiteral("自定义");
    }
    return QStringLiteral("自定义");
}

// 预设 Base URL（不含 /chat/completions 后缀，由 AIService 拼接）
inline QString aiProviderBaseUrl(AIProvider p) {
    switch (p) {
        case AIProvider::Qwen: return QStringLiteral("https://dashscope.aliyuncs.com/compatible-mode/v1");
        case AIProvider::DeepSeek: return QStringLiteral("https://api.deepseek.com/v1");
        case AIProvider::ChatGPT: return QStringLiteral("https://api.openai.com/v1");
        case AIProvider::Yuanbao: return QStringLiteral("https://api.hunyuan.cloud.tencent.com/v1");
        case AIProvider::Claude: return QStringLiteral("https://api.anthropic.com/v1");
        case AIProvider::Gemini: return QStringLiteral("https://generativelanguage.googleapis.com/v1beta/openai");
        case AIProvider::GLM: return QStringLiteral("https://open.bigmodel.cn/api/paas/v4");
        case AIProvider::Kimi: return QStringLiteral("https://api.moonshot.cn/v1");
        case AIProvider::Ernie: return QStringLiteral("https://qianfan.baidubce.com/v2");
        case AIProvider::Grok: return QStringLiteral("https://api.x.ai/v1");
        case AIProvider::StepFun: return QStringLiteral("https://api.stepfun.com/v1");
        case AIProvider::MiniMax: return QStringLiteral("https://api.minimaxi.com/v1");
        case AIProvider::Custom: return QString();
    }
    return QString();
}

// 预设默认模型名
inline QString aiProviderDefaultModel(AIProvider p) {
    switch (p) {
        case AIProvider::Qwen: return QStringLiteral("qwen-plus");
        case AIProvider::DeepSeek: return QStringLiteral("deepseek-chat");
        case AIProvider::ChatGPT: return QStringLiteral("gpt-4o-mini");
        case AIProvider::Yuanbao: return QStringLiteral("hunyuan-turbo");
        case AIProvider::Claude: return QStringLiteral("claude-sonnet-4-20250514");
        case AIProvider::Gemini: return QStringLiteral("gemini-2.0-flash");
        case AIProvider::GLM: return QStringLiteral("glm-4-flash");
        case AIProvider::Kimi: return QStringLiteral("moonshot-v1-8k");
        case AIProvider::Ernie: return QStringLiteral("ernie-4.0-turbo-8k");
        case AIProvider::Grok: return QStringLiteral("grok-2-latest");
        case AIProvider::StepFun: return QStringLiteral("step-1-8k");
        case AIProvider::MiniMax: return QStringLiteral("abab6.5s-chat");
        case AIProvider::Custom: return QString();
    }
    return QString();
}

// 是否需要在设置中填写 API Key（Linux 无设备端模型，全部需要）
inline bool aiProviderRequiresApiKey(AIProvider) {
    return true;
}

} // namespace tick