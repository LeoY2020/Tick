package com.tick.app.android.model

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.Ignore
import androidx.room.PrimaryKey
import java.util.UUID

/**
 * 任务：支持无限层级嵌套（自引用 parentTaskId / goalId 互斥）。
 * 枚举统一以 raw string 存储（对齐 iOS raw string 入库方式）。
 * 一级任务挂 goalId；子任务挂 parentTaskId；两者互斥。
 */
@Entity(
    tableName = "tasks",
    foreignKeys = [
        ForeignKey(
            entity = TaskItem::class,
            parentColumns = ["id"],
            childColumns = ["parentTaskId"],
            onDelete = ForeignKey.CASCADE
        ),
        ForeignKey(
            entity = Goal::class,
            parentColumns = ["id"],
            childColumns = ["goalId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [
        Index("parentTaskId"),
        Index("goalId")
    ]
)
data class TaskItem(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val name: String,
    /** 颜色 HEX（null = 继承父级） */
    val colorHex: String? = null,
    /** 图标名（null = 继承父级） */
    val iconSystemName: String? = null,
    /** 任务类型原始值 */
    val typeRaw: String = TaskType.SINGLE.raw,
    /** 任务状态原始值 */
    val statusRaw: String = TaskStatus.NOT_DONE.raw,
    /** 进度类型总量 */
    val totalAmount: Double = 0.0,
    /** 进度类型当前值（约束 0 ≤ 当前 ≤ 总量） */
    val currentAmount: Double = 0.0,
    /** 开始日期 epoch millis（null = 继承父级） */
    val startDate: Long? = null,
    /** 截止日期 epoch millis（null = 继承父级） */
    val endDate: Long? = null,
    /** 提醒时间 epoch millis（null = 不提醒） */
    val reminderDate: Long? = null,
    /** 重复规则原始值（null / never = 不重复） */
    val repeatRuleRaw: String? = null,
    /** 自定义重复的星期，逗号分隔（如 "1,3,5"，1=周日…7=周六） */
    val customWeekdaysRaw: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    /** 排序值 */
    val sortOrder: Int = 0,
    /** 父任务 id（与 goalId 互斥） */
    val parentTaskId: String? = null,
    /** 所属目标 id（与 parentTaskId 互斥） */
    val goalId: String? = null
) {
    // 以下为内存树引用，仅用于进度计算 / UI 展示，不持久化。
    /** 子任务（内存树） */
    @Ignore var subtasks: List<TaskItem> = emptyList()
    /** 父任务（内存树） */
    @Ignore var parentTask: TaskItem? = null
    /** 所属目标（内存树，仅用于根任务往返；环引用不存在） */
    @Ignore var goal: Goal? = null

    /** 是否拥有有效（非删除态）子任务（接管机制判定依据） */
    val hasActiveSubtasks: Boolean
        get() = subtasks.any { it.type != TaskType.SINGLE || it.status != TaskStatus.DELETED }
}

/** 任务类型（读写映射，未知回退 single） */
val TaskItem.type: TaskType get() = TaskType.fromRaw(typeRaw)

/** 任务状态（读写映射，未知回退 notDone） */
val TaskItem.status: TaskStatus get() = TaskStatus.fromRaw(statusRaw)

/** 重复规则（可选读写映射，未知回退 null） */
val TaskItem.repeatRule: RepeatRule? get() = RepeatRule.fromRaw(repeatRuleRaw)

/** 解析自定义重复的星期（1=周日…7=周六），过滤非法值 */
fun TaskItem.effectiveWeekdays(): List<Int> {
    val raw = customWeekdaysRaw ?: return emptyList()
    return raw.split(",")
        .mapNotNull { it.trim().toIntOrNull() }
        .filter { it in 1..7 }
}

/** 进度值 clamp 到 0...totalAmount */
fun TaskItem.clampProgress(): Pair<Double, Double> {
    val total = maxOf(0.0, totalAmount)
    val current = currentAmount.coerceIn(0.0, total)
    return current to total
}