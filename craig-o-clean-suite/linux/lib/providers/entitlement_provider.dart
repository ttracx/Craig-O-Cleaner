import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:craig_o_clean/models/entitlement.dart';
import 'package:craig_o_clean/services/billing_service.dart';
import 'package:craig_o_clean/services/secure_storage_service.dart';

/// Provider for secure storage service
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Provider for billing service
final billingServiceProvider = Provider<BillingService>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return BillingService(secureStorage);
});

/// Provider for current entitlement state
final entitlementProvider =
    StateNotifierProvider<EntitlementNotifier, AsyncValue<Entitlement>>((ref) {
  final billingService = ref.watch(billingServiceProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return EntitlementNotifier(billingService, secureStorage);
});

/// Provider for current entitlement status
final entitlementStatusProvider = Provider<EntitlementStatus>((ref) {
  final entitlement = ref.watch(entitlementProvider);
  return entitlement.whenOrNull(data: (e) => e.status) ??
      EntitlementStatus.free;
});

/// Provider for checking premium access
final hasPremiumAccessProvider = Provider<bool>((ref) {
  final entitlement = ref.watch(entitlementProvider);
  return entitlement.whenOrNull(data: (e) => e.hasPremiumAccess) ?? false;
});

/// Provider for current feature flags
final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  final entitlement = ref.watch(entitlementProvider);
  return entitlement.whenOrNull(data: (e) => e.effectiveFeatures) ??
      FeatureFlags.free();
});

/// Provider for trial info
final trialInfoProvider = Provider<TrialInfo?>((ref) {
  final entitlement = ref.watch(entitlementProvider);
  return entitlement.whenOrNull(data: (e) => e.trialInfo);
});

/// Provider for subscription info
final subscriptionInfoProvider = Provider<SubscriptionInfo?>((ref) {
  final entitlement = ref.watch(entitlementProvider);
  return entitlement.whenOrNull(data: (e) => e.subscriptionInfo);
});

/// Provider for available products
final availableProductsProvider = Provider<List<ProductInfo>>((ref) {
  return [
    ProductInfo.monthly,
    ProductInfo.yearly,
  ];
});

/// Provider for billing loading state
final billingLoadingProvider = StateProvider<bool>((ref) {
  return false;
});

/// Provider for billing error
final billingErrorProvider = StateProvider<String?>((ref) {
  return null;
});

/// State notifier for entitlement management
class EntitlementNotifier extends StateNotifier<AsyncValue<Entitlement>> {
  EntitlementNotifier(this._billingService, this._secureStorage)
      : super(const AsyncValue.loading()) {
    _initialize();
  }

  final BillingService _billingService;
  final SecureStorageService _secureStorage;
  Timer? _verificationTimer;

  static const _verificationInterval = Duration(hours: 1);
  static const _offlineGracePeriod = Duration(days: 7);

  Future<void> _initialize() async {
    try {
      // Try to load cached entitlement first
      final cachedEntitlement = await _loadCachedEntitlement();
      if (cachedEntitlement != null) {
        state = AsyncValue.data(cachedEntitlement);
      }

      // Verify with server
      await verifyEntitlement();

      // Start periodic verification
      _startPeriodicVerification();
    } catch (e, st) {
      // If verification fails, fall back to free tier
      state = AsyncValue.data(Entitlement.free(userId: await _getUserId()));
      state = AsyncValue.error(e, st);
    }
  }

  Future<Entitlement?> _loadCachedEntitlement() async {
    try {
      final userId = await _secureStorage.read(SecureStorageKeys.userId);
      final status = await _secureStorage.read(SecureStorageKeys.entitlementStatus);
      final tier = await _secureStorage.read(SecureStorageKeys.subscriptionTier);
      final lastVerified =
          await _secureStorage.read(SecureStorageKeys.lastVerified);

      if (userId == null || status == null) {
        return null;
      }

      final entitlementStatus = EntitlementStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => EntitlementStatus.free,
      );

      final subscriptionTier = SubscriptionTier.values.firstWhere(
        (t) => t.name == tier,
        orElse: () => SubscriptionTier.free,
      );

      DateTime? lastVerifiedDate;
      if (lastVerified != null) {
        lastVerifiedDate = DateTime.tryParse(lastVerified);
      }

      return Entitlement(
        userId: userId,
        status: entitlementStatus,
        tier: subscriptionTier,
        lastVerified: lastVerifiedDate,
        offlineGraceExpiry: lastVerifiedDate?.add(_offlineGracePeriod),
      );
    } catch (e) {
      return null;
    }
  }

  Future<String> _getUserId() async {
    var userId = await _secureStorage.read(SecureStorageKeys.userId);
    if (userId == null) {
      // Generate a new user ID
      userId = _generateUserId();
      await _secureStorage.write(SecureStorageKeys.userId, userId);
    }
    return userId;
  }

  String _generateUserId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.hashCode.abs();
    return 'user_${timestamp}_$random';
  }

  void _startPeriodicVerification() {
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(_verificationInterval, (_) {
      verifyEntitlement();
    });
  }

  /// Verify entitlement with the billing service
  Future<void> verifyEntitlement() async {
    try {
      final userId = await _getUserId();
      final entitlement = await _billingService.verifyEntitlement(userId);

      // Cache the entitlement
      await _cacheEntitlement(entitlement);

      state = AsyncValue.data(entitlement);
    } catch (e) {
      // Check if we have a valid cached entitlement with offline grace
      final currentEntitlement = state.valueOrNull;
      if (currentEntitlement != null && currentEntitlement.isOfflineGraceActive) {
        // Continue with cached entitlement
        return;
      }

      // Fall back to free tier
      final userId = await _getUserId();
      state = AsyncValue.data(Entitlement.free(userId: userId));
    }
  }

  Future<void> _cacheEntitlement(Entitlement entitlement) async {
    await _secureStorage.write(
        SecureStorageKeys.entitlementStatus, entitlement.status.name);
    await _secureStorage.write(
        SecureStorageKeys.subscriptionTier, entitlement.tier.name);
    await _secureStorage.write(SecureStorageKeys.lastVerified,
        entitlement.lastVerified?.toIso8601String() ?? '');
  }

  /// Start a trial
  Future<bool> startTrial() async {
    try {
      final userId = await _getUserId();
      final entitlement = await _billingService.startTrial(userId);
      await _cacheEntitlement(entitlement);
      state = AsyncValue.data(entitlement);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Purchase a subscription
  Future<bool> purchase(ProductInfo product) async {
    try {
      final userId = await _getUserId();
      final success = await _billingService.startCheckout(userId, product.id);
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Handle a successful payment callback
  Future<void> handlePaymentSuccess(String sessionId) async {
    try {
      final userId = await _getUserId();
      final entitlement =
          await _billingService.handlePaymentCallback(userId, sessionId);
      await _cacheEntitlement(entitlement);
      state = AsyncValue.data(entitlement);
    } catch (e) {
      // Verification will catch up later
    }
  }

  /// Restore purchases
  Future<bool> restorePurchases() async {
    try {
      await verifyEntitlement();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Manage subscription (opens customer portal)
  Future<bool> manageSubscription() async {
    try {
      final userId = await _getUserId();
      return await _billingService.openCustomerPortal(userId);
    } catch (e) {
      return false;
    }
  }

  /// Cancel subscription
  Future<bool> cancelSubscription() async {
    try {
      final userId = await _getUserId();
      final result = await _billingService.cancelSubscription(userId);
      if (result) {
        await verifyEntitlement();
      }
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Sign out and clear entitlement
  Future<void> signOut() async {
    await _secureStorage.delete(SecureStorageKeys.userId);
    await _secureStorage.delete(SecureStorageKeys.entitlementStatus);
    await _secureStorage.delete(SecureStorageKeys.subscriptionTier);
    await _secureStorage.delete(SecureStorageKeys.lastVerified);

    final userId = await _getUserId();
    state = AsyncValue.data(Entitlement.free(userId: userId));
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    super.dispose();
  }
}

/// Storage keys for secure storage
class SecureStorageKeys {
  SecureStorageKeys._();

  static const String userId = 'craig_o_clean_user_id';
  static const String entitlementStatus = 'craig_o_clean_entitlement_status';
  static const String subscriptionTier = 'craig_o_clean_subscription_tier';
  static const String lastVerified = 'craig_o_clean_last_verified';
  static const String stripeCustomerId = 'craig_o_clean_stripe_customer_id';
}
