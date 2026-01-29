# Sandbox Troubleshooting Guide

## Issue: Force Quit Not Working

### Symptoms:
- Force quit button does nothing
- Console shows "Operation not permitted" errors
- Processes don't terminate

### Solutions:

#### For Regular Apps (NSRunningApplication):
1. Should work automatically via `NSRunningApplication.forceTerminate()`
2. No password required
3. If fails, check Console for specific error

#### For Helper Processes:
1. Will prompt for admin password
2. Uses AppleScript: `do shell script "/bin/kill -9 PID" with administrator privileges`
3. User must enter password
4. If password prompt doesn't appear:
   - Check System Settings → Privacy & Security → Automation
   - Ensure Craig-O-Clean has permission for System Events

### Debugging:
```bash
# Check if app is sandboxed
codesign -d --entitlements - /path/to/Craig-O-Clean.app | grep -A1 "app-sandbox"

# Monitor force quit attempts
log stream --predicate 'subsystem == "com.CraigOClean" AND category == "ProcessManager"' --level debug
```

---

## Issue: Browser Tabs Not Working

### Symptoms:
- Tabs don't close when clicked
- Browser automation errors in console
- AppleScript error -1743 ("Not authorized")

### Solutions:

#### 1. Grant Automation Permissions:
```
System Settings → Privacy & Security → Automation
└── Craig-O-Clean
    ├── ✓ Safari
    ├── ✓ Google Chrome
    ├── ✓ Microsoft Edge
    ├── ✓ Brave Browser
    └── ✓ Arc
```

#### 2. Verify Entitlements:
The Release entitlements must include:
```xml
<key>com.apple.security.automation.apple-events</key>
<true/>
<key>com.apple.security.scripting-targets</key>
<dict>
    <key>com.apple.Safari</key>
    <array>
        <string>com.apple.Safari.scripting</string>
    </array>
    <!-- etc for other browsers -->
</dict>
```

#### 3. Restart Browser & App:
- Quit the browser completely
- Quit Craig-O-Clean
- Open Craig-O-Clean first
- Then open browser
- Try browser tab management again

### Debugging:
```bash
# Monitor browser automation
log stream --predicate 'subsystem == "com.craigoclean.app" AND category == "BrowserAutomation"' --level debug

# Test AppleScript manually
osascript -e 'tell application "Safari" to return name'
# Should return "Safari" if permissions are correct
```

---

## Issue: Excessive Permission Checks

### Symptoms:
- Logs show permission checks every 1-2 seconds
- High CPU usage
- Battery drain

### Solutions:

#### Check Current State:
```bash
# Monitor permission checks
log stream --predicate 'subsystem == "com.craigoclean.app" AND category == "Permissions"' --level info
```

#### Expected Behavior (After Fix):
- Check on app activation (debounced to 2s minimum)
- Periodic check every 30 seconds
- No duplicate checks

#### If Still Excessive:
1. Check for multiple instances of PermissionsService
2. Verify timer is not being created multiple times
3. Clean build folder and rebuild

---

## Sandbox vs Non-Sandbox Comparison

| Feature | Sandbox (Release) | Non-Sandbox (Debug) |
|---------|-------------------|---------------------|
| Force Quit (Apps) | ✅ NSRunningApplication | ✅ NSRunningApplication + kill() |
| Force Quit (Helpers) | ✅ Admin Password | ✅ Direct kill() |
| Browser Automation | ✅ AppleScript | ✅ AppleScript |
| File Access | 🔒 User-selected + Read-only | ✅ Full Access |
| Process Info | ✅ Limited | ✅ Full |
| App Store | ✅ Allowed | ❌ Not Allowed |

---

## Testing Sandbox Behavior

### Test Force Quit:
```swift
// Expected flow for sandboxed app
1. User clicks "Force Quit" on Safari
2. App calls NSRunningApplication.forceTerminate()
3. Safari quits immediately (no password)
4. Success ✅

1. User clicks "Force Quit" on "SafariHelper"
2. App detects sandbox mode
3. App shows password prompt (AppleScript)
4. User enters admin password
5. Helper process terminates
6. Success ✅
```

### Test Browser Tabs:
```swift
// Expected flow
1. User clicks "Close Tab" on google.com tab
2. App sends AppleScript to Chrome:
   tell application "Google Chrome"
       close tab 5 of window 1
   end tell
3. If automation permission granted → Success ✅
4. If not granted → Error -1743 → User sees permission prompt
```

---

## Console Commands for Debugging

### Check Entitlements:
```bash
# View all entitlements
codesign -d --entitlements :- /Applications/Craig-O-Clean.app

# Check specific entitlement
codesign -d --entitlements :- /Applications/Craig-O-Clean.app | grep -A5 "app-sandbox"
```

### Monitor Process Termination:
```bash
# Watch process exits
log stream --predicate 'eventMessage CONTAINS "exited"' --info

# Watch specific PID
log stream --predicate 'processIdentifier == 12345' --debug
```

### Check Automation Permissions Database:
```bash
# View TCC database (requires Full Disk Access)
sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT * FROM access WHERE service='kTCCServiceAppleEvents'"
```

---

## Common Error Codes

| Error | Meaning | Solution |
|-------|---------|----------|
| -1743 | "Not authorized to send Apple events" | Grant automation permission in System Settings |
| -10004 | "Privilege violation" | Check entitlements, may need admin privileges |
| -1728 | "Can't get object" | Target not available or permission denied |
| -600 | "Application isn't running" | Launch the target app first |
| EPERM (1) | Operation not permitted (kill()) | Use admin privileges in sandbox |

---

## Environment Detection

```swift
// Check if sandboxed at runtime
let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil

// Check build configuration
#if DEBUG
    // Non-sandboxed (typically)
#else
    // Sandboxed (Release builds)
#endif
```

---

## When to Use Each Method

### NSRunningApplication.forceTerminate()
- ✅ Use for: User-facing applications
- ✅ Sandbox: Works perfectly
- ✅ Admin: Not required
- ❌ Limitations: Only works for NSRunningApplication objects

### kill() System Call
- ✅ Use for: Helper processes, daemons
- ❌ Sandbox: BLOCKED
- ✅ Non-Sandbox: Works
- ⚠️ Alternative: Use AppleScript with admin privileges when sandboxed

### AppleScript with Admin Privileges
- ✅ Use for: Any process when sandboxed
- ✅ Sandbox: Works
- ⚠️ Admin: Required (user password prompt)
- ✅ Reliable: Always works if user provides password

---

## Building for Release

1. **Clean Build:**
   ```bash
   xcodebuild clean -scheme Craig-O-Clean
   ```

2. **Verify Entitlements:**
   ```bash
   # Should use Release entitlements
   grep -A1 "app-sandbox" Craig-O-Clean-Release.entitlements
   ```

3. **Build Release:**
   ```bash
   xcodebuild archive -scheme Craig-O-Clean \
     -archivePath ./build/Craig-O-Clean.xcarchive
   ```

4. **Test Sandbox Behavior:**
   - Test force quit on apps (should work without password)
   - Test force quit on helpers (should prompt for password)
   - Test browser automation (should work with permissions)

5. **Submit to App Store:**
   - Sandbox must be enabled (✅ Already done)
   - All entitlements must be justified
   - Test on fresh macOS install

---

## Support Contacts

- **File Issues:** [GitHub Issues](https://github.com/yourrepo/Craig-O-Clean/issues)
- **Documentation:** See CLAUDE.md for development guidelines
- **Logs:** Check Console.app with predicate `subsystem == "com.craigoclean.app"`
