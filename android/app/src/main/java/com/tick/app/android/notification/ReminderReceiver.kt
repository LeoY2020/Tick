package com.tick.app.android.notification

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.tick.app.android.model.RepeatRule
import com.tick.app.android.ui.MainActivity

/**
 * 提醒广播接收器：触发通知展示，并为重复规则安排下一次提醒。
 */
class ReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getStringExtra(ReminderScheduler.EXTRA_TASK_ID) ?: return
        val goalId = intent.getStringExtra(ReminderScheduler.EXTRA_GOAL_ID) ?: ""
        val taskName = intent.getStringExtra(ReminderScheduler.EXTRA_TASK_NAME) ?: ""
        val goalName = intent.getStringExtra(ReminderScheduler.EXTRA_GOAL_NAME) ?: ""
        val reminderDate = intent.getLongExtra(ReminderScheduler.EXTRA_REMINDER_DATE, 0L)
        val ruleRaw = intent.getStringExtra(ReminderScheduler.EXTRA_REPEAT_RULE)
        val weekdaysRaw = intent.getStringExtra(ReminderScheduler.EXTRA_CUSTOM_WEEKDAYS)

        val rule = RepeatRule.fromRaw(ruleRaw) ?: RepeatRule.NEVER
        val weekdays = (weekdaysRaw ?: "")
            .split(",")
            .mapNotNull { it.trim().toIntOrNull() }
            .filter { it in 1..7 }

        showNotification(context, taskId, goalId, taskName, goalName)

        // 重复规则 → 安排下一次触发
        if (rule != RepeatRule.NEVER) {
            ReminderScheduler.rescheduleNext(
                context, taskId, goalId, taskName, goalName, reminderDate, rule, weekdays
            )
        }
    }

    private fun showNotification(
        context: Context,
        taskId: String,
        goalId: String,
        taskName: String,
        goalName: String
    ) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "任务提醒",
                NotificationManager.IMPORTANCE_HIGH
            )
            manager.createNotificationChannel(channel)
        }

        // Android 13+ 通知权限被拒时静默跳过
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val launch = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("goalId", goalId)
        }
        val contentPi = PendingIntent.getActivity(
            context,
            taskId.hashCode(),
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_today)
            .setContentTitle(taskName)
            .setContentText("目标：$goalName")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentPi)
            .build()

        manager.notify(taskId.hashCode(), notification)
    }

    companion object {
        private const val CHANNEL_ID = "tick_reminders"
    }
}