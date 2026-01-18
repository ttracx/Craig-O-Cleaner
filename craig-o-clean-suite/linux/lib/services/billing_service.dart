import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:craig_o_clean/models/entitlement.dart';
import 'package:craig_o_clean/services/secure_storage_service.dart';
import 'package:craig_o_clean/providers/entitlement_provider.dart';

/// Service for handling Stripe billing on Linux
class BillingService {
  BillingService(this._secureStorage);

  final SecureStorageService _secureStorage;

  // VibeCaaS API configuration
  static const String _baseUrl = 'https://api.vibecaas.com/v1';
  static const String _appId = 'craig-o-clean-linux';

  // Stripe configuration
  static const String _stripePublicKey = 'pk_live_craig_o_clean_stripe_key';

  /// Verify user entitlement with the backend
  Future<Entitlement> verifyEntitlement(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/entitlements/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'X-App-Id': _appId,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseEntitlementResponse(userId, data);
      } else if (response.statusCode == 404) {
        // User not found, return free tier
        return Entitlement.free(userId: userId);
      } else {
        throw Exception('Failed to verify entitlement: ${response.statusCode}');
      }
    } catch (e) {
      // Network error or timeout, return cached or free tier
      final cached = await _getCachedEntitlement(userId);
      if (cached != null && cached.isOfflineGraceActive) {
        return cached;
      }
      return Entitlement.free(userId: userId);
    }
  }

  /// Start a trial for the user
  Future<Entitlement> startTrial(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/trials'),
        headers: {
          'Content-Type': 'application/json',
          'X-App-Id': _appId,
        },
        body: jsonEncode({
          'user_id': userId,
          'duration_days': 7,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseEntitlementResponse(userId, data);
      } else {
        throw Exception('Failed to start trial: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to start trial: $e');
    }
  }

  /// Start Stripe checkout session
  Future<bool> startCheckout(String userId, String productId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/checkout/sessions'),
        headers: {
          'Content-Type': 'application/json',
          'X-App-Id': _appId,
        },
        body: jsonEncode({
          'user_id': userId,
          'product_id': productId,
          'success_url': 'craigoclean://payment-success?session_id={CHECKOUT_SESSION_ID}',
          'cancel_url': 'craigoclean://payment-cancelled',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final checkoutUrl = data['url'] as String?;

        if (checkoutUrl != null) {
          // Store session ID for verification
          final sessionId = data['session_id'] as String?;
          if (sessionId != null) {
            await _secureStorage.write(
                SecureStorageKeys.stripeCustomerId, sessionId);
          }

          // Open checkout in browser
          final uri = Uri.parse(checkoutUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Handle payment callback from deep link
  Future<Entitlement> handlePaymentCallback(
      String userId, String sessionId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/checkout/verify'),
        headers: {
          'Content-Type': 'application/json',
          'X-App-Id': _appId,
        },
        body: jsonEncode({
          'user_id': userId,
          'session_id': sessionId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseEntitlementResponse(userId, data);
      } else {
        throw Exception('Payment verification failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Payment verification failed: $e');
    }
  }

  /// Open Stripe customer portal
  Future<bool> openCustomerPortal(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/billing/portal'),
        headers: {
          'Content-Type': 'application/json',
          'X-App-Id': _appId,
        },
        body: jsonEncode({
          'user_id': userId,
          'return_url': 'craigoclean://billing-complete',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final portalUrl = data['url'] as String?;

        if (portalUrl != null) {
          final uri = Uri.parse(portalUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Cancel subscription
  Future<bool> cancelSubscription(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/subscriptions/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'X-App-Id': _appId,
        },
        body: jsonEncode({
          'user_id': userId,
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Parse entitlement response from API
  Entitlement _parseEntitlementResponse(
      String userId, Map<String, dynamic> data) {
    final statusStr = data['status'] as String? ?? 'free';
    final tierStr = data['tier'] as String? ?? 'free';
    final sourceStr = data['source'] as String? ?? 'none';

    final status = EntitlementStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => EntitlementStatus.free,
    );

    final tier = SubscriptionTier.values.firstWhere(
      (t) => t.name == tierStr,
      orElse: () => SubscriptionTier.free,
    );

    final source = BillingSource.values.firstWhere(
      (s) => s.name == sourceStr,
      orElse: () => BillingSource.none,
    );

    TrialInfo? trialInfo;
    final trialData = data['trial'] as Map<String, dynamic>?;
    if (trialData != null) {
      trialInfo = TrialInfo(
        startDate: DateTime.tryParse(trialData['start_date'] as String? ?? ''),
        endDate: DateTime.tryParse(trialData['end_date'] as String? ?? ''),
        daysRemaining: trialData['days_remaining'] as int?,
        hasUsedTrial: trialData['has_used_trial'] as bool? ?? false,
      );
    }

    SubscriptionInfo? subscriptionInfo;
    final subData = data['subscription'] as Map<String, dynamic>?;
    if (subData != null) {
      subscriptionInfo = SubscriptionInfo(
        productId: subData['product_id'] as String?,
        purchaseToken: subData['purchase_token'] as String?,
        startDate: DateTime.tryParse(subData['start_date'] as String? ?? ''),
        currentPeriodEnd:
            DateTime.tryParse(subData['current_period_end'] as String? ?? ''),
        autoRenewing: subData['auto_renewing'] as bool?,
        cancelAtPeriodEnd: subData['cancel_at_period_end'] as bool?,
        priceAmount: (subData['price_amount'] as num?)?.toDouble(),
        priceCurrency: subData['price_currency'] as String?,
      );
    }

    return Entitlement(
      userId: userId,
      status: status,
      tier: tier,
      source: source,
      trialInfo: trialInfo,
      subscriptionInfo: subscriptionInfo,
      features: status == EntitlementStatus.subscribed ||
              status == EntitlementStatus.trialActive
          ? FeatureFlags.paid()
          : FeatureFlags.free(),
      lastVerified: DateTime.now(),
      offlineGraceExpiry: DateTime.now().add(const Duration(days: 7)),
    );
  }

  /// Get cached entitlement from secure storage
  Future<Entitlement?> _getCachedEntitlement(String userId) async {
    try {
      final statusStr =
          await _secureStorage.read(SecureStorageKeys.entitlementStatus);
      final tierStr =
          await _secureStorage.read(SecureStorageKeys.subscriptionTier);
      final lastVerifiedStr =
          await _secureStorage.read(SecureStorageKeys.lastVerified);

      if (statusStr == null) return null;

      final status = EntitlementStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => EntitlementStatus.free,
      );

      final tier = SubscriptionTier.values.firstWhere(
        (t) => t.name == tierStr,
        orElse: () => SubscriptionTier.free,
      );

      DateTime? lastVerified;
      if (lastVerifiedStr != null) {
        lastVerified = DateTime.tryParse(lastVerifiedStr);
      }

      return Entitlement(
        userId: userId,
        status: status,
        tier: tier,
        lastVerified: lastVerified,
        offlineGraceExpiry: lastVerified?.add(const Duration(days: 7)),
      );
    } catch (e) {
      return null;
    }
  }
}
