# Google Play Store Submission Guide

This document provides instructions for submitting Craig-O-Clean to the Google Play Store.

## Pre-Submission Checklist

### 1. App Content

- [ ] App name: "Craig-O-Clean: System Monitor"
- [ ] Short description (80 chars max)
- [ ] Full description (4000 chars max)
- [ ] App icon (512x512 PNG)
- [ ] Feature graphic (1024x500 PNG)
- [ ] Screenshots (min 2, max 8 per device type)
  - [ ] Phone screenshots (16:9 or 9:16)
  - [ ] 7-inch tablet screenshots
  - [ ] 10-inch tablet screenshots
- [ ] Promo video (optional, YouTube URL)

### 2. Store Listing Content

**Short Description:**
```
Monitor system resources, manage apps, and optimize your device performance.
```

**Full Description:**
```
Craig-O-Clean is your comprehensive system monitoring and optimization companion for Android.

KEY FEATURES:

📊 Real-Time Dashboard
• Monitor CPU usage in real-time
• Track RAM and memory utilization
• View memory pressure indicators
• Identify resource-heavy applications

📱 Smart App Manager
• View all running applications
• See detailed app resource usage
• Quick access to app settings
• Sort and search functionality

🔔 Quick Access
• Persistent notification with live stats
• Quick Settings tile for instant access
• One-tap access to top resource consumers

💎 Premium Features (7-Day Free Trial)
• End background apps
• Quick cleanup actions
• Advanced optimization tools
• Priority support

PRIVACY FIRST
• No personal data collection
• All processing happens on-device
• No ads, ever

SUBSCRIPTION OPTIONS
• Monthly: $0.99/month
• Yearly: $9.99/year (save 17%)
• Both include 7-day free trial

Download Craig-O-Clean today and take control of your device's performance!
```

### 3. App Category

- **Category**: Tools
- **Tags**: system monitor, memory cleaner, task manager, optimization

### 4. Content Rating

Complete the content rating questionnaire:
- Violence: None
- Sexual Content: None
- Language: None
- Controlled Substances: None
- User-Generated Content: None

**Expected Rating**: PEGI 3 / Everyone

### 5. Target Audience

- **Target Age Group**: 18 and over (system utility app)
- **Not designed for children**

### 6. Privacy Policy

URL to privacy policy is required. Include:
- Data collection practices (minimal/none)
- Usage of permissions
- Third-party services (billing only)
- Contact information

**Sample Privacy Policy URL**: `https://craigoclean.com/privacy`

### 7. App Access

- Full app functionality available
- No special access instructions needed
- Subscription can be tested with license testing

## Build Configuration

### Signing

1. Create a keystore for release signing:
```bash
keytool -genkey -v -keystore craigoclean-release.keystore \
  -alias craigoclean -keyalg RSA -keysize 2048 -validity 10000
```

2. Configure signing in `app/build.gradle.kts`:
```kotlin
android {
    signingConfigs {
        create("release") {
            storeFile = file("craigoclean-release.keystore")
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = "craigoclean"
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### Building Release Bundle

```bash
./gradlew bundleRelease
```

Output: `app/build/outputs/bundle/release/app-release.aab`

### ProGuard/R8

R8 is enabled by default for release builds. Custom rules in `proguard-rules.pro`.

## Subscription Configuration

### In-App Products Setup

1. Go to Play Console > Monetize > Products > Subscriptions

2. Create Monthly Subscription:
   - Product ID: `craigoclean_monthly`
   - Name: "Craig-O-Clean Monthly"
   - Description: "Full access to all Craig-O-Clean features"
   - Default price: $0.99 USD
   - Billing period: Monthly
   - Free trial: 7 days

3. Create Yearly Subscription:
   - Product ID: `craigoclean_yearly`
   - Name: "Craig-O-Clean Yearly"
   - Description: "Full access to all Craig-O-Clean features - Best Value"
   - Default price: $9.99 USD
   - Billing period: Yearly
   - Free trial: 7 days

### Testing

1. Add license testers in Play Console:
   - Settings > License testing
   - Add tester email addresses

2. Use test tracks:
   - Internal testing (fastest)
   - Closed testing
   - Open testing

## Required Permissions

Document why each permission is needed:

| Permission | Usage |
|------------|-------|
| `QUERY_ALL_PACKAGES` | View installed apps for task manager |
| `PACKAGE_USAGE_STATS` | Get app usage statistics |
| `FOREGROUND_SERVICE` | Persistent notification service |
| `POST_NOTIFICATIONS` | Show status notifications |
| `RECEIVE_BOOT_COMPLETED` | Start monitoring on device boot |
| `INTERNET` | Billing and subscription verification |

### Permission Declarations

In Play Console, declare sensitive permissions:
- `QUERY_ALL_PACKAGES`: Required for core app manager functionality
- `PACKAGE_USAGE_STATS`: Required for usage statistics display

## App Review Tips

1. **Clearly explain app functionality** in store listing
2. **Demonstrate value** over built-in Android tools
3. **Be transparent** about subscription pricing
4. **Respond promptly** to review feedback
5. **Test thoroughly** on multiple devices

## Assets Required

### App Icon
- 512x512 PNG (32-bit with alpha)
- No transparency in final icon
- Follows Google Play icon guidelines

### Screenshots
Minimum requirements:
- 2 phone screenshots
- Recommended: 8 screenshots showing key features

Screenshot content suggestions:
1. Dashboard with metrics
2. Process/app list
3. App detail view
4. Settings screen
5. Subscription/paywall
6. Quick Settings tile
7. Notification panel
8. Memory cleanup results

### Feature Graphic
- 1024x500 PNG or JPG
- No text in margins (safe zone)
- Represents app functionality

## Submission Steps

1. **Create app** in Play Console
2. **Set up store listing** with all content
3. **Upload AAB** to internal testing
4. **Configure pricing** and distribution
5. **Complete content rating** questionnaire
6. **Set up subscriptions** in Monetize section
7. **Add privacy policy** URL
8. **Review and publish** to testing track
9. **Promote** to production after testing

## Post-Launch

- Monitor crash reports in Android Vitals
- Respond to user reviews
- Track subscription metrics
- Plan regular updates

## Contact

For submission questions, contact the development team.
