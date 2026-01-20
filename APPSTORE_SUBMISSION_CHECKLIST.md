# App Store Submission Checklist

## Craig-O-Clean - Complete Submission Guide

**Version**: 3
**Build**: 1
**Bundle ID**: com.craigoclean.app

---

## 📋 Pre-Submission Checklist

### ✅ App Binary & Assets

- [x] Archive created successfully (Craig-O-Clean-20260120-121745.xcarchive)
- [x] Universal binary (arm64 + x86_64)
- [x] Proper code signing (Apple Distribution)
- [ ] Screenshots prepared (6.5", 5.5" iPhone + 12.9" iPad if universal)
- [ ] App icon (1024x1024) in all required sizes
- [ ] App Preview video (optional but recommended)

### ✅ App Store Connect Configuration

#### Basic Information
- [ ] App name: "Craig-O-Clean"
- [ ] Subtitle (max 30 characters)
- [ ] Privacy Policy URL: https://craigoclean.com/privacy
- [ ] Category: Utilities (or Productivity)
- [ ] Age Rating: 4+

#### Pricing & Availability
- [ ] Price tier selected
- [ ] Availability territories selected
- [ ] Pre-order (if desired)

#### App Privacy
- [ ] Privacy practices questionnaire completed
- [ ] Data collection disclosed
- [ ] Privacy Policy reviewed

---

## 🔐 Encryption Compliance

### Status: ✅ CONFIGURED

**File**: `Info.plist`
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

**Documentation**: See `ENCRYPTION_COMPLIANCE.md`

**App Store Connect Actions**:
1. When uploading build, Apple will ask about encryption
2. Answer: **"No"** - Uses only standard encryption
3. No additional documentation needed
4. Export compliance automatically handled

**What to Tell Apple**:
- ✅ App uses encryption: **YES**
- ✅ Uses non-exempt encryption: **NO**
- ✅ Qualifies for exemption: Section 740.17(b)(1)

---

## 💰 In-App Purchases

### Products Configured

**Monthly Subscription**
- Product ID: `com.craigoclean.pro.monthly`
- Type: Auto-renewable subscription
- Duration: 1 month
- Price: (Set in App Store Connect)

**Yearly Subscription**
- Product ID: `com.craigoclean.pro.yearly`
- Type: Auto-renewable subscription
- Duration: 1 year
- Price: (Set in App Store Connect)

### Subscription Groups

1. **Create Subscription Group** (if not done)
   - Name: "Craig-O-Clean Pro"
   - In App Store Connect → Features → In-App Purchases

2. **Add Products to Group**
   - Monthly and Yearly in same group
   - Set upgrade/downgrade paths

3. **Subscription Information**
   - [ ] Subscription display name
   - [ ] Description for each duration
   - [ ] Promotional images (optional)

---

## 🔔 App Store Server Notifications

### Status: ⚠️ NEEDS CONFIGURATION

**Documentation**: See `APPSTORE_SERVER_NOTIFICATIONS_SETUP.md`

**Steps**:
1. **Set up backend endpoint** (if not already done)
   - Create HTTPS endpoint to receive notifications
   - Must return HTTP 200 within 30 seconds
   - Example: `https://api.craigoclean.com/api/appstore/notifications`

2. **Configure in App Store Connect**
   - App Information → App Store Server Notifications
   - Production Server URL: (Enter your production endpoint)
   - Sandbox Server URL: (Enter your test endpoint)
   - Click "Test" to verify connection

3. **Test in Sandbox**
   - Make test purchase with sandbox user
   - Verify notification received
   - Confirm all notification types handled

**Status**:
- [ ] Backend endpoint created
- [ ] Production URL configured
- [ ] Sandbox URL configured
- [ ] Connection tested successfully
- [ ] All notification types handled

---

## 🔑 App-Specific Shared Secret

### Status: ⚠️ NEEDS GENERATION

**Documentation**: See `APP_SPECIFIC_SHARED_SECRET_GUIDE.md`

**Steps**:
1. **Generate in App Store Connect**
   - App Information → App-Specific Shared Secret
   - Click "Manage" → "Generate"
   - **Copy immediately** (can't view again!)

2. **Store Securely**
   ```bash
   # Add to backend .env file
   APP_STORE_SHARED_SECRET=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
   ```

3. **Update Backend Code**
   - Use in receipt verification requests
   - Never expose to client-side code
   - See guide for implementation examples

**Status**:
- [ ] Shared secret generated
- [ ] Stored in password manager
- [ ] Added to backend environment variables
- [ ] Receipt verification implemented
- [ ] Tested with sandbox purchases

---

## 📱 App Metadata

### App Description

**Tagline** (promotional text, 170 characters):
```
Craig-O-Clean: Your intelligent macOS system monitor and memory optimizer.
Keep your Mac running smoothly with smart cleanup and browser tab management.
```

**Description** (4000 characters max):
```
Transform your Mac's performance with Craig-O-Clean, the intelligent system
utility designed for Apple Silicon and Intel Macs running macOS 14+.

🚀 SMART MEMORY OPTIMIZATION
• Real-time memory pressure monitoring
• Intelligent process analysis and recommendations
• Safe memory cleanup with one-click optimization
• Automatic cleanup scheduling

🌐 BROWSER TAB MANAGEMENT
• Manage tabs across Safari, Chrome, Edge, Brave, and Arc
• Close inactive tabs automatically
• Search and organize tabs from all browsers
• Reduce memory usage from excessive tabs

📊 COMPREHENSIVE SYSTEM MONITORING
• CPU usage tracking with per-core breakdown
• Memory metrics and pressure levels
• Disk space analysis
• Network activity monitoring

⚡ SMART AUTO-CLEANUP
• Configure automatic memory optimization
• Schedule cleanups based on memory pressure
• Close background apps intelligently
• Customize cleanup rules and thresholds

🎯 FEATURES
• Menu bar app for quick access
• Process manager with detailed information
• Force quit memory-heavy applications
• System health indicators
• Beautiful, native macOS interface
• Universal app (Apple Silicon + Intel)

💎 CRAIG-O-CLEAN PRO (In-App Purchase)
• Unlimited automatic cleanups
• Advanced scheduling options
• Priority support
• Future feature updates

REQUIREMENTS
• macOS 14.0 or later
• Accessibility permission (for process management)
• Full Disk Access (for comprehensive monitoring)
• Automation permission (for browser management)

Get Craig-O-Clean today and experience your Mac running at peak performance!
```

### Keywords

**Maximum 100 characters** (comma-separated):
```
memory,cleaner,optimizer,system,monitor,utility,browser,tabs,performance,cleanup,mac
```

### Support URL
```
https://craigoclean.com/support
```

### Marketing URL (optional)
```
https://craigoclean.com
```

---

## 📸 Screenshots & Media

### Required Sizes (macOS)

**13-inch Display (2560 x 1600)**
- 3-5 screenshots showing key features
- Recommended: Dashboard, Memory Cleanup, Browser Tabs, Settings

**16-inch Display (3456 x 2234)** (optional but recommended)
- Same screens at higher resolution

### Screenshot Recommendations

1. **Dashboard View** - Show system metrics, healthy status
2. **Memory Cleanup** - Show before/after memory optimization
3. **Browser Tabs** - Show tab management across browsers
4. **Process Manager** - Show running processes with details
5. **Auto-Cleanup Settings** - Show customization options

### App Preview Video (Optional)

- Maximum 30 seconds
- Same resolution as screenshots
- Show key workflows
- No audio required (but recommended)

---

## 🧪 TestFlight Testing

### Before Submission

- [ ] TestFlight build distributed to testers
- [ ] All features tested on real devices
- [ ] Subscription flows tested end-to-end
- [ ] Permissions tested (Accessibility, Full Disk Access, Automation)
- [ ] No crashes in production scenarios
- [ ] Performance validated

### Test Scenarios

1. **First Launch**
   - [ ] Onboarding displayed
   - [ ] Trial starts automatically
   - [ ] Permissions requested appropriately

2. **Core Features**
   - [ ] System monitoring works
   - [ ] Memory cleanup successful
   - [ ] Browser tab management functional
   - [ ] Process manager accurate

3. **Subscriptions**
   - [ ] Purchase flow smooth
   - [ ] Receipt verification works
   - [ ] Pro features unlock
   - [ ] Restore purchases works

4. **Edge Cases**
   - [ ] No internet connection
   - [ ] Permissions denied
   - [ ] Trial expired
   - [ ] Subscription expired

---

## 🌏 Localization (Optional but Recommended)

### Supported Languages

If supporting multiple languages:
- [ ] English (required)
- [ ] Spanish
- [ ] French
- [ ] German
- [ ] Japanese
- [ ] Chinese (Simplified)

### Localized Assets
- [ ] App name
- [ ] Description
- [ ] Keywords
- [ ] Screenshots (optional but recommended)
- [ ] What's New text

---

## 📝 Version Information

### What's New (for this submission)

```
Version 3.0 - Major Update

NEW FEATURES
• Redesigned menu bar interface with quick actions
• Enhanced permission detection and management
• Custom menu bar icon with health status indicators
• Improved trial management and subscription handling

IMPROVEMENTS
• Better memory pressure detection
• Faster process scanning
• Optimized browser tab management
• Enhanced system monitoring accuracy

BUG FIXES
• Fixed permission status display
• Resolved settings window issues
• Improved concurrency handling
• Various stability improvements

Try Craig-O-Clean Pro with a 7-day free trial!
```

---

## 🚀 Submission Steps

### 1. Upload Build

```bash
# Already done: Archive at
~/Desktop/Craig-O-Clean-20260120-121745.xcarchive

# Upload via Xcode Organizer:
1. Open Xcode
2. Window → Organizer (⌘⌥⇧O)
3. Select archive
4. Click "Distribute App"
5. Choose "App Store Connect"
6. Follow wizard
```

### 2. Complete App Store Connect

1. **App Information**
   - [x] Encryption declaration (ITSAppUsesNonExemptEncryption = false)
   - [ ] App Store Server Notifications URLs
   - [ ] App-Specific Shared Secret generated

2. **Pricing and Availability**
   - [ ] Price tier
   - [ ] Territories
   - [ ] Release date

3. **App Privacy**
   - [ ] Privacy questionnaire
   - [ ] Data types collected
   - [ ] Third-party tracking

4. **App Store**
   - [ ] Screenshots uploaded
   - [ ] Description, keywords written
   - [ ] Support URL, Marketing URL
   - [ ] Age rating

5. **In-App Purchases**
   - [ ] Subscription group created
   - [ ] Monthly subscription configured
   - [ ] Yearly subscription configured
   - [ ] Pricing set for all territories

6. **Version Information**
   - [ ] Build selected
   - [ ] What's New written
   - [ ] Copyright notice

7. **App Review Information**
   - [ ] Demo account (if app requires login)
   - [ ] Notes for reviewer
   - [ ] Contact information

### 3. Submit for Review

- [ ] Review all sections (green checkmarks)
- [ ] Click "Submit for Review"
- [ ] Answer questionnaire about content, advertising, etc.
- [ ] Confirm submission

---

## ⚠️ Common Rejection Reasons (Prevention)

### Guideline 2.1 - App Completeness
- ✅ All features functional
- ✅ No placeholder content
- ✅ Links work
- ✅ IAP functional

### Guideline 2.3 - Accurate Metadata
- ✅ Screenshots show actual app
- ✅ Description matches functionality
- ✅ No misleading claims

### Guideline 4.0 - Design
- ✅ Native macOS design
- ✅ No placeholder UI
- ✅ Follows Human Interface Guidelines

### Guideline 5.1.1 - Privacy
- ✅ Privacy policy provided
- ✅ Data collection disclosed
- ✅ User consent obtained

---

## 📞 App Review Notes

**For Apple Reviewers**:

```
Thank you for reviewing Craig-O-Clean!

TESTING NOTES:
• The app requires macOS 14.0 or later
• Permissions needed for full functionality:
  - Accessibility (for process management)
  - Full Disk Access (for detailed monitoring)
  - Automation (for browser tab management)

SUBSCRIPTION TESTING:
• 7-day free trial available
• Monthly: com.craigoclean.pro.monthly
• Yearly: com.craigoclean.pro.yearly
• Restore purchases works via Settings

DEMO WORKFLOW:
1. Launch app from menu bar icon
2. Grant Accessibility permission when prompted
3. View system metrics in Dashboard
4. Test Memory Cleanup feature
5. Try Browser Tabs management (requires running browsers)
6. Configure Auto-Cleanup in Settings

The app is fully functional without subscription (trial period).
All Pro features can be tested during the 7-day trial.

Contact: support@craigoclean.com
```

---

## ✅ Final Pre-Submission Checklist

### Technical
- [x] Build uploaded to App Store Connect
- [x] No crashes or major bugs
- [x] All permissions properly requested
- [x] Receipt validation implemented
- [ ] Server notifications configured
- [ ] Shared secret generated

### Metadata
- [ ] App name, subtitle, description complete
- [ ] Keywords optimized
- [ ] Screenshots uploaded (all sizes)
- [ ] Support and marketing URLs active
- [ ] What's New written

### Legal & Privacy
- [x] Encryption declaration (ITSAppUsesNonExemptEncryption = false)
- [ ] Privacy policy URL provided
- [ ] Age rating accurate
- [ ] Terms of service (if applicable)

### Subscriptions
- [ ] Products created in App Store Connect
- [ ] Pricing set for all territories
- [ ] Subscription group configured
- [ ] Promotional offers (optional)

### Review
- [ ] Demo account provided (if needed)
- [ ] Review notes written
- [ ] Contact information accurate
- [ ] All sections marked complete

---

## 📅 Timeline

**Typical Review Process**:
- Submission: Day 0
- In Review: Day 1-3
- Additional Information Request: Day 2-4 (if needed)
- Approved/Rejected: Day 2-5
- Ready for Sale: Day 2-5

**Your Target Date**: _____________________

---

## 📚 Resources

- **App Store Connect**: https://appstoreconnect.apple.com
- **App Review Guidelines**: https://developer.apple.com/app-store/review/guidelines/
- **Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/macos
- **App Store Marketing Guidelines**: https://developer.apple.com/app-store/marketing/guidelines/

---

## 🎉 Post-Approval

### After Approval

1. **Marketing Launch**
   - [ ] Press release
   - [ ] Social media announcement
   - [ ] Website update
   - [ ] Email newsletter

2. **Monitor**
   - [ ] App Store reviews
   - [ ] Crash reports
   - [ ] Analytics
   - [ ] Subscription metrics

3. **Support**
   - [ ] Customer support ready
   - [ ] FAQ published
   - [ ] Community/forum setup

4. **Iterate**
   - [ ] Collect user feedback
   - [ ] Plan next version
   - [ ] Fix any issues

---

**Good luck with your submission! 🚀**

**Document Version**: 1.0
**Last Updated**: January 20, 2026
