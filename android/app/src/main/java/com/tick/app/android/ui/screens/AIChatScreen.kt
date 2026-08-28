package com.tick.app.android.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.AttachFile
import androidx.compose.material.icons.outlined.Send
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.tick.app.android.data.AIChatMessage
import com.tick.app.android.ui.theme.LocalStrings
import com.tick.app.android.ui.viewmodel.TickViewModel

@Composable
fun AIChatScreen(vm: TickViewModel, en: Boolean) {
    val strings = LocalStrings.current
    val sessions by vm.chatSessions.collectAsStateWithLifecycle()
    val generating by vm.isGenerating.collectAsStateWithLifecycle()
    val aiError by vm.aiError.collectAsStateWithLifecycle()

    var input by remember { mutableStateOf("") }
    var attachmentName by remember { mutableStateOf<String?>(null) }
    var attachmentUri by remember { mutableStateOf<android.net.Uri?>(null) }

    val openDoc = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            attachmentUri = uri
            attachmentName = uri.lastPathSegment?.substringAfterLast('/')
        }
    }

    val activeSession = sessions.firstOrNull()

    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                if (en) "AI Assistant" else "AI 助手",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f)
            )
            TextButton(onClick = { attachmentName = null; attachmentUri = null; vm.newChatSession() }) {
                Icon(Icons.Outlined.Add, contentDescription = null)
                Text(if (en) "New chat" else "新对话")
            }
        }
        HorizontalDivider()

        if (activeSession == null) {
            Box(Modifier.weight(1f).fillMaxWidth().padding(24.dp), contentAlignment = Alignment.TopCenter) {
                Text(
                    strings.aiChatHint,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            val messages = vm.messagesOf(activeSession)
            LazyColumn(
                Modifier.weight(1f).fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp)
            ) {
                items(messages, key = { it.id }) { msg ->
                    MessageBubble(msg, en)
                }
                if (generating) {
                    item {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            CircularProgressIndicator(Modifier.width(16.dp).height(16.dp))
                            Spacer(Modifier.width(8.dp))
                            Text(strings.generating, style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
            }
        }

        if (aiError != null) {
            Text(
                aiError ?: strings.aiError,
                Modifier.padding(horizontal = 16.dp),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error
            )
        }

        HorizontalDivider()
        Row(
            Modifier
                .fillMaxWidth()
                .padding(8.dp),
            verticalAlignment = Alignment.Bottom
        ) {
            IconButton(onClick = { openDoc.launch("*/*") }) {
                Icon(Icons.Outlined.AttachFile, contentDescription = strings.attach)
            }
            OutlinedTextField(
                value = input,
                onValueChange = { input = it },
                placeholder = { Text(if (en) "Type a message…" else "输入消息…") },
                maxLines = 4,
                modifier = Modifier.weight(1f)
            )
            Spacer(Modifier.width(8.dp))
            IconButton(
                enabled = generating.not() && activeSession != null && (input.isNotBlank() || attachmentUri != null),
                onClick = {
                    activeSession?.let { session ->
                        vm.sendMessage(session.id, input, attachmentUri)
                        input = ""
                        attachmentName = null
                        attachmentUri = null
                    }
                }
            ) {
                Icon(Icons.Outlined.Send, contentDescription = strings.send)
            }
        }
        attachmentName?.let {
            Text(
                "${strings.attach}: $it",
                Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
private fun MessageBubble(msg: AIChatMessage, en: Boolean) {
    val isUser = msg.role == "user"
    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start) {
        Surface(
            shape = RoundedCornerShape(14.dp),
            color = if (isUser) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
            contentColor = if (isUser) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface
        ) {
            Text(
                msg.text,
                Modifier.padding(10.dp),
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}