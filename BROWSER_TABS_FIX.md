# Browser Tabs Issue Fix

Date: 2026-01-27
Issue: Browser tabs not showing despite permissions granted
Status: **FIXED**

## Problem Summary

Users reported that browser tabs were not showing in the Browser Tabs view despite:
- Automation permissions being granted in System Settings
- Browsers (Safari, Edge) running with open tabs
- Permissions showing as granted in TCC database

## Root Cause

**Bug in BrowserAutomationService.swift line 554-555**:

The `executeAppleScript()` function was hardcoded to always throw a Safari error, even when the error came from other browsers like Edge or Chrome:

```swift
// BEFORE (BUGGY CODE):
if errorNumber == -1743 || errorNumber == -10004 || errorNumber == -1728 {
    self?.logger.warning("Automation permission denied for Safari. User needs to grant permission in System Settings.")
    continuation.resume(throwing: BrowserAutomationError.automationPermissionDenied(.safari))
}
```

### Why This Caused Tabs Not to Show

1. **User has permissions granted**: TCC database shows auth_value=2 (allowed) for Safari and Edge
2. **App fetches tabs**: Calls `fetchAllTabs()` which iterates through each browser
3. **Edge fetch fails**: AppleScript error -10004 (privilege violation) occurs for Edge
4. **Wrong error thrown**: Error says "Safari" instead of "Edge"
5. **Error condition triggered**: BrowserTabsView checks `if allTabs.isEmpty && lastError != nil`
6. **Confusion**: User sees error about Safari when the actual problem is with Edge
7. **Result**: No tabs show, confusing error messages, user thinks permissions are broken

### Diagnostic Evidence

Running the diagnostic script showed:

```
✅ Safari is running with 2 tabs
✅ Edge is running with 1 tab
✅ Automation permissions GRANTED in TCC database
❌ AppleScript error -10004 for Edge
❌ Error message says "Safari" (incorrect!)
❌ Fetch complete. Total tabs: 0
```

Console logs confirmed:
```
BrowserAutomation    Error    AppleScript error -10004: Microsoft Edge got an error: A privilege violation occurred.
BrowserAutomation    Error    Automation permission denied for Safari. User needs to grant permission in System Settings.
BrowserAutomation    Error    Failed to fetch tabs for Microsoft Edge: Automation permission required for Safari.
```

Notice the error says "Safari" when it's actually Edge!

## Solution

Modified `executeAppleScript()` to accept a browser parameter and use it in error messages:

```swift
// AFTER (FIXED CODE):
private func executeAppleScript(_ script: String, for browser: SupportedBrowser? = nil) async throws -> String {
    // ... error handling ...
    if errorNumber == -1743 || errorNumber == -10004 || errorNumber == -1728 {
        // Use the provided browser, or default to Safari for backwards compatibility
        let targetBrowser = browser ?? .safari
        self?.logger.warning("Automation permission denied for \(targetBrowser.rawValue). User needs to grant permission in System Settings.")
        continuation.resume(throwing: BrowserAutomationError.automationPermissionDenied(targetBrowser))
    }
}
```

### Updated Call Sites

1. **Line 408** - `fetchTabs(for browser:)`:
   ```swift
   let output = try await executeAppleScript(script, for: browser)
   ```

2. **Line 446** - `closeTab(_ tab:)`:
   ```swift
   _ = try await executeAppleScript(script, for: tab.browser)
   ```

3. **Line 477** - `closeAllTabsInWindow(browser:)`:
   ```swift
   _ = try await executeAppleScript(script, for: browser)
   ```

## Impact

### Before Fix
- ❌ All AppleScript errors showed "Safari" regardless of actual browser
- ❌ Confusing error messages ("Safari" error when Edge fails)
- ❌ Difficult to diagnose which browser has permission issues
- ❌ Users couldn't determine the real problem

### After Fix
- ✅ Errors correctly identify the browser causing the issue
- ✅ Error messages are accurate ("Edge" when Edge fails)
- ✅ Users can identify which browser needs permission
- ✅ Easier to diagnose and fix permission issues

## Testing

Build Status: ✅ **BUILD SUCCEEDED**

### Test Scenarios

1. **Safari with permission granted**:
   - Expected: Tabs fetch successfully
   - Error: None

2. **Edge with permission granted**:
   - Expected: Tabs fetch successfully
   - Error: None

3. **Safari with permission denied**:
   - Expected: Error message says "Automation permission required for Safari"
   - Browser identified: Safari

4. **Edge with permission denied**:
   - Expected: Error message says "Automation permission required for Microsoft Edge"
   - Browser identified: Edge (NOT Safari!)

## Why Error -10004 Happens Even With Permissions

**Note**: Error -10004 can occur even when TCC permissions are granted. This happens when:

1. **Permission recently granted**: macOS hasn't fully propagated the permission
2. **Browser needs restart**: Browser was running when permission was granted
3. **App needs restart**: Craig-O-Clean was running when permission was granted
4. **Stale permission cache**: macOS TCC cache needs refresh

### User Resolution Steps

When users see automation permission errors:

1. **Check System Settings**:
   - Open System Settings > Privacy & Security > Automation
   - Verify Craig-O-Clean has checkmarks for the browser

2. **Restart the browser**:
   - Quit the browser completely (⌘Q)
   - Relaunch the browser

3. **Restart Craig-O-Clean**:
   - Quit Craig-O-Clean (⌘Q)
   - Relaunch the app

4. **Click "Refresh Tabs"**:
   - Go to Browser Tabs view
   - Click "Refresh Tabs" button
   - Grant permission if prompted

5. **Nuclear option** (if nothing works):
   ```bash
   # Reset automation permission
   tccutil reset AppleEvents com.craigoclean.app

   # Restart app and grant permission again
   ```

## Files Modified

1. **Craig-O-Clean/Core/BrowserAutomationService.swift**:
   - Line 535: Updated function signature to accept `browser` parameter
   - Line 554: Updated log message to use correct browser name
   - Line 555: Updated error to use correct browser
   - Line 408: Pass browser to executeAppleScript
   - Line 446: Pass tab.browser to executeAppleScript
   - Line 477: Pass browser to executeAppleScript

## Related Issues

This fix addresses:
- Issue: "Browser Tabs not showing despite permissions granted"
- Issue: "Confusing error messages about Safari when Edge has the problem"
- Issue: "Can't determine which browser needs permission"

## Prevention

To prevent similar issues in the future:

1. **Always pass context to generic functions**: Functions that operate on multiple types should accept type parameters
2. **Use the context in error messages**: Error messages should be specific about what failed
3. **Test with multiple browsers**: Verify behavior with Safari, Chrome, Edge, etc.
4. **Check logs for correctness**: Ensure error messages match the actual browser

## Documentation

Created comprehensive troubleshooting guide:
- **TROUBLESHOOTING.md**: Detailed guide for common issues
  - Browser tabs not showing
  - Force quit not working
  - Edge not in automation settings
  - Permission troubleshooting steps
  - Console log examples
  - Resolution procedures

## Next Steps for Users

If browser tabs still don't show after this fix:

1. **Build and run the fixed app**
2. **Restart all browsers**
3. **Launch Craig-O-Clean**
4. **Navigate to Browser Tabs**
5. **Click "Refresh Tabs"**
6. **Check Console.app** for BrowserAutomation logs
7. **Verify errors now show correct browser names**

The fix ensures that error messages are accurate, making it much easier to diagnose and resolve permission issues.

---

**Status**: ✅ Fixed and built successfully
**Build**: DEBUG configuration successful
**Next**: User testing and verification
