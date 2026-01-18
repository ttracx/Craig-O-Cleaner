package com.craigoclean.android.data.repository

import android.app.ActivityManager
import android.content.Context
import android.os.Debug
import com.craigoclean.android.data.model.MemoryPressure
import com.craigoclean.android.data.model.SystemStats
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import java.io.RandomAccessFile
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository for accessing system statistics
 */
@Singleton
class SystemStatsRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val activityManager: ActivityManager =
        context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

    private var previousCpuStats: CpuStats? = null

    /**
     * Get current system stats as a one-shot read
     */
    suspend fun getSystemStats(): SystemStats {
        return try {
            val memoryInfo = getMemoryInfo()
            val cpuUsage = getCpuUsage()

            val totalMemory = memoryInfo.totalMem
            val availableMemory = memoryInfo.availMem
            val usedMemory = totalMemory - availableMemory
            val usagePercent = if (totalMemory > 0) {
                (usedMemory.toFloat() / totalMemory.toFloat()) * 100f
            } else 0f

            val availablePercent = if (totalMemory > 0) {
                (availableMemory.toFloat() / totalMemory.toFloat()) * 100f
            } else 0f

            SystemStats(
                cpuUsagePercent = cpuUsage,
                ramUsagePercent = usagePercent,
                ramUsedBytes = usedMemory,
                ramTotalBytes = totalMemory,
                ramAvailableBytes = availableMemory,
                memoryPressure = MemoryPressure.fromAvailablePercent(availablePercent),
                timestamp = Instant.now()
            )
        } catch (e: Exception) {
            SystemStats.EMPTY
        }
    }

    /**
     * Observe system stats with periodic updates
     */
    fun observeSystemStats(intervalMs: Long = 5000L): Flow<SystemStats> = flow {
        while (true) {
            emit(getSystemStats())
            delay(intervalMs)
        }
    }.flowOn(Dispatchers.IO)

    /**
     * Get memory info from ActivityManager
     */
    private fun getMemoryInfo(): ActivityManager.MemoryInfo {
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        return memoryInfo
    }

    /**
     * Get CPU usage by reading /proc/stat
     * Returns approximate CPU usage percentage
     */
    private fun getCpuUsage(): Float {
        return try {
            val currentStats = readCpuStats()
            val previousStats = previousCpuStats

            if (previousStats == null) {
                previousCpuStats = currentStats
                return 0f
            }

            val totalDiff = currentStats.total - previousStats.total
            val idleDiff = currentStats.idle - previousStats.idle

            previousCpuStats = currentStats

            if (totalDiff > 0) {
                ((totalDiff - idleDiff).toFloat() / totalDiff.toFloat()) * 100f
            } else {
                0f
            }
        } catch (e: Exception) {
            // Fallback: estimate from memory pressure
            estimateCpuFromMemory()
        }
    }

    /**
     * Read CPU stats from /proc/stat
     */
    private fun readCpuStats(): CpuStats {
        RandomAccessFile("/proc/stat", "r").use { reader ->
            val line = reader.readLine()
            val parts = line.split("\\s+".toRegex())

            if (parts.size >= 5 && parts[0] == "cpu") {
                val user = parts[1].toLongOrNull() ?: 0L
                val nice = parts[2].toLongOrNull() ?: 0L
                val system = parts[3].toLongOrNull() ?: 0L
                val idle = parts[4].toLongOrNull() ?: 0L
                val iowait = parts.getOrNull(5)?.toLongOrNull() ?: 0L
                val irq = parts.getOrNull(6)?.toLongOrNull() ?: 0L
                val softirq = parts.getOrNull(7)?.toLongOrNull() ?: 0L
                val steal = parts.getOrNull(8)?.toLongOrNull() ?: 0L

                val totalIdle = idle + iowait
                val total = user + nice + system + idle + iowait + irq + softirq + steal

                return CpuStats(total, totalIdle)
            }
        }
        return CpuStats(0, 0)
    }

    /**
     * Estimate CPU usage from memory pressure as fallback
     */
    private fun estimateCpuFromMemory(): Float {
        val memoryInfo = getMemoryInfo()
        val usageRatio = 1f - (memoryInfo.availMem.toFloat() / memoryInfo.totalMem.toFloat())
        // Rough estimation: high memory usage often correlates with CPU usage
        return (usageRatio * 50f).coerceIn(0f, 100f)
    }

    /**
     * Check if device is under memory pressure
     */
    fun isLowMemory(): Boolean {
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        return memoryInfo.lowMemory
    }

    /**
     * Get low memory threshold
     */
    fun getLowMemoryThreshold(): Long {
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        return memoryInfo.threshold
    }

    private data class CpuStats(
        val total: Long,
        val idle: Long
    )
}
