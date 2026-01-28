import Foundation

// MARK: - Subscription Status

enum SubscriptionStatus: String, Codable, Equatable {
    case free = "free"              // Never started trial
    case trial = "trial"            // Currently in trial period
    case trialExpired = "expired"   // Trial has ended
    case active = "active"          // Paid subscription active
    case cancelled = "cancelled"    // Subscription cancelled but may still have access

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .trial: return "Trial"
        case .trialExpired: return "Trial Expired"
        case .active: return "Pro"
        case .cancelled: return "Cancelled"
        }
    }

    var canAccessProFeatures: Bool {
        switch self {
        case .trial, .active: return true
        case .free, .trialExpired, .cancelled: return false
        }
    }
}

// MARK: - Subscription Plan

enum SubscriptionPlan: String, Codable, Equatable, CaseIterable {
    case monthly = "monthly"
    case yearly = "yearly"

    var productId: String {
        switch self {
        case .monthly: return "com.craigoclean.pro.monthly"
        case .yearly: return "com.craigoclean.pro.yearly"
        }
    }

    var stripeProductId: String {
        switch self {
        case .monthly: return "price_monthly_099"
        case .yearly: return "price_yearly_999"
        }
    }

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    var price: String {
        switch self {
        case .monthly: return "$0.99"
        case .yearly: return "$9.99"
        }
    }

    var priceDescription: String {
        switch self {
        case .monthly: return "$0.99/month"
        case .yearly: return "$9.99/year (save 17%)"
        }
    }
}

// MARK: - User Profile

struct UserProfile: Codable, Equatable {
    var userId: String
    var displayName: String?
    var email: String?

    var createdAt: Date
    var lastSignInAt: Date

    // MARK: - Trial Fields

    /// Date when the trial started (nil if trial never started)
    var trialStartDate: Date?

    /// Whether the user has ever used their trial
    var hasUsedTrial: Bool

    /// Current subscription status
    var subscriptionStatus: SubscriptionStatus

    /// Active subscription plan (if subscribed)
    var activePlan: SubscriptionPlan?

    /// Subscription expiry date (for paid subscriptions)
    var subscriptionExpiryDate: Date?

    /// Stripe customer ID (if using Stripe)
    var stripeCustomerId: String?

    /// Device identifier for trial tracking
    var deviceId: String?

    /// Avatar image data (managed separately by AvatarManager for iCloud sync)
    /// Note: This is stored separately in UserDefaults and iCloud, not in this struct
    // var avatarImageData: Data? - Managed by AvatarManager

    // MARK: - Computed Properties

    /// Trial duration in days
    static let trialDurationDays: Int = 7

    /// Date when trial expires
    var trialExpiryDate: Date? {
        guard let start = trialStartDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: Self.trialDurationDays, to: start)
    }

    /// Number of days remaining in trial
    var trialDaysRemaining: Int {
        guard let expiryDate = trialExpiryDate else { return 0 }
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
        return max(0, remaining)
    }

    /// Whether trial has expired
    var isTrialExpired: Bool {
        guard let expiryDate = trialExpiryDate else { return false }
        return Date() > expiryDate
    }

    /// Whether user can access pro features
    var canAccessProFeatures: Bool {
        switch subscriptionStatus {
        case .trial:
            return !isTrialExpired
        case .active:
            if let expiry = subscriptionExpiryDate {
                return Date() < expiry
            }
            return true
        case .free, .trialExpired, .cancelled:
            return false
        }
    }

    /// Whether user should see upgrade prompt
    var shouldShowUpgradePrompt: Bool {
        switch subscriptionStatus {
        case .trialExpired, .cancelled:
            return true
        case .trial:
            return trialDaysRemaining <= 3  // Show when 3 or fewer days left
        case .free, .active:
            return false
        }
    }

    // MARK: - Initialization

    init(userId: String,
         displayName: String? = nil,
         email: String? = nil,
         createdAt: Date = Date(),
         lastSignInAt: Date = Date(),
         trialStartDate: Date? = nil,
         hasUsedTrial: Bool = false,
         subscriptionStatus: SubscriptionStatus = .free,
         activePlan: SubscriptionPlan? = nil,
         subscriptionExpiryDate: Date? = nil,
         stripeCustomerId: String? = nil,
         deviceId: String? = nil) {
        self.userId = userId
        self.displayName = displayName
        self.email = email
        self.createdAt = createdAt
        self.lastSignInAt = lastSignInAt
        self.trialStartDate = trialStartDate
        self.hasUsedTrial = hasUsedTrial
        self.subscriptionStatus = subscriptionStatus
        self.activePlan = activePlan
        self.subscriptionExpiryDate = subscriptionExpiryDate
        self.stripeCustomerId = stripeCustomerId
        self.deviceId = deviceId
    }

    // MARK: - Codable (Backward Compatibility)

    enum CodingKeys: String, CodingKey {
        case userId, displayName, email, createdAt, lastSignInAt
        case trialStartDate, hasUsedTrial, subscriptionStatus
        case activePlan, subscriptionExpiryDate, stripeCustomerId, deviceId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastSignInAt = try container.decode(Date.self, forKey: .lastSignInAt)

        // New fields with defaults for backward compatibility
        trialStartDate = try container.decodeIfPresent(Date.self, forKey: .trialStartDate)
        hasUsedTrial = try container.decodeIfPresent(Bool.self, forKey: .hasUsedTrial) ?? false
        subscriptionStatus = try container.decodeIfPresent(SubscriptionStatus.self, forKey: .subscriptionStatus) ?? .free
        activePlan = try container.decodeIfPresent(SubscriptionPlan.self, forKey: .activePlan)
        subscriptionExpiryDate = try container.decodeIfPresent(Date.self, forKey: .subscriptionExpiryDate)
        stripeCustomerId = try container.decodeIfPresent(String.self, forKey: .stripeCustomerId)
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
    }
}

