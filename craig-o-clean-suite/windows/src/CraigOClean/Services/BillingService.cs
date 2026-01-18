// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using System.Diagnostics;
using System.Text.Json;
using CraigOClean.Models;
using Windows.Services.Store;

namespace CraigOClean.Services;

/// <summary>
/// Service for managing billing through Microsoft Store or Stripe.
/// </summary>
public sealed class BillingService : IBillingService
{
    private readonly AppSettings _settings;
    private StoreContext? _storeContext;
    private bool _isStoreAvailable;

    /// <inheritdoc/>
    public event EventHandler<SubscriptionInfo>? SubscriptionChanged;

    /// <inheritdoc/>
    public SubscriptionInfo CurrentSubscription { get; private set; } = new();

    /// <inheritdoc/>
    public BillingProvider ActiveProvider { get; private set; } = BillingProvider.None;

    /// <summary>
    /// Path to store subscription data locally.
    /// </summary>
    private static readonly string SubscriptionDataPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "CraigOClean",
        "subscription.json");

    /// <summary>
    /// Initializes a new instance of BillingService.
    /// </summary>
    public BillingService(AppSettings settings)
    {
        _settings = settings;
        LoadCachedSubscription();
    }

    /// <inheritdoc/>
    public async Task InitializeAsync()
    {
        // Try to initialize Microsoft Store first
        try
        {
            _storeContext = StoreContext.GetDefault();
            _isStoreAvailable = _storeContext != null;

            if (_isStoreAvailable)
            {
                ActiveProvider = BillingProvider.MicrosoftStore;
                Debug.WriteLine("Microsoft Store billing initialized");
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Microsoft Store not available: {ex.Message}");
            _isStoreAvailable = false;
        }

        // Fallback to Stripe if Store not available
        if (!_isStoreAvailable && !string.IsNullOrEmpty(_settings.StripePublishableKey))
        {
            ActiveProvider = BillingProvider.Stripe;
            Debug.WriteLine("Using Stripe billing");
        }

        // Check current subscription status
        await GetSubscriptionStatusAsync();
    }

    /// <inheritdoc/>
    public async Task<SubscriptionInfo> GetSubscriptionStatusAsync()
    {
        SubscriptionInfo subscription;

        if (_isStoreAvailable)
        {
            subscription = await GetStoreSubscriptionStatusAsync();
        }
        else if (ActiveProvider == BillingProvider.Stripe)
        {
            subscription = await GetStripeSubscriptionStatusAsync();
        }
        else
        {
            subscription = LoadCachedSubscription() ?? new SubscriptionInfo();
        }

        UpdateSubscription(subscription);
        return subscription;
    }

    /// <inheritdoc/>
    public async Task<bool> StartTrialAsync()
    {
        if (CurrentSubscription.Status != SubscriptionStatus.None)
        {
            return false; // Already has subscription or trial
        }

        var subscription = new SubscriptionInfo
        {
            Status = SubscriptionStatus.Trial,
            TrialStartDate = DateTime.UtcNow,
            TrialExpirationDate = DateTime.UtcNow.AddDays(ProductIds.TrialDurationDays),
            Provider = ActiveProvider
        };

        UpdateSubscription(subscription);
        await SaveSubscriptionAsync(subscription);

        return true;
    }

    /// <inheritdoc/>
    public async Task<bool> PurchaseSubscriptionAsync(SubscriptionPlan plan)
    {
        var productId = plan switch
        {
            SubscriptionPlan.Monthly => ProductIds.Monthly,
            SubscriptionPlan.Yearly => ProductIds.Yearly,
            _ => throw new ArgumentException("Invalid plan", nameof(plan))
        };

        if (_isStoreAvailable)
        {
            return await PurchaseFromStoreAsync(productId, plan);
        }
        else if (ActiveProvider == BillingProvider.Stripe)
        {
            return await PurchaseFromStripeAsync(productId, plan);
        }

        return false;
    }

    /// <inheritdoc/>
    public async Task ManageSubscriptionAsync()
    {
        await Task.Run(() =>
        {
            try
            {
                if (ActiveProvider == BillingProvider.MicrosoftStore)
                {
                    // Open Microsoft Store subscriptions page
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "ms-windows-store://account/subscriptions",
                        UseShellExecute = true
                    });
                }
                else if (ActiveProvider == BillingProvider.Stripe)
                {
                    // Open Stripe customer portal
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "https://billing.stripe.com/p/login/your-portal-link",
                        UseShellExecute = true
                    });
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Failed to open subscription management: {ex.Message}");
            }
        });
    }

    /// <inheritdoc/>
    public async Task<bool> RestorePurchasesAsync()
    {
        try
        {
            var subscription = await GetSubscriptionStatusAsync();
            return subscription.IsActive;
        }
        catch
        {
            return false;
        }
    }

    #region Microsoft Store Implementation

    private async Task<SubscriptionInfo> GetStoreSubscriptionStatusAsync()
    {
        if (_storeContext == null)
            return LoadCachedSubscription() ?? new SubscriptionInfo();

        try
        {
            // Get app license
            var appLicense = await _storeContext.GetAppLicenseAsync();

            if (appLicense.IsActive)
            {
                // Check for add-on licenses (subscriptions)
                foreach (var addOnLicense in appLicense.AddOnLicenses.Values)
                {
                    if (addOnLicense.IsActive)
                    {
                        var plan = addOnLicense.SkuStoreId.Contains("yearly", StringComparison.OrdinalIgnoreCase)
                            ? SubscriptionPlan.Yearly
                            : SubscriptionPlan.Monthly;

                        return new SubscriptionInfo
                        {
                            Status = SubscriptionStatus.Active,
                            Plan = plan,
                            Provider = BillingProvider.MicrosoftStore,
                            ExpirationDate = addOnLicense.ExpirationDate.UtcDateTime,
                            SubscriptionId = addOnLicense.SkuStoreId
                        };
                    }
                }

                // Check if trial
                if (appLicense.IsTrial)
                {
                    return new SubscriptionInfo
                    {
                        Status = SubscriptionStatus.Trial,
                        Provider = BillingProvider.MicrosoftStore,
                        TrialStartDate = DateTime.UtcNow.AddDays(-1), // Approximate
                        TrialExpirationDate = appLicense.ExpirationDate.UtcDateTime
                    };
                }
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error getting Store license: {ex.Message}");
        }

        return LoadCachedSubscription() ?? new SubscriptionInfo();
    }

    private async Task<bool> PurchaseFromStoreAsync(string productId, SubscriptionPlan plan)
    {
        if (_storeContext == null) return false;

        try
        {
            var result = await _storeContext.RequestPurchaseAsync(productId);

            switch (result.Status)
            {
                case StorePurchaseStatus.Succeeded:
                    var subscription = new SubscriptionInfo
                    {
                        Status = SubscriptionStatus.Active,
                        Plan = plan,
                        Provider = BillingProvider.MicrosoftStore,
                        PurchaseDate = DateTime.UtcNow,
                        ExpirationDate = plan == SubscriptionPlan.Monthly
                            ? DateTime.UtcNow.AddMonths(1)
                            : DateTime.UtcNow.AddYears(1),
                        AutoRenewEnabled = true,
                        SubscriptionId = productId
                    };
                    UpdateSubscription(subscription);
                    await SaveSubscriptionAsync(subscription);
                    return true;

                case StorePurchaseStatus.AlreadyPurchased:
                    await GetSubscriptionStatusAsync();
                    return CurrentSubscription.IsActive;

                default:
                    Debug.WriteLine($"Purchase failed: {result.Status}");
                    return false;
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Store purchase error: {ex.Message}");
            return false;
        }
    }

    #endregion

    #region Stripe Implementation

    private async Task<SubscriptionInfo> GetStripeSubscriptionStatusAsync()
    {
        // In a real implementation, this would call your backend API
        // to verify the subscription status with Stripe
        await Task.Delay(100); // Simulate API call

        // For now, return cached subscription
        return LoadCachedSubscription() ?? new SubscriptionInfo();
    }

    private async Task<bool> PurchaseFromStripeAsync(string productId, SubscriptionPlan plan)
    {
        // In a real implementation, this would:
        // 1. Open a checkout session URL from your backend
        // 2. Handle the redirect back from Stripe
        // 3. Verify the subscription was created

        try
        {
            // Open Stripe Checkout (would be your actual checkout URL)
            var checkoutUrl = $"https://your-backend.com/create-checkout-session?product={productId}";

            await Task.Run(() =>
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = checkoutUrl,
                    UseShellExecute = true
                });
            });

            // Note: In production, you'd need to handle the callback
            // and verify the purchase was successful
            return true;
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Stripe purchase error: {ex.Message}");
            return false;
        }
    }

    #endregion

    #region Helpers

    private void UpdateSubscription(SubscriptionInfo subscription)
    {
        CurrentSubscription = subscription;
        _settings.CachedSubscription = subscription;
        _settings.Save();
        SubscriptionChanged?.Invoke(this, subscription);
    }

    private SubscriptionInfo? LoadCachedSubscription()
    {
        try
        {
            if (_settings.CachedSubscription != null)
            {
                return _settings.CachedSubscription;
            }

            if (File.Exists(SubscriptionDataPath))
            {
                var json = File.ReadAllText(SubscriptionDataPath);
                return JsonSerializer.Deserialize<SubscriptionInfo>(json);
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error loading cached subscription: {ex.Message}");
        }

        return null;
    }

    private async Task SaveSubscriptionAsync(SubscriptionInfo subscription)
    {
        try
        {
            var directory = Path.GetDirectoryName(SubscriptionDataPath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            var json = JsonSerializer.Serialize(subscription, new JsonSerializerOptions
            {
                WriteIndented = true
            });

            await File.WriteAllTextAsync(SubscriptionDataPath, json);
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error saving subscription: {ex.Message}");
        }
    }

    #endregion
}
