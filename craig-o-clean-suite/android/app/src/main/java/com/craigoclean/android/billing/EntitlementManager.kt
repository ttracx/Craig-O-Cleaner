package com.craigoclean.android.billing

import com.android.billingclient.api.Purchase
import com.craigoclean.android.BuildConfig
import com.craigoclean.android.data.local.PreferencesDataStore
import com.craigoclean.android.data.model.EntitlementStatus
import com.craigoclean.android.data.model.SubscriptionTier
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.time.Instant
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manages user entitlements and feature gating
 * Handles trial periods and subscription status
 */
@Singleton
class EntitlementManager @Inject constructor(
    private val billingRepository: BillingRepository,
    private val preferencesDataStore: PreferencesDataStore,
    private val externalScope: CoroutineScope
) {
    private val _entitlementStatus = MutableStateFlow(EntitlementStatus.FREE)
    val entitlementStatus: StateFlow<EntitlementStatus> = _entitlementStatus.asStateFlow()

    companion object {
        private const val TRIAL_DURATION_DAYS = 7L
    }

    init {
        observeEntitlements()
    }

    /**
     * Observe billing and preferences to update entitlement status
     */
    private fun observeEntitlements() {
        externalScope.launch {
            combine(
                billingRepository.purchases,
                preferencesDataStore.trialStartTime,
                preferencesDataStore.subscriptionProductId,
                preferencesDataStore.subscriptionExpiry
            ) { purchases, trialStart, productId, expiry ->
                calculateEntitlementStatus(purchases, trialStart, productId, expiry)
            }.collect { status ->
                _entitlementStatus.value = status
            }
        }
    }

    /**
     * Calculate current entitlement status from purchases and stored data
     */
    private fun calculateEntitlementStatus(
        purchases: List<Purchase>,
        trialStartTime: Long?,
        storedProductId: String?,
        storedExpiry: Long?
    ): EntitlementStatus {
        // Check active purchases first
        val activePurchase = purchases.find { purchase ->
            purchase.purchaseState == Purchase.PurchaseState.PURCHASED &&
            purchase.products.any { it == BuildConfig.MONTHLY_SKU || it == BuildConfig.YEARLY_SKU }
        }

        if (activePurchase != null) {
            val productId = activePurchase.products.first()
            val tier = when (productId) {
                BuildConfig.MONTHLY_SKU -> SubscriptionTier.MONTHLY
                BuildConfig.YEARLY_SKU -> SubscriptionTier.YEARLY
                else -> SubscriptionTier.FREE
            }

            return EntitlementStatus(
                tier = tier,
                isTrialActive = false,
                trialDaysRemaining = 0,
                expirationDate = null, // Managed by Play Store
                productId = productId,
                purchaseToken = activePurchase.purchaseToken
            )
        }

        // Check stored subscription (for offline support)
        if (storedProductId != null && storedExpiry != null) {
            val now = System.currentTimeMillis()
            if (now < storedExpiry) {
                val tier = when (storedProductId) {
                    BuildConfig.MONTHLY_SKU -> SubscriptionTier.MONTHLY
                    BuildConfig.YEARLY_SKU -> SubscriptionTier.YEARLY
                    else -> SubscriptionTier.FREE
                }

                return EntitlementStatus(
                    tier = tier,
                    isTrialActive = false,
                    trialDaysRemaining = 0,
                    expirationDate = Instant.ofEpochMilli(storedExpiry),
                    productId = storedProductId,
                    purchaseToken = null
                )
            }
        }

        // Check trial status
        if (trialStartTime != null) {
            val trialDaysRemaining = calculateTrialDaysRemaining(trialStartTime)
            if (trialDaysRemaining > 0) {
                return EntitlementStatus(
                    tier = SubscriptionTier.FREE,
                    isTrialActive = true,
                    trialDaysRemaining = trialDaysRemaining,
                    expirationDate = Instant.ofEpochMilli(
                        trialStartTime + TimeUnit.DAYS.toMillis(TRIAL_DURATION_DAYS)
                    ),
                    productId = null,
                    purchaseToken = null
                )
            }
        }

        // Default to free tier
        return EntitlementStatus.FREE
    }

    /**
     * Calculate remaining trial days
     */
    private fun calculateTrialDaysRemaining(trialStartTime: Long): Int {
        val now = System.currentTimeMillis()
        val trialEndTime = trialStartTime + TimeUnit.DAYS.toMillis(TRIAL_DURATION_DAYS)
        val remainingMillis = trialEndTime - now

        if (remainingMillis <= 0) return 0

        return TimeUnit.MILLISECONDS.toDays(remainingMillis).toInt() + 1
    }

    /**
     * Start the free trial period
     */
    suspend fun startTrial() {
        val existingTrialStart = preferencesDataStore.trialStartTime.first()
        if (existingTrialStart == null) {
            preferencesDataStore.setTrialStartTime(System.currentTimeMillis())
        }
    }

    /**
     * Check if user has started a trial before
     */
    suspend fun hasUsedTrial(): Boolean {
        return preferencesDataStore.trialStartTime.first() != null
    }

    /**
     * Check if a specific feature is available
     */
    fun canAccessFeature(feature: ProFeature): Boolean {
        val status = _entitlementStatus.value
        return when (feature) {
            ProFeature.VIEW_METRICS -> true // Always available
            ProFeature.VIEW_APPS -> true // Always available
            ProFeature.QUICK_SETTINGS_TILE -> status.canUseProFeatures
            ProFeature.PERSISTENT_NOTIFICATION -> status.canUseProFeatures
            ProFeature.APP_MANAGEMENT -> status.canUseProFeatures
            ProFeature.BOOT_START -> status.canUseProFeatures
        }
    }

    /**
     * Check if user can use pro features (subscription or trial active)
     */
    fun canUseProFeatures(): Boolean {
        return _entitlementStatus.value.canUseProFeatures
    }

    /**
     * Get current subscription tier
     */
    fun getCurrentTier(): SubscriptionTier {
        return _entitlementStatus.value.tier
    }

    /**
     * Check if trial is currently active
     */
    fun isTrialActive(): Boolean {
        return _entitlementStatus.value.isTrialActive
    }

    /**
     * Refresh entitlement status from billing
     */
    suspend fun refreshEntitlements() {
        billingRepository.queryExistingPurchases()
    }
}

/**
 * Pro features that require subscription or trial
 */
enum class ProFeature {
    VIEW_METRICS,
    VIEW_APPS,
    QUICK_SETTINGS_TILE,
    PERSISTENT_NOTIFICATION,
    APP_MANAGEMENT,
    BOOT_START
}
