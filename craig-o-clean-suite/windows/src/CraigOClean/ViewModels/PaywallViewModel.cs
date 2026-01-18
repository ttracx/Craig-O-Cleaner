// Copyright (c) Craig-O-Clean. All rights reserved.
// Licensed under the MIT License.

using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CraigOClean.Models;
using CraigOClean.Services;
using System.Diagnostics;

namespace CraigOClean.ViewModels;

/// <summary>
/// ViewModel for the Paywall page.
/// </summary>
public sealed partial class PaywallViewModel : ObservableObject
{
    private readonly IBillingService _billingService;
    private readonly IEntitlementManager _entitlementManager;

    [ObservableProperty]
    private SubscriptionInfo _currentSubscription = new();

    [ObservableProperty]
    private bool _isLoading;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    [ObservableProperty]
    private bool _showError;

    [ObservableProperty]
    private string _errorMessage = string.Empty;

    [ObservableProperty]
    private bool _isTrialActive;

    [ObservableProperty]
    private int _trialDaysRemaining;

    [ObservableProperty]
    private bool _canStartTrial;

    [ObservableProperty]
    private string _monthlyPrice = "$4.99/month";

    [ObservableProperty]
    private string _yearlyPrice = "$39.99/year";

    [ObservableProperty]
    private string _yearlySavings = "Save 33%";

    [ObservableProperty]
    private bool _isMonthlySelected;

    [ObservableProperty]
    private bool _isYearlySelected = true;

    /// <summary>
    /// Pro features list.
    /// </summary>
    public List<ProFeature> ProFeatures { get; } =
    [
        new("Unlimited Process Management", "End and kill any non-system process", "\uE71D"),
        new("Advanced Cleanup", "Deep clean temporary files, logs, and caches", "\uE74D"),
        new("Real-time Monitoring", "Continuous CPU and memory monitoring with alerts", "\uE9D9"),
        new("System Tray Integration", "Quick access from system tray with live stats", "\uE8A7"),
        new("Priority Support", "Get help from our support team", "\uE8BD"),
        new("No Ads", "Clean, ad-free experience", "\uE8E1")
    ];

    /// <summary>
    /// Initializes a new instance of PaywallViewModel.
    /// </summary>
    public PaywallViewModel(
        IBillingService billingService,
        IEntitlementManager entitlementManager)
    {
        _billingService = billingService;
        _entitlementManager = entitlementManager;

        // Subscribe to changes
        _billingService.SubscriptionChanged += OnSubscriptionChanged;

        // Load current state
        UpdateFromSubscription(_billingService.CurrentSubscription);
    }

    /// <summary>
    /// Loads initial data.
    /// </summary>
    [RelayCommand]
    private async Task LoadAsync()
    {
        IsLoading = true;
        ShowError = false;

        try
        {
            var subscription = await _billingService.GetSubscriptionStatusAsync();
            UpdateFromSubscription(subscription);
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error loading subscription: {ex.Message}");
            ShowError = true;
            ErrorMessage = "Failed to load subscription status. Please try again.";
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Updates view state from subscription info.
    /// </summary>
    private void UpdateFromSubscription(SubscriptionInfo subscription)
    {
        CurrentSubscription = subscription;
        IsTrialActive = subscription.Status == SubscriptionStatus.Trial;
        TrialDaysRemaining = subscription.TrialDaysRemaining;
        CanStartTrial = subscription.Status == SubscriptionStatus.None;
    }

    /// <summary>
    /// Handles subscription changes.
    /// </summary>
    private void OnSubscriptionChanged(object? sender, SubscriptionInfo subscription)
    {
        UpdateFromSubscription(subscription);
    }

    /// <summary>
    /// Selects monthly plan.
    /// </summary>
    [RelayCommand]
    private void SelectMonthly()
    {
        IsMonthlySelected = true;
        IsYearlySelected = false;
    }

    /// <summary>
    /// Selects yearly plan.
    /// </summary>
    [RelayCommand]
    private void SelectYearly()
    {
        IsMonthlySelected = false;
        IsYearlySelected = true;
    }

    /// <summary>
    /// Starts a free trial.
    /// </summary>
    [RelayCommand]
    private async Task StartTrialAsync()
    {
        if (!CanStartTrial)
            return;

        IsLoading = true;
        ShowError = false;
        StatusMessage = "Starting your free trial...";

        try
        {
            var success = await _billingService.StartTrialAsync();

            if (success)
            {
                StatusMessage = "Trial started! Enjoy 7 days of Pro features.";
            }
            else
            {
                ShowError = true;
                ErrorMessage = "Could not start trial. You may have already used your trial period.";
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error starting trial: {ex.Message}");
            ShowError = true;
            ErrorMessage = "Failed to start trial. Please try again.";
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Purchases the selected subscription.
    /// </summary>
    [RelayCommand]
    private async Task PurchaseAsync()
    {
        var plan = IsYearlySelected ? SubscriptionPlan.Yearly : SubscriptionPlan.Monthly;

        IsLoading = true;
        ShowError = false;
        StatusMessage = "Processing purchase...";

        try
        {
            var success = await _billingService.PurchaseSubscriptionAsync(plan);

            if (success)
            {
                StatusMessage = "Thank you for your purchase!";
            }
            else
            {
                ShowError = true;
                ErrorMessage = "Purchase was not completed. Please try again.";
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error purchasing: {ex.Message}");
            ShowError = true;
            ErrorMessage = "Failed to process purchase. Please try again.";
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Restores previous purchases.
    /// </summary>
    [RelayCommand]
    private async Task RestorePurchasesAsync()
    {
        IsLoading = true;
        ShowError = false;
        StatusMessage = "Restoring purchases...";

        try
        {
            var success = await _billingService.RestorePurchasesAsync();

            if (success)
            {
                StatusMessage = "Purchases restored successfully!";
            }
            else
            {
                ShowError = true;
                ErrorMessage = "No previous purchases found.";
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error restoring purchases: {ex.Message}");
            ShowError = true;
            ErrorMessage = "Failed to restore purchases. Please try again.";
        }
        finally
        {
            IsLoading = false;
        }
    }

    /// <summary>
    /// Opens terms of service.
    /// </summary>
    [RelayCommand]
    private void OpenTerms()
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "https://www.craigoclean.com/terms",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error opening terms: {ex.Message}");
        }
    }

    /// <summary>
    /// Opens privacy policy.
    /// </summary>
    [RelayCommand]
    private void OpenPrivacy()
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "https://www.craigoclean.com/privacy",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error opening privacy: {ex.Message}");
        }
    }

    /// <summary>
    /// Cleans up resources.
    /// </summary>
    public void Cleanup()
    {
        _billingService.SubscriptionChanged -= OnSubscriptionChanged;
    }
}

/// <summary>
/// Represents a Pro feature for display.
/// </summary>
public sealed class ProFeature
{
    /// <summary>
    /// Gets the feature title.
    /// </summary>
    public string Title { get; }

    /// <summary>
    /// Gets the feature description.
    /// </summary>
    public string Description { get; }

    /// <summary>
    /// Gets the icon glyph.
    /// </summary>
    public string IconGlyph { get; }

    /// <summary>
    /// Initializes a new instance of ProFeature.
    /// </summary>
    public ProFeature(string title, string description, string iconGlyph)
    {
        Title = title;
        Description = description;
        IconGlyph = iconGlyph;
    }
}
