package com.craigoclean.android.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.craigoclean.android.billing.EntitlementManager
import com.craigoclean.android.data.model.AppInfo
import com.craigoclean.android.data.model.EntitlementStatus
import com.craigoclean.android.data.model.MemoryPressure
import com.craigoclean.android.data.model.SystemStats
import com.craigoclean.android.data.model.UserPreferences
import com.craigoclean.android.data.local.PreferencesDataStore
import com.craigoclean.android.data.repository.AppRepository
import com.craigoclean.android.data.repository.SystemStatsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI state for the Dashboard screen
 */
data class DashboardUiState(
    val systemStats: SystemStats = SystemStats.EMPTY,
    val topMemoryApps: List<AppInfo> = emptyList(),
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val error: String? = null
)

/**
 * ViewModel for the Dashboard screen
 * Provides system metrics and top memory-consuming apps
 */
@HiltViewModel
class DashboardViewModel @Inject constructor(
    private val systemStatsRepository: SystemStatsRepository,
    private val appRepository: AppRepository,
    private val preferencesDataStore: PreferencesDataStore,
    private val entitlementManager: EntitlementManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(DashboardUiState())
    val uiState: StateFlow<DashboardUiState> = _uiState.asStateFlow()

    val entitlementStatus: StateFlow<EntitlementStatus> = entitlementManager.entitlementStatus
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = EntitlementStatus.FREE
        )

    val userPreferences: StateFlow<UserPreferences> = preferencesDataStore.userPreferences
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = UserPreferences.DEFAULT
        )

    private var refreshJob: Job? = null

    init {
        loadInitialData()
        startAutoRefresh()
    }

    /**
     * Load initial dashboard data
     */
    private fun loadInitialData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                val stats = systemStatsRepository.getSystemStats()
                val topApps = appRepository.getTopMemoryApps(5)

                _uiState.value = _uiState.value.copy(
                    systemStats = stats,
                    topMemoryApps = topApps,
                    isLoading = false,
                    error = null
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Failed to load system stats"
                )
            }
        }
    }

    /**
     * Start automatic refresh based on user preferences
     */
    private fun startAutoRefresh() {
        refreshJob?.cancel()
        refreshJob = viewModelScope.launch {
            preferencesDataStore.userPreferences.collect { prefs ->
                val intervalMs = prefs.refreshIntervalSeconds * 1000L
                while (true) {
                    delay(intervalMs)
                    refreshData(showLoading = false)
                }
            }
        }
    }

    /**
     * Manually refresh dashboard data
     */
    fun refreshData(showLoading: Boolean = true) {
        viewModelScope.launch {
            if (showLoading) {
                _uiState.value = _uiState.value.copy(isRefreshing = true)
            }

            try {
                val stats = systemStatsRepository.getSystemStats()
                val topApps = appRepository.getTopMemoryApps(5)

                _uiState.value = _uiState.value.copy(
                    systemStats = stats,
                    topMemoryApps = topApps,
                    isRefreshing = false,
                    error = null
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isRefreshing = false,
                    error = "Failed to refresh data"
                )
            }
        }
    }

    /**
     * Clear any error state
     */
    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    /**
     * Get memory pressure color based on current status
     */
    fun getMemoryPressureColor(pressure: MemoryPressure): MemoryPressureColor {
        return when (pressure) {
            MemoryPressure.LOW -> MemoryPressureColor.LOW
            MemoryPressure.MODERATE -> MemoryPressureColor.MODERATE
            MemoryPressure.HIGH -> MemoryPressureColor.HIGH
            MemoryPressure.CRITICAL -> MemoryPressureColor.CRITICAL
            MemoryPressure.UNKNOWN -> MemoryPressureColor.UNKNOWN
        }
    }

    /**
     * Check if user can access pro features
     */
    fun canAccessProFeatures(): Boolean {
        return entitlementManager.canUseProFeatures()
    }

    override fun onCleared() {
        super.onCleared()
        refreshJob?.cancel()
    }
}

/**
 * Memory pressure color indicators
 */
enum class MemoryPressureColor {
    LOW,
    MODERATE,
    HIGH,
    CRITICAL,
    UNKNOWN
}
