# Craig-O-Clean Sandbox Edition - User Guide

Welcome to Craig-O-Clean Sandbox Edition, designed for Mac App Store distribution with full Apple sandbox compliance.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Understanding Sandbox](#understanding-sandbox)
3. [Dashboard](#dashboard)
4. [Process Manager](#process-manager)
5. [Browser Tab Management](#browser-tab-management)
6. [File Cleanup](#file-cleanup)
7. [Permissions](#permissions)
8. [FAQ](#faq)

---

## Getting Started

### Installation from Mac App Store

1. Open the Mac App Store
2. Search for "Craig-O-Clean"
3. Click "Get" or the price button
4. Enter your Apple ID password or use Touch ID
5. Launch from Launchpad or Applications

### First Launch

When you first open Craig-O-Clean Sandbox Edition:

1. **Welcome Screen** - Brief introduction to features
2. **Permission Setup** - Optional permission grants for enhanced features
3. **Dashboard** - Main app view with system metrics

### What's Different from Standard Edition?

The Sandbox Edition operates within Apple's App Sandbox:

| Feature | Standard | Sandbox Edition |
|---------|----------|-----------------|
| System Monitoring | ✅ Full | ✅ Full |
| Process Management | ✅ All processes | ✅ User processes |
| Browser Tabs | ✅ Full | ✅ With permission |
| Memory Purge | ✅ Available | ❌ Not available |
| File Cleanup | ✅ System-wide | ✅ User-selected folders |

---

## Understanding Sandbox

### What is App Sandbox?

App Sandbox is Apple's security technology that:
- Limits what apps can access
- Protects your data from malicious software
- Requires explicit user permission for sensitive operations

### How It Affects You

**Good News:**
- Your data is protected
- Clear permission prompts
- No hidden operations

**Limitations:**
- Some features require explicit permission
- File access limited to folders you select
- No system-wide memory purge

### Permission Philosophy

Craig-O-Clean Sandbox follows the principle:
> "No silent power - only user-mediated actions"

Every action that touches your data requires your explicit consent.

---

## Dashboard

The Dashboard shows your Mac's health in real-time.

### Available Metrics

All metrics work fully in sandbox:

| Metric | Source | Details |
|--------|--------|---------|
| **CPU Usage** | Native Mach APIs | Per-core and total |
| **Memory** | Native Mach APIs | Active, wired, compressed, free |
| **Memory Pressure** | DispatchSource | System pressure notifications |
| **Disk** | FileManager | Total, used, free space |
| **Network** | BSD getifaddrs | Upload/download speeds |

### Memory Pressure Indicator

The pressure indicator reflects actual system state:
- **Normal (Green)** - System has plenty of memory
- **Warning (Yellow)** - Consider closing some apps
- **Critical (Red)** - Performance may be affected

### What You Can Do

When memory pressure is elevated:
1. Review the process list for memory hogs
2. Close unused applications
3. Close browser tabs
4. Clean cached files in selected folders

---

## Process Manager

Monitor and manage running applications.

### Viewing Processes

The process list shows:
- Application name and icon
- Process ID (PID)
- CPU usage percentage
- Memory consumption
- Bundle identifier

### Filtering

| Filter | Shows |
|--------|-------|
| **All** | All visible processes |
| **User Apps** | Regular applications |
| **Background** | Background processes |
| **Heavy** | Memory > 100 MB |

### Terminating Apps

**Graceful Quit:**
1. Select an app
2. Click "Quit"
3. App is asked to close normally
4. Unsaved work prompts appear

**Force Quit:**
1. Select an unresponsive app
2. Click "Force Quit"
3. Confirm the action
4. App terminates immediately

**Protected Processes:**
System-critical processes cannot be terminated:
- Finder, Dock, WindowServer
- System services
- Craig-O-Clean itself

### Sandbox Limitations

In sandbox mode:
- Can terminate your own user's apps
- Cannot terminate system processes owned by root
- Some background helpers may be protected

---

## Browser Tab Management

Manage tabs across browsers with user permission.

### Supported Browsers

| Browser | Support | Permission Required |
|---------|---------|-------------------|
| Safari | Full | Automation |
| Chrome | Full | Automation |
| Edge | Full | Automation |
| Brave | Full | Automation |
| Arc | Partial | Automation |

### Granting Permission

First time accessing browser tabs:

1. Click on "Browser Tabs" section
2. System shows: "Craig-O-Clean would like to control [Browser]"
3. Click "OK" to allow
4. Tabs appear in the list

**If you clicked "Don't Allow":**
1. Open System Settings
2. Go to Privacy & Security → Automation
3. Find Craig-O-Clean
4. Enable the browser

### Managing Tabs

Once permission is granted:

**View Tabs:**
- See all open tabs across windows
- Grouped by domain
- Shows title and URL

**Close Tabs:**
- Click X on individual tab
- "Close All" for a domain
- Select multiple and "Close Selected"

**Heavy Tabs:**
Quick button to close resource-intensive tabs:
- YouTube, Netflix, Twitch
- Social media sites
- Web apps like Figma

### Why Permission is Needed

Browser tab access requires Automation permission because:
- Craig-O-Clean uses AppleScript to communicate with browsers
- This is a privacy-sensitive operation
- macOS requires explicit user consent

---

## File Cleanup

Clean files in folders you explicitly select.

### How It Works

Unlike the standard edition, Sandbox Edition:
1. **Cannot** access arbitrary folders
2. **Can** access folders you select via Open Panel
3. **Saves** your selections as bookmarks for future access

### Adding a Folder

1. Click "Add Folder" button
2. Navigate to the folder you want to clean
3. Click "Open" to grant access
4. Folder appears in your saved list

**Suggested Locations:**
- `~/Library/Caches/` - User cache files
- `~/Downloads/` - Old downloads
- `~/Documents/` - Document folders

### Scanning

After adding a folder:
1. Select it from the list
2. Click "Scan"
3. Review found items:
   - Cache files
   - Temporary files
   - Log files
   - Large files

### Cleaning

1. Review scan results
2. Uncheck items you want to keep
3. Choose cleanup method:
   - **Move to Trash** - Recoverable
   - **Delete** - Permanent
4. Confirm the action

### Security-Scoped Bookmarks

Your folder selections are saved as secure bookmarks:
- Persist across app restarts
- Can be revoked anytime
- Only grant access to specific folders

### Cleaning App Container

Craig-O-Clean can always clean its own container:
- App's cache files
- Temporary data
- No permission needed

---

## Permissions

### Required Permissions

| Permission | Purpose | Required? |
|------------|---------|-----------|
| None | Basic monitoring | ✅ Automatic |

### Optional Permissions

| Permission | Purpose | How to Grant |
|------------|---------|--------------|
| **Automation** | Browser tab control | Prompted on first use |
| **Accessibility** | Advanced features | System Settings |
| **File Access** | Folder cleanup | Open Panel selection |

### Managing Permissions

**View Current Status:**
1. Open Craig-O-Clean
2. Go to Settings → Permissions
3. See status for each permission

**Grant New Permission:**
1. Click "Enable" next to the permission
2. Follow system prompts
3. Status updates automatically

**Revoke Permission:**
1. Open System Settings
2. Go to Privacy & Security
3. Find the relevant section
4. Disable Craig-O-Clean

### Permission Explanations

**Automation:**
> "Craig-O-Clean would like to control [App]"

This allows reading browser tab information and closing tabs. Craig-O-Clean cannot:
- Access browsing history
- Read passwords or cookies
- Access other browser data

**Accessibility:**
> Required for some advanced features

Currently used for enhanced window management. Craig-O-Clean does not:
- Log keystrokes
- Monitor screen content
- Access sensitive UI elements

**File Access:**
> Via Open Panel and security-scoped bookmarks

You control exactly which folders Craig-O-Clean can access. It cannot:
- Access folders you haven't selected
- Access system folders
- Access other users' files

---

## FAQ

### General

**Q: Why is this version different from the standard version?**

A: The Sandbox Edition is designed for Mac App Store distribution, which requires compliance with Apple's App Sandbox. This ensures your security and privacy but limits some features.

**Q: Is my data safe?**

A: Yes! The sandbox ensures Craig-O-Clean can only access:
- System metrics (CPU, memory, etc.)
- Folders you explicitly select
- Browsers you grant permission for

**Q: Can I use both editions?**

A: Yes, but they're separate apps with separate settings and permissions.

### Features

**Q: Why can't I purge memory?**

A: The `purge` command requires administrator privileges, which sandboxed apps cannot request. Instead:
- Close memory-heavy apps
- Close browser tabs
- Clean cache files

**Q: Why can't I clean all caches?**

A: Sandboxed apps can only access folders you explicitly grant. Add cache folders via the folder picker to clean them.

**Q: Some processes show "Cannot terminate"?**

A: In sandbox mode, you can only terminate processes owned by your user account. System processes require elevated privileges.

### Permissions

**Q: I denied a permission. How do I grant it now?**

A:
1. Open System Settings
2. Go to Privacy & Security
3. Find Automation (for browsers) or relevant section
4. Enable Craig-O-Clean

**Q: Why do I need to grant permission for each browser?**

A: macOS requires separate permission for each app you want to automate. This protects you from apps secretly controlling your software.

**Q: The permission prompt doesn't appear?**

A: Try:
1. Restart Craig-O-Clean
2. Ensure the browser is installed
3. Reset with: `tccutil reset AppleEvents com.craigoclean.sandbox`

### Troubleshooting

**Q: The app crashes on launch?**

A: Try:
1. Restart your Mac
2. Reinstall from App Store
3. Check Console.app for error logs

**Q: Metrics aren't updating?**

A:
1. Check if auto-refresh is enabled
2. Try manual refresh (pull down or button)
3. Restart the app

**Q: Browser tabs don't load?**

A:
1. Check Automation permission
2. Ensure browser is running
3. Try restarting both apps

---

## Privacy Statement

Craig-O-Clean Sandbox Edition:

- ✅ Runs entirely locally
- ✅ Collects no personal data
- ✅ Sends nothing over the network
- ✅ Stores only your preferences locally
- ✅ Respects all sandbox restrictions

Your Mac, your data, your control.

---

## Getting Help

- **In-App:** Settings → Help
- **Support:** [SUPPORT.md](../SUPPORT.md)
- **Issues:** GitHub repository

---

*Craig-O-Clean Sandbox Edition - Secure • Private • Powerful*
