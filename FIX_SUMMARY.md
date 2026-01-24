# Craig-O-Clean: Fixes for Safari Tabs & Force Quit Issues

## Issues Identified

### 1. Safari Tabs Not Showing
**Error:** `AppleScript error -10004: Safari got an error: A privilege violation occurred.`

**Root Cause:** macOS requires explicit user permission for apps to control Safari via AppleScript/Automation.

**Fix:** Grant Automation permission in System Settings

### 2. Force Quit Not Working
**Error:** `Sandbox: Craig-O-Clean(7163) deny(1) signal others [Safari(5085)] signum:15`

**Root Cause:** The app is sandboxed (`com.apple.security.app-sandbox = true` in entitlements), which prevents sending kill signals to other processes. The sandbox blocks:
- Sending signals (SIGTERM, SIGKILL) to other processes
- Directly terminating apps outside the sandbox

**Current Code:** Uses `app.forceTerminate()` which works for some apps but fails for protected/sandboxed apps

**Fix:** Multiple approaches needed (already partially implemented in ProcessManager.swift:251)

---

## Fix 1: Grant Safari Automation Permission

### Quick Steps:
1. **Open System Settings** → Privacy & Security → Automation
2. Find **Craig-O-Clean** in the list
3. Toggle **ON** the switch for Safari
4. Restart Safari (if needed)
5. Click "Refresh" in Craig-O-Clean's Browser Tabs view

### If Craig-O-Clean doesn't appear in Automation settings:

Option A: **Trigger the permission prompt**
```bash
# 1. Make sure Safari is running with some tabs open
# 2. In Craig-O-Clean, go to Browser Tabs view
# 3. Click the Refresh button
# 4. A permission dialog should appear - click "OK" or "Allow"
```

Option B: **Reset TCC database** (if permission was previously denied)
```bash
# WARNING: This resets ALL automation permissions for ALL apps
tccutil reset AppleEvents

# Then restart Craig-O-Clean and try again
```

### Verification:
```bash
# Check if permission is granted
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT service, client, allowed FROM access WHERE service='kTCCServiceAppleEvents';" 2>/dev/null
```

---

## Fix 2: Force Quit Implementation (Multiple Strategies)

The app already implements multiple fallback strategies in ProcessManager. swift, but here's how they work:

### Strategy 1: NSRunningApplication.forceTerminate() (Current - Line 626)
- **Works for:** Most regular apps
- **Fails for:** System apps, protected apps, apps requiring elevated privileges
- **Sandbox:** ✅ Allowed (uses public API)

### Strategy 2: NSRunningApplication.terminate() + Timeout (Already implemented)
- **Works for:** Apps that respond to graceful termination
- **Fails for:** Hung apps, unresponsive apps
- **Sandbox:** ✅ Allowed

### Strategy 3: Privileged Helper (Line 629 - Currently disabled)
- **Works for:** All apps (requires admin password)
- **Implementation:** Uses `PrivilegeService` (currently TODO commented out)
- **Sandbox:** ✅ Allowed with proper entitlements (SMJobBless)

### Strategy 4: AppleScript (Alternative - not currently implemented)
```swift
// Could be added as another fallback
func forceQuitViaAppleScript(pid: Int32) -> Bool {
    let script = """
    tell application "System Events"
        set theProcess to first process whose unix id is \(pid)
        kill theProcess
    end tell
    """
    // Requires Automation permission for System Events
}
```

---

## Recommended Solution

### For Browser Tabs (Immediate Fix):
✅ Grant Automation permission for Safari (see Fix 1 above)

### For Force Quit (Choose One):

#### Option A: Re-enable Privileged Helper (Best for production)
The app already has the infrastructure for this:
- Entitlements include `SMPrivilegedExecutables`
- `CraigOCleanHelper` target exists
- Need to uncomment `PrivilegeService` code

**Pros:**
- Can kill any process
- Proper macOS pattern for system utilities
- User provides admin password once

**Cons:**
- Requires user to authorize with admin password
- More complex setup

#### Option B: Request Temporary Sandbox Exception (Development only)
Add to entitlements (NOT recommended for App Store):
```xml
<key>com.apple.security.temporary-exception.apple-events</key>
<array>
    <string>com.apple.systemevents</string>
</array>
```

**Pros:**
- Quick fix for development

**Cons:**
- Won't be approved for App Store
- Security red flag

#### Option C: Remove Sandbox (NOT recommended)
Remove `<key>com.apple.security.app-sandbox</key>` from entitlements

**Pros:**
- Force quit works immediately

**Cons:**
- Can't submit to App Store
- Loses all sandbox security benefits
- Requires Full Disk Access for other features

---

## Implementation Plan

### Phase 1: Immediate (User Action)
1. ✅ Grant Safari Automation permission (manual - see Fix 1)
2. Test browser tabs feature

### Phase 2: Code Improvements (Optional)
1. Re-enable `PrivilegeService` for privileged operations
2. Add better error messages when force quit fails
3. Implement user-friendly prompts to guide permission granting

### Phase 3: Enhanced Force Quit (Future)
1. Implement tiered approach:
   - Try `forceTerminate()` first (fast, no password)
   - If fails, show dialog asking if user wants to use admin privileges
   - Use PrivilegedHelper for stubborn processes

---

## Testing After Fix

### Browser Tabs:
```
1. Open Safari with 3-5 tabs
2. Open Craig-O-Clean
3. Navigate to "Browser Tabs" view
4. Click "Refresh"
5. ✅ Should see Safari tabs listed
```

### Force Quit:
```
1. Open a test app (e.g., Calculator, TextEdit)
2. In Craig-O-Clean → Processes view
3. Right-click on the app → "Force Quit"
4. ✅ App should close

For protected apps (e.g., Safari):
- If using PrivilegeService: You'll be prompted for password, then it works
- If not: May fail with "Unable to quit app" message
```

---

## Files to Review

1. **Craig-O-Clean/Core/BrowserAutomationService.swift:434-461**
   - AppleScript execution and error handling
   - Error -1743 (permission denied) → error -10004 (privilege violation)

2. **Craig-O-Clean/Core/PermissionsService.swift:484**
   - Automation permission checking
   - Shows in error log: `PermissionsService.checkAutomationPermission`

3. **Craig-O-Clean/ProcessManager.swift:251**
   - Process termination logic
   - Multiple fallback strategies

4. **Craig-O-Clean/Craig_O_CleanApp.swift:626-643**
   - Force quit menu handler
   - Currently uses `forceTerminate()` first, then falls back to `ProcessManager`

---

## Quick Reference

| Feature | Current Status | Fix Required | Difficulty |
|---------|---------------|--------------|------------|
| Safari tabs | ❌ Not working | Grant permission | Easy (user action) |
| Chrome/Edge tabs | ❓ Unknown | Grant permission per browser | Easy |
| Force quit regular apps | ✅ Working | None | N/A |
| Force quit system apps | ❌ Not working | Re-enable PrivilegeService | Medium |
| Force quit Safari | ❌ Blocked by sandbox | Re-enable PrivilegeService | Medium |

---

## Notes

- **Sandbox vs Security:** The app is sandboxed for App Store compliance and security
- **SMJobBless:** Proper pattern for privileged operations in sandboxed apps
- **TCC (Transparency, Consent, Control):** macOS privacy framework that requires explicit user permission for automation
- **Debug vs Release:** Permissions are tied to code signature and app path - debug builds from Xcode have different paths than release builds
