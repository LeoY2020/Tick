package com.tick.app.android.ui.screens

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ArrowDropDown
import androidx.compose.material.icons.outlined.ArrowRight
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.KeyboardArrowRight
import androidx.compose.material.icons.outlined.MoreVert
import androidx.compose.material.icons.outlined.PlaylistAdd
import androidx.compose.material3.Card
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.AlertDialog
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.tick.app.android.domain.ProgressEngine
import com.tick.app.android.model.Goal
import com.tick.app.android.model.TaskItem
import com.tick.app.android.model.TaskStatus
import com.tick.app.android.model.TaskType
import com.tick.app.android.model.status
import com.tick.app.android.model.type
import com.tick.app.android.ui.theme.LocalStrings
import com.tick.app.android.ui.util.CountdownFormatter
import com.tick.app.android.ui.util.HexColor
import com.tick.app.android.ui.util.iconForName

@Composable
fun GoalDetailScreen(
    goal: Goal?,
    tree: List<TaskItem>,
    expandedTasks: Set<String>,
    en: Boolean,
    onToggleExpand: (String) -> Unit,
    onAddRootTask: () -> Unit,
    onAddSubtask: (TaskItem) -> Unit,
    onEditTask: (TaskItem) -> Unit,
    onDeleteTask: (TaskItem) -> Unit,
    onToggleStatus: (TaskItem) -> Unit,
    onStepProgress: (TaskItem, Double) -> Unit
) {
    val strings = LocalStrings.current
    if (goal == null) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(strings.noGoal, style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(8.dp))
                Text(strings.noGoalHint, style = MaterialTheme.typography.bodyMedium)
            }
        }
        return
    }

    val progress = ProgressEngine.goalProgress(goal, tree)
    val countdownText = CountdownFormatter.remaining(
        goal.endDate ?: 0L, goal.endDatePreciseToHour, en
    )

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        // 倒计时
        if (goal.endDate != null) {
            Card(Modifier.fillMaxWidth()) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(strings.countdown, style = MaterialTheme.typography.labelLarge)
                    Spacer(Modifier.weight(1f))
                    Text(
                        countdownText ?: "",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
            Spacer(Modifier.height(12.dp))
        }

        // 总进度
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Row(Modifier.fillMaxWidth()) {
                    Text(strings.totalProgress, style = MaterialTheme.typography.labelLarge)
                    Spacer(Modifier.weight(1f))
                    Text(
                        strings.hanDoneCount.replace("{0}", progress.doneItems.toString())
                            .replace("{1}", progress.totalItems.toString()),
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
                Spacer(Modifier.height(8.dp))
                AnimatedProgressBar(
                    fraction = progress.fraction,
                    color = MaterialTheme.colorScheme.primary
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    percentText(progress.fraction),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Spacer(Modifier.height(8.dp))

        if (tree.isEmpty()) {
            Spacer(Modifier.height(40.dp))
            Text(
                strings.addTask,
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .clickable { onAddRootTask() }
                    .padding(8.dp),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary
            )
        } else {
            tree.forEach { node ->
                TaskRowNode(
                    task = node,
                    depth = 0,
                    expandedTasks = expandedTasks,
                    en = en,
                    onToggleExpand = onToggleExpand,
                    onAddSubtask = onAddSubtask,
                    onEditTask = onEditTask,
                    onDeleteTask = onDeleteTask,
                    onToggleStatus = onToggleStatus,
                    onStepProgress = onStepProgress
                )
            }
        }
        Spacer(Modifier.height(96.dp))
    }
}

@Composable
private fun TaskRowNode(
    task: TaskItem,
    depth: Int,
    expandedTasks: Set<String>,
    en: Boolean,
    onToggleExpand: (String) -> Unit,
    onAddSubtask: (TaskItem) -> Unit,
    onEditTask: (TaskItem) -> Unit,
    onDeleteTask: (TaskItem) -> Unit,
    onToggleStatus: (TaskItem) -> Unit,
    onStepProgress: (TaskItem, Double) -> Unit
) {
    val hasSubtasks = task.subtasks.isNotEmpty()
    val isExpanded = task.id in expandedTasks
    var menuOpen by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }

    Column {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(start = (depth * 20).dp, top = 4.dp, bottom = 4.dp)
                .clickable {
                    if (hasSubtasks) onToggleExpand(task.id)
                    else if (task.type == TaskType.SINGLE &&
                        !ProgressEngine.hasActiveSubtasks(task) &&
                        ProgressEngine.isDeleted(task).not()
                    ) onToggleStatus(task)
                }
                .padding(horizontal = 8.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 展开箭头
            Box(Modifier.size(24.dp), contentAlignment = Alignment.Center) {
                if (hasSubtasks) {
                    Icon(
                        imageVector = if (isExpanded) Icons.Outlined.ArrowDropDown else Icons.Outlined.KeyboardArrowRight,
                        contentDescription = if (isExpanded) "collapse" else "expand",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            // 颜色/图标
            val effectiveColor = effectiveColorFor(task)
            if (task.iconSystemName != null) {
                val icon = iconForName(task.iconSystemName)
                if (icon != null) {
                    Icon(
                        imageVector = icon,
                        contentDescription = task.name,
                        modifier = Modifier.size(20.dp),
                        tint = effectiveColor
                    )
                } else {
                    ColorDot(effectiveColor)
                }
            } else {
                ColorDot(effectiveColor)
            }

            Spacer(Modifier.width(8.dp))

            // 内容
            Column(Modifier.weight(1f)) {
                Text(
                    task.name,
                    style = MaterialTheme.typography.bodyLarge,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    color = if (ProgressEngine.isDeleted(task))
                        MaterialTheme.colorScheme.onSurfaceVariant
                    else MaterialTheme.colorScheme.onSurface
                )
                if (task.type == TaskType.PROGRESS) {
                    Spacer(Modifier.height(4.dp))
                    val (cur, tot) = ProgressEngine.effectiveProgress(task)
                    val ratio = if (tot > 0) (cur / tot).toDouble().coerceIn(0.0, 1.0) else 0.0
                    AnimatedProgressBar(
                        fraction = ratio,
                        color = effectiveColor,
                        trackColor = effectiveColor.copy(alpha = 0.15f)
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        percentText(ratio),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            // 尾部控件
            if (task.type == TaskType.SINGLE) {
                if (!ProgressEngine.hasActiveSubtasks(task)) {
                    StatusCircle(
                        status = task.status,
                        color = effectiveColor,
                        enabled = ProgressEngine.isDeleted(task).not()
                    )
                } else {
                    EffectiveStatusPill(ProgressEngine.effectiveStatus(task), en)
                }
            } else {
                if (!ProgressEngine.hasActiveSubtasks(task)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedButton(
                            onClick = { onStepProgress(task, -1.0) },
                            modifier = Modifier.size(30.dp),
                            contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)
                        ) { Text("−", style = MaterialTheme.typography.titleMedium) }
                        Spacer(Modifier.width(4.dp))
                        val (cur, tot) = ProgressEngine.effectiveProgress(task)
                        Text("${cur.toInt()}/${tot.toInt()}", style = MaterialTheme.typography.labelLarge)
                        Spacer(Modifier.width(4.dp))
                        OutlinedButton(
                            onClick = { onStepProgress(task, 1.0) },
                            modifier = Modifier.size(30.dp),
                            contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)
                        ) { Text("+", style = MaterialTheme.typography.titleMedium) }
                    }
                } else {
                    Text(
                        "⚬",
                        style = MaterialTheme.typography.titleLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            // 更多菜单
            Box {
                Icon(
                    imageVector = Icons.Outlined.MoreVert,
                    contentDescription = "menu",
                    modifier = Modifier
                        .clickable { menuOpen = true }
                        .padding(4.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                    DropdownMenuItem(
                        text = { Text(if (en) "Add subtask" else "添加子任务") },
                        leadingIcon = { Icon(Icons.Outlined.PlaylistAdd, contentDescription = null) },
                        onClick = { menuOpen = false; onAddSubtask(task) }
                    )
                    DropdownMenuItem(
                        text = { Text(if (en) "Edit" else "编辑") },
                        leadingIcon = { Icon(Icons.Outlined.Edit, contentDescription = null) },
                        onClick = { menuOpen = false; onEditTask(task) }
                    )
                    DropdownMenuItem(
                        text = { Text(if (en) "Delete" else "删除") },
                        leadingIcon = { Icon(Icons.Outlined.Delete, contentDescription = null) },
                        onClick = { menuOpen = false; confirmDelete = true }
                    )
                }
            }
        }

        // 级联删除确认
        if (confirmDelete) {
            val cascade = hasSubtasks
            AlertDialog(
                onDismissRequest = { confirmDelete = false },
                title = { Text(if (en) "Delete task" else "删除任务") },
                text = {
                    Text(if (cascade) (if (en) "This task has subtasks. All descendants will be removed too." else "该任务包含子任务，删除将一并删除全部子任务。") else (if (en) "Delete this task?" else "确定删除该任务？"))
                },
                confirmButton = {
                    TextButton(onClick = {
                        confirmDelete = false
                        onDeleteTask(task)
                    }) { Text(if (en) "Delete" else "删除") }
                },
                dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text(if (en) "Cancel" else "取消") } }
            )
        }

        if (hasSubtasks && isExpanded) {
            task.subtasks.forEach { sub ->
                TaskRowNode(
                    task = sub,
                    depth = depth + 1,
                    expandedTasks = expandedTasks,
                    en = en,
                    onToggleExpand = onToggleExpand,
                    onAddSubtask = onAddSubtask,
                    onEditTask = onEditTask,
                    onDeleteTask = onDeleteTask,
                    onToggleStatus = onToggleStatus,
                    onStepProgress = onStepProgress
                )
            }
        }
    }
}

@Composable
private fun ColorDot(color: Color) {
    Box(
        Modifier
            .size(12.dp)
            .background(color, CircleShape)
    )
}

@Composable
private fun StatusCircle(status: TaskStatus, color: Color, enabled: Boolean) {
    val fill = when {
        !enabled -> Color.Gray.copy(alpha = 0.3f)
        status == TaskStatus.DONE -> color
        status == TaskStatus.HALF_DONE -> color.copy(alpha = 0.5f)
        else -> color.copy(alpha = 0.25f)
    }
    Box(
        Modifier
            .size(22.dp)
            .background(fill, CircleShape)
            .clickable(enabled = false) {}
    )
}

@Composable
private fun EffectiveStatusPill(status: TaskStatus, en: Boolean) {
    val label = when (status) {
        TaskStatus.DONE -> if (en) "✓" else "完成"
        TaskStatus.HALF_DONE -> if (en) "◐" else "半成"
        else -> if (en) "○" else "未成"
    }
    Text(
        label,
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

@Composable
private fun effectiveColorFor(task: TaskItem): Color {
    val hex = ProgressEngine.effectiveColor(task)
    return HexColor.parse(hex) ?: if (hex == "auto") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.primary
}

/** 带动画（400ms 平滑过渡）与 trackColor 支持的确定进度条。 */
@Composable
private fun AnimatedProgressBar(
    fraction: Double,
    color: Color,
    trackColor: Color? = null
) {
    val animated by animateFloatAsState(
        targetValue = fraction.toFloat().coerceIn(0f, 1f),
        animationSpec = tween(durationMillis = 400),
        label = "progress"
    )
    LinearProgressIndicator(
        progress = { animated },
        modifier = Modifier.fillMaxWidth(),
        color = color,
        trackColor = trackColor
    )
}

private fun percentText(fraction: Double): String =
    "${(fraction.coerceIn(0.0, 1.0) * 100).toInt()}%"