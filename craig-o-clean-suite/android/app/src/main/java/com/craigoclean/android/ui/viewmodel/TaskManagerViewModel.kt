package com.craigoclean.android.ui.viewmodel

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.craigoclean.android.billing.EntitlementManager
import com.craigoclean.android.data.local.PreferencesDataStore
import com.craigoclean.android.data.model.AppInfo
import com.craigoclean.android.data.model.AppSortOption
import com.craigoclean.android.data.model.EntitlementStatus
import com.craigoclean.android.data.repository.AppRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI state for the Task Manager screen
 */
data class TaskManagerUiState(
    val apps: List<AppInfo> = emptyList(),
    val filteredApps: List<AppInfo> = emptyList(),
    val searchQuery: String = "",
    val sortOption: AppSortOption = AppSortOption.MEMORY,
    val showSystemApps: Boolean = false,
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val error: String? = null,
    val hasUsageStatsPermission: Boolean = false
)

/**
 * ViewModel for the Task Manager screen
 * Provides app list with search, sort, and filter capabilities
 */
@HiltViewModel
class TaskManagerViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val appRepository: AppRepository,
    private val preferencesDataStore: PreferencesDataStore,
    private val entitlementManager: EntitlementManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(TaskManagerUiState())
    val uiState: StateFlow<TaskManagerUiState> = _uiState.asStateFlow()

    private val _searchQuery = MutableStateFlow("")

    val entitlementStatus: StateFlow<EntitlementStatus> = entitlementManager.entitlementStatus
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = EntitlementStatus.FREE
        )

    init {
        checkPermissions()
        loadPreferences()
        loadApps()
        observeSearchQuery()
    }

    /**
     * Check if usage stats permission is granted
     */
    private fun checkPermissions() {
        val hasPermission = appRepository.hasUsageStatsPermission()
        _uiState.value = _uiState.value.copy(hasUsageStatsPermission = hasPermission)
    }

    /**
     * Load user preferences
     */
    private fun loadPreferences() {
        viewModelScope.launch {
            preferencesDataStore.userPreferences.collect { prefs ->
                val currentState = _uiState.value
                if (currentState.showSystemApps != prefs.showSystemApps) {
                    _uiState.value = currentState.copy(showSystemApps = prefs.showSystemApps)
                    loadApps()
                }
            }
        }
    }

    /**
     * Load apps from repository
     */
    private fun loadApps() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                val state = _uiState.value
                val apps = appRepository.getAppsWithMemoryUsage(
                    includeSystemApps = state.showSystemApps,
                    sortOption = state.sortOption
                )

                _uiState.value = _uiState.value.copy(
                    apps = apps,
                    filteredApps = filterApps(apps, state.searchQuery),
                    isLoading = false,
                    error = null
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Failed to load apps"
                )
            }
        }
    }

    /**
     * Observe search query changes with debounce
     */
    @OptIn(FlowPreview::class)
    private fun observeSearchQuery() {
        viewModelScope.launch {
            _searchQuery
                .debounce(300)
                .collect { query ->
                    val currentState = _uiState.value
                    _uiState.value = currentState.copy(
                        searchQuery = query,
                        filteredApps = filterApps(currentState.apps, query)
                    )
                }
        }
    }

    /**
     * Filter apps based on search query
     */
    private fun filterApps(apps: List<AppInfo>, query: String): List<AppInfo> {
        if (query.isBlank()) return apps

        return apps.filter { app ->
            app.appName.contains(query, ignoreCase = true) ||
            app.packageName.contains(query, ignoreCase = true)
        }
    }

    /**
     * Update search query
     */
    fun onSearchQueryChange(query: String) {
        _searchQuery.value = query
        _uiState.value = _uiState.value.copy(searchQuery = query)
    }

    /**
     * Clear search query
     */
    fun clearSearch() {
        onSearchQueryChange("")
    }

    /**
     * Update sort option
     */
    fun onSortOptionChange(sortOption: AppSortOption) {
        _uiState.value = _uiState.value.copy(sortOption = sortOption)
        loadApps()
    }

    /**
     * Toggle showing system apps
     */
    fun toggleShowSystemApps() {
        viewModelScope.launch {
            val newValue = !_uiState.value.showSystemApps
            preferencesDataStore.setShowSystemApps(newValue)
        }
    }

    /**
     * Refresh app list
     */
    fun refreshApps() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isRefreshing = true)

            try {
                checkPermissions()
                val state = _uiState.value
                val apps = appRepository.getAppsWithMemoryUsage(
                    includeSystemApps = state.showSystemApps,
                    sortOption = state.sortOption
                )

                _uiState.value = _uiState.value.copy(
                    apps = apps,
                    filteredApps = filterApps(apps, state.searchQuery),
                    isRefreshing = false,
                    error = null
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isRefreshing = false,
                    error = "Failed to refresh apps"
                )
            }
        }
    }

    /**
     * Open app info settings for a specific app
     */
    fun openAppInfo(packageName: String) {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    /**
     * Launch an app
     */
    fun launchApp(packageName: String) {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(packageName)
        launchIntent?.let { intent ->
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)
        }
    }

    /**
     * Open usage access settings
     */
    fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    /**
     * Clear error state
     */
    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    /**
     * Check if user can access pro features
     */
    fun canAccessProFeatures(): Boolean {
        return entitlementManager.canUseProFeatures()
    }
}
