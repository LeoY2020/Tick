package com.tick.app.android.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance

/**
 * 7 套纯色主题（单代码库 + enum Skin + 运行时设置页切换）。
 * brand 为各主题色；深/浅色 ColorScheme 由 [Skin.colorScheme] 参数化派生。
 */
enum class Skin(
    val id: String,
    val displayName: String,
    /** 主题色（ARGB，0xFFRRGGBB） */
    val brand: Long
) {
    RED("red", "红色", 0xFFE53935),
    ORANGE("orange", "活力橙", 0xFFFF6900),
    LEMON("lemon", "柠檬黄", 0xFFFFD200),
    EMERALD("emerald", "翡翠绿", 0xFF067A4A),
    AZURE("azure", "蔚蓝", 0xFF3B82F6),
    LAKE("lake", "湖蓝", 0xFF2E6BE6),
    LILAC("lilac", "淡紫", 0xFF6750A4);

    companion object {
        fun fromId(id: String?): Skin = Skin.entries.firstOrNull { it.id == id } ?: EMERALD

        fun defaultId(): String = EMERALD.id
    }
}

internal fun Long.toColor(): Color = Color(this)

/** 品牌色派生：secondary = 品牌色压暗（浅色）或提亮（深色） */
internal fun Skin.brandSecondary(dark: Boolean): Color =
    if (dark) brand.toColor().lighten(0.30f) else brand.toColor().darken(0.22f)

/** 品牌色派生：tertiary = 品牌色向紫/青偏移，形成对比 */
internal fun Skin.brandTertiary(dark: Boolean): Color =
    if (dark) brand.toColor().lighten(0.45f) else brand.toColor().darken(0.38f)

internal fun Color.lighten(amount: Float): Color = lerp(this, Color.White, amount)
internal fun Color.darken(amount: Float): Color = lerp(this, Color.Black, amount)

/** 根据亮度决定其上文字取黑色还是白色 */
internal fun Color.contrastOn(): Color =
    if (luminance() > 0.5f) Color(0xFF000000) else Color(0xFFFFFFFF)