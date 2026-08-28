package com.tick.app.android.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance

/**
 * 8 套 Android 厂商皮肤（单代码库 + enum Skin + 运行时设置页切换）。
 * brand 为各厂商标志色；深/浅色 ColorScheme 由 [Skin.colorScheme] 参数化派生。
 */
enum class Skin(
    val id: String,
    val displayName: String,
    /** 品牌色（ARGB，0xFFRRGGBB） */
    val brand: Long,
    /** HyperOS 采用橙色调 + 半透明玻璃质感 */
    val translucentGlass: Boolean = false
) {
    COLOROS("coloros", "ColorOS", 0xFF067A4A),
    ONEUI("oneui", "One UI", 0xFF3B82F6),
    ORIGINOS("originos", "OriginOS", 0xFF2856D6),
    REALMEUI("realmeui", "realme UI", 0xFFFFD200),
    FLYME("flyme", "Flyme", 0xFF0084FF),
    MIUI("miui", "MIUI", 0xFFFF6900),
    HYPEROS("hyperos", "HyperOS", 0xFFFF6900, translucentGlass = true),
    MAGICOS("magicos", "MagicOS", 0xFF2E6BE6);

    companion object {
        fun fromId(id: String?): Skin = Skin.entries.firstOrNull { it.id == id } ?: COLOROS

        fun defaultId(): String = COLOROS.id
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