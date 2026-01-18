package com.craigoclean.android.ui.navigation

import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.craigoclean.android.ui.screens.DashboardScreen
import com.craigoclean.android.ui.screens.PaywallScreen
import com.craigoclean.android.ui.screens.SettingsScreen
import com.craigoclean.android.ui.screens.TaskManagerScreen

/**
 * Main navigation host for the app
 */
@Composable
fun AppNavigation(
    navController: NavHostController,
    paddingValues: PaddingValues,
    onNavigateToPaywall: () -> Unit,
    modifier: Modifier = Modifier
) {
    NavHost(
        navController = navController,
        startDestination = Screen.Dashboard.route,
        modifier = modifier.padding(paddingValues),
        enterTransition = {
            fadeIn(animationSpec = tween(300)) + slideIntoContainer(
                towards = AnimatedContentTransitionScope.SlideDirection.Start,
                animationSpec = tween(300)
            )
        },
        exitTransition = {
            fadeOut(animationSpec = tween(300)) + slideOutOfContainer(
                towards = AnimatedContentTransitionScope.SlideDirection.Start,
                animationSpec = tween(300)
            )
        },
        popEnterTransition = {
            fadeIn(animationSpec = tween(300)) + slideIntoContainer(
                towards = AnimatedContentTransitionScope.SlideDirection.End,
                animationSpec = tween(300)
            )
        },
        popExitTransition = {
            fadeOut(animationSpec = tween(300)) + slideOutOfContainer(
                towards = AnimatedContentTransitionScope.SlideDirection.End,
                animationSpec = tween(300)
            )
        }
    ) {
        composable(route = Screen.Dashboard.route) {
            DashboardScreen(
                onNavigateToPaywall = onNavigateToPaywall
            )
        }

        composable(route = Screen.TaskManager.route) {
            TaskManagerScreen(
                onNavigateToPaywall = onNavigateToPaywall
            )
        }

        composable(route = Screen.Settings.route) {
            SettingsScreen(
                onNavigateToPaywall = onNavigateToPaywall
            )
        }

        composable(route = Screen.Paywall.route) {
            PaywallScreen(
                onDismiss = {
                    navController.popBackStack()
                }
            )
        }
    }
}
