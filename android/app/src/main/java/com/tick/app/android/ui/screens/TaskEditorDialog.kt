package com.tick.app.android.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Remove
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TimePickerDialog
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.tick.app.android.model.RepeatRule
import com.tick.app.android.model.TaskItem
import com.tick.app.android.model.TaskStatus
import com.tick.app.android.model.TaskType
import com.tick.app.android.ui.theme.LocalStrings
import androidx.compose.material3.ExperimentalMaterial3Api
import java.util.Calendar

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TaskEditorDialog(
    task: TaskItem,
    en: Boolean,
    onSave: (
        name: String, type: TaskType, status: TaskStatus, totalAmount: Double, currentAmount: Double,
        startDate: Long?, endDate: Long?, reminderDate: Long?,
        repeatRule: RepeatRule?, customWeekdaysRaw: String?
    ) -> Unit,
    onDismiss: () -> Unit
) {
    val strings = LocalStrings.current
    var name by rememberSaveable { mutableStateOf(task.name) }
    var type by remember { mutableStateOf(task.type) }
    var status by remember { mutableStateOf(task.status) }
    var total by remember { mutableStateOf(task.totalAmount.toString()) }
    var current by remember { mutableStateOf(task.currentAmount) }
    var startDate by remember { mutableLongStateOf(task.startDate ?: 0L) }
    var endDate by remember { mutableLongStateOf(task.endDate ?: 0L) }

    var reminderOn by remember { mutableStateOf(task.reminderDate != null) }
    var reminderTime by remember { mutableLongStateOf(task.reminderDate ?: System.currentTimeMillis()) }
    var repeatRule by remember { mutableStateOf(task.repeatRule ?: RepeatRule.NEVER) }
    var weekdays by remember { mutableStateOf(task.effectiveWeekdays().toSet()) }

    var showTimePicker by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(strings.reasonEdit) },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
            ) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(strings.taskName) },
                    placeholder = { Text(strings.taskNameHint) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(12.dp))
                Text(strings.taskType, style = androidx.compose.material3.MaterialTheme.typography.labelLarge)
                Spacer(Modifier.height(6.dp))
                SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                    SegmentedButton(
                        selected = type == TaskType.SINGLE,
                        onClick = { type = TaskType.SINGLE },
                        shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2)
                    ) { Text(strings.typeSingle) }
                    SegmentedButton(
                        selected = type == TaskType.PROGRESS,
                        onClick = { type = TaskType.PROGRESS },
                        shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2)
                    ) { Text(strings.typeProgress) }
                }

                if (type == TaskType.SINGLE) {
                    Spacer(Modifier.height(12.dp))
                    Text(strings.status, style = androidx.compose.material3.MaterialTheme.typography.labelLarge)
                    Spacer(Modifier.height(6.dp))
                    SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                        listOf(TaskStatus.NOT_DONE, TaskStatus.HALF_DONE, TaskStatus.DONE).forEachIndexed { i, s ->
                            SegmentedButton(
                                selected = status == s,
                                onClick = { status = s },
                                shape = SegmentedButtonDefaults.itemShape(index = i, count = 3)
                            ) {
                                Text(statusLabel(s, en))
                            }
                        }
                    }
                } else {
                    Spacer(Modifier.height(12.dp))
                    OutlinedTextField(
                        value = total,
                        onValueChange = { total = it.filter(Char::isDigit).take(7) },
                        label = { Text(strings.total) },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(8.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(strings.current, Modifier.weight(1f))
                        OutlinedButton(onClick = { current = (current - 1).coerceAtLeast(0.0) }) {
                            Icon(Icons.Outlined.Remove, contentDescription = "minus", Modifier.size(18.dp))
                        }
                        Spacer(Modifier.width(8.dp))
                        Text("$current", style = androidx.compose.material3.MaterialTheme.typography.titleMedium)
                        Spacer(Modifier.width(8.dp))
                        OutlinedButton(onClick = { current = (current + 1).coerceAtMost(total.toDouble().let { if (it.isNaN()) current else it }) }) {
                            Icon(Icons.Outlined.Add, contentDescription = "plus", Modifier.size(18.dp))
                        }
                    }
                }

                Spacer(Modifier.height(12.dp))

                // 提醒
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                    Text(strings.reminderTime, Modifier.weight(1f))
                    Switch(checked = reminderOn, onCheckedChange = { reminderOn = it })
                }
                if (reminderOn) {
                    Spacer(Modifier.height(6.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedButton(onClick = { showTimePicker = true }) {
                            Text(timeLabel(reminderTime))
                        }
                        Spacer(Modifier.width(12.dp))
                        Text(strings.repeat, style = androidx.compose.material3.MaterialTheme.typography.labelLarge)
                    }
                    Spacer(Modifier.height(6.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                        RepeatRule.entries.filter { it != RepeatRule.NEVER }.forEach { r ->
                            FilterChip(
                                selected = repeatRule == r,
                                onClick = { repeatRule = r },
                                label = { Text(repeatLabel(r, en)) }
                            )
                        }
                    }
                    if (repeatRule == RepeatRule.CUSTOM) {
                        Spacer(Modifier.height(6.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            (1..7).forEach { wd ->
                                val selected = wd in weekdays
                                FilterChip(
                                    selected = selected,
                                    onClick = {
                                        weekdays = if (selected) weekdays - wd else weekdays + wd
                                    },
                                    label = { Text(weekdayLabel(wd)) }
                                )
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val totalValue = total.toDoubleOrNull()?.coerceAtLeast(0.0) ?: 0.0
                val currentValue = current.coerceIn(0.0, totalValue)
                val reminder = if (reminderOn) reminderTime else null
                val weekdaysRaw = if (repeatRule == RepeatRule.CUSTOM)
                    weekdays.sorted().joinToString(",")
                else null
                onSave(
                    name, type, status, totalValue, currentValue,
                    startDate.takeIf { it > 0 }, endDate.takeIf { it > 0 },
                    reminder, if (reminderOn) repeatRule else null, weekdaysRaw
                )
                onDismiss()
            }) { Text(strings.save) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(strings.cancel) } }
    )

    if (showTimePicker) {
        val cal = Calendar.getInstance()
        val state = rememberTimePickerState(
            initialHour = cal.get(Calendar.HOUR_OF_DAY),
            initialMinute = cal.get(Calendar.MINUTE),
            is24Hour = true
        )
        TimePickerDialog(
            onDismissRequest = { showTimePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    val base = Calendar.getInstance()
                    base.set(Calendar.HOUR_OF_DAY, state.hour)
                    base.set(Calendar.MINUTE, state.minute)
                    base.set(Calendar.SECOND, 0)
                    base.set(Calendar.MILLISECOND, 0)
                    reminderTime = base.timeInMillis.coerceAtLeast(System.currentTimeMillis())
                    showTimePicker = false
                }) { Text(strings.done) }
            },
            dismissButton = { TextButton(onClick = { showTimePicker = false }) { Text(strings.cancel) } }
        ) {
            TimePicker(state = state)
        }
    }
}

private fun statusLabel(status: TaskStatus, en: Boolean): String = when (status) {
    TaskStatus.NOT_DONE -> if (en) "Not done" else "未完成"
    TaskStatus.HALF_DONE -> if (en) "Half" else "半完成"
    TaskStatus.DONE -> if (en) "Done" else "完成"
    TaskStatus.DELETED -> if (en) "Deleted" else "删除"
}

private fun repeatLabel(r: RepeatRule, en: Boolean): String = when (r) {
    RepeatRule.NEVER -> if (en) "None" else "不重复"
    RepeatRule.DAILY -> if (en) "Daily" else "每天"
    RepeatRule.WEEKLY -> if (en) "Weekly" else "每周"
    RepeatRule.MONTHLY -> if (en) "Monthly" else "每月"
    RepeatRule.CUSTOM -> if (en) "Custom" else "自定义"
}

private fun weekdayLabel(wd: Int): String = when (wd) {
    1 -> "日"
    2 -> "一"
    3 -> "二"
    4 -> "三"
    5 -> "四"
    6 -> "五"
    7 -> "六"
    else -> ""
}

private fun timeLabel(millis: Long): String {
    val cal = Calendar.getInstance().apply { timeInMillis = millis }
    return "%02d:%02d".format(cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
}