package com.craigoclean.android.ui.viewmodel

import android.app.Activity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.craigoclean.android.billing.BillingEvent
import com.craigoclean.android.billing.BillingRepository
import com.craigoclean.android.billing.EntitlementManager
import com.craigoclean.android.data.model.EntitlementStatus
import com.craigoclean.android.data.model.SubscriptionProduct
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI state for the Paywall screen
 */
data class PaywallUiState(
    val products: List<SubscriptionProduct> = emptyList(),
    val selectedProductId: String? = null,
    val isLoading: Boolean = true,
    val isPurchasing: Boolean = false,
    val error: String? = null,
    val isBillingAvailable: Boolean = true
)

/**
 * Events emitted by the Paywall
 */
sealed class PaywallEvent {
    data object PurchaseSuccess : PaywallEvent()
    data class PurchaseError(val message: String) : PaywallEvent()
    data object PurchasesRestored : PaywallEvent()
    data object NoPurchasesFound : PaywallEvent()
    data object TrialStarted : PaywallEvent()
    data object Dismiss : PaywallEvent()
}

/**
 * ViewModel for the Paywall screen
 * Handles subscription purchases and trial activation
 */
@HiltViewModel
class PaywallViewModel @Inject constructor(
    private val billingRepository: BillingRepository,
    private val entitlementManager: EntitlementManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(PaywallUiState())
    val uiState: StateFlow<PaywallUiState> = _uiState.asStateFlow()

    private val _events = MutableSharedFlow<PaywallEvent>()
    val events: SharedFlow<PaywallEvent> = _events.asSharedFlow()

    val entitlementStatus: StateFlow<EntitlementStatus> = entitlementManager.entitlementStatus
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = EntitlementStatus.FREE
        )

    init {
        observeProducts()
        observeBillingEvents()
        loadProducts()
    }

    /**
     * Observe product updates from billing repository
     */
    private fun observeProducts() {
        viewModelScope.launch {
            billingRepository.products.collect { products ->
                _uiState.value = _uiState.value.copy(
                    products = products,
                    isLoading = false,
                    selectedProductId = products.firstOrNull()?.productId
                )
            }
        }
    }

    /**
     * Observe billing events
     */
    private fun observeBillingEvents() {
        viewModelScope.launch {
            billingRepository.billingEvents.collect { event ->
                when (event) {
                    is BillingEvent.PurchaseSuccess -> {
                        _uiState.value = _uiState.value.copy(isPurchasing = false)
                        _events.emit(PaywallEvent.PurchaseSuccess)
                    }
                    is BillingEvent.PurchaseError -> {
                        _uiState.value = _uiState.value.copy(
                            isPurchasing = false,
                            error = event.message
                        )
                        _events.emit(PaywallEvent.PurchaseError(event.message))
                    }
                    is BillingEvent.PurchaseCanceled -> {
                        _uiState.value = _uiState.value.copy(isPurchasing = false)
                    }
                    is BillingEvent.PurchasePending -> {
                        _uiState.value = _uiState.value.copy(isPurchasing = false)
                    }
                    is BillingEvent.PurchasesRestored -> {
                        _uiState.value = _uiState.value.copy(isLoading = false)
                        _events.emit(PaywallEvent.PurchasesRestored)
                    }
                    is BillingEvent.NoPurchasesFound -> {
                        _uiState.value = _uiState.value.copy(isLoading = false)
                        _events.emit(PaywallEvent.NoPurchasesFound)
                    }
                    is BillingEvent.BillingUnavailable -> {
                        _uiState.value = _uiState.value.copy(
                            isLoading = false,
                            isBillingAvailable = false,
                            error = "Billing is currently unavailable"
                        )
                    }
                }
            }
        }
    }

    /**
     * Load subscription products
     */
    private fun loadProducts() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            billingRepository.queryProducts()
        }
    }

    /**
     * Select a subscription product
     */
    fun selectProduct(productId: String) {
        _uiState.value = _uiState.value.copy(selectedProductId = productId)
    }

    /**
     * Purchase the selected subscription
     */
    fun purchaseSelectedProduct(activity: Activity) {
        val productId = _uiState.value.selectedProductId ?: return

        _uiState.value = _uiState.value.copy(isPurchasing = true, error = null)
        billingRepository.launchBillingFlow(activity, productId)
    }

    /**
     * Start the free trial
     */
    fun startTrial() {
        viewModelScope.launch {
            val hasUsedTrial = entitlementManager.hasUsedTrial()
            if (hasUsedTrial) {
                _uiState.value = _uiState.value.copy(
                    error = "You have already used your free trial"
                )
                return@launch
            }

            entitlementManager.startTrial()
            _events.emit(PaywallEvent.TrialStarted)
        }
    }

    /**
     * Restore previous purchases
     */
    fun restorePurchases() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            billingRepository.restorePurchases()
        }
    }

    /**
     * Clear error state
     */
    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    /**
     * Check if trial has been used
     */
    suspend fun hasUsedTrial(): Boolean {
        return entitlementManager.hasUsedTrial()
    }

    /**
     * Get monthly product
     */
    fun getMonthlyProduct(): SubscriptionProduct? {
        return _uiState.value.products.find { it.productId.contains("monthly") }
    }

    /**
     * Get yearly product
     */
    fun getYearlyProduct(): SubscriptionProduct? {
        return _uiState.value.products.find { it.productId.contains("yearly") }
    }
}
