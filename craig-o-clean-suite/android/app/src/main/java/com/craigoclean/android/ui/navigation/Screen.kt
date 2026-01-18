package com.craigoclean.android.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.ListAlt
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Dashboard
import androidx.compose.material.icons.outlined.ListAlt
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Star
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * Sealed class representing navigation destinations
 */
sealed class Screen(
    val route: String,
    val title: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector
) {
    /**
     * Dashboard screen showing system metrics overview
     */
    data object Dashboard : Screen(
        route = "dashboard",
        title = "Dashboard",
        selectedIcon = Icons.Filled.Dashboard,
        unselectedIcon = Icons.Outlined.Dashboard
    )

    /**
     * Task Manager screen showing running apps
     */
    data object TaskManager : Screen(
        route = "task_manager",
        title = "Apps",
        selectedIcon = Icons.Filled.ListAlt,
        unselectedIcon = Icons.Outlined.ListAlt
    )

    /**
     * Settings screen for app configuration
     */
    data object Settings : Screen(
        route = "settings",
        title = "Settings",
        selectedIcon = Icons.Filled.Settings,
        unselectedIcon = Icons.Outlined.Settings
    )

    /**
     * Paywall screen for subscription management
     */
    data object Paywall : Screen(
        route = "paywall",
        title = "Upgrade",
        selectedIcon = Icons.Filled.Star,
        unselectedIcon = Icons.Outlined.Star
    )

    companion object {
        /**
         * List of screens shown in bottom navigation
         */
        val bottomNavItems = listOf(Dashboard, TaskManager, Settings)

        /**
         * Get screen from route
         */
        fun fromRoute(route: String?): Screen {
            return when (route) {
                Dashboard.route -> Dashboard
                TaskManager.route -> TaskManager
                Settings.route -> Settings
                Paywall.route -> Paywall
                else -> Dashboard
            }
        }
    }
}
