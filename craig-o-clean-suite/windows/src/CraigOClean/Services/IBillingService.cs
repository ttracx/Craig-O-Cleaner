// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using CraigOClean.Models;

namespace CraigOClean.Services;

/// <summary>
/// Service interface for billing and subscription management.
/// </summary>
public interface IBillingService
{
    /// <summary>
    /// Event raised when subscription status changes.
    /// </summary>
    event EventHandler<SubscriptionInfo>? SubscriptionChanged;

    /// <summary>
    /// Gets the current subscription information.
    /// </summary>
    SubscriptionInfo CurrentSubscription { get; }

    /// <summary>
    /// Initializes the billing service and checks subscription status.
    /// </summary>
    Task InitializeAsync();

    /// <summary>
    /// Gets the current subscription status from the provider.
    /// </summary>
    Task<SubscriptionInfo> GetSubscriptionStatusAsync();

    /// <summary>
    /// Starts a trial if eligible.
    /// </summary>
    Task<bool> StartTrialAsync();

    /// <summary>
    /// Purchases a subscription.
    /// </summary>
    Task<bool> PurchaseSubscriptionAsync(SubscriptionPlan plan);

    /// <summary>
    /// Manages an existing subscription (opens management portal).
    /// </summary>
    Task ManageSubscriptionAsync();

    /// <summary>
    /// Restores purchases (useful for re-installation).
    /// </summary>
    Task<bool> RestorePurchasesAsync();

    /// <summary>
    /// Gets the billing provider being used.
    /// </summary>
    BillingProvider ActiveProvider { get; }
}
