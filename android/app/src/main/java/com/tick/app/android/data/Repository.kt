package com.tick.app.android.data

import com.tick.app.android.model.Goal
import com.tick.app.android.model.TaskItem
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map

/**
 * 内存任务树构建：把扁平的任务表（自引用 parentTaskId / goalId）组装为嵌套树，
 * 并填充 parentTask / goal / subtasks 内存引用，供进度引擎与 UI 使用。
 */
object TaskTreeBuilder {

    /** 构建 goal 下的根任务树（每个节点的内存引用已就绪） */
    fun build(goalId: String, all: List<TaskItem>, goal: Goal?): List<TaskItem> {
        val byParentId = all.groupBy { it.parentTaskId }

        fun order(list: List<TaskItem>): List<TaskItem> =
            list.sortedWith(compareBy({ it.sortOrder }, { it.createdAt }, { it.id }))

        fun buildNode(node: TaskItem, parent: TaskItem?) {
            node.parentTask = parent
            node.goal = if (parent == null) goal else null
            val children = order(byParentId[node.id].orEmpty())
            node.subtasks = children
            for (child in children) buildNode(child, node)
        }

        val roots = order(byParentId[null]?.filter { it.goalId == goalId }.orEmpty())
        for (root in roots) buildNode(root, null)
        return roots
    }
}

/**
 * 统一数据仓库：组合四个 DAO，提供领域操作与任务树构建。
 */
class Repository(
    private val goalDao: GoalDao,
    private val taskDao: TaskDao,
    private val aiChatDao: AIChatDao,
    private val settingsDao: SettingsDao
) {
    // MARK: - Goal

    val goals: Flow<List<Goal>> = goalDao.observeAll()

    suspend fun addGoal(goal: Goal): String = goalDao.insert(goal).let { goal.id }

    suspend fun updateGoal(goal: Goal) = goalDao.update(goal)

    suspend fun deleteGoal(goalId: String) = goalDao.deleteById(goalId)

    suspend fun goalById(goalId: String): Goal? = goalDao.getById(goalId)

    // MARK: - Task

    /** 观察某个目标的一级任务树（每个节点内存引用就绪） */
    fun observeGoalTree(goalId: String): Flow<List<TaskItem>> =
        combine(taskDao.observeAll(), goalDao.observeById(goalId)) { tasks, goal ->
            TaskTreeBuilder.build(goalId, tasks, goal)
        }

    suspend fun rootTasks(goalId: String): List<TaskItem> {
        val tasks = taskDao.getAll()
        val goal = goalDao.getById(goalId)
        return TaskTreeBuilder.build(goalId, tasks, goal)
    }

    suspend fun addTask(task: TaskItem): String = taskDao.insert(task).let { task.id }

    suspend fun updateTask(task: TaskItem) = taskDao.update(task)

    /** 观察全部任务（扁平表，用于备份导出等） */
    fun observeAllTasks(): Flow<List<TaskItem>> = taskDao.observeAll()

    /** 删除任务（外键级联删除整棵子树） */
    suspend fun deleteTask(taskId: String) = taskDao.deleteById(taskId)

    suspend fun taskById(taskId: String): TaskItem? = taskDao.getById(taskId)

    suspend fun getGoalFlatTasks(goalId: String): List<TaskItem> = taskDao.getFlatByGoal(goalId)

    // MARK: - AI Chat

    val chatSessions: Flow<List<AIChatSession>> = aiChatDao.observeAll()

    suspend fun addSession(session: AIChatSession): String = aiChatDao.insert(session).let { session.id }

    suspend fun updateSession(session: AIChatSession) = aiChatDao.update(session)

    suspend fun deleteSession(sessionId: String) = aiChatDao.deleteById(sessionId)

    fun observeSession(sessionId: String): Flow<AIChatSession?> = aiChatDao.observeById(sessionId)

    suspend fun sessionById(sessionId: String): AIChatSession? = aiChatDao.getById(sessionId)

    // MARK: - Settings

    val settings: Flow<Settings?> = settingsDao.observe()

    val settingsOrNull: Flow<Settings?> = settingsDao.observe()

    suspend fun currentSettings(): Settings? = settingsDao.get()

    /** 返回当前设置，若不存在则创建默认并返回 */
    suspend fun ensureSettings(): Settings {
        val existing = settingsDao.get()
        if (existing != null) return existing
        val fresh = Settings()
        settingsDao.upsert(fresh)
        return fresh
    }

    suspend fun saveSettings(settings: Settings) = settingsDao.upsert(settings)

    // 以下在导入恢复时由 DataBackupManager 使用
    suspend fun clearAllTasks() = taskDao.deleteAll()
    suspend fun clearAllGoals() = goalDao.getAll().forEach { goalDao.deleteById(it.id) }
}