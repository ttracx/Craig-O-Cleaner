package com.craigoclean.android.data.model

/**
 * User preferences for the app
 */
data class UserPreferences(
    val refreshIntervalSeconds: Int = DEFAULT_REFRESH_INTERVAL,
    val notificationsEnabled: Boolean = true,
    val startOnBoot: Boolean = false,
    val darkModeEnabled: Boolean = false,
    val showSystemApps: Boolean = false
) {
    companion object {
        const val DEFAULT_REFRESH_INTERVAL = 30
        const val MIN_REFRESH_INTERVAL = 10
        const val MAX_REFRESH_INTERVAL = 300

        val DEFAULT = UserPreferences()
    }
}

/**
 * Refresh interval options
 */
enum class RefreshInterval(val seconds: Int, val label: String) {
    FAST(10, "10 seconds"),
    NORMAL(30, "30 seconds"),
    SLOW(60, "1 minute"),
    VERY_SLOW(300, "5 minutes")
}
