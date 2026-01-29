# App Store Compliance Guide

This document outlines the Apple App Store compliance measures implemented in Craig-O-Clean Lite.

## Core Compliance Principles

### 1. No External Purchase Links

The Lite edition **never** includes:
- Direct purchase links
- Prices or pricing information
- "Buy", "Purchase", "Subscribe" buttons
- Checkout or payment flows
- In-app purchase prompts for Pro features

### 2. No Upgrade Pressure

The app avoids:
- Modal paywalls blocking functionality
- Forced upgrade flows
- Recurring "upgrade" prompts
- Time-limited offers or scarcity messaging
- Banner ads for Pro edition

### 3. Standalone Value

Lite is a fully functional product:
- All advertised features work
- No artificial limitations for upsell
- Useful for typical user cache cleanup
- Complete without Pro

## Implemented Funnel Design

### Compare Editions Sheet

Location: Settings → "Compare Craig-O-Clean Editions"

Content:
- Side-by-side feature comparison
- Neutral, informational language
- "Copy Pro Info Link" button (primary)
- No prices or purchase CTAs

### Pro Feature Unavailability

When user taps a Pro-only feature:

```
┌─────────────────────────────────────┐
│                                     │
│     [Lock Icon]                     │
│                                     │
│  Not Available in This Edition      │
│                                     │
│  [Explanation of why: sandbox       │
│   permissions, system access, etc.] │
│                                     │
│  [Copy Pro Info Link]  [OK]         │
│                                     │
└─────────────────────────────────────┘
```

Key points:
- Explains the technical reason (permissions, sandbox)
- Does not mention price or upgrade
- Provides informational link option
- Easy dismissal with "OK"

## Approved Copy Library

### Safe Button Labels

- "Compare Editions"
- "Learn about Pro"
- "Copy Pro Info Link"
- "See Advanced Tools"
- "More Options"

### Safe Explanatory Text

- "Some advanced tools require permissions not available in the Mac App Store edition."
- "Craig-O-Clean Lite focuses on user-level cache management within your home directory."
- "System-wide cleanup requires elevated access available in the direct-download edition."

### Avoided Language

- ❌ "Upgrade now"
- ❌ "Unlock Pro"
- ❌ "Limited time"
- ❌ "Only $X.XX"
- ❌ "Subscribe"
- ❌ "Buy"
- ❌ "Premium"

## Technical Enforcement

### Sandbox Restrictions

The Lite edition entitlements strictly enforce:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>

<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

No access to:
- `/Library/` (system directories)
- `/System/`
- Other users' directories
- Privileged operations

### Capability Gating

```swift
// In AppStoreLiteCapabilities
var capabilities: Capabilities {
    Capabilities(
        canDeleteSystemWideCaches: false,
        canRunPrivilegedOperations: false,
        canAutoUpdate: false,
        canUseExternalLicensing: false,
        // Only user-level operations enabled
        canDeleteUserCaches: true
    )
}
```

### Path Validation

All file operations validate paths:

```swift
func isPathAllowed(_ path: String) -> Bool {
    let home = NSHomeDirectory()
    guard path.hasPrefix(home) else { return false }

    // Block sensitive directories
    let blocked = ["/.ssh", "/Library/Keychains", ...]
    return !blocked.any { path.contains($0) }
}
```

## Review Preparation

### Screenshots

Prepare screenshots showing:
- Dashboard with "Lite" badge visible
- Cleanup feature working
- Compare Editions sheet (informational only)
- No purchase prompts

### App Description

Focus on:
- What Lite can do (positive framing)
- User-level cleanup capabilities
- No mention of "limited" or "basic"
- No reference to paid version in first paragraph

### Review Notes

Consider adding:
- "This is a standalone utility for user-level cache cleanup"
- "Compare Editions provides informational comparison only"
- "No in-app purchases or external purchase links"

## Compliance Checklist

Before submission:

- [ ] No prices displayed anywhere
- [ ] No "Buy" or "Purchase" buttons
- [ ] No external checkout links
- [ ] Compare Editions is informational only
- [ ] Pro features show explanation, not upsell
- [ ] Lite works as standalone product
- [ ] All sandbox entitlements minimal
- [ ] No misleading performance claims
- [ ] No "RAM cleaner" language
- [ ] No "speed up Mac" claims

## Related Guidelines

- [App Store Review Guidelines 3.1.1](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase) - In-App Purchase
- [App Store Review Guidelines 3.2.2](https://developer.apple.com/app-store/review/guidelines/#unacceptable) - Unacceptable Business Models
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/in-app-purchase) - In-App Purchase

## Updates

This document should be reviewed before each App Store submission to ensure continued compliance with evolving guidelines.
