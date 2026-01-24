# TestFlight Distribution Guide

## Craig-O Clean Terminator Edition - Beta Testing Program

This guide covers the complete TestFlight setup, beta testing, and distribution process.

---

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Build Preparation](#build-preparation)
3. [TestFlight Configuration](#testflight-configuration)
4. [Internal Testing](#internal-testing)
5. [External Testing](#external-testing)
6. [Beta Tester Management](#beta-tester-management)
7. [Feedback Collection](#feedback-collection)
8. [Iteration Process](#iteration-process)

---

## Initial Setup

### Prerequisites

#### 1. Apple Developer Account
- **Type**: Individual or Organization
- **Cost**: $99/year
- **URL**: https://developer.apple.com

#### 2. App Store Connect Access
- **URL**: https://appstoreconnect.apple.com
- **Role**: Admin or App Manager

#### 3. Xcode Configuration
- **Version**: Xcode 15.0+
- **macOS**: Ventura (13.0) or later
- **Command Line Tools**: Installed

#### 4. Code Signing
- **Team**: NeuralQuantum.ai LLC
- **Bundle ID**: `ai.neuralquantum.CraigOTerminator`
- **Certificates**:
  - Apple Distribution Certificate
  - Mac App Distribution Certificate

---

## Build Preparation

### Step 1: Version & Build Number

Update in Xcode:
1. Select project in Navigator
2. Select target "CraigOTerminator"
3. General tab:
   - **Version**: 1.0.0
   - **Build**: Auto-increment (e.g., 2026.1.24.1)

Or via command line:
```bash
agvtool new-marketing-version 1.0.0
agvtool next-version -all
```

### Step 2: Code Signing

**Automatic Signing (Recommended)**:
1. Xcode → Signing & Capabilities
2. ✓ Automatically manage signing
3. Team: Select your team
4. Provisioning Profile: Automatic

**Manual Signing**:
1. Create App ID in Developer Portal
2. Create Provisioning Profile (App Store Distribution)
3. Download and install profiles
4. Select in Xcode

### Step 3: Entitlements Verification

Ensure `CraigOTerminator.entitlements` includes:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Apple Sign In -->
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>

    <!-- iCloud -->
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.ai.neuralquantum.CraigOTerminator</string>
    </array>

    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
        <string>CloudDocuments</string>
    </array>

    <key>com.apple.developer.ubiquity-kvstore-identifier</key>
    <string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>

    <!-- Sandbox (required for Mac App Store) -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- Required for system utilities -->
    <key>com.apple.security.scripting-targets</key>
    <dict>
        <key>com.apple.systemevents</key>
        <array>
            <string>com.apple.systemevents</string>
        </array>
    </dict>
</dict>
</plist>
```

### Step 4: Info.plist Validation

Required keys:
- `CFBundleIdentifier`: ai.neuralquantum.CraigOTerminator
- `CFBundleShortVersionString`: 1.0.0
- `CFBundleVersion`: Build number
- `LSMinimumSystemVersion`: 13.0
- `LSUIElement`: true (for menu bar only)
- `NSAppleScriptEnabled`: true

### Step 5: Build Settings

**Release Configuration**:
1. Build Configuration: Release
2. Optimization Level: -O (Fastest)
3. Strip Debug Symbols: Yes
4. Enable Bitcode: No (not required for macOS)
5. Validate Build: Yes

### Step 6: Clean Build

```bash
# Navigate to project
cd /Volumes/VibeStore/Craig-O-Cleaner/TerminatorEdition/Xcode

# Clean build folder
xcodebuild clean -project CraigOTerminator.xcodeproj -scheme CraigOTerminator

# Archive for distribution
xcodebuild archive \
  -project CraigOTerminator.xcodeproj \
  -scheme CraigOTerminator \
  -configuration Release \
  -archivePath ./build/CraigOTerminator.xcarchive
```

---

## TestFlight Configuration

### Step 1: Create App in App Store Connect

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "My Apps"
3. Click "+" → "New App"
4. Fill in:
   - **Platform**: macOS
   - **Name**: Craig-O Clean Terminator Edition
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: ai.neuralquantum.CraigOTerminator
   - **SKU**: CRAIG-O-TERMINATOR-2026
   - **User Access**: Full Access

### Step 2: App Information

Navigate to App Information and set:
- **Category**: Utilities
- **Secondary Category**: Productivity
- **Content Rights**: Contains third-party content
- **Age Rating**: 4+

### Step 3: TestFlight Settings

1. Click "TestFlight" tab
2. Set up test information:

**Beta App Information**:
```
Beta App Description:
[Copy from APP_STORE_CONNECT.md]

Feedback Email: beta@neuralquantum.ai
Marketing URL: https://neuralquantum.ai/craig-o
Privacy Policy URL: https://neuralquantum.ai/craig-o/privacy
```

**Beta App Review Information**:
```
Contact Information:
- First Name: Tommy
- Last Name: Xaypanya
- Phone: +1 (XXX) XXX-XXXX
- Email: appstore@neuralquantum.ai

Sign-in Required: No

Review Notes:
[Copy from APP_STORE_CONNECT.md]
```

---

## Internal Testing

### Phase 1: Team Testing (Week 1)

**Objective**: Verify basic functionality before external beta

#### Setup Internal Testing

1. TestFlight → Internal Testing
2. Create new group: "Core Team"
3. Add internal testers (max 100):
   - Enter Apple IDs of team members
   - They must have App Store Connect access

#### Upload Build

**Via Xcode**:
1. Product → Archive
2. Window → Organizer
3. Select archive
4. Click "Distribute App"
5. Select "TestFlight & App Store"
6. Follow prompts
7. Upload

**Via Transporter App**:
1. Export archive as .pkg
2. Open Transporter app
3. Drag .pkg file
4. Click "Deliver"

#### Build Processing
- Upload time: 5-15 minutes
- Processing time: 10-60 minutes
- Status: Check in App Store Connect

#### Internal Testing Checklist

- [ ] App launches successfully
- [ ] Menu bar icon appears
- [ ] Quick cleanup works
- [ ] Full cleanup works
- [ ] Process management functional
- [ ] Browser tab detection works
- [ ] Settings save/load correctly
- [ ] Apple Sign In works
- [ ] iCloud sync functional
- [ ] No critical crashes
- [ ] Performance acceptable
- [ ] UI renders correctly
- [ ] Dark mode works
- [ ] Autonomous mode operational

#### Feedback Collection (Internal)

Create Google Form or Notion page:
```
Internal Beta Feedback - Build [X]

1. What device/macOS version are you using?
2. What features did you test?
3. What worked well?
4. What didn't work?
5. Any crashes or errors?
6. Performance issues?
7. UI/UX feedback?
8. Feature requests?
9. Overall rating (1-10)?
10. Additional comments?
```

---

## External Testing

### Phase 2: Limited Beta (Week 2)

**Objective**: Get real user feedback from 50-100 testers

#### Setup External Testing

1. TestFlight → External Testing
2. Create new group: "Beta Testers - Wave 1"
3. Add build to group
4. Submit for Beta App Review

**Beta App Review**:
- **Timeline**: Usually 24-48 hours
- **Requirements**: All info filled in TestFlight settings
- **Status**: Check in App Store Connect

#### Recruit Beta Testers

**Methods**:
1. **Email List**: Notify existing users
2. **Social Media**: Twitter, Reddit, forums
3. **Website**: Landing page with signup form
4. **Product Hunt**: Post beta announcement
5. **Communities**: Mac-related Discord/Slack groups

**Beta Signup Form**:
```
Craig-O Clean Beta Program

Name: _______________
Email: _______________
Mac Model: _______________
macOS Version: _______________
How did you hear about us? _______________
What features are you most excited about? _______________

[ ] I agree to provide feedback
[ ] I understand this is beta software
```

#### Invite Testers

**Via Email**:
1. Export email list
2. App Store Connect → TestFlight → External Groups
3. Add testers by email
4. Click "Invite"

**Via Public Link** (Max 10,000 testers):
1. TestFlight → Public Link
2. Enable public link
3. Share: https://testflight.apple.com/join/XXXXXXXX

#### Onboarding Email Template

```
Subject: Welcome to Craig-O Clean Beta! 🚀

Hi [Name],

Welcome to the Craig-O Clean Terminator Edition beta program!

GETTING STARTED:
1. Install TestFlight from the Mac App Store
2. Click your invitation link (or open email on your Mac)
3. Install Craig-O Clean
4. Start cleaning!

WHAT TO TEST:
✓ Quick Cleanup (Menu Bar → Quick Cleanup)
✓ Process Management (Main Window → Processes)
✓ Browser Tab Management
✓ Settings & Preferences
✓ Optional: Apple Sign In + iCloud Sync
✓ Optional: Ollama AI Integration

HOW TO PROVIDE FEEDBACK:
• Use TestFlight's built-in feedback (shake or screenshot)
• Email us: beta@neuralquantum.ai
• Fill out weekly survey: [link]

IMPORTANT NOTES:
⚠️ This is beta software - use at your own risk
⚠️ Some features may not work perfectly
⚠️ Your feedback is invaluable!

SUPPORT:
Email: beta@neuralquantum.ai
Response time: <24 hours

Thank you for helping make Craig-O Clean better!

Best,
Tommy Xaypanya
NeuralQuantum.ai Team

P.S. As a beta tester, you'll get free access to Pro features when we launch! 🎁
```

---

## Beta Tester Management

### Tester Groups

**Recommended Structure**:
1. **Internal Testing** (App Store Connect users)
   - Core team: 5-10 people
   - QA team: 2-5 people

2. **External Testing - Wave 1** (Week 2)
   - Early adopters: 50 testers
   - High engagement expected

3. **External Testing - Wave 2** (Week 3)
   - General beta: 100-500 testers
   - Broader testing

4. **External Testing - Wave 3** (Week 4+)
   - Public beta: Up to 10,000 testers
   - Via public link

### Tester Metrics

Track in spreadsheet:
```
Tester Name | Email | Group | Build | Installed | Active | Feedback | Crashes | Rating
```

**Key Metrics**:
- Install rate (invited vs installed)
- Active testers (used in last 7 days)
- Feedback submissions
- Crash-free rate
- Average session duration
- Feature usage

### Communication Schedule

**Weekly Update Email**:
```
Subject: Craig-O Clean Beta Update - Week [X]

Hi Beta Testers!

WHAT'S NEW THIS WEEK:
• [Feature 1]
• [Bug fix 2]
• [Improvement 3]

METRICS:
• Active testers: [X]
• Crash-free rate: [X]%
• Average rating: [X]/5

TOP FEEDBACK:
1. [Issue 1] - Fixed ✅
2. [Request 1] - Coming next week
3. [Bug 1] - Under investigation

WHAT TO TEST THIS WEEK:
→ [Specific feature or scenario]

THANK YOU:
Special thanks to [tester names] for excellent feedback!

Keep the feedback coming!
[Team]
```

---

## Feedback Collection

### Methods

#### 1. TestFlight Built-in Feedback
**Pros**:
- Includes screenshots
- Crash logs attached
- Device info automatic

**Cons**:
- Limited organization
- No threading

**Best for**: Bug reports, crashes

#### 2. Dedicated Feedback Tool

**Options**:
- **Canny**: Feature requests, voting
- **Discord**: Community discussions
- **Notion**: Organized feedback database
- **GitHub Issues**: Public bug tracking

**Recommended**: Discord for community + Notion for tracking

#### 3. Surveys

**Weekly Survey** (Google Forms/Typeform):
```
Craig-O Clean - Week [X] Survey

1. How many times did you use the app this week?
   [ ] Daily [ ] 3-5 times [ ] 1-2 times [ ] Not at all

2. Which features did you use? (Check all)
   [ ] Quick Cleanup
   [ ] Full Cleanup
   [ ] Process Management
   [ ] Browser Management
   [ ] Diagnostics
   [ ] Autonomous Mode
   [ ] iCloud Sync
   [ ] Ollama AI

3. Rate your experience (1-5):
   Performance: ⭐⭐⭐⭐⭐
   Reliability: ⭐⭐⭐⭐⭐
   Ease of Use: ⭐⭐⭐⭐⭐
   Design: ⭐⭐⭐⭐⭐

4. Did you encounter any bugs or issues?
   [Text field]

5. What feature should we prioritize next?
   [Text field]

6. Would you recommend this to a friend? (1-10)
   1 2 3 4 5 6 7 8 9 10

7. Any other feedback?
   [Text field]
```

### Feedback Tracking

**Notion Template**:
```
Feedback Database

Properties:
- ID (Auto-number)
- Tester Name (Text)
- Email (Email)
- Build Number (Select)
- Category (Select: Bug, Feature Request, UI/UX, Performance)
- Priority (Select: Critical, High, Medium, Low)
- Status (Select: New, In Progress, Fixed, Won't Fix)
- Description (Long text)
- Screenshot (File)
- Assigned To (Person)
- Created Date (Date)
- Resolved Date (Date)

Views:
- All Feedback
- Open Bugs
- Feature Requests
- By Priority
- By Tester
- By Build
```

---

## Iteration Process

### Development Cycle

**2-Week Sprints**:

#### Week 1: Build & Test
- **Monday-Tuesday**: Development
- **Wednesday**: Internal build
- **Thursday**: Internal testing
- **Friday**: Fixes & improvements

#### Week 2: External Beta
- **Monday**: Upload to TestFlight
- **Tuesday**: Beta App Review approval
- **Wednesday**: Invite testers
- **Thursday-Sunday**: Collect feedback

### Version Numbering

**Semantic Versioning**: MAJOR.MINOR.PATCH
- **1.0.0**: Initial release
- **1.0.1**: Bug fixes
- **1.1.0**: New features
- **2.0.0**: Major changes

**Build Numbers**: DATE.INCREMENT
- **2026.1.24.1**: First build on Jan 24, 2026
- **2026.1.24.2**: Second build same day
- **2026.1.25.1**: First build next day

### Release Notes Template

```
Version 1.0.0 (Build 2026.1.24.1)

NEW FEATURES:
• Revolutionary autonomous agent architecture
• Apple Sign In integration
• iCloud settings sync
• Advanced process management
• Cross-browser tab management

IMPROVEMENTS:
• Faster memory cleanup
• More accurate resource detection
• Improved dark mode support
• Better error messages

BUG FIXES:
• Fixed crash when terminating system processes
• Resolved iCloud sync delay issue
• Corrected memory calculation accuracy
• Fixed menu bar icon not appearing on some systems

KNOWN ISSUES:
• Ollama installation must be done manually
• Some browser tab counts may be delayed
• First launch requires admin password

Thank you for testing!
```

### Graduation Criteria

**Ready for App Store when**:
- ✅ Crash-free rate > 99.5%
- ✅ Average rating > 4.5/5
- ✅ All critical bugs fixed
- ✅ At least 50 active beta testers
- ✅ Positive feedback on core features
- ✅ Performance metrics acceptable
- ✅ iCloud sync stable
- ✅ Apple Sign In working
- ✅ All TestFlight feedback addressed
- ✅ App Store screenshots finalized
- ✅ Privacy policy published
- ✅ Support infrastructure ready

---

## Best Practices

### Do's
✓ Communicate frequently with testers
✓ Acknowledge all feedback
✓ Fix crashes immediately
✓ Iterate quickly (weekly builds)
✓ Thank beta testers publicly
✓ Offer early bird perks
✓ Document everything
✓ Test on various macOS versions

### Don'ts
✗ Ignore negative feedback
✗ Release broken builds
✗ Over-promise features
✗ Spam testers with updates
✗ Neglect TestFlight console
✗ Skip beta app review
✗ Forget to increment build numbers
✗ Rush to App Store

---

## Troubleshooting

### Common Issues

#### Build Upload Fails
**Causes**:
- Invalid code signing
- Missing entitlements
- Incorrect bundle ID

**Solutions**:
1. Verify code signing in Xcode
2. Clean build folder
3. Check entitlements file
4. Ensure bundle ID matches App Store Connect

#### Beta App Review Rejection
**Common Reasons**:
- Incomplete test information
- Missing privacy policy
- Unclear instructions
- Sign-in issues

**Solutions**:
- Provide detailed review notes
- Add demo credentials if needed
- Include video demonstration
- Respond quickly to feedback

#### Testers Can't Install
**Causes**:
- macOS version too old
- TestFlight not installed
- Apple ID mismatch

**Solutions**:
- Verify system requirements
- Send installation guide
- Check tester email matches Apple ID

---

## Resources

### Apple Documentation
- [TestFlight Help](https://developer.apple.com/testflight/)
- [App Store Connect Guide](https://developer.apple.com/app-store-connect/)
- [Beta Testing](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)

### Tools
- **Xcode**: Build and archive
- **Transporter**: Upload builds
- **TestFlight**: Manage testers
- **App Store Connect**: Configure app

### Support
- **Email**: appstore@neuralquantum.ai
- **Discord**: [Community link]
- **Documentation**: https://neuralquantum.ai/craig-o/docs

---

**Last Updated**: January 24, 2026
**Version**: 1.0
**Team**: NeuralQuantum.ai LLC
