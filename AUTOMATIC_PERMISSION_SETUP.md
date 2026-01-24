# Automatic Safari Permission Setup - Implementation Summary

## Overview

The app now **automatically prompts users** for Safari automation permission and provides an easy one-click setup process.

---

## What Was Added

### 1. **Automatic Permission Request on First Launch**

**File**: `Craig-O-Clean/Core/BrowserAutomationService.swift`

- **Lines 212-266**: New automatic permission setup on first launch
- The app now checks if Safari permissions have been requested before
- On first launch, it:
  1. Checks if Safari is installed
  2. Launches Safari automatically (in background) if not running
  3. Triggers the macOS permission dialog by executing a simple AppleScript
  4. Only does this once per installation (tracked via `UserDefaults`)

**Key Methods Added**:

```swift
func checkAndRequestSafariPermissionIfNeeded() async
func triggerSafariPermissionPrompt() async
```

### 2. **One-Click "Request Permission" Button**

**File**: `Craig-O-Clean/UI/BrowserTabsView.swift`

- **Line 20**: Added `isRequestingPermission` state variable
- **Lines 172-191**: New prominent "Request Permission" button with:
  - Automatic Safari launch if needed
  - Triggers system permission dialog
  - Shows loading state while requesting
  - Auto-refreshes permission status after completion

**What it does**:
1. User clicks "Request Permission"
2. App launches Safari in background if needed
3. App executes AppleScript to trigger system prompt
4. User sees the macOS permission dialog
5. User clicks "OK" or "Allow"
6. App auto-refreshes to verify permission was granted

### 3. **Improved User Instructions**

**File**: `Craig-O-Clean/UI/BrowserTabsView.swift`

- **Lines 145-166**: Updated quick setup instructions
- **Lines 766-791**: Enhanced help sheet with automatic trigger explanation

**Before**: Users had to manually navigate System Settings

**After**: Clear 3-step process:
1. Click "Request Permission"
2. Click "OK" when dialog appears
3. If no dialog, use manual option

---

## How It Works

### First Launch Experience

```
User launches Craig-O-Clean
    ↓
BrowserAutomationService initializes
    ↓
Checks: "Have we requested Safari permission before?"
    ↓ (No)
Checks: "Is Safari installed?"
    ↓ (Yes)
Launches Safari in background (non-intrusive)
    ↓
Executes AppleScript: "tell application Safari to get name"
    ↓
macOS displays system permission dialog
    ↓
User clicks "OK" or "Allow"
    ↓
Permission granted! ✅
```

### Manual Request (from Browser Tabs view)

```
User navigates to "Browser Tabs"
    ↓
No permissions? Shows "Permission Required" screen
    ↓
User clicks "Request Permission" button
    ↓
App launches Safari if needed
    ↓
App triggers permission prompt
    ↓
macOS shows dialog
    ↓
User grants permission
    ↓
App refreshes and shows tabs ✅
```

---

## User Experience Improvements

### Before This Change

❌ User navigates to Browser Tabs
❌ Sees error: "A privilege violation occurred"
❌ Reads complex instructions
❌ Opens System Settings manually
❌ Navigates to Privacy & Security → Automation
❌ Finds Craig-O-Clean (if it's even listed)
❌ Toggles Safari permission
❌ Returns to app
❌ Clicks refresh

**Steps**: 9+ clicks, requires understanding of macOS System Settings

### After This Change

✅ User navigates to Browser Tabs
✅ Sees friendly "Permission Required" screen
✅ Clicks "Request Permission" button
✅ Sees macOS permission dialog
✅ Clicks "OK"
✅ App auto-refreshes and shows tabs

**Steps**: 3 clicks, clear visual flow

---

## Technical Details

### Permission Detection

The app uses multiple methods to detect permission status:

1. **Proactive Check** (`checkAutomationPermission`):
   - Executes minimal AppleScript
   - Catches error code `-1743` (permission denied)
   - Returns `.granted`, `.denied`, or `.notDetermined`

2. **Permission Tracking**:
   - `UserDefaults` key: `"hasRequestedSafariAutomation"`
   - Prevents repeated prompting (good UX)
   - User can manually trigger again if needed

### Safari Launch Behavior

```swift
// Uses modern macOS 11+ API
let configuration = NSWorkspace.OpenConfiguration()
configuration.activates = false  // Don't bring Safari to front
configuration.hides = false      // But do launch it

await NSWorkspace.shared.openApplication(at: safariURL, configuration: configuration)
```

**Why launch Safari?**
- macOS only shows the permission dialog when the target app is running
- Launching in background is non-intrusive
- User doesn't need to manually open Safari first

### Permission Prompt Trigger

```swift
let script = """
tell application "Safari"
    get name
end tell
"""
```

**Why this script?**
- Minimal operation (just gets Safari's name)
- Doesn't modify anything
- Guaranteed to trigger permission dialog on first run
- Fast and reliable

---

## Entitlements & Configuration

### Already Configured (No Changes Needed)

✅ **Info.plist** (`Craig-O-Clean/Info.plist`):
- `NSAppleEventsUsageDescription` (line 54-55) - User-facing explanation
- This is what macOS shows in the permission dialog

✅ **Entitlements** (`Craig-O-Clean/Craig-O-Clean.entitlements`):
- `com.apple.security.automation.apple-events` = `true` (line 11-12)
- `com.apple.security.scripting-targets` with Safari (lines 17-22)

---

## Testing the Implementation

### Test 1: First Launch (Clean Install)

```bash
# Reset the permission request flag
defaults delete com.craigoclean.app hasRequestedSafariAutomation

# Reset Safari automation permission
tccutil reset AppleEvents

# Launch the app
# Expected: After 2 seconds, Safari launches and permission dialog appears
```

### Test 2: Manual Request

1. Navigate to "Browser Tabs"
2. Expected: See "Permission Required" screen
3. Click "Request Permission"
4. Expected: See loading spinner, then permission dialog
5. Click "OK"
6. Expected: Screen refreshes, shows browser tabs

### Test 3: Permission Denied

1. When dialog appears, click "Don't Allow"
2. Expected: Screen still shows "Permission Required"
3. Expected: "Request Permission" button available to try again
4. Expected: "Open System Settings" button available for manual fix

### Test 4: Already Granted

1. Grant permission manually via System Settings
2. Navigate to "Browser Tabs"
3. Expected: Immediately shows tabs, no permission screen

---

## Fallback Options

If automatic prompting fails, users can still:

1. **Open System Settings** button
   - Direct link to Automation settings
   - Formatted URL: `x-apple.systempreferences:com.apple.preference.security?Privacy_Automation`

2. **Learn More** button
   - Opens detailed help sheet
   - Step-by-step instructions with screenshots
   - Troubleshooting tips

3. **Manual Script** (`grant-safari-permission.sh`)
   - Interactive command-line guide
   - Checks current permission status
   - Offers to open System Settings

---

## Success Criteria

You'll know the automatic setup is working when:

✅ First-time users see a permission dialog within 2 seconds of app launch
✅ Dialog clearly states "Craig-O-Clean wants to control Safari"
✅ After clicking "OK", Browser Tabs view loads successfully
✅ No manual navigation to System Settings required
✅ Clear visual feedback during permission request process

---

## Error Handling

### If Safari Is Not Installed

```swift
guard installedBrowsers.contains(.safari) else {
    logger.info("Safari not installed, skipping permission request")
    return
}
```

The app gracefully skips Safari permission request if Safari isn't installed.

### If Permission Previously Denied

The system won't show the dialog again automatically. Users must:
1. Click "Open System Settings"
2. Manually toggle the permission in Privacy & Security

**Alternative**: Reset all automation permissions with:
```bash
tccutil reset AppleEvents
```

### If AppleScript Execution Fails

```swift
do {
    _ = try await executeAppleScript(script)
    logger.info("Safari permission prompt triggered successfully")
} catch {
    logger.warning("Safari permission prompt failed (may be denied): \(error.localizedDescription)")
}
```

Errors are logged but don't crash the app. User can retry or use manual option.

---

## Future Enhancements

### Possible Improvements

1. **Multi-Browser Support**
   - Auto-request for Chrome, Edge, Brave after Safari
   - Show progress: "Setting up permissions for 3 browsers..."

2. **In-App Permission Dialog Preview**
   - Show users what the macOS dialog will look like
   - Reduce surprise/confusion

3. **Onboarding Flow**
   - Dedicated welcome screen on first launch
   - Guide through all required permissions (Automation, Accessibility, etc.)
   - Celebrate when permissions are granted

4. **Smart Retry**
   - Detect when user returns from System Settings
   - Auto-refresh and show success message

5. **Permission Status Widget**
   - Show real-time status in menu bar
   - Quick access to re-request if needed

---

## Related Files

| File | Purpose |
|------|---------|
| `Craig-O-Clean/Core/BrowserAutomationService.swift` | Core automation logic, permission triggering |
| `Craig-O-Clean/Core/PermissionsService.swift` | Permission status checking |
| `Craig-O-Clean/UI/BrowserTabsView.swift` | User interface for permission requests |
| `Craig-O-Clean/Info.plist` | Permission usage descriptions |
| `Craig-O-Clean/Craig-O-Clean.entitlements` | Automation entitlements |
| `grant-safari-permission.sh` | Command-line helper script |

---

## Summary

The automatic permission setup provides a **significantly better user experience** by:

1. **Proactively requesting** Safari permission on first launch
2. **One-click setup** from the Browser Tabs view
3. **Clear visual feedback** during the permission process
4. **Automatic Safari launching** if needed
5. **Graceful fallbacks** if automatic setup fails

Users no longer need to understand macOS System Settings navigation. The app guides them through the entire process automatically.

---

**Last Updated**: January 23, 2026
**Status**: ✅ Implemented and Ready for Testing
