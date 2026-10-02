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
import com.tick.app.android.ui.theme.Strings
import com.tick.app.android.ui.viewmodel.TickViewModel
import androidx.compose.runtime.LaunchedEffect

/** 设置页展示的版本号（语言无关的纯文本，便于分辨安装包新旧；须与 build.gradle.kts 的 versionName 保持一致）。 */
private const val APP_VERSION_TEXT = "v1.0.0 beta1"

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: TickViewModel) {
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
                    Text(themeLabel(mode, strings))
                }
            }
        }

        Spacer(Modifier.height(20.dp))
        Text(strings.skin, style = MaterialTheme.typography.titleMedium)
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
                Text(strings.skinNames[skin.id] ?: skin.displayName, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
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
                Text(languageLabel(lang, strings), Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
                RadioButton(selected = settings.language == lang, onClick = { vm.setLanguage(lang) })
            }
        }
        if (settings.language == AppLanguage.ZH_HANS) {
            // 切换后立即生效，无需提示
        }

        Spacer(Modifier.height(20.dp))
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text(strings.aiConfig, Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            OutlinedButton(onClick = { showAIDialog = true }) {
                Text(modelLabel(settings.aiModel, strings))
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
        Spacer(Modifier.height(24.dp))
        Text(
            text = APP_VERSION_TEXT,
            modifier = Modifier.align(Alignment.CenterHorizontally),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(48.dp))
    }

    val lastResult by vm.lastResult.collectAsStateWithLifecycle()
    LaunchedEffect(lastResult) {
        val ok = lastResult?.getOrNull()
        if (ok != null) {
            Toast.makeText(
                context,
                if (ok) strings.done else strings.failed,
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

/** 主题模式显示名，随当前界面语言本地化。 */
private fun themeLabel(mode: ThemeMode, strings: Strings): String = when (mode) {
    ThemeMode.SYSTEM -> strings.themeSystem
    ThemeMode.LIGHT -> strings.themeLight
    ThemeMode.DARK -> strings.themeDark
}

/** AI 模型显示名：自定义走本地化文案，四家中文品牌名走术语表，其余保留品牌原名。 */
private fun modelLabel(model: AIModel, strings: Strings): String = when (model) {
    AIModel.CUSTOM -> strings.modelCustom
    else -> strings.modelNames[model.id] ?: model.displayName
}

/** 语言选项的显示名，随当前界面语言本地化。 */
private fun languageLabel(lang: AppLanguage, strings: Strings): String = when (lang) {
    AppLanguage.SYSTEM -> strings.langSystem
    AppLanguage.ZH_HANS -> strings.langZh
    AppLanguage.ZH_HANT -> strings.langZhHant
    AppLanguage.JA -> strings.langJa
    AppLanguage.KO -> strings.langKo
    AppLanguage.EN -> strings.langEn
    AppLanguage.FR -> strings.langFr
    AppLanguage.DE -> strings.langDe
    AppLanguage.ES -> strings.langEs
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AIConfigDialog(
    currentModel: AIModel,
    baseUrl: String,
    modelName: String,
    apiKey: String,
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
                ModelDropdown(model) { model = it }
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
private fun ModelDropdown(selected: AIModel, onSelect: (AIModel) -> Unit) {
    val strings = LocalStrings.current
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = modelLabel(selected, strings),
            onValueChange = {},
            readOnly = true,
            label = { Text(strings.provider) },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier
                .menuAnchor()
                .fillMaxWidth()
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            AIModel.entries.forEach { m ->
                DropdownMenuItem(
                    text = { Text(modelLabel(m, strings)) },
                    onClick = { onSelect(m); expanded = false }
                )
            }
        }
    }
}