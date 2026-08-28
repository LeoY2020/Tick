package com.tick.app.android.data

import androidx.room.Entity
import androidx.room.PrimaryKey
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * 一条对话消息（AI 聊天 / 生成任务共用），持久化到 AIChatSession 供历史恢复。
 */
data class AIChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val role: String, // "user" | "assistant"
    val text: String,
    val createdAt: Long = System.currentTimeMillis()
)

/**
 * AI 聊天会话。消息以 JSON 数组形式内嵌存储（保持四张表结构）。
 */
@Entity(tableName = "ai_chat_sessions")
data class AIChatSession(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val title: String = "新对话",
    val messagesJson: String = "[]",
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

/** AIChatMessage 与 JSON 数组的编解码（基于 Android 内置 org.json） */
object ChatMessageCodec {
    fun encode(messages: List<AIChatMessage>): String {
        val arr = JSONArray()
        for (m in messages) {
            val obj = JSONObject()
            obj.put("id", m.id)
            obj.put("role", m.role)
            obj.put("text", m.text)
            obj.put("createdAt", m.createdAt)
            arr.put(obj)
        }
        return arr.toString()
    }

    fun decode(json: String): List<AIChatMessage> {
        return try {
            val arr = JSONArray(json)
            (0 until arr.length()).mapNotNull { i ->
                val obj = arr.optJSONObject(i) ?: return@mapNotNull null
                AIChatMessage(
                    id = obj.optString("id", UUID.randomUUID().toString()),
                    role = obj.optString("role", "user"),
                    text = obj.optString("text", ""),
                    createdAt = obj.optLong("createdAt", 0L)
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun messages(session: AIChatSession): List<AIChatMessage> = decode(session.messagesJson)

    fun withMessages(session: AIChatSession, messages: List<AIChatMessage>): AIChatSession =
        session.copy(messagesJson = encode(messages), updatedAt = System.currentTimeMillis())
}