package com.tick.app.android.model

/** 任务类型：单项 / 进度。原始值按 iOS 一致使用 raw string 存储。 */
enum class TaskType(val raw: String, val displayName: String) {
    /** 单项任务 */
    SINGLE("single", "单项"),
    /** 进度任务 */
    PROGRESS("progress", "进度");

    companion object {
        fun fromRaw(raw: String?): TaskType = entries.firstOrNull { it.raw == raw } ?: SINGLE
    }
}

/** 任务状态：未完成 → 半完成 → 完成 / 删除。 */
enum class TaskStatus(val raw: String, val displayName: String) {
    /** 未完成 */
    NOT_DONE("notDone", "未完成"),
    /** 半完成 */
    HALF_DONE("halfDone", "半完成"),
    /** 完成 */
    DONE("done", "完成"),
    /** 删除（不计入进度） */
    DELETED("deleted", "删除");

    companion object {
        fun fromRaw(raw: String?): TaskStatus = entries.firstOrNull { it.raw == raw } ?: NOT_DONE
    }
}

/** 目标进度统计模式。 */
enum class ProgressCountingMode(val raw: String, val displayName: String) {
    /** 统计所有层级任务 */
    ALL_TASKS("allTasks", "全部任务"),
    /** 只统计叶子任务 */
    LEAF_TASKS("leafTasks", "仅叶子任务");

    companion object {
        fun fromRaw(raw: String?): ProgressCountingMode =
            entries.firstOrNull { it.raw == raw } ?: ALL_TASKS
    }
}

/** 提醒重复规则。 */
enum class RepeatRule(val raw: String, val displayName: String) {
    /** 不重复 */
    NEVER("never", "不重复"),
    /** 每天 */
    DAILY("daily", "每天"),
    /** 每周 */
    WEEKLY("weekly", "每周"),
    /** 每月 */
    MONTHLY("monthly", "每月"),
    /** 自定义（周几多选，1=周日…7=周六） */
    CUSTOM("custom", "自定义");

    companion object {
        fun fromRaw(raw: String?): RepeatRule? = raw?.let { r ->
            entries.firstOrNull { it.raw == r }
        }
    }
}

/** 设置——配色方案（深色/浅色/跟随系统）。 */
enum class ThemeMode(val raw: String, val displayName: String) {
    SYSTEM("system", "跟随系统"),
    LIGHT("light", "亮色"),
    DARK("dark", "暗色");

    companion object {
        fun fromRaw(raw: String?): ThemeMode = entries.firstOrNull { it.raw == raw } ?: SYSTEM
    }
}

/** 设置——语言（简体中文 / English，跟随系统可选）。 */
enum class AppLanguage(val raw: String, val displayName: String, val localeTag: String?) {
    SYSTEM("system", "跟随系统", null),
    ZH_HANS("zhHans", "简体中文", "zh"),
    EN("en", "English", "en");

    companion object {
        fun fromRaw(raw: String?): AppLanguage = entries.firstOrNull { it.raw == raw } ?: SYSTEM
    }
}