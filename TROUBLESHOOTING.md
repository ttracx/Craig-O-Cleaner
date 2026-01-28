# Craig-O-Clean Troubleshooting Guide

Last Updated: 2026-01-27

## Issue 1: Browser Tabs Not Showing

### Symptoms
- Browser Tabs view shows "No tabs found" despite having open browser tabs
- Automation permissions are granted in System Settings
- Browsers (Safari, Edge, Chrome, etc.) are running with open tabs

### Root Causes

#### 1. No Browser Windows Open
**Most Common**: The browser is running but has NO windows open.

**Diagnostic Steps**:
```bash
# Check if Safari has windows
osascript -e 'tell application "Safari" to count windows'

# Check if Safari has tabs
osascript -e 'tell application "Safari" to count (tabs of windows)'

# Check for Edge
osascript -e 'tell application "Microsoft Edge" to if it is running then count windows'
```

**Solution**:
- Open at least one browser window with tabs
- Click "Refresh Tabs" button in the app

#### 2. Automation Permission Not Actually Granted
Even if System Settings shows the app in the list, permission might not be fully granted.

**Diagnostic Steps**:
```bash
# Check TCC database for automation permissions
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT client, indirect_object_identifier, auth_value
   FROM access
   WHERE service='kTCCServiceAppleEvents'
   AND client='com.craigoclean.app';"
```

**Expected Output**:
```
com.craigoclean.app|com.apple.Safari|2
com.craigoclean.app|com.microsoft.edgemac|2
```
(`auth_value=2` means "allowed")

**Solution**:
1. Open System Settings > Privacy & Security > Automation
2. Find Craig-O-Clean in the list
3. Ensure the target browser is checked
4. If not present, the app needs to trigger the permission prompt by clicking "Refresh Tabs"

#### 3. Browser Not Detected as Running
The app may not detect the browser as running due to bundle identifier mismatch.

**Diagnostic Steps**:
1. Open the Browser Tabs view
2. Look at the "Diagnostic Info" section at the bottom
3. Check if your browser is listed under "Running browsers"

**Solution**:
- If browser is not listed, try restarting the browser
- Click "Refresh Tabs" after restarting
- Check Console.app for logs from Craig-O-Clean category "BrowserAutomation"

#### 4. Browser Has No Tabs (Edge Case)
The browser is running with windows but somehow has 0 tabs (rare).

**Solution**:
- Open at least one tab in the browser
- Click "Refresh Tabs"

### Expected Console Logs

When Browser Tabs are being fetched successfully, you should see logs like:

```
BrowserAutomation    info    Starting to fetch tabs from 2 running browsers
BrowserAutomation    info    Fetching tabs for Safari
BrowserAutomation    info    Successfully fetched 1 windows with 2 total tabs for Safari
BrowserAutomation    info    Fetching tabs for Microsoft Edge
BrowserAutomation    info    Successfully fetched 1 windows with 1 total tabs for Microsoft Edge
BrowserAutomation    info    Fetch complete. Total tabs: 3
```

### Troubleshooting Steps

1. **Verify browsers are running with tabs**:
   ```bash
   # Safari
   osascript -e 'tell application "Safari"
       set tabList to {}
       repeat with w in windows
           repeat with t in tabs of w
               set end of tabList to {name of t, URL of t}
           end repeat
       end repeat
       return tabList
   end tell'
   ```

2. **Check automation permissions**:
   - Open System Settings
   - Navigate to Privacy & Security > Automation
   - Verify Craig-O-Clean is listed and has checkmarks for Safari/Chrome/Edge

3. **Restart the app**:
   - Quit Craig-O-Clean completely (⌘Q)
   - Relaunch the app
   - Navigate to Browser Tabs
   - Wait for auto-fetch or click "Refresh Tabs"

4. **Check Console logs**:
   - Open Console.app
   - Filter by "Craig-O-Clean" or "BrowserAutomation"
   - Look for error messages or permission denied errors

5. **Reset automation permissions** (nuclear option):
   ```bash
   # WARNING: This will reset ALL automation permissions for the app
   tccutil reset AppleEvents com.craigoclean.app
   ```
   Then relaunch the app and grant permissions again.

---

## Issue 2: Force Quit Not Working from Menu Bar

### Symptoms
- Clicking "Force Quit" on a process shows alerts but the process doesn't terminate
- Admin password prompt appears but fails with "incorrect password" even when password is correct
- Error message: "Failed to force quit '[App Name]'"

### Root Causes

#### 1. System-Protected Process
**Most Common**: Safari, Finder, and other system apps are protected by macOS and cannot be force quit by sandboxed applications.

**Affected Apps**:
- Safari (com.apple.Safari)
- Finder (com.apple.finder)
- System Settings (com.apple.systempreferences)
- App Store (com.apple.AppStore)
- Other Apple-signed system apps

**Why This Happens**:
- macOS has System Integrity Protection (SIP) that prevents apps from terminating system processes
- Even with admin privileges, sandboxed apps cannot kill protected processes
- The AppleScript `do shell script "kill -9" with administrator privileges` fails for these apps

**Console Logs**:
```
PrivilegeService    info     Force killing process with PID: 78718
PrivilegeService    error    Using AppleScript fallback for force kill (Debug mode)
PrivilegeService    error    AppleScript force kill PID 78718 failed: The administrator user name or password was incorrect.
```

**Solution**:
Use macOS Activity Monitor or Terminal instead:

```bash
# Using Activity Monitor:
1. Open Activity Monitor
2. Find the process
3. Click "Force Quit" button (or ⌘⌥⎋)

# Using Terminal:
sudo kill -9 [PID]
```

**App Limitation**:
The force quit feature works well for:
- Third-party applications (Chrome, Slack, VS Code, etc.)
- User-launched processes
- Non-system apps

It **cannot** force quit:
- Safari and other Apple system apps
- Processes owned by root or system
- Processes protected by SIP

#### 2. Admin Password Not Entered
User cancelled the password prompt or entered incorrect password.

**Console Logs**:
```
Craig-O-Clean    info    Attempting to force quit process: Safari (PID: 78718)
Craig-O-Clean    error   NSRunningApplication.forceTerminate() returned false
Craig-O-Clean    info    Force killing process with PID: 78718
Craig-O-Clean    error   AppleScript force kill PID 78718 failed: The administrator user name or password was incorrect.
```

**Solution**:
1. When the password prompt appears, enter your macOS admin password
2. Do not cancel the prompt
3. Ensure you're using an administrator account

#### 3. Process Requires Special Privileges
Some processes require specific entitlements or privileges beyond what the app can provide.

**Examples**:
- Kernel extensions
- LaunchDaemons
- System services
- Security agents

**Solution**:
Use Terminal with sudo:
```bash
sudo launchctl kill SIGKILL system/[service-name]
```

### Improved User Experience

The app now shows progressive feedback when attempting force quit:

1. **Initial Attempt**:
   - Alert: "Force Quitting..."
   - Message: "Attempting to force quit '[App Name]'. If an admin password prompt appears, enter your password."

2. **Escalation**:
   - Alert: "Admin Privileges Needed"
   - Message: "Standard force quit failed. Trying with administrator privileges... If a password prompt appears, please enter your password."

3. **Success**:
   - Alert: "✅ Success"
   - Message: "' [App Name]' was force quit successfully using administrator privileges."

4. **Failure**:
   - Alert: "❌ Failed"
   - Message with possible reasons:
     * System-protected process (like Safari)
     * Admin password was not entered
     * Process requires special privileges
     * Suggestion to use Activity Monitor

### What Works vs What Doesn't

#### ✅ Force Quit Works For:
- Google Chrome
- Microsoft Edge
- Brave Browser
- Slack
- Discord
- VS Code
- Most third-party apps
- User-launched processes

#### ❌ Force Quit Fails For:
- Safari (system-protected)
- Finder (system-protected)
- System Settings (system-protected)
- Kernel processes
- Root-owned processes
- LaunchDaemons

### Workaround for Protected Apps

**Option 1: Activity Monitor**
1. Open Activity Monitor (Applications > Utilities > Activity Monitor)
2. Find the process
3. Click "Force Quit" (or double-click and click "Quit")
4. Click "Force Quit" in the confirmation dialog

**Option 2: Terminal**
```bash
# For most processes
sudo killall [ProcessName]

# For specific PID
sudo kill -9 [PID]

# For Safari specifically
killall Safari
# (Safari will auto-restart if "Reopen windows when logging back in" is enabled)
```

**Option 3: Restart**
- For persistent system processes, restart your Mac

---

## Issue 3: Edge Browser Not in Automation Settings

### Symptoms
- Edge is running but doesn't appear in System Settings > Privacy & Security > Automation under Craig-O-Clean

### This is EXPECTED Behavior

**Why This Happens**:
macOS only shows apps in the Automation list AFTER the app has attempted to control them.

**How It Works**:
1. Craig-O-Clean tries to fetch tabs from Edge
2. macOS shows a permission prompt: "Craig-O-Clean would like to control Microsoft Edge"
3. User clicks "OK"
4. Edge now appears in the Automation list

**To Trigger the Prompt**:
1. Make sure Edge is running
2. Open Craig-O-Clean
3. Navigate to Browser Tabs
4. Click "Refresh Tabs"
5. macOS will show the permission prompt
6. Click "OK"
7. Edge will now appear in System Settings > Automation

**This behavior is the same for all browsers**:
- Safari
- Chrome
- Edge
- Brave
- Arc

**Normal Sequence**:
```
First Launch:
- No browsers in Automation list

After clicking "Refresh Tabs":
- macOS shows permission prompt for each detected browser
- User approves
- Browsers now appear in Automation list
```

---

## General Debugging Tips

### Enable Verbose Logging

Check Console.app for detailed logs:
1. Open Console.app
2. Filter by "Craig-O-Clean"
3. Look for categories:
   - `Permissions` - Permission checks
   - `BrowserAutomation` - Browser tab fetching
   - `PrivilegeService` - Force quit attempts
   - `ProcessManager` - Process management

### Common Log Messages

**Success**:
```
BrowserAutomation    info    Successfully fetched 2 windows with 5 total tabs for Safari
Permissions          info    Accessibility permission: GRANTED
Permissions          info    Full Disk Access granted: TCC database readable
```

**Permission Denied**:
```
BrowserAutomation    error   Failed to fetch tabs for Safari: Automation permission denied
```

**Force Quit Failed**:
```
PrivilegeService     error   AppleScript force kill PID 78718 failed: The administrator user name or password was incorrect.
```

### Reset All Permissions

If you want to start fresh:

```bash
# Reset automation permissions
tccutil reset AppleEvents com.craigoclean.app

# Reset accessibility
tccutil reset Accessibility com.craigoclean.app

# Reset all TCC permissions
tccutil reset All com.craigoclean.app
```

Then relaunch the app and grant permissions again.

---

## Contact & Support

- **GitHub Issues**: Report bugs or request features
- **Console Logs**: Always include Console.app logs when reporting issues
- **System Info**: Include macOS version, app version, and affected browsers

---

## Quick Reference

### Browser Tab Issues
1. Check if browser has open windows/tabs
2. Verify automation permissions in System Settings
3. Click "Refresh Tabs" button
4. Check Console logs for errors

### Force Quit Issues
1. Works for third-party apps only
2. Safari and system apps are protected
3. Use Activity Monitor for protected apps
4. Enter admin password when prompted

### Permission Issues
1. Browsers appear in Automation list AFTER first access attempt
2. Click "Refresh Tabs" to trigger permission prompts
3. Check System Settings > Privacy & Security > Automation
4. Grant permissions when macOS prompts you
