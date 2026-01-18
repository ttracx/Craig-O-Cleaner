package com.craigoclean.android.data.model

import java.time.Instant

/**
 * Represents current system statistics
 */
data class SystemStats(
    val cpuUsagePercent: Float,
    val ramUsagePercent: Float,
    val ramUsedBytes: Long,
    val ramTotalBytes: Long,
    val ramAvailableBytes: Long,
    val memoryPressure: MemoryPressure,
    val timestamp: Instant = Instant.now()
) {
    val ramUsedMb: Long get() = ramUsedBytes / (1024 * 1024)
    val ramTotalMb: Long get() = ramTotalBytes / (1024 * 1024)
    val ramAvailableMb: Long get() = ramAvailableBytes / (1024 * 1024)

    companion object {
        val EMPTY = SystemStats(
            cpuUsagePercent = 0f,
            ramUsagePercent = 0f,
            ramUsedBytes = 0L,
            ramTotalBytes = 0L,
            ramAvailableBytes = 0L,
            memoryPressure = MemoryPressure.UNKNOWN
        )
    }
}

/**
 * Memory pressure levels based on available memory thresholds
 */
enum class MemoryPressure {
    LOW,        // > 50% available
    MODERATE,   // 25-50% available
    HIGH,       // 10-25% available
    CRITICAL,   // < 10% available
    UNKNOWN;

    companion object {
        fun fromAvailablePercent(availablePercent: Float): MemoryPressure {
            return when {
                availablePercent > 50f -> LOW
                availablePercent > 25f -> MODERATE
                availablePercent > 10f -> HIGH
                availablePercent >= 0f -> CRITICAL
                else -> UNKNOWN
            }
        }
    }
}
