package com.tick.app.android.ai

import com.tick.app.android.data.AIChatMessage
import com.tick.app.android.model.AIModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** AI 生成的任务树节点（宽容解码：缺字段不失败） */
data class TaskNode(
    val name: String = "",
    val children: List<TaskNode> = emptyList()
) {
    val trimmedName: String get() = name.trim()
}

/** 一次聊天回复的结构化结果：是否生成任务、生成的任务树、展示文字。 */
data class ChatReply(
    val shouldGenerateTasks: Boolean = false,
    val tasks: List<TaskNode> = emptyList(),
    val message: String = ""
)

/** AI 服务错误 */
sealed class AIServiceError(message: String) : Exception(message) {
    object MissingAPIKey : AIServiceError("请先在 设置 → AI 模型 中填写 API Key")
    object MissingConfiguration : AIServiceError("请填写 Base URL 与模型名后重试")
    data class Network(val detail: String) : AIServiceError("网络请求失败：$detail")
    data class BadResponse(val detail: String) : AIServiceError("模型服务返回了异常响应：$detail")
    object EmptyResult : AIServiceError("模型未生成有效内容")
}

/**
 * AI 服务：OpenAI 兼容 API 客户端（多轮对话，POST {base}/chat/completions）+ JSON envelope 解析。
 *
 * Android 各厂商助手（小爱/Bixby/YOYO 等）无公开 API → 不内嵌，由用户自行配置 OpenAI 兼容 API。
 * 默认 Base https://api.deepseek.com/v1、模型 deepseek-chat、temperature 0.3。
 * 组包：system 提示词 + 历史消息 + 当前消息（附件内容注入为首条用户消息）。
 */
object AIService {

    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(90, TimeUnit.SECONDS)
        .writeTimeout(90, TimeUnit.SECONDS)
        .build()

    /** 输给模型的 temperature */
    private const val TEMPERATURE = 0.3

    /**
     * 聊天系统提示词：要求输出 JSON envelope（任务入库 + 展示文字），由 AI 自行判断是否生成任务。
     * 硬性禁止生成"了解xxx / 阅读附件 / 整理要点"类空泛任务。
     */
    const val CHAT_SYSTEM_PROMPT: String = """你是一个严谨的中文任务规划助手。你可以依据以下两类信息来生成具体、可执行、有信息量的分层任务清单：
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
{"generate": false, "message": "我目前还缺少足够的信息来生成有意义的任务。你可以上传带文字的文本 / Markdown / PDF，或在对话里描述你想规划的事项。"}
3. 其他普通闲聊（未要求生成任务）时，输出：
{"generate": false, "message": "你的回复文字"}"""

    /**
     * 与 AI 多轮对话，返回结构化结果。
     * @param history 会话历史（不含本次输入）
     * @param currentMessage 用户本次输入
     * @param attachmentText 附件正文（可空）
     */
    suspend fun chatReply(
        history: List<AIChatMessage>,
        currentMessage: String,
        attachmentText: String?,
        apiKey: String,
        baseUrl: String,
        modelName: String
    ): ChatReply = withContext(Dispatchers.IO) {
        if (apiKey.isBlank()) throw AIServiceError.MissingAPIKey
        val raw = requestText(history, currentMessage, attachmentText, apiKey, baseUrl, modelName)
        parseChatReply(raw)
    }

    // MARK: - 请求

    private fun requestText(
        history: List<AIChatMessage>,
        currentMessage: String,
        attachmentText: String?,
        apiKey: String,
        baseUrl: String,
        modelName: String
    ): String {
        val url = resolveUrl(baseUrl)
        val modelId = normalizeModel(modelName)
        val body = buildBody(modelId, mergedMessages(history, currentMessage, attachmentText))

        val request = Request.Builder()
            .url(url)
            .addHeader("Content-Type", "application/json")
            .addHeader("Authorization", "Bearer $apiKey")
            .post(body.toRequestBody("application/json".toMediaType()))
            .build()

        client.newCall(request).execute().use { response ->
            val text = response.body?.string().orEmpty()
            if (!response.isSuccessful) throw AIServiceError.Network("HTTP ${response.code}")
            return parseOpenAIResponse(text)
        }
    }

    /** 组包：system + history + current（附件正文注入为当前消息之前的首条用户消息） */
    private fun buildBody(modelId: String, messages: List<Pair<String, String>>): String {
        val arr = JSONArray()
        arr.put(JSONObject().put("role", "system").put("content", CHAT_SYSTEM_PROMPT))
        for ((role, content) in messages) {
            arr.put(JSONObject().put("role", role).put("content", content))
        }
        return JSONObject()
            .put("model", modelId)
            .put("messages", arr)
            .put("temperature", TEMPERATURE)
            .toString()
    }

    /** 组装消息列表：附件内容 → 历史 → 当前输入（保持时间顺序，当前在末尾） */
    private fun mergedMessages(
        history: List<AIChatMessage>,
        currentMessage: String,
        attachmentText: String?
    ): List<Pair<String, String>> {
        val result = mutableListOf<Pair<String, String>>()
        val attachment = attachmentText?.trim()
        if (!attachment.isNullOrEmpty()) {
            result.add("user" to "附件内容：\n$attachment")
        }
        for (m in history) {
            result.add((if (m.role == "assistant") "assistant" else "user") to m.text)
        }
        val current = currentMessage.trim()
        if (current.isNotEmpty()) {
            result.add("user" to current)
        }
        if (result.isEmpty()) throw AIServiceError.EmptyResult
        return result
    }

    /** 解析 {base}/chat/completions；base 需作为完整 Base URL（含协议与主机） */
    private fun resolveUrl(baseUrl: String): String {
        val base = baseUrl.trim().trimEnd('/')
        if (base.isBlank()) throw AIServiceError.MissingConfiguration
        return if (base.endsWith("/chat/completions")) base else "$base/chat/completions"
    }

    private fun normalizeModel(modelName: String): String {
        val name = modelName.trim()
        if (name.isBlank()) throw AIServiceError.MissingConfiguration
        return name
    }

    private fun parseOpenAIResponse(json: String): String {
        val root = try {
            JSONObject(json)
        } catch (e: Exception) {
            throw AIServiceError.BadResponse("非 JSON 响应")
        }
        val choices = root.optJSONArray("choices")
            ?: throw AIServiceError.BadResponse("缺少 choices")
        val message = choices.optJSONObject(0)?.optJSONObject("message")
            ?: throw AIServiceError.BadResponse("缺少 message")
        val content = message.optString("content", "")
        if (content.isBlank()) throw AIServiceError.EmptyResult
        return content
    }

    // MARK: - envelope 解析

    /** 解析 chatReply 的 JSON envelope；解析失败或非 generate 时把原文当普通文字回复 */
    private fun parseChatReply(raw: String): ChatReply {
        val cleaned = stripCodeFences(raw).trim()
        val obj = jsonObject(cleaned)
        if (obj != null) {
            val generate = obj.optBoolean("generate", false)
            val tasks = parseTaskNodes(obj.optJSONArray("tasks") ?: JSONArray())
            val message = obj.optString("message", "")
            if (generate) {
                val nodes = tasks.filter { it.trimmedName.isNotEmpty() }
                return ChatReply(
                    shouldGenerateTasks = true,
                    tasks = nodes,
                    message = if (message.isBlank()) "已为你生成 ${nodes.size} 个任务。" else message
                )
            }
            if (message.isNotBlank()) return ChatReply(message = message)
        }
        return ChatReply(message = raw)
    }

    private fun parseTaskNodes(arr: JSONArray): List<TaskNode> {
        val nodes = mutableListOf<TaskNode>()
        for (i in 0 until arr.length()) {
            val obj = arr.optJSONObject(i) ?: continue
            val name = obj.optString("name", "")
            val children = obj.optJSONArray("children")?.let { parseTaskNodes(it) } ?: emptyList()
            nodes.add(TaskNode(name = name, children = children))
        }
        return nodes
    }

    /** 抽取文本中第一个 '{' 到最后一个 '}' 的 JSON 对象子串 */
    private fun jsonObject(text: String): JSONObject? {
        val start = text.indexOf('{')
        val end = text.lastIndexOf('}')
        if (start < 0 || end < 0 || start >= end) return null
        return try {
            JSONObject(text.substring(start, end + 1))
        } catch (e: Exception) {
            null
        }
    }

    /** 去掉 ``` 代码围栏 */
    private fun stripCodeFences(text: String): String {
        val lines = text.lines().toMutableList()
        if (lines.isNotEmpty() && lines.first().contains("```")) lines.removeAt(0)
        if (lines.isNotEmpty() && lines.last().contains("```")) lines.removeAt(lines.size - 1)
        return lines.joinToString("\n")
    }
}