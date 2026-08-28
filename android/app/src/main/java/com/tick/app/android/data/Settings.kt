package com.tick.app.android.data

import android.content.Context
import androidx.room.Entity
import androidx.room.PrimaryKey
import com.tick.app.android.model.AppLanguage
import com.tick.app.android.model.AIModel
import com.tick.app.android.model.ThemeMode

/**
 * 应用设置（单行存储，id 固定为 1）。
 * 注意：API Key 单独存储在 SecurePrefs（SharedPreferences），不在 Room 中持久化。
 */
@Entity(tableName = "settings")
data class Settings(
    @PrimaryKey val id: Int = 1,
    /** 配色方案（深色/浅色/跟随系统） */
    val themeModeRaw: String = ThemeMode.SYSTEM.raw,
    /** 所选皮肤 id（runtime 切换，见 ui.theme.Skin） */
    val skinId: String = "coloros",
    /** 语言（简体中文 / English / 跟随系统） */
    val languageRaw: String = AppLanguage.SYSTEM.raw,
    /** 所选 AI 模型 id */
    val aiModelId: String = AIModel.DEEPSEEK.id,
    /** AI Base URL（空则回退所选集成的默认值） */
    val baseUrl: String = "",
    /** AI 模型名（空则回退所选集成的默认值） */
    val modelName: String = ""
) {
    val themeMode: ThemeMode get() = ThemeMode.fromRaw(themeModeRaw)
    val aiModel: AIModel get() = AIModel.fromId(aiModelId)
    val language: AppLanguage get() = AppLanguage.fromRaw(languageRaw)
}