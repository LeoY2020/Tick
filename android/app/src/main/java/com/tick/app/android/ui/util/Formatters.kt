package com.tick.app.android.ui.util

import androidx.compose.ui.graphics.Color
import com.tick.app.android.ui.theme.Strings
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.abs

/** 十六进制颜色解析：支持 "#RRGGBB"、"auto"（null）等。空/非法返回 null。 */
object HexColor {
    fun parse(hex: String?): Color? {
        if (hex.isNullOrBlank() || hex == "auto") return null
        val cleaned = hex.removePrefix("#")
        val value = when (cleaned.length) {
            6 -> 0xFF000000L or cleaned.toLongOrNull(16)!!
            8 -> cleaned.toLongOrNull(16)!!
            else -> return null
        }
        return Color(value)
    }
}

/**
 * 目标截止倒计时格式化。
 * - 未设置截止日期 → null；
 * - 精确到小时 → 显示天 + 小时；
 * - 否则 → 显示天（不足一天显示 "今天"）。
 */
object CountdownFormatter {
    fun remaining(endDate: Long, preciseToHour: Boolean, strings: Strings): String? {
        val now = System.currentTimeMillis()
        if (endDate <= 0) return null
        if (endDate <= now) return strings.countdownExpired

        val calNow = Calendar.getInstance()
        val calEnd = Calendar.getInstance().apply { timeInMillis = endDate }

        val diffMillis = endDate - now
        val totalMinutes = diffMillis / 60_000
        val days = totalMinutes / (60 * 24)
        val hours = (totalMinutes % (60 * 24)) / 60

        return if (preciseToHour) {
            strings.countdownDaysHours.replace("{0}", days.toString()).replace("{1}", hours.toString())
        } else {
            val dayDiff = calEnd.get(Calendar.DAY_OF_YEAR) - calNow.get(Calendar.DAY_OF_YEAR)
            when {
                dayDiff <= 0 -> strings.countdownToday
                else -> strings.countdownDays.replace("{0}", dayDiff.toString())
            }
        }
    }

    fun absolute(endDate: Long, preciseToHour: Boolean): String {
        val pattern = if (preciseToHour) "yyyy-MM-dd HH:mm" else "yyyy-MM-dd"
        return SimpleDateFormat(pattern, Locale.getDefault()).format(Date(endDate))
    }

    /** 防止连续跨天导致的负数显示 */
    @Suppress("unused")
    fun safeDays(now: Long, target: Long): Int = abs(((target - now) / 86_400_000)).toInt()
}