package com.tick.app.android.domain

import com.tick.app.android.model.Goal
import com.tick.app.android.model.ProgressCountingMode
import com.tick.app.android.model.TaskItem
import com.tick.app.android.model.TaskStatus
import com.tick.app.android.model.TaskType
import com.tick.app.android.model.progressCountingMode
import com.tick.app.android.model.status
import com.tick.app.android.model.type

/** 目标总进度结果（删除态不计） */
data class GoalProgress(
    /** 计入总量的任务数 */
    val totalItems: Int,
    /** 加权完成度（单项完成=1 半完成=0.5；进度=比率） */
    val completedWeight: Double
) {
    val fraction: Double
        get() = if (totalItems == 0) 0.0 else completedWeight / totalItems.toDouble()

    /** 已完成项数（整数展示用） */
    val doneItems: Int
        get() = completedWeight.toInt()
}

/**
 * 递归进度计算引擎：自底向上汇总（纯计算，不修改模型数据）。
 *
 * 与 iOS 版 ProgressEngine 语义严格一致：
 * - 删除态判定：单项任务且状态为删除 → 整棵子树不计入总量和进度（任何层级）；
 * - 接管机制：有有效（非删除态）子任务时状态/进度只读，由直接子任务折算汇总；
 *   全部有效子任务删除 → 接管解除，回落手动值（保留手动值）；
 * - 统计模式：allTasks = 所有层级任务都计入；leafTasks = 仅统计任务树末端（无有效子任务）节点；
 * - 继承链：颜色/图标/起止日期沿 parentTask 链取最近已设置值，最终回退所属 Goal。
 */
object ProgressEngine {

    /** 删除态判定：单项且状态为删除（任何层级均不计入总量和进度） */
    fun isDeleted(task: TaskItem): Boolean =
        task.type == TaskType.SINGLE && task.status == TaskStatus.DELETED

    /** 是否拥有有效（非删除态）子任务（接管机制判定依据） */
    fun hasActiveSubtasks(task: TaskItem): Boolean =
        task.subtasks.any { !isDeleted(it) }

    // MARK: - 有效状态与有效进度

    /**
     * 有效状态：有有效子任务（被接管）时由直接子任务折算，否则用手动状态。
     * - 无任何有效子任务 → 手动状态；
     * - 存在半完成子任务，或完成与未完成混合 → 半完成；
     * - 全部完成 → 完成；全部未完成 → 未完成。
     */
    fun effectiveStatus(task: TaskItem): TaskStatus {
        val active = task.subtasks.filterNot { isDeleted(it) }
        if (active.isEmpty()) return task.status

        var hasDone = false
        var hasHalf = false
        var hasNotDone = false
        for (sub in active) {
            when (subtaskStatus(sub)) {
                TaskStatus.DONE -> hasDone = true
                TaskStatus.HALF_DONE -> hasHalf = true
                TaskStatus.NOT_DONE -> hasNotDone = true
                TaskStatus.DELETED -> Unit // 已被过滤，不会到达
            }
        }
        // 有效子任务全部为删除态 → 接管解除，回落手动状态（防御分支）
        if (!hasDone && !hasHalf && !hasNotDone) return task.status
        if (hasHalf || (hasDone && hasNotDone)) return TaskStatus.HALF_DONE
        return if (hasDone) TaskStatus.DONE else TaskStatus.NOT_DONE
    }

    /**
     * 有效进度：有有效子任务（被接管）时由直接子任务汇总，否则用手动值（clamp 到 0...total）。
     * 被接管时：当前 = 子任务当前之和，总量 = 子任务总量之和（忽略手动总量）。
     */
    fun effectiveProgress(task: TaskItem): Pair<Double, Double> {
        val active = task.subtasks.filterNot { isDeleted(it) }
        if (active.isEmpty()) return manualProgress(task)

        var current = 0.0
        var total = 0.0
        var hasCounting = false
        for (sub in active) {
            hasCounting = true
            val contribution = childContribution(sub)
            current += contribution.first
            total += contribution.second
        }
        if (hasCounting) return current to total
        return manualProgress(task)
    }

    // MARK: - 目标总进度

    /** 目标总进度：按目标统计模式递归统计整棵任务树，删除态任务整棵子树不计入 */
    fun goalProgress(goal: Goal, rootTasks: List<TaskItem>): GoalProgress {
        var totalItems = 0
        var completedWeight = 0.0

        fun accumulate(task: TaskItem) {
            if (isDeleted(task)) return
            when (goal.progressCountingMode) {
                ProgressCountingMode.ALL_TASKS -> {
                    totalItems += 1
                    completedWeight += taskWeight(task)
                    for (sub in task.subtasks) accumulate(sub)
                }
                ProgressCountingMode.LEAF_TASKS -> {
                    val active = task.subtasks.filterNot { isDeleted(it) }
                    if (active.isEmpty()) {
                        totalItems += 1
                        completedWeight += taskWeight(task)
                    } else {
                        for (sub in active) accumulate(sub)
                    }
                }
            }
        }

        for (root in rootTasks) accumulate(root)
        return GoalProgress(totalItems = totalItems, completedWeight = completedWeight)
    }

    // MARK: - 继承链解析

    /** 有效颜色：沿父链取最近已设置值，最终回退所属 Goal 的颜色；无归属回退 "#000000" */
    fun effectiveColor(task: TaskItem): String {
        var cursor: TaskItem? = task
        while (cursor != null) {
            val hex = cursor.colorHex
            if (!hex.isNullOrBlank()) return hex
            cursor = cursor.parentTask
        }
        return rootGoal(task)?.colorHex ?: "#000000"
    }

    /** 有效图标：沿父链取最近已设置值，最终回退所属 Goal 的图标 */
    fun effectiveIcon(task: TaskItem): String? {
        var cursor: TaskItem? = task
        while (cursor != null) {
            val icon = cursor.iconSystemName
            if (!icon.isNullOrBlank()) return icon
            cursor = cursor.parentTask
        }
        return rootGoal(task)?.iconSystemName
    }

    /** 有效开始日期：沿父链取最近已设置值，最终回退所属 Goal */
    fun effectiveStartDate(task: TaskItem): Long? {
        var cursor: TaskItem? = task
        while (cursor != null) {
            cursor.startDate?.let { return it }
            cursor = cursor.parentTask
        }
        return rootGoal(task)?.startDate
    }

    /** 有效截止日期：沿父链取最近已设置值，最终回退所属 Goal */
    fun effectiveEndDate(task: TaskItem): Long? {
        var cursor: TaskItem? = task
        while (cursor != null) {
            cursor.endDate?.let { return it }
            cursor = cursor.parentTask
        }
        return rootGoal(task)?.endDate
    }

    /** 沿 parentTask 链向上找到所属 Goal */
    fun rootGoal(task: TaskItem): Goal? {
        var cursor: TaskItem? = task
        while (cursor != null) {
            cursor.goal?.let { return it }
            cursor = cursor.parentTask
        }
        return null
    }

    // MARK: - 子任务贡献

    /**
     * 单个子任务对父级汇总的贡献：单项 → (状态权重, 1)；进度 → 有效 (current, total)；删除态返回 (0, 0)。
     */
    fun childContribution(task: TaskItem): Pair<Double, Double> {
        if (isDeleted(task)) return 0.0 to 0.0
        return if (task.type == TaskType.SINGLE) {
            statusWeight(effectiveStatus(task)) to 1.0
        } else {
            effectiveProgress(task)
        }
    }

    /** 单项状态权重：完成=1 半完成=0.5 未完成/删除=0 */
    fun statusWeight(status: TaskStatus): Double = when (status) {
        TaskStatus.DONE -> 1.0
        TaskStatus.HALF_DONE -> 0.5
        TaskStatus.NOT_DONE, TaskStatus.DELETED -> 0.0
    }

    /** 单个任务节点的权重：单项 → 有效状态权重；进度 → 有效比率 */
    fun taskWeight(task: TaskItem): Double =
        if (task.type == TaskType.SINGLE) statusWeight(effectiveStatus(task))
        else effectiveRatio(task)

    /** 有效比率：current / total（total ≤ 0 时为 0，上限 1） */
    fun effectiveRatio(task: TaskItem): Double {
        val progress = effectiveProgress(task)
        return if (progress.second > 0.0) minOf(progress.first / progress.second, 1.0) else 0.0
    }

    // MARK: - 私有辅助

    /** 手动进度：current clamp 到 0...total，total 取非负 */
    private fun manualProgress(task: TaskItem): Pair<Double, Double> {
        val total = maxOf(0.0, task.totalAmount)
        val current = task.currentAmount.coerceIn(0.0, total)
        return current to total
    }

    /** 子任务折算状态：单项用有效状态；进度按有效比率折算（1→完成，0<比率<1→半完成，0→未完成） */
    private fun subtaskStatus(sub: TaskItem): TaskStatus {
        if (sub.type != TaskType.PROGRESS) return effectiveStatus(sub)
        val ratio = effectiveRatio(sub)
        return when {
            ratio >= 1.0 -> TaskStatus.DONE
            ratio > 0.0 -> TaskStatus.HALF_DONE
            else -> TaskStatus.NOT_DONE
        }
    }
}