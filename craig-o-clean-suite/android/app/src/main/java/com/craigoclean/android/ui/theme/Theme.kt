package com.craigoclean.android.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

/**
 * VibeCaaS Brand Colors
 */
object VibeCaaSColors {
    // Primary - VibePurple
    val VibePurple = Color(0xFF6D4AFF)
    val VibePurpleDark = Color(0xFF5A3DD9)
    val VibePurpleLight = Color(0xFF8A6FFF)

    // Secondary - AquaTeal
    val AquaTeal = Color(0xFF14B8A6)
    val AquaTealDark = Color(0xFF0D9488)
    val AquaTealLight = Color(0xFF2DD4BF)

    // Accent - SignalAmber
    val SignalAmber = Color(0xFFFF8C00)
    val SignalAmberDark = Color(0xFFD97706)
    val SignalAmberLight = Color(0xFFFBBF24)

    // Status Colors
    val ErrorRed = Color(0xFFDC2626)
    val SuccessGreen = Color(0xFF16A34A)
    val WarningYellow = Color(0xFFEAB308)

    // Memory Pressure Colors
    val PressureLow = SuccessGreen
    val PressureModerate = Color(0xFF84CC16)
    val PressureHigh = WarningYellow
    val PressureCritical = ErrorRed
}

/**
 * Light color scheme using VibeCaaS colors
 */
private val LightColorScheme = lightColorScheme(
    primary = VibeCaaSColors.VibePurple,
    onPrimary = Color.White,
    primaryContainer = VibeCaaSColors.VibePurpleLight.copy(alpha = 0.2f),
    onPrimaryContainer = VibeCaaSColors.VibePurpleDark,

    secondary = VibeCaaSColors.AquaTeal,
    onSecondary = Color.White,
    secondaryContainer = VibeCaaSColors.AquaTealLight.copy(alpha = 0.2f),
    onSecondaryContainer = VibeCaaSColors.AquaTealDark,

    tertiary = VibeCaaSColors.SignalAmber,
    onTertiary = Color.White,
    tertiaryContainer = VibeCaaSColors.SignalAmberLight.copy(alpha = 0.2f),
    onTertiaryContainer = VibeCaaSColors.SignalAmberDark,

    error = VibeCaaSColors.ErrorRed,
    onError = Color.White,
    errorContainer = VibeCaaSColors.ErrorRed.copy(alpha = 0.1f),
    onErrorContainer = VibeCaaSColors.ErrorRed,

    background = Color(0xFFFAFAFA),
    onBackground = Color(0xFF1F2937),

    surface = Color.White,
    onSurface = Color(0xFF1F2937),
    surfaceVariant = Color(0xFFF3F4F6),
    onSurfaceVariant = Color(0xFF6B7280),

    outline = Color(0xFFE5E7EB),
    outlineVariant = Color(0xFFF3F4F6)
)

/**
 * Dark color scheme using VibeCaaS colors
 */
private val DarkColorScheme = darkColorScheme(
    primary = VibeCaaSColors.VibePurpleLight,
    onPrimary = Color(0xFF1A1A2E),
    primaryContainer = VibeCaaSColors.VibePurple.copy(alpha = 0.3f),
    onPrimaryContainer = VibeCaaSColors.VibePurpleLight,

    secondary = VibeCaaSColors.AquaTealLight,
    onSecondary = Color(0xFF1A1A2E),
    secondaryContainer = VibeCaaSColors.AquaTeal.copy(alpha = 0.3f),
    onSecondaryContainer = VibeCaaSColors.AquaTealLight,

    tertiary = VibeCaaSColors.SignalAmberLight,
    onTertiary = Color(0xFF1A1A2E),
    tertiaryContainer = VibeCaaSColors.SignalAmber.copy(alpha = 0.3f),
    onTertiaryContainer = VibeCaaSColors.SignalAmberLight,

    error = Color(0xFFEF4444),
    onError = Color(0xFF1A1A2E),
    errorContainer = VibeCaaSColors.ErrorRed.copy(alpha = 0.2f),
    onErrorContainer = Color(0xFFEF4444),

    background = Color(0xFF121212),
    onBackground = Color(0xFFF9FAFB),

    surface = Color(0xFF1F1F1F),
    onSurface = Color(0xFFF9FAFB),
    surfaceVariant = Color(0xFF2D2D2D),
    onSurfaceVariant = Color(0xFF9CA3AF),

    outline = Color(0xFF374151),
    outlineVariant = Color(0xFF2D2D2D)
)

/**
 * Craig-O-Clean Material 3 Theme
 */
@Composable
fun CraigOCleanTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.primary.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = false
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
