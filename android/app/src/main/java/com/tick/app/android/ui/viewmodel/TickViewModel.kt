package com.tick.app.android.ui.viewmodel

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.tick.app.android.ai.AIService
import com.tick.app.android.ai.ChatReply
import com.tick.app.android.ai.TaskNode
import com.tick.app.android.backup.DataBackupManager
import com.tick.app.android.data.AIChatMessage
import com.tick.app.android.data.AIChatSession
import com.tick.app.android.data.AppDatabase
import com.tick.app.android.data.ChatMessageCodec
import com.tick.app.android.data.Repository
import com.tick.app.android.data.SecurePrefs
import com.tick.app.android.data.Settings
import com.tick.app.android.doc.DocumentTextExtractor
import com.tick.app.android.model.AppLanguage
import com.tick.app.android.model.AIModel
import com.tick.app.android.model.Goal
import com.tick.app.android.model.ProgressCountingMode
import com.tick.app.android.model.RepeatRule
import com.tick.app.android.model.TaskItem
import com.tick.app.android.model.TaskStatus
import com.tick.app.android.model.TaskType
import com.tick.app.android.model.ThemeMode
import com.tick.app.android.model.progressCountingMode
import com.tick.app.android.model.status
import com.tick.app.android.model.type
import com.tick.app.android.notification.ReminderScheduler
import com.tick.app.android.ui.theme.Skin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class TickViewModel(application: Application) : AndroidViewModel(application) {

    private val db = AppDatabase.get(application)
    private val repo = Repository(db.goalDao(), db.taskDao(), db.aiChatDao(), db.settingsDao())
    private val context = application

    // MARK: - 设置

    val settings: StateFlow<Settings> = repo.settings
        .map { it ?: Settings() }
        .flowOn(Dispatchers.IO)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), Settings())

    init {
        viewModelScope.launch(Dispatchers.IO) { repo.ensureSettings() }
    }

    // MARK: - 目标

    val goals: StateFlow<List<Goal>> = repo.goals
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val selectedGoalId: MutableStateFlow<String?> = MutableStateFlow(null)

    val selectedGoal: StateFlow<Goal?> = combine(goals, selectedGoalId) { gs, id ->
        gs.firstOrNull { it.id == id }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    /** 数据写入版本号：任何任务/目标的增删改都 +1，使 goalTree 重新查询，
     *  避免 Room Flow 在个别动静下延迟触发导致 UI 不即时刷新。 */
    private val dataRevision = MutableStateFlow(0L)

    @Suppress("UNCHECKED_CAST")
    val goalTree: StateFlow<List<TaskItem>> = combine(selectedGoalId, dataRevision) { id, _ -> id }
        .flatMapLatest { id ->
            if (id == null) kotlinx.coroutines.flow.flowOf(emptyList())
            else repo.observeGoalTree(id)
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    /** 展开/折叠状态集合（按任务 id） */
    val expandedTasks: MutableStateFlow<Set<String>> = MutableStateFlow(emptySet())

    private fun bumpRevision() {
        dataRevision.value = dataRevision.value + 1
    }

    fun selectGoal(id: String) {
        if (id.isEmpty()) return
        selectedGoalId.value = id
        expandedTasks.value = emptySet()
    }

    fun toggleExpand(taskId: String) {
        expandedTasks.value = expandedTasks.value.let { set ->
            if (taskId in set) set - taskId else set + taskId
        }
    }

    fun createGoal(
        name: String,
        colorHex: String,
        icon: String?,
        startDate: Long?,
        endDate: Long?,
        startPrecise: Boolean,
        endPrecise: Boolean,
        mode: ProgressCountingMode
    ) {
        viewModelScope.launch(Dispatchers.IO) {
            val goal = Goal(
                name = name.trim(),
                colorHex = colorHex,
                iconSystemName = icon,
                startDate = startDate,
                endDate = endDate,
                startDatePreciseToHour = startPrecise,
                endDatePreciseToHour = endPrecise,
                progressCountingModeRaw = mode.raw
            )
            repo.addGoal(goal)
        }
    }

    fun updateGoal(
        goalId: String,
        name: String,
        colorHex: String,
        icon: String?,
        startDate: Long?,
        endDate: Long?,
        startPrecise: Boolean,
        endPrecise: Boolean,
        mode: ProgressCountingMode
    ) {
        viewModelScope.launch(Dispatchers.IO) {
            val existing = repo.goalById(goalId) ?: return@launch
            repo.updateGoal(
                existing.copy(
                    name = name.trim(),
                    colorHex = colorHex,
                    iconSystemName = icon,
                    startDate = startDate,
                    endDate = endDate,
                    startDatePreciseToHour = startPrecise,
                    endDatePreciseToHour = endPrecise,
                    progressCountingModeRaw = mode.raw
                )
            )
        }
    }

    fun deleteGoal(goalId: String) {
        viewModelScope.launch(Dispatchers.IO) {
            repo.deleteGoal(goalId)
            if (selectedGoalId.value == goalId) {
                selectFirstGoal()
            }
        }
    }

    private suspend fun selectFirstGoal() {
        val first = repo.goals.first().firstOrNull()
        selectGoal(first?.id ?: "")
    }

    // MARK: - 任务

    fun addTask(
        goalId: String,
        parentTaskId: String?,
        name: String,
        type: TaskType,
        totalAmount: Double,
        currentAmount: Double
    ) {
        viewModelScope.launch(Dispatchers.IO) {
            val goal = repo.goalById(goalId) ?: return@launch
            val sort = if (parentTaskId == null) {
                (repo.rootTasks(goalId).size) // 追加到末尾
            } else {
                treeSize(repo.rootTasks(goalId), parentTaskId)
            }
            val task = TaskItem(
                name = name.trim(),
                typeRaw = type.raw,
                totalAmount = maxOf(0.0, totalAmount),
                currentAmount = currentAmount.coerceIn(0.0, maxOf(0.0, totalAmount)),
                goalId = goalId,
                parentTaskId = parentTaskId,
                sortOrder = parentTaskId?.let { 0 } ?: sort
            )
            repo.addTask(task)
            bumpRevision()
        }
    }

    private suspend fun treeSize(roots: List<TaskItem>, parentId: String): Int {
        fun walk(node: TaskItem): Int = 1 + node.subtasks.sumOf { walk(it) }
        return roots.sumOf { walk(it) }
    }

    fun updateTask(task: TaskItem) {
        viewModelScope.launch(Dispatchers.IO) {
            repo.updateTask(task)
            rescheduleTask(task)
            bumpRevision()
        }
    }

    /** 原地保存编辑任务（新对象），并刷新提醒 */
    fun saveTask(
        taskId: String,
        name: String,
        type: TaskType,
        status: TaskStatus,
        totalAmount: Double,
        currentAmount: Double,
        startDate: Long?,
        endDate: Long?,
        reminderDate: Long?,
        repeatRule: RepeatRule?,
        customWeekdaysRaw: String?
    ) {
        viewModelScope.launch(Dispatchers.IO) {
            val existing = repo.taskById(taskId) ?: return@launch
            val saved = existing.copy(
                name = name.trim(),
                typeRaw = type.raw,
                statusRaw = status.raw,
                totalAmount = maxOf(0.0, totalAmount),
                currentAmount = currentAmount.coerceIn(0.0, maxOf(0.0, totalAmount)),
                startDate = startDate,
                endDate = endDate,
                reminderDate = reminderDate,
                repeatRuleRaw = repeatRule?.raw,
                customWeekdaysRaw = customWeekdaysRaw
            )
            repo.updateTask(saved)
            rescheduleTask(saved)
            bumpRevision()
        }
    }

    fun deleteTask(taskId: String) {
        viewModelScope.launch(Dispatchers.IO) {
            ReminderScheduler.cancel(context, taskId)
            repo.deleteTask(taskId)
            bumpRevision()
        }
    }

    fun toggleSingleStatus(task: TaskItem) {
        if (task.type == TaskType.PROGRESS) return
        val next = when (task.status) {
            TaskStatus.NOT_DONE -> TaskStatus.DONE
            TaskStatus.DONE -> TaskStatus.HALF_DONE
            TaskStatus.HALF_DONE -> TaskStatus.NOT_DONE
            TaskStatus.DELETED -> TaskStatus.NOT_DONE
        }
        updateTask(task.copy(statusRaw = next.raw))
    }

    fun setProgress(task: TaskItem, delta: Double) {
        if (task.type != TaskType.PROGRESS) return
        val current = (task.currentAmount + delta).coerceIn(0.0, maxOf(0.0, task.totalAmount))
        updateTask(task.copy(currentAmount = current))
    }

    private suspend fun rescheduleTask(task: TaskItem) {
        val goal = goalNameOf(task)
        ReminderScheduler.schedule(context, task, goal?.first ?: task.goalId.orEmpty(), goal?.second ?: "")
    }

    private suspend fun goalNameOf(task: TaskItem): Pair<String?, String>? {
        val gid = task.goalId ?: task.goal?.id
        if (gid == null) return null
        val goal = repo.goalById(gid) ?: return null
        return gid to goal.name
    }

    // MARK: - 设置操作

    fun setThemeMode(mode: ThemeMode) = updateSettings { it.copy(themeModeRaw = mode.raw) }

    fun setSkin(skin: Skin) = updateSettings { it.copy(skinId = skin.id) }

    fun setLanguage(language: AppLanguage) = updateSettings { it.copy(languageRaw = language.raw) }

    fun setAiModel(model: AIModel) = updateSettings { it.copy(aiModelId = model.id) }

    fun setAiConfig(baseUrl: String, modelName: String) =
        updateSettings { it.copy(baseUrl = baseUrl, modelName = modelName) }

    fun setApiKey(apiKey: String) {
        SecurePrefs.setApiKey(context, apiKey)
    }

    fun apiKey(): String = SecurePrefs.getApiKey(context)

    private fun updateSettings(transform: (Settings) -> Settings) {
        viewModelScope.launch(Dispatchers.IO) {
            val current = repo.currentSettings() ?: Settings()
            repo.saveSettings(transform(current))
        }
    }

    // MARK: - 备份

    /** 导出：返回 JSON 字符串，由 UI 写入用户选择的 Uri */
    suspend fun exportData(): String = DataBackupManager.export(repo, settings.value)

    fun exportToUri(uri: Uri) {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val json = DataBackupManager.export(repo, settings.value)
                DataBackupManager.writeToUri(context, uri, json)
                lastResult.value = Result.success(true)
            } catch (e: Exception) {
                lastResult.value = Result.success(false)
            }
        }
    }

    fun importFromUri(uri: Uri) {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val json = DataBackupManager.readFromUri(context, uri)
                val parsed = DataBackupManager.importJson(repo, json)
                repo.saveSettings(parsed)
                selectFirstGoal()
                lastResult.value = Result.success(true)
            } catch (e: Exception) {
                lastResult.value = Result.success(false)
            }
        }
    }

    /** 数据处理结果事件（导出/导入是否成功；null = 无事件，UI 消费后置空） */
    val lastResult: MutableStateFlow<Result<Boolean>?> = MutableStateFlow(null)

    fun clearLastResult() { lastResult.value = null }

    // MARK: - AI 聊天

    val chatSessions: StateFlow<List<AIChatSession>> = repo.chatSessions
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val isGenerating = MutableStateFlow(false)

    val aiError = MutableStateFlow<String?>(null)

    fun newChatSession() {
        viewModelScope.launch(Dispatchers.IO) {
            val session = AIChatSession()
            repo.addSession(session)
        }
    }

    fun deleteChatSession(sessionId: String) {
        viewModelScope.launch(Dispatchers.IO) { repo.deleteSession(sessionId) }
    }

    fun messagesOf(session: AIChatSession): List<AIChatMessage> = ChatMessageCodec.messages(session)

    /**
     * 发送一条用户消息。若返回 generate=true，把生成的任务树写入当前选中的 Goal（不展示），
     * 同时把 assistant 消息（message 字段）追加进会话。
     */
    fun sendMessage(sessionId: String, text: String, attachmentUri: Uri?) {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                isGenerating.value = true
                aiError.value = null

                val session = repo.sessionById(sessionId) ?: return@launch
                var messages = ChatMessageCodec.messages(session)

                // 解析附件
                var attachmentText: String? = null
                if (attachmentUri != null) {
                    try {
                        attachmentText = DocumentTextExtractor.extractText(context, attachmentUri)
                    } catch (e: Exception) {
                        aiError.value = e.message ?: "附件解析失败"
                    }
                }

                messages = messages + AIChatMessage(role = "user", text = text)
                repo.updateSession(ChatMessageCodec.withMessages(session, messages))

                val s = settings.value
                val apiKey = SecurePrefs.getApiKey(context)
                val baseUrl = s.baseUrl.ifBlank { s.aiModel.defaultBaseUrl }
                val modelName = s.modelName.ifBlank { s.aiModel.defaultModel }

                val reply: ChatReply = AIService.chatReply(
                    history = messages.dropLast(1),
                    currentMessage = text,
                    attachmentText = attachmentText,
                    apiKey = apiKey,
                    baseUrl = baseUrl,
                    modelName = modelName
                )

                val assistantText = buildString {
                    if (reply.message.isNotBlank()) append(reply.message)
                    if (attachmentText != null) {
                        if (this.isNotEmpty()) append("\n\n")
                        append("【附件】${attachmentText.take(120)}${if (attachmentText.length > 120) "…" else ""}")
                    }
                }.ifEmpty { "收到" }

                // 生成任务 → 写入当前选中目标
                if (reply.shouldGenerateTasks && reply.tasks.isNotEmpty()) {
                    val goalId = selectedGoalId.value
                    if (goalId != null) {
                        writeTaskTree(goalId, reply.tasks)
                    }
                }

                val updated = session.copy(messagesJson = ChatMessageCodec.encode(messages + AIChatMessage(role = "assistant", text = assistantText)))
                repo.updateSession(updated)
            } catch (e: Exception) {
                aiError.value = e.message ?: "请求失败"
            } finally {
                isGenerating.value = false
            }
        }
    }

    private suspend fun writeTaskTree(goalId: String, nodes: List<TaskNode>) {
        var sort = repo.rootTasks(goalId).size
        for (node in nodes) {
            if (node.trimmedName.isEmpty()) continue
            val task = TaskItem(
                name = node.trimmedName,
                goalId = goalId,
                sortOrder = sort
            )
            repo.addTask(task)
            sort++
            writeChildren(task, node.children, goalId)
        }
    }

    private suspend fun writeChildren(parent: TaskItem, children: List<TaskNode>, goalId: String) {
        var sort = 0
        for (child in children) {
            if (child.trimmedName.isEmpty()) continue
            val task = TaskItem(
                name = child.trimmedName,
                goalId = goalId,
                parentTaskId = parent.id,
                sortOrder = sort
            )
            repo.addTask(task)
            sort++
            writeChildren(task, child.children, goalId)
        }
    }

    /** 通知跳转：定位目标 id */
    fun handleDeepLink(goalId: String?) {
        if (!goalId.isNullOrBlank()) selectGoal(goalId)
    }
}