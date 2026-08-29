package com.tick.app.android.ui

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.enableEdgeToEdge
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Menu
import androidx.compose.material.icons.outlined.MoreVert
import androidx.compose.material.icons.outlined.Remove
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.NavigationDrawerItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.launch
import com.tick.app.android.model.AppLanguage
import com.tick.app.android.model.Goal
import com.tick.app.android.model.TaskItem
import com.tick.app.android.model.TaskType
import com.tick.app.android.ui.screens.AIChatScreen
import com.tick.app.android.ui.screens.GoalDetailScreen
import com.tick.app.android.ui.screens.GoalEditorSheet
import com.tick.app.android.ui.screens.SettingsScreen
import com.tick.app.android.ui.screens.TaskEditorDialog
import com.tick.app.android.ui.theme.LocalStrings
import com.tick.app.android.ui.theme.Skin
import com.tick.app.android.ui.theme.Strings
import com.tick.app.android.ui.theme.TickTheme
import com.tick.app.android.ui.viewmodel.TickViewModel

private enum class Screen { MAIN, SETTINGS, AICHAT }

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val vm: TickViewModel = viewModel()
            TickAppRoot(vm)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val vm = androidx.lifecycle.ViewModelProvider(this)[TickViewModel::class.java]
        vm.handleDeepLink(intent.getStringExtra("goalId"))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TickAppRoot(vm: TickViewModel) {
    val settings by vm.settings.collectAsStateWithLifecycle()
    val goals by vm.goals.collectAsStateWithLifecycle()
    val selectedGoal by vm.selectedGoal.collectAsStateWithLifecycle()
    val selectedGoalId by vm.selectedGoalId.collectAsStateWithLifecycle()
    val tree by vm.goalTree.collectAsStateWithLifecycle()
    val expandedTasks by vm.expandedTasks.collectAsStateWithLifecycle()

    val skin = Skin.fromId(settings.skinId)
    val en = settings.language == AppLanguage.EN

    CompositionLocalProvider(LocalStrings provides Strings.of(settings.language)) {
        TickTheme(skin = skin, themeMode = settings.themeMode) {
            AppContent(
                vm = vm,
                goals = goals,
                selectedGoal = selectedGoal,
                selectedGoalId = selectedGoalId,
                tree = tree,
                expandedTasks = expandedTasks,
                isEmpty = goals.isEmpty(),
                en = en
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AppContent(
    vm: TickViewModel,
    goals: List<Goal>,
    selectedGoal: Goal?,
    selectedGoalId: String?,
    tree: List<TaskItem>,
    expandedTasks: Set<String>,
    isEmpty: Boolean,
    en: Boolean
) {
    val strings = LocalStrings.current
    var screen by rememberSaveable { mutableStateOf(Screen.MAIN) }
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()

    var showGoalEditor by remember { mutableStateOf(false) }
    var editingGoal by remember { mutableStateOf<Goal?>(null) }
    var editingTask by remember { mutableStateOf<TaskItem?>(null) }
    var quickAddParent by remember { mutableStateOf<TaskItem?>(null) }
    var showQuickAdd by remember { mutableStateOf(false) }
    var confirmDeleteGoal by remember { mutableStateOf(false) }
    var topBarMenu by remember { mutableStateOf(false) }

    LaunchedEffect(goals) {
        if (selectedGoalId == null && goals.isNotEmpty()) vm.selectGoal(goals.first().id)
    }

    val notifPerm = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}
    LaunchedEffect(Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            notifPerm.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    val appTitle = when (screen) {
        Screen.MAIN -> selectedGoal?.name ?: strings.appName
        Screen.SETTINGS -> strings.settings
        Screen.AICHAT -> strings.aiChat
    }

    ModalNavigationDrawer(
        drawerState = drawerState,
        drawerContent = {
            ModalDrawerSheet {
                Text(
                    strings.goals,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(16.dp)
                )
                goals.forEach { g ->
                    NavigationDrawerItem(
                        label = { Text(g.name) },
                        selected = g.id == selectedGoalId,
                        onClick = {
                            vm.selectGoal(g.id)
                            screen = Screen.MAIN
                            scope.launch { drawerState.close() }
                        },
                        modifier = Modifier.padding(horizontal = 8.dp)
                    )
                }
                NavigationDrawerItem(
                    label = { Text(strings.newGoal) },
                    selected = false,
                    icon = { Icon(Icons.Outlined.Add, contentDescription = null) },
                    onClick = {
                        editingGoal = null
                        showGoalEditor = true
                        scope.launch { drawerState.close() }
                    },
                    modifier = Modifier.padding(horizontal = 8.dp)
                )
                Spacer(Modifier.height(8.dp))
                NavigationDrawerItem(
                    label = { Text(strings.settings) },
                    selected = screen == Screen.SETTINGS,
                    icon = { Icon(Icons.Outlined.Settings, contentDescription = null) },
                    onClick = { screen = Screen.SETTINGS; scope.launch { drawerState.close() } },
                    modifier = Modifier.padding(horizontal = 8.dp)
                )
                NavigationDrawerItem(
                    label = { Text(strings.aiChat) },
                    selected = screen == Screen.AICHAT,
                    icon = { Icon(Icons.Outlined.ChatBubbleOutline, contentDescription = null) },
                    onClick = { screen = Screen.AICHAT; scope.launch { drawerState.close() } },
                    modifier = Modifier.padding(horizontal = 8.dp)
                )
            }
        }
    ) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(appTitle) },
                    navigationIcon = {
                        IconButton(onClick = { scope.launch { drawerState.open() } }) {
                            Icon(Icons.Outlined.Menu, contentDescription = strings.settingsMenu)
                        }
                    },
                    actions = {
                        if (screen == Screen.MAIN && selectedGoal != null) {
                            Box {
                                IconButton(onClick = { topBarMenu = true }) {
                                    Icon(Icons.Outlined.MoreVert, contentDescription = "goal menu")
                                }
                                DropdownMenu(expanded = topBarMenu, onDismissRequest = { topBarMenu = false }) {
                                    DropdownMenuItem(
                                        text = { Text(strings.editGoal) },
                                        leadingIcon = { Icon(Icons.Outlined.Edit, contentDescription = null) },
                                        onClick = {
                                            topBarMenu = false
                                            editingGoal = selectedGoal
                                            showGoalEditor = true
                                        }
                                    )
                                    DropdownMenuItem(
                                        text = { Text(strings.delete) },
                                        leadingIcon = { Icon(Icons.Outlined.Delete, contentDescription = null) },
                                        onClick = { topBarMenu = false; confirmDeleteGoal = true }
                                    )
                                }
                            }
                        }
                        IconButton(onClick = { screen = Screen.AICHAT }) {
                            Icon(Icons.Outlined.ChatBubbleOutline, contentDescription = strings.aiChat)
                        }
                        IconButton(onClick = { screen = Screen.SETTINGS }) {
                            Icon(Icons.Outlined.Settings, contentDescription = strings.settings)
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Color.Transparent,
                        titleContentColor = MaterialTheme.colorScheme.onSurface
                    )
                )
            },
            floatingActionButton = {
                if (screen == Screen.MAIN) {
                    FloatingActionButton(onClick = {
                        quickAddParent = null
                        showQuickAdd = true
                    }) {
                        Icon(Icons.Outlined.Add, contentDescription = strings.addTask)
                    }
                }
            }
        ) { padding ->
            Box(Modifier.fillMaxSize().padding(padding)) {
                when (screen) {
                    Screen.MAIN -> {
                        if (isEmpty) {
                            Column(
                                Modifier
                                    .fillMaxSize()
                                    .padding(24.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.Center
                            ) {
                                Text(strings.noGoal, style = MaterialTheme.typography.titleMedium)
                                Spacer(Modifier.height(8.dp))
                                Text(strings.noGoalHint, style = MaterialTheme.typography.bodyMedium)
                                Spacer(Modifier.height(16.dp))
                                TextButton(onClick = {
                                    editingGoal = null
                                    showGoalEditor = true
                                }) { Text(strings.newGoal) }
                            }
                        } else {
                            GoalDetailScreen(
                                goal = selectedGoal,
                                tree = tree,
                                expandedTasks = expandedTasks,
                                en = en,
                                onToggleExpand = vm::toggleExpand,
                                onAddRootTask = {
                                    quickAddParent = null
                                    showQuickAdd = true
                                },
                                onAddSubtask = {
                                    quickAddParent = it
                                    showQuickAdd = true
                                },
                                onEditTask = { editingTask = it },
                                onDeleteTask = { vm.deleteTask(it.id) },
                                onToggleStatus = { vm.toggleSingleStatus(it) },
                                onStepProgress = { t, d -> vm.setProgress(t, d) }
                            )
                        }
                    }
                    Screen.SETTINGS -> SettingsScreen(vm, en = en)
                    Screen.AICHAT -> AIChatScreen(vm, en = en)
                }
            }
        }
    }

    if (showGoalEditor) {
        GoalEditorSheet(
            goal = editingGoal,
            en = en,
            onSave = { name, color, icon, s, e, sp, ep, mode ->
                if (editingGoal == null) {
                    vm.createGoal(name, color, icon, s, e, sp, ep, mode)
                } else {
                    vm.updateGoal(editingGoal!!.id, name, color, icon, s, e, sp, ep, mode)
                }
            },
            onDismiss = { showGoalEditor = false }
        )
    }

    editingTask?.let { t ->
        TaskEditorDialog(
            task = t,
            en = en,
            onSave = { name, type, status, totalA, currentA, s, e, reminder, rule, weekdays ->
                vm.saveTask(t.id, name, type, status, totalA, currentA, s, e, reminder, rule, weekdays)
            },
            onDismiss = { editingTask = null }
        )
    }

    if (showQuickAdd) {
        QuickAddTaskDialog(
            en = en,
            onSubmit = { name, type, totalAmount, currentAmount ->
                val goalId = selectedGoalId ?: return@QuickAddTaskDialog
                vm.addTask(goalId, quickAddParent?.id, name, type, totalAmount, currentAmount)
                showQuickAdd = false
            },
            onDismiss = { showQuickAdd = false }
        )
    }

    if (confirmDeleteGoal) {
        val target = selectedGoal
        AlertDialog(
            onDismissRequest = { confirmDeleteGoal = false },
            title = { Text(strings.delete) },
            text = { Text(strings.reasonDeleteGoal) },
            confirmButton = {
                TextButton(onClick = {
                    confirmDeleteGoal = false
                    target?.let { vm.deleteGoal(it.id) }
                }) { Text(strings.delete) }
            },
            dismissButton = { TextButton(onClick = { confirmDeleteGoal = false }) { Text(strings.cancel) } }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun QuickAddTaskDialog(
    en: Boolean,
    onSubmit: (name: String, type: TaskType, totalAmount: Double, currentAmount: Double) -> Unit,
    onDismiss: () -> Unit
) {
    val strings = LocalStrings.current
    var name by remember { mutableStateOf("") }
    var type by remember { mutableStateOf(TaskType.SINGLE) }
    var total by remember { mutableStateOf("0") }
    var current by remember { mutableStateOf(0.0) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(strings.newTask) },
        text = {
            Column {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(strings.taskName) },
                    placeholder = { Text(strings.taskNameHint) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(12.dp))
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
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

                if (type == TaskType.PROGRESS) {
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
                        Text("$current", style = MaterialTheme.typography.titleMedium)
                        Spacer(Modifier.width(8.dp))
                        OutlinedButton(onClick = {
                            val cap = total.toDoubleOrNull()
                            current = (current + 1).let {
                                if (cap != null && !cap.isNaN()) it.coerceAtMost(cap) else it
                            }
                        }) {
                            Icon(Icons.Outlined.Add, contentDescription = "plus", Modifier.size(18.dp))
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(enabled = name.isNotBlank(), onClick = {
                val totalValue = total.toDoubleOrNull()?.coerceAtLeast(0.0) ?: 0.0
                val currentValue = current.coerceIn(0.0, totalValue)
                onSubmit(name, type, totalValue, currentValue)
            }) { Text(strings.add) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(strings.cancel) } }
    )
}