package com.craigoclean.android.data.repository

import android.app.ActivityManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import com.craigoclean.android.data.model.AppInfo
import com.craigoclean.android.data.model.AppSortOption
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository for accessing app information and usage stats
 */
@Singleton
class AppRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val packageManager: PackageManager = context.packageManager
    private val activityManager: ActivityManager =
        context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val usageStatsManager: UsageStatsManager? =
        context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager

    /**
     * Get list of apps with memory usage information
     */
    suspend fun getAppsWithMemoryUsage(
        includeSystemApps: Boolean = false,
        sortOption: AppSortOption = AppSortOption.MEMORY
    ): List<AppInfo> = withContext(Dispatchers.IO) {
        try {
            val usageStatsMap = getUsageStats()
            val runningProcesses = getRunningProcesses()

            val apps = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
                .filter { appInfo ->
                    includeSystemApps || (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) == 0
                }
                .mapNotNull { appInfo ->
                    createAppInfo(appInfo, usageStatsMap, runningProcesses)
                }

            sortApps(apps, sortOption)
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * Get top memory-consuming apps
     */
    suspend fun getTopMemoryApps(count: Int = 5): List<AppInfo> = withContext(Dispatchers.IO) {
        getAppsWithMemoryUsage(
            includeSystemApps = true,
            sortOption = AppSortOption.MEMORY
        ).take(count)
    }

    /**
     * Observe apps with periodic updates
     */
    fun observeApps(
        intervalMs: Long = 10000L,
        includeSystemApps: Boolean = false,
        sortOption: AppSortOption = AppSortOption.MEMORY
    ): Flow<List<AppInfo>> = flow {
        while (true) {
            emit(getAppsWithMemoryUsage(includeSystemApps, sortOption))
            kotlinx.coroutines.delay(intervalMs)
        }
    }.flowOn(Dispatchers.IO)

    /**
     * Search apps by name or package
     */
    suspend fun searchApps(
        query: String,
        includeSystemApps: Boolean = false
    ): List<AppInfo> = withContext(Dispatchers.IO) {
        if (query.isBlank()) {
            return@withContext getAppsWithMemoryUsage(includeSystemApps)
        }

        getAppsWithMemoryUsage(includeSystemApps).filter { app ->
            app.appName.contains(query, ignoreCase = true) ||
                    app.packageName.contains(query, ignoreCase = true)
        }
    }

    /**
     * Check if usage stats permission is granted
     */
    fun hasUsageStatsPermission(): Boolean {
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE)
                as? UsageStatsManager ?: return false

        val endTime = System.currentTimeMillis()
        val startTime = endTime - TimeUnit.DAYS.toMillis(1)

        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startTime,
            endTime
        )

        return stats.isNotEmpty()
    }

    /**
     * Get usage stats for last 24 hours
     */
    private fun getUsageStats(): Map<String, UsageStats> {
        if (usageStatsManager == null) return emptyMap()

        val endTime = System.currentTimeMillis()
        val startTime = endTime - TimeUnit.DAYS.toMillis(1)

        return try {
            usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                startTime,
                endTime
            ).associateBy { it.packageName }
        } catch (e: SecurityException) {
            emptyMap()
        }
    }

    /**
     * Get running processes info
     */
    private fun getRunningProcesses(): Map<String, ActivityManager.RunningAppProcessInfo> {
        return try {
            activityManager.runningAppProcesses
                ?.associateBy { it.processName.split(":").first() }
                ?: emptyMap()
        } catch (e: Exception) {
            emptyMap()
        }
    }

    /**
     * Create AppInfo from ApplicationInfo
     */
    private fun createAppInfo(
        appInfo: ApplicationInfo,
        usageStatsMap: Map<String, UsageStats>,
        runningProcesses: Map<String, ActivityManager.RunningAppProcessInfo>
    ): AppInfo? {
        return try {
            val packageName = appInfo.packageName
            val appName = packageManager.getApplicationLabel(appInfo).toString()
            val icon = try {
                packageManager.getApplicationIcon(appInfo)
            } catch (e: Exception) {
                null
            }

            val packageInfo = try {
                packageManager.getPackageInfo(packageName, 0)
            } catch (e: Exception) {
                null
            }

            val versionName = packageInfo?.versionName
            val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo?.longVersionCode ?: 0L
            } else {
                @Suppress("DEPRECATION")
                packageInfo?.versionCode?.toLong() ?: 0L
            }

            val usageStats = usageStatsMap[packageName]
            val lastUsed = usageStats?.lastTimeUsed ?: 0L

            // Estimate memory from process info
            val memoryMb = estimateMemoryUsage(packageName, runningProcesses)

            val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            AppInfo(
                packageName = packageName,
                appName = appName,
                icon = icon,
                memoryUsageMb = memoryMb,
                lastUsedTimestamp = lastUsed,
                isSystemApp = isSystemApp,
                versionName = versionName,
                versionCode = versionCode
            )
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Estimate memory usage for an app
     */
    private fun estimateMemoryUsage(
        packageName: String,
        runningProcesses: Map<String, ActivityManager.RunningAppProcessInfo>
    ): Long {
        val processInfo = runningProcesses[packageName] ?: return 0L

        return try {
            val pids = intArrayOf(processInfo.pid)
            val memoryInfos = activityManager.getProcessMemoryInfo(pids)
            memoryInfos.firstOrNull()?.totalPss?.toLong()?.div(1024) ?: 0L
        } catch (e: Exception) {
            // Estimate based on importance
            when (processInfo.importance) {
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND -> 150L
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE -> 100L
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE -> 50L
                else -> 25L
            }
        }
    }

    /**
     * Sort apps based on sort option
     */
    private fun sortApps(apps: List<AppInfo>, sortOption: AppSortOption): List<AppInfo> {
        return when (sortOption) {
            AppSortOption.NAME -> apps.sortedBy { it.appName.lowercase() }
            AppSortOption.MEMORY -> apps.sortedByDescending { it.memoryUsageMb }
            AppSortOption.RECENT -> apps.sortedByDescending { it.lastUsedTimestamp }
        }
    }
}
