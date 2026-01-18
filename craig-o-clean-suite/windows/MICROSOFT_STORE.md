# Microsoft Store Submission Guide

This document provides instructions for submitting Craig-O-Clean to the Microsoft Store.

## Pre-Submission Checklist

### 1. Partner Center Account

- [ ] Microsoft Partner Center account created
- [ ] Developer account verified
- [ ] Payment profile configured (for paid apps/IAP)

### 2. App Identity

- [ ] Reserve app name: "Craig-O-Clean"
- [ ] App identity configured in Package.appxmanifest
- [ ] Publisher identity matches Partner Center

### 3. Store Listing Content

**App Name**: Craig-O-Clean

**Short Description** (100 chars):
```
Monitor system resources, manage processes, and optimize Windows 11 performance.
```

**Description** (10,000 chars max):
```
Craig-O-Clean is a powerful system monitoring and optimization tool designed for Windows 11.

FEATURES:

📊 Real-Time System Dashboard
• Live CPU usage monitoring (overall and per-core)
• Memory utilization with detailed breakdown
• Commit charge and available memory tracking
• Visual memory pressure indicator

📋 Advanced Process Manager
• Complete list of running processes
• CPU and memory usage per process
• End task and force kill options
• Search and sort functionality
• Protected system process detection

🔔 System Tray Integration
• Quick access from system tray
• Live metrics in tray popup
• One-click actions for top resource hogs
• Minimal resource footprint

🧹 Smart Cleanup Tools
• Guided cleanup recommendations
• Safe temporary file removal
• No aggressive "RAM cleaning" gimmicks
• Transparent about what gets cleaned

💎 Premium Features (7-Day Free Trial)
• Process termination actions
• Quick tray actions
• Bulk cleanup operations
• Advanced optimization tools

PRIVACY & SECURITY
• No data collection or telemetry
• All processing happens locally
• No internet required for core features
• Open about system access needs

SUBSCRIPTION OPTIONS
• Monthly: $0.99/month
• Yearly: $9.99/year (2 months free)
• Both include 7-day free trial

Built with WinUI 3 for the best Windows 11 experience. Fast, efficient, and designed to help you understand and manage your system resources.
```

### 4. Visual Assets

Required assets for Store listing:

| Asset | Size | Format |
|-------|------|--------|
| Store logo | 300x300 | PNG |
| App icon | Various | PNG |
| Hero image | 1920x1080 | PNG |
| Screenshots | 1366x768 min | PNG |
| Promotional images | Various | PNG |

**Screenshots to include:**
1. Dashboard view with metrics
2. Process list with sorting
3. System tray popup
4. Settings screen
5. Subscription/paywall screen

### 5. Age Rating

Complete IARC questionnaire:
- No violence, fear, sexuality, drugs, gambling
- No user-generated content
- No social features

**Expected Rating**: PEGI 3 / Everyone

## Build Configuration

### MSIX Packaging

The app uses MSIX packaging for Store distribution.

1. **Package Identity** in `Package.appxmanifest`:
```xml
<Identity Name="YourPublisher.CraigOClean"
          Publisher="CN=Your Publisher ID"
          Version="1.0.0.0" />
```

2. **Build MSIX Package**:
```bash
dotnet publish -c Release -p:Platform=x64
```

Or using Visual Studio:
- Right-click project > Publish > Create App Packages
- Select "Microsoft Store" distribution
- Configure version and architecture

### Architectures

Build for multiple architectures:
- x64 (required)
- ARM64 (recommended for Surface devices)

### Code Signing

For Store submission:
1. Signing is handled by Microsoft during ingestion
2. For sideloading, create a self-signed certificate

## Subscription Configuration

### Store-Managed Subscriptions

1. In Partner Center, go to **Add-ons**

2. Create Monthly Subscription:
   - Product ID: `craigoclean_monthly`
   - Product type: Subscription
   - Price: $0.99 USD
   - Billing period: Monthly
   - Free trial: 7 days

3. Create Yearly Subscription:
   - Product ID: `craigoclean_yearly`
   - Product type: Subscription
   - Price: $9.99 USD
   - Billing period: Yearly
   - Free trial: 7 days

### StoreContext API Integration

```csharp
// Query subscriptions
var storeContext = StoreContext.GetDefault();
var products = await storeContext.GetStoreProductsAsync(
    new[] { "Subscription" },
    new[] { "craigoclean_monthly", "craigoclean_yearly" }
);

// Check active licenses
var license = await storeContext.GetAppLicenseAsync();
foreach (var addon in license.AddOnLicenses)
{
    if (addon.Value.IsActive)
    {
        // User has active subscription
    }
}
```

## Capabilities & Permissions

Document required capabilities in manifest:

```xml
<Capabilities>
  <rescap:Capability Name="runFullTrust" />
  <Capability Name="internetClient" />
</Capabilities>
```

| Capability | Purpose |
|------------|---------|
| runFullTrust | Required for process management APIs |
| internetClient | Subscription verification |

### Process Access Justification

The app requires `runFullTrust` to:
- Enumerate all running processes
- Read process CPU/memory statistics
- Terminate user processes (with confirmation)
- Access performance counters

## Testing

### Windows App Certification Kit (WACK)

Before submission, run WACK:
1. Install Windows SDK
2. Run: `appcert.exe reset`
3. Run: `appcert.exe test -apptype desktop -packagefullname <PackageFullName>`

### Store Test Environment

1. Create private flight group in Partner Center
2. Add test accounts
3. Submit to flight group first
4. Test subscription flow end-to-end

## Submission Steps

1. **Create App Reservation**
   - Partner Center > Apps and games > New product
   - Reserve "Craig-O-Clean" name

2. **Configure Product Setup**
   - App type: Desktop application
   - Publishing option: Immediately after certification

3. **Properties**
   - Category: Utilities & tools
   - Subcategory: System utilities
   - Privacy policy URL
   - Website URL
   - Support contact

4. **Age Ratings**
   - Complete IARC questionnaire
   - Confirm rating for all markets

5. **Pricing and Availability**
   - Free download (with IAP subscriptions)
   - Select markets
   - Configure organizational licensing

6. **Add-ons**
   - Create subscription products
   - Configure pricing per market
   - Set trial periods

7. **Store Listings**
   - Add descriptions in each language
   - Upload screenshots and images
   - Add search terms

8. **Packages**
   - Upload MSIX package(s)
   - Verify package contents

9. **Submission Options**
   - Certification notes (if any)
   - Restricted capabilities justification

10. **Submit for Certification**

## Certification Notes

Include notes for Microsoft reviewers:

```
Craig-O-Clean is a system monitoring utility that provides:
1. Real-time CPU and memory monitoring
2. Process management (view, end task, force kill)
3. System tray integration for quick access

The app requires runFullTrust capability to access:
- Process enumeration APIs (Toolhelp32)
- Performance counters for CPU metrics
- Process termination (TerminateProcess API)

All process termination requires explicit user confirmation.
System-critical processes are protected from termination.

For testing subscriptions, use a test account or contact us for a promo code.
```

## Post-Certification

### Monitoring

- Check certification status in Partner Center
- Review any certification failures
- Monitor crash reports after release

### Updates

1. Increment version in Package.appxmanifest
2. Build new MSIX package
3. Submit update through Partner Center
4. Add release notes

## Troubleshooting

### Common Certification Failures

1. **Missing Privacy Policy**: Add URL in Properties
2. **Crash on Launch**: Test on clean Windows install
3. **API Compatibility**: Test on Windows 10 and 11
4. **Performance Issues**: Optimize startup time

### Support Resources

- [Windows App Certification Kit](https://docs.microsoft.com/windows/uwp/debug-test-perf/windows-app-certification-kit)
- [Partner Center Help](https://docs.microsoft.com/partner-center/)
- [Store Policies](https://docs.microsoft.com/windows/uwp/publish/store-policies)

## Direct Distribution (Alternative)

For distribution outside the Store:

1. Create self-signed certificate
2. Sign MSIX package
3. Distribute via website
4. Users must trust certificate before installing
5. Use Stripe for billing (separate flow)

See `src/CraigOClean/Services/StripeBillingService.cs` for direct billing implementation.
