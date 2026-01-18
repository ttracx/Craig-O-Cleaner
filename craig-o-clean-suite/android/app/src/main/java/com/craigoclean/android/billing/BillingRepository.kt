package com.craigoclean.android.billing

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.craigoclean.android.BuildConfig
import com.craigoclean.android.data.local.PreferencesDataStore
import com.craigoclean.android.data.model.BillingPeriod
import com.craigoclean.android.data.model.SubscriptionProduct
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume

/**
 * Billing events emitted by the repository
 */
sealed class BillingEvent {
    data class PurchaseSuccess(val productId: String) : BillingEvent()
    data class PurchaseError(val message: String) : BillingEvent()
    data object PurchaseCanceled : BillingEvent()
    data object PurchasePending : BillingEvent()
    data object PurchasesRestored : BillingEvent()
    data object NoPurchasesFound : BillingEvent()
    data object BillingUnavailable : BillingEvent()
}

/**
 * Repository for handling Google Play Billing operations
 * Implements Google Play Billing Library v6+
 */
@Singleton
class BillingRepository @Inject constructor(
    @ApplicationContext private val context: Context,
    private val billingClient: BillingClient,
    private val preferencesDataStore: PreferencesDataStore,
    private val externalScope: CoroutineScope
) : PurchasesUpdatedListener {

    private val _products = MutableStateFlow<List<SubscriptionProduct>>(emptyList())
    val products: StateFlow<List<SubscriptionProduct>> = _products.asStateFlow()

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    private val _purchases = MutableStateFlow<List<Purchase>>(emptyList())
    val purchases: StateFlow<List<Purchase>> = _purchases.asStateFlow()

    private val _billingEvents = MutableSharedFlow<BillingEvent>()
    val billingEvents: SharedFlow<BillingEvent> = _billingEvents.asSharedFlow()

    private var productDetailsList: List<ProductDetails> = emptyList()

    companion object {
        private val PRODUCT_IDS = listOf(
            BuildConfig.MONTHLY_SKU,
            BuildConfig.YEARLY_SKU
        )
    }

    init {
        connectToBillingService()
    }

    /**
     * Connect to the Google Play Billing service
     */
    fun connectToBillingService() {
        if (billingClient.isReady) {
            _isConnected.value = true
            return
        }

        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(billingResult: BillingResult) {
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    _isConnected.value = true
                    externalScope.launch {
                        queryProducts()
                        queryExistingPurchases()
                    }
                } else {
                    _isConnected.value = false
                    externalScope.launch {
                        _billingEvents.emit(BillingEvent.BillingUnavailable)
                    }
                }
            }

            override fun onBillingServiceDisconnected() {
                _isConnected.value = false
                // Retry connection with exponential backoff in production
            }
        })
    }

    /**
     * Query available subscription products
     */
    suspend fun queryProducts() {
        if (!billingClient.isReady) {
            return
        }

        val productList = PRODUCT_IDS.map { productId ->
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(productId)
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        }

        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(productList)
            .build()

        val result = suspendCancellableCoroutine { continuation ->
            billingClient.queryProductDetailsAsync(params) { billingResult, productDetailsList ->
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    continuation.resume(productDetailsList)
                } else {
                    continuation.resume(emptyList())
                }
            }
        }

        productDetailsList = result
        _products.value = result.mapNotNull { details ->
            convertToSubscriptionProduct(details)
        }
    }

    /**
     * Convert ProductDetails to our SubscriptionProduct model
     */
    private fun convertToSubscriptionProduct(details: ProductDetails): SubscriptionProduct? {
        val subscriptionOffer = details.subscriptionOfferDetails?.firstOrNull() ?: return null
        val pricingPhase = subscriptionOffer.pricingPhases.pricingPhaseList.firstOrNull() ?: return null

        val billingPeriod = when {
            pricingPhase.billingPeriod.contains("M") -> BillingPeriod.MONTHLY
            pricingPhase.billingPeriod.contains("Y") -> BillingPeriod.YEARLY
            else -> BillingPeriod.MONTHLY
        }

        // Check for free trial
        val hasFreeTrial = subscriptionOffer.pricingPhases.pricingPhaseList.any {
            it.priceAmountMicros == 0L
        }
        val freeTrialDays = if (hasFreeTrial) {
            subscriptionOffer.pricingPhases.pricingPhaseList
                .firstOrNull { it.priceAmountMicros == 0L }
                ?.let { parseTrialDays(it.billingPeriod) } ?: 7
        } else 7

        return SubscriptionProduct(
            productId = details.productId,
            name = details.name,
            description = details.description,
            price = pricingPhase.formattedPrice,
            priceMicros = pricingPhase.priceAmountMicros,
            currencyCode = pricingPhase.priceCurrencyCode,
            billingPeriod = billingPeriod,
            hasFreeTrial = hasFreeTrial,
            freeTrialDays = freeTrialDays
        )
    }

    /**
     * Parse trial period string to days
     */
    private fun parseTrialDays(billingPeriod: String): Int {
        return when {
            billingPeriod.contains("D") -> {
                billingPeriod.replace("P", "").replace("D", "").toIntOrNull() ?: 7
            }
            billingPeriod.contains("W") -> {
                (billingPeriod.replace("P", "").replace("W", "").toIntOrNull() ?: 1) * 7
            }
            else -> 7
        }
    }

    /**
     * Launch the billing flow for a subscription
     */
    fun launchBillingFlow(activity: Activity, productId: String): BillingResult {
        val productDetails = productDetailsList.find { it.productId == productId }
            ?: return BillingResult.newBuilder()
                .setResponseCode(BillingClient.BillingResponseCode.ITEM_UNAVAILABLE)
                .setDebugMessage("Product not found")
                .build()

        val offerToken = productDetails.subscriptionOfferDetails?.firstOrNull()?.offerToken
            ?: return BillingResult.newBuilder()
                .setResponseCode(BillingClient.BillingResponseCode.ITEM_UNAVAILABLE)
                .setDebugMessage("No offer available")
                .build()

        val productDetailsParams = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(productDetails)
            .setOfferToken(offerToken)
            .build()

        val billingFlowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productDetailsParams))
            .build()

        return billingClient.launchBillingFlow(activity, billingFlowParams)
    }

    /**
     * Query existing purchases for restoration
     */
    suspend fun queryExistingPurchases() {
        if (!billingClient.isReady) {
            return
        }

        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.SUBS)
            .build()

        val result = suspendCancellableCoroutine { continuation ->
            billingClient.queryPurchasesAsync(params) { billingResult, purchases ->
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    continuation.resume(purchases)
                } else {
                    continuation.resume(emptyList())
                }
            }
        }

        _purchases.value = result
        processPurchases(result)
    }

    /**
     * Restore purchases
     */
    suspend fun restorePurchases() {
        queryExistingPurchases()

        val activePurchases = _purchases.value.filter {
            it.purchaseState == Purchase.PurchaseState.PURCHASED
        }

        if (activePurchases.isNotEmpty()) {
            _billingEvents.emit(BillingEvent.PurchasesRestored)
        } else {
            _billingEvents.emit(BillingEvent.NoPurchasesFound)
        }
    }

    /**
     * Called when purchases are updated
     */
    override fun onPurchasesUpdated(billingResult: BillingResult, purchases: List<Purchase>?) {
        externalScope.launch {
            when (billingResult.responseCode) {
                BillingClient.BillingResponseCode.OK -> {
                    purchases?.let { processPurchases(it) }
                }
                BillingClient.BillingResponseCode.USER_CANCELED -> {
                    _billingEvents.emit(BillingEvent.PurchaseCanceled)
                }
                BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> {
                    queryExistingPurchases()
                }
                else -> {
                    _billingEvents.emit(
                        BillingEvent.PurchaseError(
                            billingResult.debugMessage ?: "Purchase failed"
                        )
                    )
                }
            }
        }
    }

    /**
     * Process and acknowledge purchases
     */
    private suspend fun processPurchases(purchases: List<Purchase>) {
        for (purchase in purchases) {
            when (purchase.purchaseState) {
                Purchase.PurchaseState.PURCHASED -> {
                    if (!purchase.isAcknowledged) {
                        acknowledgePurchase(purchase)
                    }

                    // Save subscription info
                    val productId = purchase.products.firstOrNull() ?: continue
                    val expiryTime = System.currentTimeMillis() + getSubscriptionDuration(productId)

                    preferencesDataStore.saveSubscription(
                        productId = productId,
                        token = purchase.purchaseToken,
                        expiryTimestamp = expiryTime
                    )

                    _purchases.value = _purchases.value + purchase
                    _billingEvents.emit(BillingEvent.PurchaseSuccess(productId))
                }
                Purchase.PurchaseState.PENDING -> {
                    _billingEvents.emit(BillingEvent.PurchasePending)
                }
                else -> { /* Unspecified state */ }
            }
        }
    }

    /**
     * Acknowledge a purchase
     */
    private suspend fun acknowledgePurchase(purchase: Purchase) {
        val acknowledgeParams = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()

        suspendCancellableCoroutine { continuation ->
            billingClient.acknowledgePurchase(acknowledgeParams) { billingResult ->
                continuation.resume(billingResult)
            }
        }
    }

    /**
     * Get subscription duration in milliseconds
     */
    private fun getSubscriptionDuration(productId: String): Long {
        return when (productId) {
            BuildConfig.MONTHLY_SKU -> 30L * 24 * 60 * 60 * 1000 // 30 days
            BuildConfig.YEARLY_SKU -> 365L * 24 * 60 * 60 * 1000 // 365 days
            else -> 30L * 24 * 60 * 60 * 1000
        }
    }

    /**
     * End billing client connection
     */
    fun endConnection() {
        if (billingClient.isReady) {
            billingClient.endConnection()
        }
    }
}
