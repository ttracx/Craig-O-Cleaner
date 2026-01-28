# Craig-O-Clean Support & Troubleshooting

This guide covers frequently asked questions, common issues, and troubleshooting steps for Craig-O-Clean.

---

## Table of Contents

1. [Frequently Asked Questions](#frequently-asked-questions)
2. [Installation Issues](#installation-issues)
3. [Permission Problems](#permission-problems)
4. [Feature-Specific Issues](#feature-specific-issues)
5. [Performance Issues](#performance-issues)
6. [Error Messages](#error-messages)
7. [Getting Additional Help](#getting-additional-help)

---

## Frequently Asked Questions

### General Questions

<details>
<summary><strong>What does Craig-O-Clean do?</strong></summary>

Craig-O-Clean is a system utility for macOS that helps you:
- Monitor CPU, memory, disk, and network usage in real-time
- Manage and terminate running processes
- Optimize memory by closing unused applications
- Manage browser tabs across Safari, Chrome, Edge, Brave, and Arc

It runs in your menu bar for quick access while providing a full Control Center for detailed management.
</details>

<details>
<summary><strong>Is Craig-O-Clean safe to use?</strong></summary>

Yes, Craig-O-Clean is designed with safety in mind:
- **No network connections** - All processing happens locally
- **No data collection** - Your information never leaves your Mac
- **Protected processes** - Critical system processes cannot be terminated
- **Confirmation dialogs** - All destructive actions require confirmation
- **Open source** - Code is available for review
</details>

<details>
<summary><strong>Does Craig-O-Clean work on Intel Macs?</strong></summary>

Craig-O-Clean is optimized for Apple Silicon (M1/M2/M3) Macs. While it may run on Intel Macs via Rosetta 2, this is not officially supported, and some features may not work as expected.
</details>

<details>
<summary><strong>Why does Craig-O-Clean need permissions?</strong></summary>

| Permission | Why It's Needed |
|------------|-----------------|
| **Automation** | To communicate with browsers for tab management |
| **Accessibility** | For advanced window management features |

Craig-O-Clean requests only the minimum permissions needed and explains each request clearly.
</details>

<details>
<summary><strong>Will closing apps cause data loss?</strong></summary>

- **Graceful Quit**: Apps are asked to quit normally, giving them a chance to save data
- **Force Quit**: Immediately terminates the app, which may cause unsaved work to be lost

Always use graceful quit first. Force quit only when an app is unresponsive.
</details>

### Memory Questions

<details>
<summary><strong>What is memory pressure?</strong></summary>

Memory pressure indicates how hard your system is working to manage memory:
- **Normal (Green)** - Plenty of memory available
- **Warning (Yellow)** - Memory is becoming constrained
- **Critical (Red)** - System is under memory stress, may slow down

The pressure indicator is more important than raw memory numbers.
</details>

<details>
<summary><strong>Should I always aim for low memory usage?</strong></summary>

No! macOS is designed to use available memory efficiently:
- **Inactive memory** is cached data that speeds up your Mac
- **Compressed memory** helps fit more in RAM
- Focus on **memory pressure**, not total usage

Only clean up when you see Warning or Critical pressure, or when apps are slow.
</details>

<details>
<summary><strong>What does "Memory Clean" do?</strong></summary>

Memory Clean runs two system commands:
1. `sync` - Flushes filesystem buffers to disk
2. `purge` - Releases inactive memory pages

This requires administrator password and may provide temporary relief. Results vary based on system state.
</details>

### Browser Questions

<details>
<summary><strong>Why can't I see tabs from a browser?</strong></summary>

You need to grant Automation permission for each browser:
1. Open System Settings → Privacy & Security → Automation
2. Find Craig-O-Clean
3. Enable the toggle for the browser

The first time you access a browser's tabs, macOS will prompt you automatically.
</details>

<details>
<summary><strong>Will closing browser tabs close the whole browser?</strong></summary>

No, closing tabs only affects the specific tabs you select. The browser and other tabs remain open.
</details>

---

## Installation Issues

### "Craig-O-Clean can't be opened because Apple cannot check it for malicious software"

**Solution:**
1. Control-click (or right-click) the app
2. Select "Open" from the menu
3. Click "Open" in the dialog

Or:
1. Open System Settings → Privacy & Security
2. Scroll down to find the blocked app message
3. Click "Open Anyway"

### "Craig-O-Clean is damaged and can't be opened"

**Solution:**
```bash
# Remove quarantine attribute
xattr -cr /Applications/Craig-O-Clean.app
```

Then try opening the app again.

### Build fails in Xcode

**Common fixes:**

1. **Clean build folder:**
   - Xcode → Product → Clean Build Folder (⇧⌘K)

2. **Delete derived data:**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

3. **Check signing:**
   - Xcode → Preferences → Accounts
   - Ensure you're signed in with an Apple ID
   - Or select "Sign to Run Locally" in the project settings

4. **Update Xcode:**
   - Ensure you have Xcode 15 or later

---

## Permission Problems

### Automation Permission Denied

**Symptoms:**
- Browser tabs don't load
- Error message about permission denied
- "Craig-O-Clean would like to control [Browser]" never appeared

**Solutions:**

1. **Check System Settings:**
   - Open System Settings → Privacy & Security → Automation
   - Find Craig-O-Clean in the list
   - Enable toggles for desired browsers

2. **Reset permissions (if corrupted):**
   ```bash
   tccutil reset AppleEvents com.craigoclean.app
   ```
   Then restart Craig-O-Clean and try again.

3. **Browser not in list:**
   - The browser must be installed and run at least once
   - Try opening the browser, then restarting Craig-O-Clean

### Accessibility Permission Not Working

**Symptoms:**
- Some features don't work even after granting permission
- Craig-O-Clean not in Accessibility list

**Solutions:**

1. **Manually add to list:**
   - System Settings → Privacy & Security → Accessibility
   - Click the lock to unlock
   - Click "+" and add Craig-O-Clean
   - Ensure the checkbox is enabled

2. **Remove and re-add:**
   - Uncheck Craig-O-Clean in the list
   - Remove it with the "-" button
   - Add it again with "+"
   - Restart Craig-O-Clean

3. **Check Full Disk Access:**
   - Some operations may also require Full Disk Access
   - System Settings → Privacy & Security → Full Disk Access

---

## Feature-Specific Issues

### Menu Bar Icon Not Visible

**Causes & Solutions:**

1. **App not running:**
   - Check Activity Monitor for "Craig-O-Clean"
   - Restart the app

2. **Icon hidden by notch (MacBook Pro):**
   - Some menu bar items may be hidden under the notch
   - Try closing other menu bar apps
   - Use a menu bar management app like Bartender

3. **System Settings issue:**
   - System Settings → Control Center → check menu bar settings

### Process List Empty or Incomplete

**Solutions:**

1. **Refresh the list:**
   - Click the refresh button or press ⌘R

2. **Check filter settings:**
   - Ensure "All" filter is selected
   - Clear any search text

3. **Restart the app:**
   - Quit and relaunch Craig-O-Clean

### Can't Terminate a Process

**Why this happens:**

1. **Protected process:**
   - System-critical processes cannot be terminated
   - Craig-O-Clean prevents termination of: `kernel_task`, `launchd`, `Finder`, `Dock`, `WindowServer`, etc.

2. **Permission denied:**
   - The process belongs to another user or system
   - Elevated privileges are required

3. **Process is stuck:**
   - Try Force Quit instead of Quit
   - If that fails, restart your Mac

### Smart Cleanup Not Freeing Memory

**Why this happens:**

- macOS may immediately re-cache data
- Background processes may restart
- Memory pressure was already normal

**Tips:**
- Focus on memory pressure, not raw numbers
- Close individual heavy apps manually
- Restart apps that have been running for a long time

---

## Performance Issues

### Craig-O-Clean Using High CPU

**Solutions:**

1. **Reduce refresh interval:**
   - Settings → Monitoring → Refresh Interval
   - Try 5-10 seconds instead of 1-2

2. **Close Control Center:**
   - The mini popover uses less resources
   - Only open Control Center when needed

3. **Disable auto-refresh:**
   - Toggle off auto-refresh in Dashboard
   - Manually refresh when needed

### Craig-O-Clean Using High Memory

**Typical memory usage:** 50-150 MB

If higher:
1. Close and reopen the app
2. Reduce the number of tracked processes
3. Report the issue if persistent

### System Slowdown After Cleanup

**Why this happens:**
- macOS needs to rebuild caches
- Apps need to reload data
- This is temporary

**Prevention:**
- Don't over-clean
- Only clean when memory pressure is Warning or Critical
- Allow system to stabilize after cleanup

---

## Error Messages

### "Cannot connect to browser"

**Cause:** Browser automation permission issue

**Fix:**
1. Check Automation permissions
2. Ensure browser is running
3. Restart both Craig-O-Clean and the browser

### "Access denied"

**Cause:** Insufficient permissions for the operation

**Fix:**
1. Check if operation requires administrator access
2. Verify permissions in System Settings
3. For memory purge, enter admin password when prompted

### "Process not found"

**Cause:** Process terminated between list refresh and action

**Fix:**
- This is normal; the process was already closed
- Refresh the process list to see current state

### "Script execution failed"

**Cause:** AppleScript error when communicating with browser

**Fix:**
1. Restart the target browser
2. Reset Automation permissions
3. Try the operation again

---

## Getting Additional Help

### Before Reporting an Issue

1. **Check this document** for your issue
2. **Try restarting** Craig-O-Clean
3. **Try restarting** your Mac
4. **Update** to the latest version
5. **Check permissions** are correctly set

### Information to Include

When reporting an issue, please include:

1. **macOS version:** (e.g., macOS 14.2)
2. **Mac model:** (e.g., MacBook Pro M2)
3. **Craig-O-Clean version:** (from About menu)
4. **Steps to reproduce:** What you did before the issue
5. **Expected behavior:** What should happen
6. **Actual behavior:** What actually happened
7. **Screenshots:** If applicable
8. **Console logs:** (see below)

### Getting Console Logs

```bash
# Open Console app and filter by Craig-O-Clean
# Or use terminal:
log show --predicate 'process == "Craig-O-Clean"' --last 1h
```

### Contact

- **GitHub Issues:** [Report bugs and request features](https://github.com/your-repo/Craig-O-Cleaner/issues)
- **Documentation:** Check all `.md` files in the repository

---

## Diagnostic Export

Craig-O-Clean can export diagnostic information:

1. Open Control Center
2. Go to Settings → Diagnostics
3. Click "Export Diagnostic Report"
4. Save and attach to your issue report

The report includes:
- System information
- App version
- Permission states
- Recent errors (no personal data)

---

*Last updated: January 2026*
