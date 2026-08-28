package com.tick.app.android.ui.util

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Code
import androidx.compose.material.icons.outlined.FitnessCenter
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material.icons.outlined.Restaurant
import androidx.compose.material.icons.outlined.School
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.outlined.Work
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * 图标名 → Material 图标映射。名称为空或未知返回 null（不显示图标）。
 */
fun iconForName(name: String?): ImageVector? {
    return when (name) {
        "star" -> Icons.Outlined.Star
        "flag" -> Icons.Outlined.Flag
        "book" -> Icons.Outlined.MenuBook
        "work" -> Icons.Outlined.Work
        "home" -> Icons.Outlined.Home
        "fitness_center" -> Icons.Outlined.FitnessCenter
        "school" -> Icons.Outlined.School
        "code" -> Icons.Outlined.Code
        "lightbulb" -> Icons.Outlined.Lightbulb
        "restaurant" -> Icons.Outlined.Restaurant
        null, "" -> null
        else -> null
    }
}