package com.craigoclean.android.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.craigoclean.android.ui.theme.VibeCaaSColors

/**
 * Circular gauge component for displaying metrics
 */
@Composable
fun MetricGauge(
    value: Float,
    label: String,
    modifier: Modifier = Modifier,
    maxValue: Float = 100f,
    size: Dp = 120.dp,
    strokeWidth: Dp = 12.dp,
    gaugeColor: Color = VibeCaaSColors.VibePurple,
    trackColor: Color = MaterialTheme.colorScheme.surfaceVariant,
    showPercentage: Boolean = true
) {
    val progress = (value / maxValue).coerceIn(0f, 1f)
    val animatedProgress by animateFloatAsState(
        targetValue = progress,
        animationSpec = tween(durationMillis = 500),
        label = "progress"
    )

    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier.size(size)
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .aspectRatio(1f)
                .padding(strokeWidth / 2)
        ) {
            val sweepAngle = 270f
            val startAngle = 135f

            // Track
            drawArc(
                color = trackColor,
                startAngle = startAngle,
                sweepAngle = sweepAngle,
                useCenter = false,
                style = Stroke(
                    width = strokeWidth.toPx(),
                    cap = StrokeCap.Round
                ),
                topLeft = Offset.Zero,
                size = Size(this.size.width, this.size.height)
            )

            // Progress
            drawArc(
                color = gaugeColor,
                startAngle = startAngle,
                sweepAngle = sweepAngle * animatedProgress,
                useCenter = false,
                style = Stroke(
                    width = strokeWidth.toPx(),
                    cap = StrokeCap.Round
                ),
                topLeft = Offset.Zero,
                size = Size(this.size.width, this.size.height)
            )
        }

        Column(
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            if (showPercentage) {
                Text(
                    text = "${value.toInt()}%",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
            Text(
                text = label,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
        }
    }
}

/**
 * Get gauge color based on percentage value
 */
@Composable
fun getGaugeColorForValue(value: Float): Color {
    return when {
        value < 50f -> VibeCaaSColors.SuccessGreen
        value < 75f -> VibeCaaSColors.SignalAmber
        value < 90f -> VibeCaaSColors.SignalAmberDark
        else -> VibeCaaSColors.ErrorRed
    }
}
