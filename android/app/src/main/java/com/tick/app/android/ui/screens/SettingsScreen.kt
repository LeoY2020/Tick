package com.tick.app.android.ui.screens

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.outlined.Download
import androidx.compose.material.icons.outlined.Upload
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExposedDropdownMenu
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.tick.app.android.model.AIModel
import com.tick.app.android.model.AppLanguage
import com.tick.app.android.model.ThemeMode
import com.tick.app.android.ui.theme.LocalStrings
import com.tick.app.android.ui.theme.Skin
import com.tick.app.android.ui.viewmodel.TickViewModel
import androidx.compose.runtime.LaunchedEffect

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: TickViewModel, en: Boolean) {
    val context = LocalContext.current
    val strings = LocalStrings.current
    val settings by vm.settings.collectAsStateWithLifecycle()

    var showAIDialog by remember { mutableStateOf(false) }

    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        if (uri != null) vm.exportToUri(uri)
    }
    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) { vm.importFromUri(uri); uri }
    }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        Text(strings.themeMode, style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
            ThemeMode.entries.forEachIndexed { i, mode ->
                SegmentedButton(
                    selected = settings.themeMode == mode,
                    onClick = { vm.setThemeMode(mode) },
                    shape = SegmentedButtonDefaults.itemShape(index = i, count = ThemeMode.entries.size)
                ) {
                    Text(themeLabel(mode, en))
                }
            }
        }

        Spacer(Modifier.height(20.dp))
        Text(strings.skin, style = MaterialTheme.typography.titleMedium)
        if (settings.skinId == Skin.HYPEROS.id) {
            Text(
                strings.hyperosGlassNote,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(Modifier.height(4.dp))
        }
        Spacer(Modifier.height(8.dp))
        Skin.entries.forEach { skin ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable { vm.setSkin(skin) }
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    Modifier
                        .size(22.dp)
                        .background(skin.brand.toComposeColor(), CircleShape)
                )
                Spacer(Modifier.width(12.dp))
                Text(skin.displayName, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
                RadioButton(
                    selected = settings.skinId == skin.id,
                    onClick = { vm.setSkin(skin) }
                )
            }
        }

        Spacer(Modifier.height(12.dp))
        Text(strings.language, style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        AppLanguage.entries.forEach { lang ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable { vm.setLanguage(lang) }
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(lang.displayName, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
                RadioButton(selected = settings.language == lang, onClick = { vm.setLanguage(lang) })
            }
        }
        if (settings.language == AppLanguage.ZH_HANS) {
            // 切换后立即生效，无需提示
        }

        Spacer(Modifier.height(20.dp))
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text(strings.aiConfig, style = MaterialTheme.typography.titleMedium, Modifier.weight(1f))
            OutlinedButton(onClick = { showAIDialog = true }) {
                Text(if (en) settings.aiModel.displayName else settings.aiModel.displayName)
            }
        }
        Spacer(Modifier.height(12.dp))
        Box(Modifier.fillMaxWidth()) {
            Text(
                strings.aiCopilotNote,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Spacer(Modifier.height(20.dp))
        Text(strings.dataBackup, style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(12.dp)) {
            OutlinedButton(onClick = { exportLauncher.launch("tick_backup.json") }) {
                Icon(Icons.Outlined.Upload, contentDescription = null, Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(strings.exportData)
            }
            OutlinedButton(onClick = { importLauncher.launch(arrayOf("application/json", "text/plain", "*/*")) }) {
                Icon(Icons.Outlined.Download, contentDescription = null, Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(strings.importData)
            }
        }
        Spacer(Modifier.height(48.dp))
    }

    val lastResult by vm.lastResult.collectAsStateWithLifecycle()
    LaunchedEffect(lastResult) {
        val ok = lastResult?.getOrNull()
        if (ok != null) {
            Toast.makeText(
                context,
                if (ok) (if (en) "Done" else "完成") else (if (en) "Failed" else "操作失败"),
                Toast.LENGTH_SHORT
            ).show()
            vm.clearLastResult()
        }
    }

    if (showAIDialog) {
        AIConfigDialog(
            currentModel = settings.aiModel,
            baseUrl = settings.baseUrl,
            modelName = settings.modelName,
            apiKey = vm.apiKey(),
            en = en,
            onDismiss = { showAIDialog = false },
            onSave = { model, base, modelName, key ->
                vm.setAiModel(model)
                vm.setAiConfig(base, modelName)
                vm.setApiKey(key)
                showAIDialog = false
            }
        )
    }
}

/** 适配皮肤 ARGB Long → Compose Color（避免引入 ui 包耦合，直接内联实现） */
private fun Long.toComposeColor(): Color = Color(this)

@Composable
private fun themeLabel(mode: ThemeMode, en: Boolean): String = when (mode) {
    ThemeMode.SYSTEM -> if (en) "System" else "跟随系统"
    ThemeMode.LIGHT -> if (en) "Light" else "亮色"
    ThemeMode.DARK -> if (en) "Dark" else "暗色"
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AIConfigDialog(
    currentModel: AIModel,
    baseUrl: String,
    modelName: String,
    apiKey: String,
    en: Boolean,
    onDismiss: () -> Unit,
    onSave: (AIModel, String, String, String) -> Unit
) {
    var model by remember { mutableStateOf(currentModel) }
    var base by remember { mutableStateOf(baseUrl) }
    var mName by remember { mutableStateOf(modelName) }
    var key by remember { mutableStateOf(apiKey) }
    val strings = LocalStrings.current

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(strings.aiConfig) },
        text = {
            Column {
                ModelDropdown(model, en) { model = it }
                Spacer(Modifier.height(12.dp))
                OutlinedTextField(
                    value = base,
                    onValueChange = { base = it },
                    label = { Text(strings.aiBaseUrl) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = mName,
                    onValueChange = { mName = it },
                    label = { Text(strings.aiModelName) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = key,
                    onValueChange = { key = it },
                    label = { Text(strings.apiKey) },
                    placeholder = { Text(strings.apiKeyHint) },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            TextButton(onClick = {
                onSave(model, base.trim(), mName.trim(), key.trim())
            }) { Text(strings.save) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(strings.cancel) } }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ModelDropdown(selected: AIModel, en: Boolean, onSelect: (AIModel) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = selected.displayName,
            onValueChange = {},
            readOnly = true,
            label = { Text(if (en) "Provider" else "服务商") },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier
                .menuAnchor()
                .fillMaxWidth()
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            AIModel.entries.forEach { m ->
                DropdownMenuItem(
                    text = { Text(m.displayName) },
                    onClick = { onSelect(m); expanded = false }
                )
            }
        }
    }
}