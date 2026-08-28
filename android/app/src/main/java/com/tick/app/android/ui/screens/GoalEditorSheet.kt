package com.tick.app.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Event
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.tick.app.android.model.Goal
import com.tick.app.android.model.ProgressCountingMode
import com.tick.app.android.ui.theme.LocalStrings
import com.tick.app.android.ui.util.HexColor
import com.tick.app.android.ui.util.iconForName
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** 颜色/图标材质数据 */
internal val PRESET_COLORS = listOf(
    "auto", "#E53935", "#FB8C00", "#FDD835", "#43A047", "#00ACC1",
    "#1E88E5", "#5E35B1", "#D81B60", "#6D4C41"
)

internal val PRESET_ICONS = listOf(
    "", "star", "flag", "book", "work", "home", "fitness_center",
    "school", "code", "lightbulb", "restaurant"
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GoalEditorSheet(
    goal: Goal?,
    en: Boolean,
    onSave: (name: String, color: String, icon: String?, startDate: Long?, endDate: Long?,
           startPrecise: Boolean, endPrecise: Boolean, mode: ProgressCountingMode) -> Unit,
    onDismiss: () -> Unit
) {
    val strings = LocalStrings.current
    var name by remember { mutableStateOf(goal?.name ?: "") }
    var color by remember { mutableStateOf(goal?.colorHex ?: "auto") }
    var icon by remember { mutableStateOf(goal?.iconSystemName.orEmpty()) }
    var startDate by remember { mutableLongStateOf(goal?.startDate ?: 0L) }
    var endDate by remember { mutableLongStateOf(goal?.endDate ?: 0L) }
    var startPrecise by remember { mutableStateOf(goal?.startDatePreciseToHour ?: false) }
    var endPrecise by remember { mutableStateOf(goal?.endDatePreciseToHour ?: false) }
    var mode by remember { mutableStateOf(goal?.progressCountingMode ?: ProgressCountingMode.ALL_TASKS) }

    var showStartPicker by remember { mutableStateOf(false) }
    var showEndPicker by remember { mutableStateOf(false) }

    val dateFmt = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (goal == null) strings.newGoal else strings.editGoal) },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
            ) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(strings.goalName) },
                    placeholder = { Text(strings.goalNameHint) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(16.dp))
                Text(strings.color, style = MaterialTheme.typography.labelLarge)
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    PRESET_COLORS.forEach { c ->
                        val isAuto = c == "auto"
                        val isSelected = if (isAuto) color == "auto" else color == c
                        val bgColor = if (isAuto) MaterialTheme.colorScheme.surfaceVariant else (HexColor.parse(c) ?: Color.Gray)
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .background(bgColor, CircleShape)
                                .border(
                                    width = if (isSelected) 3.dp else 1.dp,
                                    color = if (isSelected) MaterialTheme.colorScheme.primary else Color.Gray.copy(alpha = 0.5f),
                                    shape = CircleShape
                                )
                                .clickable { color = c },
                            contentAlignment = Alignment.Center
                        ) {
                            if (isAuto) {
                                Text("—", style = MaterialTheme.typography.labelMedium)
                            }
                        }
                    }
                }

                Spacer(Modifier.height(16.dp))
                Text(strings.icon, style = MaterialTheme.typography.labelLarge)
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    PRESET_ICONS.forEach { ic ->
                        val isSelected = icon == ic
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .background(
                                    if (isSelected) MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
                                    else MaterialTheme.colorScheme.surfaceVariant,
                                    CircleShape
                                )
                                .border(
                                    1.dp,
                                    if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent,
                                    CircleShape
                                )
                                .clickable { icon = ic },
                            contentAlignment = Alignment.Center
                        ) {
                            if (ic.isEmpty()) {
                                Text("无", style = MaterialTheme.typography.labelSmall)
                            } else {
                                Icon(
                                    imageVector = iconForName(ic) ?: Icons.Outlined.Check,
                                    contentDescription = ic,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                    }
                }

                Spacer(Modifier.height(16.dp))

                // 开始日期
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(if (en) "Start" else "开始日期", Modifier.weight(1f))
                    OutlinedButton(onClick = { showStartPicker = true }) {
                        Icon(Icons.Outlined.Event, contentDescription = null, Modifier.size(18.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(if (startDate > 0) dateFmt.format(Date(startDate)) else (if (en) "Set" else "设置"))
                    }
                }

                // 截止日期
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(strings.endDate, Modifier.weight(1f))
                    OutlinedButton(onClick = { showEndPicker = true }) {
                        Icon(Icons.Outlined.Event, contentDescription = null, Modifier.size(18.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(if (endDate > 0) dateFmt.format(Date(endDate)) else (if (en) "Set" else "设置"))
                    }
                }

                Spacer(Modifier.height(12.dp))
                Text(strings.progressMode, style = MaterialTheme.typography.labelLarge)
                Spacer(Modifier.height(8.dp))
                SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                    SegmentedButton(
                        selected = mode == ProgressCountingMode.ALL_TASKS,
                        onClick = { mode = ProgressCountingMode.ALL_TASKS },
                        shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2)
                    ) {
                        Text(if (en) "All" else "全部任务")
                    }
                    SegmentedButton(
                        selected = mode == ProgressCountingMode.LEAF_TASKS,
                        onClick = { mode = ProgressCountingMode.LEAF_TASKS },
                        shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2)
                    ) {
                        Text(if (en) "Leaf" else "叶子")
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                onSave(
                    name, color, icon.ifBlank { null },
                    startDate.takeIf { it > 0 }, endDate.takeIf { it > 0 },
                    startPrecise, endPrecise, mode
                )
                onDismiss()
            }) { Text(strings.save) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(strings.cancel) }
        }
    )

    if (showStartPicker) {
        val state = rememberDatePickerState(initialSelectedDateMillis = startDate.takeIf { it > 0 })
        DatePickerDialog(
            onDismissRequest = { showStartPicker = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { startDate = it }
                    showStartPicker = false
                }) { Text(strings.confirm) }
            },
            dismissButton = { TextButton(onClick = { showStartPicker = false }) { Text(strings.cancel) } }
        ) {
            DatePicker(state = state)
        }
    }

    if (showEndPicker) {
        val state = rememberDatePickerState(initialSelectedDateMillis = endDate.takeIf { it > 0 })
        DatePickerDialog(
            onDismissRequest = { showEndPicker = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { endDate = it }
                    showEndPicker = false
                }) { Text(strings.confirm) }
            },
            dismissButton = { TextButton(onClick = { showEndPicker = false }) { Text(strings.cancel) } }
        ) {
            DatePicker(state = state)
        }
    }
}