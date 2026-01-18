package com.craigoclean.android.data.local

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.craigoclean.android.data.model.UserPreferences
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "craig_o_clean_prefs")

/**
 * DataStore for persisting user preferences
 */
@Singleton
class PreferencesDataStore @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private object Keys {
        val REFRESH_INTERVAL = intPreferencesKey("refresh_interval")
        val NOTIFICATIONS_ENABLED = booleanPreferencesKey("notifications_enabled")
        val START_ON_BOOT = booleanPreferencesKey("start_on_boot")
        val DARK_MODE_ENABLED = booleanPreferencesKey("dark_mode_enabled")
        val SHOW_SYSTEM_APPS = booleanPreferencesKey("show_system_apps")
        val TRIAL_START_TIME = longPreferencesKey("trial_start_time")
        val SUBSCRIPTION_PRODUCT_ID = stringPreferencesKey("subscription_product_id")
        val SUBSCRIPTION_TOKEN = stringPreferencesKey("subscription_token")
        val SUBSCRIPTION_EXPIRY = longPreferencesKey("subscription_expiry")
    }

    /**
     * Observe user preferences
     */
    val userPreferences: Flow<UserPreferences> = context.dataStore.data.map { prefs ->
        UserPreferences(
            refreshIntervalSeconds = prefs[Keys.REFRESH_INTERVAL]
                ?: UserPreferences.DEFAULT_REFRESH_INTERVAL,
            notificationsEnabled = prefs[Keys.NOTIFICATIONS_ENABLED] ?: true,
            startOnBoot = prefs[Keys.START_ON_BOOT] ?: false,
            darkModeEnabled = prefs[Keys.DARK_MODE_ENABLED] ?: false,
            showSystemApps = prefs[Keys.SHOW_SYSTEM_APPS] ?: false
        )
    }

    /**
     * Update refresh interval
     */
    suspend fun setRefreshInterval(seconds: Int) {
        context.dataStore.edit { prefs ->
            prefs[Keys.REFRESH_INTERVAL] = seconds.coerceIn(
                UserPreferences.MIN_REFRESH_INTERVAL,
                UserPreferences.MAX_REFRESH_INTERVAL
            )
        }
    }

    /**
     * Update notifications enabled
     */
    suspend fun setNotificationsEnabled(enabled: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[Keys.NOTIFICATIONS_ENABLED] = enabled
        }
    }

    /**
     * Update start on boot
     */
    suspend fun setStartOnBoot(enabled: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[Keys.START_ON_BOOT] = enabled
        }
    }

    /**
     * Update dark mode
     */
    suspend fun setDarkModeEnabled(enabled: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[Keys.DARK_MODE_ENABLED] = enabled
        }
    }

    /**
     * Update show system apps
     */
    suspend fun setShowSystemApps(show: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[Keys.SHOW_SYSTEM_APPS] = show
        }
    }

    // Trial and subscription persistence

    /**
     * Get trial start time
     */
    val trialStartTime: Flow<Long?> = context.dataStore.data.map { prefs ->
        prefs[Keys.TRIAL_START_TIME]
    }

    /**
     * Set trial start time
     */
    suspend fun setTrialStartTime(timestamp: Long) {
        context.dataStore.edit { prefs ->
            prefs[Keys.TRIAL_START_TIME] = timestamp
        }
    }

    /**
     * Get subscription info
     */
    val subscriptionProductId: Flow<String?> = context.dataStore.data.map { prefs ->
        prefs[Keys.SUBSCRIPTION_PRODUCT_ID]
    }

    val subscriptionToken: Flow<String?> = context.dataStore.data.map { prefs ->
        prefs[Keys.SUBSCRIPTION_TOKEN]
    }

    val subscriptionExpiry: Flow<Long?> = context.dataStore.data.map { prefs ->
        prefs[Keys.SUBSCRIPTION_EXPIRY]
    }

    /**
     * Save subscription info
     */
    suspend fun saveSubscription(productId: String, token: String, expiryTimestamp: Long) {
        context.dataStore.edit { prefs ->
            prefs[Keys.SUBSCRIPTION_PRODUCT_ID] = productId
            prefs[Keys.SUBSCRIPTION_TOKEN] = token
            prefs[Keys.SUBSCRIPTION_EXPIRY] = expiryTimestamp
        }
    }

    /**
     * Clear subscription info
     */
    suspend fun clearSubscription() {
        context.dataStore.edit { prefs ->
            prefs.remove(Keys.SUBSCRIPTION_PRODUCT_ID)
            prefs.remove(Keys.SUBSCRIPTION_TOKEN)
            prefs.remove(Keys.SUBSCRIPTION_EXPIRY)
        }
    }

    /**
     * Clear all preferences
     */
    suspend fun clearAll() {
        context.dataStore.edit { prefs ->
            prefs.clear()
        }
    }
}
