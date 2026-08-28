package com.tick.app.android.model

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.UUID

/**
 * 目标：顶层组织单元。进度统计模式以 raw string 存储，未知/未设置回退 allTasks。
 */
@Entity(tableName = "goals")
data class Goal(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val name: String,
    /** 颜色 HEX 字符串（如 "#000000"；"auto" = 深色白 / 浅色黑） */
    val colorHex: String = "auto",
    /** 图标名（null = 未设置） */
    val iconSystemName: String? = null,
    /** 开始日期 epoch millis（null = 未设置） */
    val startDate: Long? = null,
    /** 截止日期 epoch millis（null = 未设置） */
    val endDate: Long? = null,
    /** 开始时间是否精确到小时 */
    val startDatePreciseToHour: Boolean = false,
    /** 截止时间是否精确到小时 */
    val endDatePreciseToHour: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    /** 进度统计模式原始值（未设置回退 allTasks） */
    val progressCountingModeRaw: String = ProgressCountingMode.ALL_TASKS.raw
)

/** 进度统计模式（读写映射，未知/未设置回退 allTasks） */
val Goal.progressCountingMode: ProgressCountingMode
    get() = ProgressCountingMode.fromRaw(progressCountingModeRaw)