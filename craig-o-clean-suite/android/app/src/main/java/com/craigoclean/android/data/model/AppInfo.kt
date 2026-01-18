package com.craigoclean.android.data.model

import android.graphics.drawable.Drawable

/**
 * Represents information about an installed/running app
 */
data class AppInfo(
    val packageName: String,
    val appName: String,
    val icon: Drawable?,
    val memoryUsageMb: Long,
    val lastUsedTimestamp: Long,
    val isSystemApp: Boolean,
    val versionName: String?,
    val versionCode: Long
) {
    companion object {
        val EMPTY = AppInfo(
            packageName = "",
            appName = "",
            icon = null,
            memoryUsageMb = 0L,
            lastUsedTimestamp = 0L,
            isSystemApp = false,
            versionName = null,
            versionCode = 0L
        )
    }
}

/**
 * Sort options for app list
 */
enum class AppSortOption {
    NAME,
    MEMORY,
    RECENT
}
