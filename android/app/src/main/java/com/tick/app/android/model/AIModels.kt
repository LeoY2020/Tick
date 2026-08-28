package com.tick.app.android.model

/**
 * AI 模型。Android 各厂商助手（小爱/YOYO/Bixby/小布/Jovi/Aicy）无第三方公开大模型 API，
 * 统一走 OpenAI 兼容 API（用户自配 baseUrl / model / apiKey）。
 * 默认模型为 DeepSeek（base https://api.deepseek.com/v1、模型 deepseek-chat）。
 */
enum class AIModel(
    val id: String,
    val displayName: String,
    val defaultBaseUrl: String,
    val defaultModel: String
) {
    DEEPSEEK("deepseek", "DeepSeek", "https://api.deepseek.com/v1", "deepseek-chat"),
    QWEN("qwen", "千问", "https://dashscope.aliyuncs.com/compatible-mode/v1", "qwen-plus"),
    CHATGPT("chatgpt", "ChatGPT", "https://api.openai.com/v1", "gpt-4o-mini"),
    YUANBAO("yuanbao", "元宝", "https://api.hunyuan.cloud.tencent.com/v1", "hunyuan-turbo"),
    CLAUDE("claude", "Claude", "", "claude-sonnet-4-20250514"),
    GEMINI("gemini", "Gemini", "https://generativelanguage.googleapis.com/v1beta/openai", "gemini-2.0-flash"),
    GLM("glm", "GLM", "https://open.bigmodel.cn/api/paas/v4", "glm-4-flash"),
    KIMI("kimi", "Kimi", "https://api.moonshot.cn/v1", "moonshot-v1-8k"),
    ERNIE("ernie", "文心", "https://qianfan.baidubce.com/v2", "ernie-4.0-turbo-8k"),
    GROK("grok", "Grok", "https://api.x.ai/v1", "grok-2-latest"),
    STEPFUN("stepfun", "阶跃星辰", "https://api.stepfun.com/v1", "step-1-8k"),
    MINIMAX("minimax", "MiniMax", "https://api.minimax.chat/v1", "abab6.5s-chat"),
    CUSTOM("custom", "自定义", "", "");

    companion object {
        fun fromId(id: String?): AIModel = entries.firstOrNull { it.id == id } ?: DEEPSEEK
    }
}