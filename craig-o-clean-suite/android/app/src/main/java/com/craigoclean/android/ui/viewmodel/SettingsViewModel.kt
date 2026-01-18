package com.craigoclean.android.ui.viewmodel

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.craigoclean.android.BuildConfig
import com.craigoclean.android.billing.EntitlementManager
import com.craigoclean.android.billing.ProFeature
import com.craigoclean.android.data.local.PreferencesDataStore
import com.craigoclean.android.data.model.EntitlementStatus
import com.craigoclean.android.data.model.RefreshInterval
import com.craigoclean.android.data.model.UserPreferences
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI state for Settings screen
 */
data class SettingsUiState(
    val showRefreshIntervalDialog: Boolean = false,
    val showProFeatureDialog: Boolean = false,
    val blockedFeature: String = ""
)

/**
 * ViewModel for the Settings screen
 * Manages app preferences and settings
 */
@HiltViewModel
class SettingsViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val preferencesDataStore: PreferencesDataStore,
    private val entitlementManager: EntitlementManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    val userPreferences: StateFlow<UserPreferences> = preferencesDataStore.userPreferences
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = UserPreferences.DEFAULT
        )

    val entitlementStatus: StateFlow<EntitlementStatus> = entitlementManager.entitlementStatus
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = EntitlementStatus.FREE
        )

    /**
     * Get app version string
     */
    fun getVersionString(): String {
        return "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"
    }

    /**
     * Show refresh interval selection dialog
     */
    fun showRefreshIntervalDialog() {
        _uiState.value = _uiState.value.copy(showRefreshIntervalDialog = true)
    }

    /**
     * Hide refresh interval dialog
     */
    fun hideRefreshIntervalDialog() {
        _uiState.value = _uiState.value.copy(showRefreshIntervalDialog = false)
    }

    /**
     * Update refresh interval
     */
    fun setRefreshInterval(interval: RefreshInterval) {
        viewModelScope.launch {
            preferencesDataStore.setRefreshInterval(interval.seconds)
            hideRefreshIntervalDialog()
        }
    }

    /**
     * Toggle notifications enabled
     * Requires pro subscription for persistent monitoring
     */
    fun toggleNotifications(enabled: Boolean, onRequiresPro: () -> Unit) {
        if (enabled && !entitlementManager.canAccessFeature(ProFeature.PERSISTENT_NOTIFICATION)) {
            _uiState.value = _uiState.value.copy(
                showProFeatureDialog = true,
                blockedFeature = "Persistent Notification"
            )
            onRequiresPro()
            return
        }

        viewModelScope.launch {
            preferencesDataStore.setNotificationsEnabled(enabled)
        }
    }

    /**
     * Toggle start on boot
     * Requires pro subscription
     */
    fun toggleStartOnBoot(enabled: Boolean, onRequiresPro: () -> Unit) {
        if (enabled && !entitlementManager.canAccessFeature(ProFeature.BOOT_START)) {
            _uiState.value = _uiState.value.copy(
                showProFeatureDialog = true,
                blockedFeature = "Start on Boot"
            )
            onRequiresPro()
            return
        }

        viewModelScope.launch {
            preferencesDataStore.setStartOnBoot(enabled)
        }
    }

    /**
     * Toggle dark mode
     */
    fun toggleDarkMode(enabled: Boolean) {
        viewModelScope.launch {
            preferencesDataStore.setDarkModeEnabled(enabled)
        }
    }

    /**
     * Toggle show system apps
     */
    fun toggleShowSystemApps(show: Boolean) {
        viewModelScope.launch {
            preferencesDataStore.setShowSystemApps(show)
        }
    }

    /**
     * Hide pro feature dialog
     */
    fun hideProFeatureDialog() {
        _uiState.value = _uiState.value.copy(showProFeatureDialog = false)
    }

    /**
     * Open privacy policy URL
     */
    fun openPrivacyPolicy() {
        openUrl("https://craigoclean.com/privacy")
    }

    /**
     * Open terms of service URL
     */
    fun openTermsOfService() {
        openUrl("https://craigoclean.com/terms")
    }

    /**
     * Open support email
     */
    fun contactSupport() {
        val intent = Intent(Intent.ACTION_SENDTO).apply {
            data = Uri.parse("mailto:support@craigoclean.com")
            putExtra(Intent.EXTRA_SUBJECT, "Craig-O-Clean Support - Android")
            putExtra(Intent.EXTRA_TEXT, buildSupportEmailBody())
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    /**
     * Build support email body with device info
     */
    private fun buildSupportEmailBody(): String {
        return """
            |
            |
            |---
            |App Version: ${getVersionString()}
            |Android Version: ${android.os.Build.VERSION.RELEASE}
            |Device: ${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}
            |Subscription: ${entitlementStatus.value.tier}
        """.trimMargin()
    }

    /**
     * Open URL in browser
     */
    private fun openUrl(url: String) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    /**
     * Get current refresh interval label
     */
    fun getRefreshIntervalLabel(seconds: Int): String {
        return RefreshInterval.entries.find { it.seconds == seconds }?.label
            ?: "$seconds seconds"
    }

    /**
     * Check if user has pro access
     */
    fun isPro(): Boolean {
        return entitlementManager.canUseProFeatures()
    }
}
