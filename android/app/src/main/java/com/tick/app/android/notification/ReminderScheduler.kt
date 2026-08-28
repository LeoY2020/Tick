package com.tick.app.android.notification

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.tick.app.android.model.RepeatRule
import com.tick.app.android.model.TaskItem
import com.tick.app.android.model.effectiveWeekdays
import com.tick.app.android.model.repeatRule
import java.util.Calendar

/**
 * 本地通知提醒调度器。
 * 提醒时间 + 重复规则（不重复 / 每天 / 每周 / 每月 / 自定义周几多选），
 * 通知内容含任务名与所属目标名。
 */
object ReminderScheduler {

    const val EXTRA_TASK_ID = "extra_task_id"
    const val EXTRA_GOAL_ID = "extra_goal_id"
    const val EXTRA_TASK_NAME = "extra_task_name"
    const val EXTRA_GOAL_NAME = "extra_goal_name"
    const val EXTRA_REPEAT_RULE = "extra_repeat_rule"
    const val EXTRA_CUSTOM_WEEKDAYS = "extra_custom_weekdays"
    const val EXTRA_REMINDER_DATE = "extra_reminder_date"

    /** 为任务注册提醒：先取消旧请求，再按重复规则设置闹钟 */
    fun schedule(context: Context, task: TaskItem, goalId: String, goalName: String) {
        cancel(context, task.id)

        val reminderDate = task.reminderDate ?: return
        val rule = task.repeatRule ?: RepeatRule.NEVER
        val weekdays = task.effectiveWeekdays()

        val fireTimes = nextFireTimes(rule, reminderDate, weekdays, System.currentTimeMillis())
        for (fireTime in fireTimes) {
            setAlarm(
                context = context,
                taskId = task.id,
                goalId = goalId,
                taskName = task.name,
                goalName = goalName,
                reminderDate = reminderDate,
                rule = rule,
                weekdays = weekdays,
                fireTime = fireTime
            )
        }
    }

    /** 用于重复规则触发后的下一次调度（由 ReminderReceiver 调用） */
    fun rescheduleNext(
        context: Context,
        taskId: String,
        goalId: String,
        taskName: String,
        goalName: String,
        reminderDate: Long,
        rule: RepeatRule,
        weekdays: List<Int>
    ) {
        val fireTimes = nextFireTimes(rule, reminderDate, weekdays, System.currentTimeMillis())
        for (fireTime in fireTimes) {
            setAlarm(context, taskId, goalId, taskName, goalName, reminderDate, rule, weekdays, fireTime)
        }
    }

    /** 取消任务全部提醒 */
    fun cancel(context: Context, taskId: String) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val suffixes = listOf("") + (1..7).map { "-w$it" }
        for (suffix in suffixes) {
            alarm.cancel(alarmPendingIntent(context, taskId, suffix, null))
        }
    }

    /**
     * 计算接下来需要触发的时刻（NEVER 返回 1 个；CUSTOM 周几返回各星期各 1 个）。
     * 纯逻辑，便于测试。
     */
    fun nextFireTimes(
        rule: RepeatRule,
        reminderDate: Long,
        weekdays: List<Int>,
        nowMillis: Long
    ): List<Long> {
        val base = Calendar.getInstance().apply { timeInMillis = reminderDate }
        val hour = base.get(Calendar.HOUR_OF_DAY)
        val minute = base.get(Calendar.MINUTE)

        return when (rule) {
            RepeatRule.NEVER -> listOf(reminderDate)
            RepeatRule.DAILY -> listOf(nextAtTime(hour, minute, nowMillis))
            RepeatRule.WEEKLY -> listOf(nextAtWeekday(base.get(Calendar.DAY_OF_WEEK), hour, minute, nowMillis))
            RepeatRule.MONTHLY -> listOf(nextAtDayOfMonth(base.get(Calendar.DAY_OF_MONTH), hour, minute, nowMillis))
            RepeatRule.CUSTOM -> {
                val valid = weekdays.filter { it in 1..7 }.distinct().sorted()
                if (valid.isEmpty()) listOf(nextAtTime(hour, minute, nowMillis))
                else valid.map { nextAtWeekday(it, hour, minute, nowMillis) }
            }
        }
    }

    // MARK: - 时刻计算（1=周日…7=周六，对应 Calendar.DAY_OF_WEEK）

    private fun nextAtTime(hour: Int, minute: Int, now: Long): Long {
        val cal = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
        }
        if (cal.timeInMillis <= now) cal.add(Calendar.DAY_OF_MONTH, 1)
        return cal.timeInMillis
    }

    private fun nextAtWeekday(weekday: Int, hour: Int, minute: Int, now: Long): Long {
        val cal = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.DAY_OF_WEEK, weekday)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
        }
        if (cal.timeInMillis <= now) cal.add(Calendar.DAY_OF_MONTH, 7)
        return cal.timeInMillis
    }

    private fun nextAtDayOfMonth(day: Int, hour: Int, minute: Int, now: Long): Long {
        val cal = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.DAY_OF_MONTH, day)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
        }
        if (cal.timeInMillis <= now) cal.add(Calendar.MONTH, 1)
        return cal.timeInMillis
    }

    // MARK: - 闹钟

    private fun setAlarm(
        context: Context,
        taskId: String,
        goalId: String,
        taskName: String,
        goalName: String,
        reminderDate: Long,
        rule: RepeatRule,
        weekdays: List<Int>,
        fireTime: Long
    ) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        if (fireTime <= System.currentTimeMillis()) return

        // 自定义周几按星期区分配 requestCode，其余共用一个
        val suffix = if (rule == RepeatRule.CUSTOM) {
            "-w" + Calendar.getInstance().apply { timeInMillis = fireTime }.get(Calendar.DAY_OF_WEEK)
        } else {
            ""
        }

        val extras = BundleBuilder(taskId, goalId, taskName, goalName, reminderDate, rule, weekdays)
        val pi = alarmPendingIntent(context, taskId, suffix, extras)
        try {
            alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireTime, pi)
        } catch (e: SecurityException) {
            alarm.set(AlarmManager.RTC_WAKEUP, fireTime, pi)
        }
    }

    private fun alarmPendingIntent(
        context: Context,
        taskId: String,
        suffix: String,
        builder: BundleBuilder?
    ): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java)
        builder?.applyTo(intent)
        val requestCode = (taskId + suffix).hashCode()
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** 用于把提醒参数写入 Intent extras 的小工具 */
    class BundleBuilder(
        private val taskId: String,
        private val goalId: String,
        private val taskName: String,
        private val goalName: String,
        private val reminderDate: Long,
        private val rule: RepeatRule,
        private val weekdays: List<Int>
    ) {
        fun applyTo(intent: Intent) {
            intent.putExtra(EXTRA_TASK_ID, taskId)
            intent.putExtra(EXTRA_GOAL_ID, goalId)
            intent.putExtra(EXTRA_TASK_NAME, taskName)
            intent.putExtra(EXTRA_GOAL_NAME, goalName)
            intent.putExtra(EXTRA_REMINDER_DATE, reminderDate)
            intent.putExtra(EXTRA_REPEAT_RULE, rule.raw)
            intent.putExtra(EXTRA_CUSTOM_WEEKDAYS, weekdays.joinToString(","))
        }
    }
}