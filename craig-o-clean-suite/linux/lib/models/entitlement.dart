import 'package:equatable/equatable.dart';

/// Entitlement status enumeration
enum EntitlementStatus {
  free,
  trialActive,
  trialExpired,
  subscribed,
  subscriptionExpired,
  subscriptionGracePeriod,
  subscriptionPaused,
}

/// Subscription tier enumeration
enum SubscriptionTier {
  free,
  trial,
  monthly,
  yearly,
}

/// Billing source enumeration
enum BillingSource {
  none,
  stripe,
}

/// Feature flags for access control
class FeatureFlags extends Equatable {
  const FeatureFlags({
    this.canViewMetrics = true,
    this.canViewProcessList = true,
    this.canViewMetricsDetail = false,
    this.canEndProcesses = false,
    this.canForceKillProcesses = false,
    this.canUseQuickActionsFromTray = false,
    this.canBulkProcessActions = false,
    this.canMemoryCleanup = false,
    this.canAdvancedCleanup = false,
    this.canCustomRefreshRate = false,
    this.canExportMetrics = false,
  });

  final bool canViewMetrics;
  final bool canViewProcessList;
  final bool canViewMetricsDetail;
  final bool canEndProcesses;
  final bool canForceKillProcesses;
  final bool canUseQuickActionsFromTray;
  final bool canBulkProcessActions;
  final bool canMemoryCleanup;
  final bool canAdvancedCleanup;
  final bool canCustomRefreshRate;
  final bool canExportMetrics;

  /// Free tier features
  factory FeatureFlags.free() => const FeatureFlags();

  /// Trial/Paid tier features (full access)
  factory FeatureFlags.paid() => const FeatureFlags(
        canViewMetrics: true,
        canViewProcessList: true,
        canViewMetricsDetail: true,
        canEndProcesses: true,
        canForceKillProcesses: true,
        canUseQuickActionsFromTray: true,
        canBulkProcessActions: true,
        canMemoryCleanup: true,
        canAdvancedCleanup: true,
        canCustomRefreshRate: true,
        canExportMetrics: true,
      );

  @override
  List<Object?> get props => [
        canViewMetrics,
        canViewProcessList,
        canViewMetricsDetail,
        canEndProcesses,
        canForceKillProcesses,
        canUseQuickActionsFromTray,
        canBulkProcessActions,
        canMemoryCleanup,
        canAdvancedCleanup,
        canCustomRefreshRate,
        canExportMetrics,
      ];
}

/// Trial information
class TrialInfo extends Equatable {
  const TrialInfo({
    this.startDate,
    this.endDate,
    this.daysRemaining,
    this.hasUsedTrial = false,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final int? daysRemaining;
  final bool hasUsedTrial;

  bool get isActive {
    if (startDate == null || endDate == null) return false;
    final now = DateTime.now();
    return now.isAfter(startDate!) && now.isBefore(endDate!);
  }

  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  @override
  List<Object?> get props => [startDate, endDate, daysRemaining, hasUsedTrial];
}

/// Subscription information
class SubscriptionInfo extends Equatable {
  const SubscriptionInfo({
    this.productId,
    this.purchaseToken,
    this.startDate,
    this.currentPeriodEnd,
    this.autoRenewing,
    this.cancelAtPeriodEnd,
    this.priceAmount,
    this.priceCurrency,
  });

  final String? productId;
  final String? purchaseToken;
  final DateTime? startDate;
  final DateTime? currentPeriodEnd;
  final bool? autoRenewing;
  final bool? cancelAtPeriodEnd;
  final double? priceAmount;
  final String? priceCurrency;

  bool get isActive {
    if (currentPeriodEnd == null) return false;
    return DateTime.now().isBefore(currentPeriodEnd!);
  }

  @override
  List<Object?> get props => [
        productId,
        purchaseToken,
        startDate,
        currentPeriodEnd,
        autoRenewing,
        cancelAtPeriodEnd,
        priceAmount,
        priceCurrency,
      ];
}

/// User entitlement model
class Entitlement extends Equatable {
  const Entitlement({
    required this.userId,
    required this.status,
    required this.tier,
    this.source = BillingSource.none,
    this.trialInfo,
    this.subscriptionInfo,
    this.features,
    this.lastVerified,
    this.offlineGraceExpiry,
  });

  final String userId;
  final EntitlementStatus status;
  final SubscriptionTier tier;
  final BillingSource source;
  final TrialInfo? trialInfo;
  final SubscriptionInfo? subscriptionInfo;
  final FeatureFlags? features;
  final DateTime? lastVerified;
  final DateTime? offlineGraceExpiry;

  /// Check if user has premium access
  bool get hasPremiumAccess {
    switch (status) {
      case EntitlementStatus.trialActive:
      case EntitlementStatus.subscribed:
      case EntitlementStatus.subscriptionGracePeriod:
        return true;
      case EntitlementStatus.free:
      case EntitlementStatus.trialExpired:
      case EntitlementStatus.subscriptionExpired:
      case EntitlementStatus.subscriptionPaused:
        return false;
    }
  }

  /// Get effective feature flags based on entitlement
  FeatureFlags get effectiveFeatures {
    if (features != null) return features!;
    return hasPremiumAccess ? FeatureFlags.paid() : FeatureFlags.free();
  }

  /// Check if offline grace period is active
  bool get isOfflineGraceActive {
    if (offlineGraceExpiry == null) return false;
    return DateTime.now().isBefore(offlineGraceExpiry!);
  }

  /// Create a free tier entitlement
  factory Entitlement.free({required String userId}) => Entitlement(
        userId: userId,
        status: EntitlementStatus.free,
        tier: SubscriptionTier.free,
        features: FeatureFlags.free(),
      );

  Entitlement copyWith({
    String? userId,
    EntitlementStatus? status,
    SubscriptionTier? tier,
    BillingSource? source,
    TrialInfo? trialInfo,
    SubscriptionInfo? subscriptionInfo,
    FeatureFlags? features,
    DateTime? lastVerified,
    DateTime? offlineGraceExpiry,
  }) {
    return Entitlement(
      userId: userId ?? this.userId,
      status: status ?? this.status,
      tier: tier ?? this.tier,
      source: source ?? this.source,
      trialInfo: trialInfo ?? this.trialInfo,
      subscriptionInfo: subscriptionInfo ?? this.subscriptionInfo,
      features: features ?? this.features,
      lastVerified: lastVerified ?? this.lastVerified,
      offlineGraceExpiry: offlineGraceExpiry ?? this.offlineGraceExpiry,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        status,
        tier,
        source,
        trialInfo,
        subscriptionInfo,
        features,
        lastVerified,
        offlineGraceExpiry,
      ];
}

/// Product information for purchases
class ProductInfo extends Equatable {
  const ProductInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.priceAmount,
    required this.priceCurrency,
    required this.period,
    this.trialDays,
    this.badge,
  });

  final String id;
  final String name;
  final String description;
  final double priceAmount;
  final String priceCurrency;
  final String period; // 'month' or 'year'
  final int? trialDays;
  final String? badge;

  /// Monthly subscription product
  static ProductInfo get monthly => const ProductInfo(
        id: 'craigoclean_monthly',
        name: 'Craig-O-Clean Monthly',
        description: 'Full access to all Craig-O-Clean features',
        priceAmount: 0.99,
        priceCurrency: 'USD',
        period: 'month',
        trialDays: 7,
      );

  /// Yearly subscription product
  static ProductInfo get yearly => const ProductInfo(
        id: 'craigoclean_yearly',
        name: 'Craig-O-Clean Yearly',
        description: 'Full access to all Craig-O-Clean features - Best value!',
        priceAmount: 9.99,
        priceCurrency: 'USD',
        period: 'year',
        trialDays: 7,
        badge: 'Best Value - 2 Months Free!',
      );

  /// Get formatted price string
  String get formattedPrice {
    final symbol = priceCurrency == 'USD' ? '\$' : priceCurrency;
    return '$symbol${priceAmount.toStringAsFixed(2)}/$period';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        priceAmount,
        priceCurrency,
        period,
        trialDays,
        badge,
      ];
}
