package com.tick.app.android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tick.app.android.model.ThemeMode

private fun baseLightSurface(skin: Skin): androidx.compose.ui.graphics.Color {
    return if (skin.id == Skin.HYPEROS.id) {
        skin.brand.toColor().lighten(0.82f)
    } else {
        androidx.compose.ui.graphics.Color(0xFFFFFFFF)
    }
}

private fun baseDarkSurface(skin: Skin): androidx.compose.ui.graphics.Color {
    return if (skin.id == Skin.HYPEROS.id) {
        skin.brand.toColor().lighten(0.12f)
    } else {
        androidx.compose.ui.graphics.Color(0xFF181818)
    }
}

/** 皮肤浅色 ColorScheme */
fun Skin.lightColorScheme(): ColorScheme {
    val p = brand.toColor()
    val onP = p.contrastOn()
    val bg = if (translucentGlass) p.lighten(0.86f) else Color(0xFFFDFDFD)
    val surface = baseLightSurface(this)
    return lightColorScheme(
        primary = p,
        onPrimary = onP,
        primaryContainer = p.lighten(0.72f),
        onPrimaryContainer = p.darken(0.42f),
        secondary = brandSecondary(false),
        onSecondary = Color(0xFFFFFFFF),
        secondaryContainer = brandSecondary(false).lighten(0.72f),
        onSecondaryContainer = brandSecondary(false).darken(0.42f),
        tertiary = brandTertiary(false),
        background = bg,
        onBackground = Color(0xFF1C1B1F),
        surface = surface,
        surfaceVariant = bg,
        onSurface = Color(0xFF1C1B1F),
        onSurfaceVariant = Color(0xFF49454F),
        outline = Color(0xFF79747E),
        error = Color(0xFFB3261E),
        onError = Color(0xFFFFFFFF)
    )
}

/** 皮肤深色 ColorScheme */
fun Skin.darkColorScheme(): ColorScheme {
    val p = brand.toColor().lighten(0.35f)
    val onP = p.contrastOn()
    val bg = if (translucentGlass) brand.toColor().darken(0.55f) else Color(0xFF141414)
    val surface = baseDarkSurface(this)
    return darkColorScheme(
        primary = p,
        onPrimary = onP,
        primaryContainer = brand.toColor().darken(0.30f),
        onPrimaryContainer = p.lighten(0.55f),
        secondary = brandSecondary(true),
        onSecondary = Color(0xFF000000),
        secondaryContainer = brandSecondary(true).darken(0.30f),
        onSecondaryContainer = brandSecondary(true).lighten(0.65f),
        tertiary = brandTertiary(true),
        background = bg,
        onBackground = Color(0xFFE6E1E5),
        surface = surface,
        surfaceVariant = bg,
        onSurface = Color(0xFFE6E1E5),
        onSurfaceVariant = Color(0xFFCAC4D0),
        outline = Color(0xFF938F99),
        error = Color(0xFFF2B8B5),
        onError = Color(0xFF601410)
    )
}

private fun defaultShapes(skin: Skin): Shapes {
    val r = when (skin) {
        Skin.COLOROS -> 14f
        Skin.ONEUI -> 18f
        Skin.ORIGINOS -> 16f
        Skin.REALMEUI -> 10f
        Skin.FLYME -> 8f
        Skin.MIUI -> 12f
        Skin.HYPEROS -> 16f
        Skin.MAGICOS -> 14f
    }
    return Shapes(
        extraSmall = RoundedCornerShape((r * 0.5f).dp),
        small = RoundedCornerShape((r * 0.75f).dp),
        medium = RoundedCornerShape(r.dp),
        large = RoundedCornerShape((r * 1.25f).dp),
        extraLarge = RoundedCornerShape((r * 1.5f).dp)
    )
}

private fun tickTypography(): Typography = Typography(
    titleLarge = TextStyle(fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.SemiBold),
    titleMedium = TextStyle(fontSize = 16.sp, lineHeight = 24.sp, fontWeight = FontWeight.SemiBold),
    titleSmall = TextStyle(fontSize = 14.sp, lineHeight = 20.sp, fontWeight = FontWeight.Medium),
    bodyLarge = TextStyle(fontSize = 16.sp, lineHeight = 24.sp),
    bodyMedium = TextStyle(fontSize = 14.sp, lineHeight = 20.sp),
    labelLarge = TextStyle(fontSize = 14.sp, lineHeight = 20.sp, fontWeight = FontWeight.Medium)
)

/**
 * 应用主题：以选中的 [Skin] 参数化 Material 3，配色深/浅/跟随系统由 [ThemeMode] 决定。
 */
@Composable
fun TickTheme(
    skin: Skin,
    themeMode: ThemeMode,
    content: @Composable () -> Unit
) {
    val dark = when (themeMode) {
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
        ThemeMode.DARK -> true
        ThemeMode.LIGHT -> false
    }
    val colorScheme = if (dark) skin.darkColorScheme() else skin.lightColorScheme()
    MaterialTheme(
        colorScheme = colorScheme,
        shapes = defaultShapes(skin),
        typography = tickTypography(),
        content = content
    )
}