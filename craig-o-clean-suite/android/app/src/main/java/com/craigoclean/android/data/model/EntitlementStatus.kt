package com.craigoclean.android.data.model

import java.time.Instant

/**
 * Represents the user's subscription/entitlement status
 */
data class EntitlementStatus(
    val tier: SubscriptionTier,
    val isTrialActive: Boolean = false,
    val trialDaysRemaining: Int = 0,
    val expirationDate: Instant? = null,
    val productId: String? = null,
    val purchaseToken: String? = null
) {
    val isPro: Boolean
        get() = tier == SubscriptionTier.MONTHLY ||
                tier == SubscriptionTier.YEARLY ||
                isTrialActive

    val canUseProFeatures: Boolean
        get() = isPro

    companion object {
        val FREE = EntitlementStatus(tier = SubscriptionTier.FREE)

        fun trial(daysRemaining: Int): EntitlementStatus {
            return EntitlementStatus(
                tier = SubscriptionTier.FREE,
                isTrialActive = true,
                trialDaysRemaining = daysRemaining
            )
        }
    }
}

/**
 * Subscription tier levels
 */
enum class SubscriptionTier {
    FREE,
    MONTHLY,
    YEARLY
}

/**
 * Subscription product information
 */
data class SubscriptionProduct(
    val productId: String,
    val name: String,
    val description: String,
    val price: String,
    val priceMicros: Long,
    val currencyCode: String,
    val billingPeriod: BillingPeriod,
    val hasFreeTrial: Boolean = true,
    val freeTrialDays: Int = 7
)

/**
 * Billing period for subscriptions
 */
enum class BillingPeriod {
    MONTHLY,
    YEARLY
}
