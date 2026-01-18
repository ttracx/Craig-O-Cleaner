package com.craigoclean.android.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.craigoclean.android.data.model.MemoryPressure
import com.craigoclean.android.ui.theme.VibeCaaSColors

/**
 * Memory pressure indicator card
 */
@Composable
fun MemoryPressureIndicator(
    pressure: MemoryPressure,
    availableMemoryMb: Long,
    totalMemoryMb: Long,
    modifier: Modifier = Modifier
) {
    val pressureInfo = getPressureInfo(pressure)
    val animatedColor by animateColorAsState(
        targetValue = pressureInfo.color,
        animationSpec = tween(500),
        label = "pressureColor"
    )

    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = animatedColor.copy(alpha = 0.1f)
        ),
        shape = RoundedCornerShape(16.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Status indicator
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(animatedColor.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = pressureInfo.icon,
                    contentDescription = null,
                    tint = animatedColor,
                    modifier = Modifier.size(24.dp)
                )
            }

            Spacer(modifier = Modifier.width(16.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Memory Pressure",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Spacer(modifier = Modifier.height(4.dp))

                Text(
                    text = pressureInfo.label,
                    style = MaterialTheme.typography.titleMedium,
                    color = animatedColor
                )

                Spacer(modifier = Modifier.height(4.dp))

                Text(
                    text = "$availableMemoryMb MB / $totalMemoryMb MB available",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

/**
 * Compact memory pressure badge
 */
@Composable
fun MemoryPressureBadge(
    pressure: MemoryPressure,
    modifier: Modifier = Modifier
) {
    val pressureInfo = getPressureInfo(pressure)

    Row(
        modifier = modifier
            .background(
                color = pressureInfo.color.copy(alpha = 0.15f),
                shape = RoundedCornerShape(8.dp)
            )
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = pressureInfo.icon,
            contentDescription = null,
            tint = pressureInfo.color,
            modifier = Modifier.size(16.dp)
        )

        Spacer(modifier = Modifier.width(6.dp))

        Text(
            text = pressureInfo.label,
            style = MaterialTheme.typography.labelMedium,
            color = pressureInfo.color
        )
    }
}

/**
 * Data class for pressure display info
 */
private data class PressureInfo(
    val label: String,
    val color: Color,
    val icon: ImageVector
)

/**
 * Get display info for memory pressure level
 */
private fun getPressureInfo(pressure: MemoryPressure): PressureInfo {
    return when (pressure) {
        MemoryPressure.LOW -> PressureInfo(
            label = "Low",
            color = VibeCaaSColors.SuccessGreen,
            icon = Icons.Default.CheckCircle
        )
        MemoryPressure.MODERATE -> PressureInfo(
            label = "Moderate",
            color = VibeCaaSColors.AquaTeal,
            icon = Icons.Default.Info
        )
        MemoryPressure.HIGH -> PressureInfo(
            label = "High",
            color = VibeCaaSColors.SignalAmber,
            icon = Icons.Default.Warning
        )
        MemoryPressure.CRITICAL -> PressureInfo(
            label = "Critical",
            color = VibeCaaSColors.ErrorRed,
            icon = Icons.Default.Error
        )
        MemoryPressure.UNKNOWN -> PressureInfo(
            label = "Unknown",
            color = Color.Gray,
            icon = Icons.Default.Info
        )
    }
}
