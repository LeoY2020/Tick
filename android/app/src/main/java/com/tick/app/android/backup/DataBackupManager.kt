package com.tick.app.android.backup

import android.content.Context
import android.net.Uri
import com.tick.app.android.data.Repository
import com.tick.app.android.data.Settings
import com.tick.app.android.model.Goal
import com.tick.app.android.model.TaskItem
import kotlinx.coroutines.flow.first
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * 数据导出 / 导入 / 备份。
 *
 * 导出：把全部目标 + 全部任务（保留树结构 parentTaskId / goalId）+ 设置 序列化为 JSON，
 *      写入用户通过 SAF（系统文件选择器）选择的 Uri。
 * 导入：从 JSON 恢复（清空后重建），保持树关系。
 */
object DataBackupManager {

    class BackupError(message: String) : Exception(message)

    private const val KEY_GOALS = "goals"
    private const val KEY_TASKS = "tasks"
    private const val KEY_SETTINGS = "settings"

    // MARK: - 导出

    suspend fun export(repo: Repository, settings: Settings): String {
        val goals = repo.goals.first()
        val tasks = repo.observeAllTasks().first()
        return buildJson(goals, tasks, settings)
    }

    private fun buildJson(
        goals: List<Goal>,
        tasks: List<TaskItem>,
        settings: com.tick.app.android.data.Settings
    ): String {
        val obj = JSONObject()
        val goalsArr = JSONArray()
        for (g in goals) {
            val go = JSONObject()
            go.put("id", g.id)
            go.put("name", g.name)
            go.put("colorHex", g.colorHex)
            go.put("iconSystemName", g.iconSystemName)
            putNullable(go, "startDate", g.startDate)
            putNullable(go, "endDate", g.endDate)
            go.put("startDatePreciseToHour", g.startDatePreciseToHour)
            go.put("endDatePreciseToHour", g.endDatePreciseToHour)
            go.put("createdAt", g.createdAt)
            go.put("progressCountingModeRaw", g.progressCountingModeRaw)
            goalsArr.put(go)
        }
        val tasksArr = JSONArray()
        for (t in tasks) {
            val to = JSONObject()
            to.put("id", t.id)
            to.put("name", t.name)
            putNullable(to, "colorHex", t.colorHex)
            putNullable(to, "iconSystemName", t.iconSystemName)
            to.put("typeRaw", t.typeRaw)
            to.put("statusRaw", t.statusRaw)
            to.put("totalAmount", t.totalAmount)
            to.put("currentAmount", t.currentAmount)
            putNullable(to, "startDate", t.startDate)
            putNullable(to, "endDate", t.endDate)
            putNullable(to, "reminderDate", t.reminderDate)
            putNullable(to, "repeatRuleRaw", t.repeatRuleRaw)
            putNullable(to, "customWeekdaysRaw", t.customWeekdaysRaw)
            to.put("createdAt", t.createdAt)
            to.put("sortOrder", t.sortOrder)
            putNullable(to, "parentTaskId", t.parentTaskId)
            putNullable(to, "goalId", t.goalId)
            tasksArr.put(to)
        }
        val settingsObj = JSONObject()
        settingsObj.put("themeModeRaw", settings.themeModeRaw)
        settingsObj.put("skinId", settings.skinId)
        settingsObj.put("languageRaw", settings.languageRaw)
        settingsObj.put("aiModelId", settings.aiModelId)
        settingsObj.put("baseUrl", settings.baseUrl)
        settingsObj.put("modelName", settings.modelName)

        obj.put(KEY_GOALS, goalsArr)
        obj.put(KEY_TASKS, tasksArr)
        obj.put(KEY_SETTINGS, settingsObj)
        return obj.toString(2)
    }

    private fun putNullable(obj: JSONObject, key: String, value: Any?) {
        if (value != null) obj.put(key, value) else obj.put(key, JSONObject.NULL)
    }

    // MARK: - 写入 / 读取 Uri

    fun writeToUri(context: Context, uri: Uri, json: String) {
        try {
            context.contentResolver.openOutputStream(uri, "w")?.use { it.write(json.toByteArray(Charsets.UTF_8)) }
                ?: throw BackupError("无法写入目标文件")
        } catch (e: BackupError) {
            throw e
        } catch (e: Exception) {
            throw BackupError("导出失败：${e.message}")
        }
    }

    fun readFromUri(context: Context, uri: Uri): String {
        return try {
            context.contentResolver.openInputStream(uri)?.use { it.readBytes().toString(Charsets.UTF_8) }
                ?: throw BackupError("无法读取备份文件")
        } catch (e: BackupError) {
            throw e
        } catch (e: Exception) {
            throw BackupError("读取备份文件失败：${e.message}")
        }
    }

    // MARK: - 导入

    /** 从 JSON 恢复：清空旧的 goals/tasks 后重建，并返回解析出的 Settings（可能为 null） */
    suspend fun importJson(repo: Repository, json: String): com.tick.app.android.data.Settings {
        val obj = try {
            JSONObject(json)
        } catch (e: Exception) {
            throw BackupError("备份文件不是有效的 JSON")
        }
        val goalsArr = obj.optJSONArray(KEY_GOALS) ?: JSONArray()
        val tasksArr = obj.optJSONArray(KEY_TASKS) ?: JSONArray()

        val goals = parseGoals(goalsArr)
        val tasks = parseTasks(tasksArr)
        val settings = parseSettings(obj.optJSONObject(KEY_SETTINGS))

        if (goals.isNotEmpty()) {
            repo.clearAllGoals()
        }
        if (tasks.isNotEmpty()) {
            repo.clearAllTasks()
        } else {
            // 若任务整体为空但旧数据存在，也清理，避免残留
            try { repo.clearAllTasks() } catch (e: Exception) { /* ignore */ }
        }

        for (g in goals) repo.addGoal(g)
        for (t in tasks) repo.addTask(t)
        if (settings != null) repo.saveSettings(settings)
        return settings ?: repo.ensureSettings()
    }

    private fun parseGoals(arr: JSONArray): List<Goal> {
        val list = mutableListOf<Goal>()
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            try {
                list.add(
                    Goal(
                        id = o.optString("id", UUID.randomUUID().toString()),
                        name = o.optString("name", ""),
                        colorHex = o.optString("colorHex", "auto"),
                        iconSystemName = optNullableString(o, "iconSystemName"),
                        startDate = optNullableLong(o, "startDate"),
                        endDate = optNullableLong(o, "endDate"),
                        startDatePreciseToHour = o.optBoolean("startDatePreciseToHour", false),
                        endDatePreciseToHour = o.optBoolean("endDatePreciseToHour", false),
                        createdAt = o.optLong("createdAt", System.currentTimeMillis()),
                        progressCountingModeRaw = o.optString("progressCountingModeRaw", "allTasks")
                    )
                )
            } catch (e: Exception) {
                // 跳过损坏条目
            }
        }
        return list
    }

    private fun parseTasks(arr: JSONArray): List<TaskItem> {
        val list = mutableListOf<TaskItem>()
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            try {
                val task = TaskItem(
                    id = o.optString("id", UUID.randomUUID().toString()),
                    name = o.optString("name", ""),
                    colorHex = optNullableString(o, "colorHex"),
                    iconSystemName = optNullableString(o, "iconSystemName"),
                    typeRaw = o.optString("typeRaw", "single"),
                    statusRaw = o.optString("statusRaw", "notDone"),
                    totalAmount = o.optDouble("totalAmount", 0.0),
                    currentAmount = o.optDouble("currentAmount", 0.0),
                    startDate = optNullableLong(o, "startDate"),
                    endDate = optNullableLong(o, "endDate"),
                    reminderDate = optNullableLong(o, "reminderDate"),
                    repeatRuleRaw = optNullableString(o, "repeatRuleRaw"),
                    customWeekdaysRaw = optNullableString(o, "customWeekdaysRaw"),
                    createdAt = o.optLong("createdAt", System.currentTimeMillis()),
                    sortOrder = o.optInt("sortOrder", 0),
                    parentTaskId = optNullableString(o, "parentTaskId"),
                    goalId = optNullableString(o, "goalId")
                )
                list.add(task)
            } catch (e: Exception) {
                // 跳过损坏条目
            }
        }
        return list
    }

    private fun parseSettings(o: JSONObject?): com.tick.app.android.data.Settings? {
        if (o == null) return null
        return try {
            com.tick.app.android.data.Settings(
                themeModeRaw = o.optString("themeModeRaw", "system"),
                skinId = o.optString("skinId", "emerald"),
                languageRaw = o.optString("languageRaw", "system"),
                aiModelId = o.optString("aiModelId", "deepseek"),
                baseUrl = o.optString("baseUrl", ""),
                modelName = o.optString("modelName", "")
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun optNullableString(o: JSONObject, key: String): String? =
        if (o.isNull(key)) null else o.optString(key, "").takeIf { it.isNotEmpty() }

    private fun optNullableLong(o: JSONObject, key: String): Long? =
        if (o.isNull(key)) null else o.optLong(key, -1L).let { if (it < 0) null else it }
}