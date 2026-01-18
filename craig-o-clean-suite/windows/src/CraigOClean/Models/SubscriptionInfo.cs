// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

namespace CraigOClean.Models;

/// <summary>
/// Represents subscription information for the application.
/// </summary>
public sealed class SubscriptionInfo
{
    /// <summary>
    /// Gets or sets the current subscription status.
    /// </summary>
    public SubscriptionStatus Status { get; set; } = SubscriptionStatus.Trial;

    /// <summary>
    /// Gets or sets the subscription plan type.
    /// </summary>
    public SubscriptionPlan Plan { get; set; } = SubscriptionPlan.None;

    /// <summary>
    /// Gets or sets when the trial started.
    /// </summary>
    public DateTime? TrialStartDate { get; set; }

    /// <summary>
    /// Gets or sets when the trial expires.
    /// </summary>
    public DateTime? TrialExpirationDate { get; set; }

    /// <summary>
    /// Gets or sets when the subscription was purchased.
    /// </summary>
    public DateTime? PurchaseDate { get; set; }

    /// <summary>
    /// Gets or sets when the subscription expires/renews.
    /// </summary>
    public DateTime? ExpirationDate { get; set; }

    /// <summary>
    /// Gets or sets whether auto-renewal is enabled.
    /// </summary>
    public bool AutoRenewEnabled { get; set; }

    /// <summary>
    /// Gets or sets the billing provider.
    /// </summary>
    public BillingProvider Provider { get; set; } = BillingProvider.None;

    /// <summary>
    /// Gets or sets the provider-specific subscription ID.
    /// </summary>
    public string? SubscriptionId { get; set; }

    /// <summary>
    /// Gets or sets the customer ID.
    /// </summary>
    public string? CustomerId { get; set; }

    /// <summary>
    /// Gets whether the subscription is currently active.
    /// </summary>
    public bool IsActive => Status switch
    {
        SubscriptionStatus.Active => ExpirationDate == null || ExpirationDate > DateTime.UtcNow,
        SubscriptionStatus.Trial => TrialExpirationDate == null || TrialExpirationDate > DateTime.UtcNow,
        _ => false
    };

    /// <summary>
    /// Gets the number of trial days remaining.
    /// </summary>
    public int TrialDaysRemaining
    {
        get
        {
            if (Status != SubscriptionStatus.Trial || TrialExpirationDate == null)
                return 0;

            var remaining = (TrialExpirationDate.Value - DateTime.UtcNow).Days;
            return Math.Max(0, remaining);
        }
    }

    /// <summary>
    /// Gets whether premium features are available.
    /// </summary>
    public bool HasPremiumAccess => IsActive;
}

/// <summary>
/// Subscription status values.
/// </summary>
public enum SubscriptionStatus
{
    /// <summary>
    /// No subscription, basic features only.
    /// </summary>
    None,

    /// <summary>
    /// Currently in trial period.
    /// </summary>
    Trial,

    /// <summary>
    /// Active paid subscription.
    /// </summary>
    Active,

    /// <summary>
    /// Subscription expired.
    /// </summary>
    Expired,

    /// <summary>
    /// Subscription cancelled.
    /// </summary>
    Cancelled,

    /// <summary>
    /// Payment issue, grace period.
    /// </summary>
    GracePeriod
}

/// <summary>
/// Available subscription plans.
/// </summary>
public enum SubscriptionPlan
{
    /// <summary>
    /// No subscription plan.
    /// </summary>
    None,

    /// <summary>
    /// Monthly subscription.
    /// </summary>
    Monthly,

    /// <summary>
    /// Yearly subscription (discounted).
    /// </summary>
    Yearly
}

/// <summary>
/// Billing provider types.
/// </summary>
public enum BillingProvider
{
    /// <summary>
    /// No billing provider.
    /// </summary>
    None,

    /// <summary>
    /// Microsoft Store in-app purchases.
    /// </summary>
    MicrosoftStore,

    /// <summary>
    /// Stripe direct billing.
    /// </summary>
    Stripe
}

/// <summary>
/// Product identifiers for in-app purchases.
/// </summary>
public static class ProductIds
{
    /// <summary>
    /// Monthly subscription product ID.
    /// </summary>
    public const string Monthly = "craigoclean_monthly";

    /// <summary>
    /// Yearly subscription product ID.
    /// </summary>
    public const string Yearly = "craigoclean_yearly";

    /// <summary>
    /// Trial duration in days.
    /// </summary>
    public const int TrialDurationDays = 7;
}
