# Craig-O-Clean User Guide

Welcome to Craig-O-Clean, your comprehensive macOS system utility for monitoring and optimizing your Mac's performance.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Menu Bar App](#menu-bar-app)
3. [Dashboard](#dashboard)
4. [Process Manager](#process-manager)
5. [Memory Cleanup](#memory-cleanup)
6. [Browser Tab Management](#browser-tab-management)
7. [Settings & Permissions](#settings--permissions)
8. [Keyboard Shortcuts](#keyboard-shortcuts)
9. [Tips & Best Practices](#tips--best-practices)

---

## Getting Started

### First Launch

When you first launch Craig-O-Clean:

1. **Menu Bar Icon** - Look for the Craig-O-Clean icon in your menu bar (top-right of screen)
2. **Click the Icon** - Left-click to open the mini dashboard
3. **Grant Permissions** - Follow prompts to enable necessary permissions

### System Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon Mac (M1, M2, M3, or later)
- ~50 MB disk space

---

## Menu Bar App

Craig-O-Clean lives in your menu bar for quick access.

### Left-Click: Mini Dashboard

Opens a compact popover showing:
- **Memory Usage** - Current RAM usage with pressure indicator
- **CPU Usage** - System load at a glance
- **Disk Space** - Available storage
- **Top Processes** - 6 highest memory consumers
- **Quick Actions** - One-click cleanup buttons

### Right-Click: Context Menu

Access quick actions:
- **Smart Cleanup** - Intelligently close memory-heavy apps
- **Close Background Apps** - Close apps running in background
- **Close Heavy Apps** - Close top memory consumers
- **Memory Clean** - Advanced memory optimization (requires admin)
- **Force Quit App** - Submenu to force quit any running app
- **Open Control Center** - Launch the full application window
- **About / Quit** - App info and exit

### Status Indicator Colors

The menu bar icon changes color based on system health:
- **Default (Template)** - System healthy, normal operation
- **Orange** - Warning: Memory or CPU usage elevated
- **Red** - Critical: High memory pressure or CPU usage

---

## Dashboard

The Dashboard provides a comprehensive view of your system's health.

### CPU Card

- **Usage Gauge** - Visual percentage of CPU utilization
- **Per-Core Bars** - Individual core usage (click to expand)
- **Load Averages** - 1, 5, and 15-minute load averages

### Memory Card

- **Usage Bar** - Color-coded breakdown:
  - **Blue** - Active memory (in use by apps)
  - **Purple** - Wired memory (system reserved)
  - **Green** - Compressed memory
  - **Gray** - Inactive/Free
- **Pressure Indicator** - Normal / Warning / Critical
- **Swap Usage** - Virtual memory on disk

### Disk Card

- **Usage Visualization** - Used vs. available space
- **Capacity** - Total, used, and free in GB/TB
- **Percentage** - Quick reference of disk fullness

### Network Card

- **Download Speed** - Current incoming data rate
- **Upload Speed** - Current outgoing data rate
- **Total Traffic** - Cumulative bytes transferred

### Refresh Controls

- **Auto-Refresh Toggle** - Enable/disable automatic updates
- **Interval Selector** - Choose 1-10 second refresh rate
- **Manual Refresh** - Click refresh button anytime

---

## Process Manager

View and manage all running processes on your Mac.

### Process List

Each process shows:
- **Icon** - App icon (for user apps)
- **Name** - Process or app name
- **PID** - Process identifier
- **CPU %** - Current CPU usage
- **Memory** - RAM consumption
- **Bundle ID** - Application identifier (when available)

### Filtering

Use the filter buttons to narrow the list:
- **All** - Show all processes
- **User Apps** - Only regular applications
- **System** - Background and system processes
- **Heavy (>100MB)** - Memory-intensive processes

### Search

Type in the search bar to find processes by:
- Process name
- Bundle identifier
- PID

### Sorting

Click column headers or use the sort menu:
- Name (A-Z)
- CPU Usage (High to Low)
- Memory Usage (High to Low)
- PID

### Terminating Processes

1. **Select a Process** - Click on any process row
2. **Click Quit** - Graceful termination request
3. **Click Force Quit** - Immediate termination (use with caution)
4. **Confirm** - Review the confirmation dialog

**Protected Processes**: Craig-O-Clean prevents termination of critical system processes like `kernel_task`, `launchd`, `Finder`, etc.

### Export to CSV

Click the export button to save the process list:
- Includes all visible processes
- Contains name, PID, CPU%, memory, bundle ID
- Useful for analysis or support

---

## Memory Cleanup

Optimize your Mac's memory usage with intelligent cleanup suggestions.

### Analysis

Click "Analyze" to scan for cleanup candidates. Craig-O-Clean categorizes apps:

1. **Heavy Memory Users** (>500 MB)
   - Apps consuming significant RAM
   - Best candidates for freeing memory

2. **Background Apps**
   - Apps running without a visible window
   - Often forgotten but using resources

3. **Inactive Apps**
   - Apps not recently used
   - Safe to close in most cases

4. **Browser Processes**
   - Browser helpers and renderers
   - Often major memory consumers

### Quick Actions

- **Smart Cleanup** - Automatically selects best candidates and closes them
- **Close Background** - Closes all background apps at once
- **Close Top 3 Heavy** - Closes the three largest memory users

### Manual Selection

1. Review the candidate list
2. Uncheck any apps you want to keep
3. Click "Clean Selected" to terminate checked apps
4. View the results summary

### Memory Purge (Advanced)

The "Memory Clean" option runs system commands to:
1. Flush filesystem buffers (`sync`)
2. Purge inactive memory (`purge`)

**Note**: Requires administrator password. Results vary by system state.

---

## Browser Tab Management

Manage tabs across multiple browsers from one place.

### Supported Browsers

- Safari
- Google Chrome
- Microsoft Edge
- Brave Browser
- Arc

### Permissions Required

Each browser requires Automation permission:

1. First time accessing a browser, macOS will prompt
2. Click "OK" to allow Craig-O-Clean to control the browser
3. Or enable manually in System Settings → Privacy & Security → Automation

### Tab View

The tab list shows:
- **Browser Icon** - Which browser owns the tab
- **Tab Title** - Page title
- **URL** - Full web address
- **Domain** - Simplified domain name
- **Window/Tab Index** - Position in browser

### Grouping

Tabs are grouped by domain, showing:
- Domain name
- Number of tabs from that domain
- "Close All" button for the domain

### Closing Tabs

- **Individual Tab** - Click the X button on any tab row
- **By Domain** - Click "Close All" next to a domain
- **Bulk Selection** - Check multiple tabs, then "Close Selected"
- **Heavy Tabs** - Quick button to close resource-intensive tabs (YouTube, Netflix, etc.)

### Domain Statistics

View which domains have the most tabs open, helping identify tab hoarding.

---

## Settings & Permissions

### General Settings

- **Show in Dock** - Display app icon in Dock when Control Center is open
- **Launch at Login** - Start Craig-O-Clean when you log in
- **Enable Notifications** - Show system alerts and cleanup notifications

### Monitoring Settings

- **Refresh Interval** - How often to update metrics (1-10 seconds)
- **Memory Warning Threshold** - Percentage to trigger warning (default: 80%)
- **CPU Warning Threshold** - Percentage to trigger warning (default: 90%)

### Permissions

View and manage permissions:

#### Automation Permission

Required for browser tab management.

**To Enable:**
1. Open System Settings
2. Go to Privacy & Security → Automation
3. Find Craig-O-Clean
4. Enable each browser you want to manage

**Status Indicators:**
- ✅ Green checkmark - Permission granted
- ⚠️ Yellow warning - Permission needed
- ❌ Red X - Permission denied

#### Accessibility Permission (Optional)

Enables advanced features.

**To Enable:**
1. Open System Settings
2. Go to Privacy & Security → Accessibility
3. Click the lock to make changes
4. Add or enable Craig-O-Clean

### Diagnostics

- **System Info** - View macOS version, hardware details
- **Export Diagnostics** - Generate a report for support

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open Control Center | ⌘O (from popover) |
| Refresh Data | ⌘R (in main window) |
| Quit Craig-O-Clean | ⌘Q |
| Close Window | ⌘W |
| Settings | ⌘, |

---

## Tips & Best Practices

### For Best Performance

1. **Regular Cleanup** - Run Smart Cleanup weekly
2. **Monitor Trends** - Watch for apps that consistently use high memory
3. **Close Unused Tabs** - Browser tabs are major memory consumers
4. **Restart Heavy Apps** - Apps like browsers benefit from occasional restarts

### Memory Management

1. **Don't Over-Clean** - Some inactive memory is normal and helpful
2. **Focus on Pressure** - The pressure indicator matters more than raw numbers
3. **Close vs. Hide** - Hidden apps still use memory; close what you don't need

### Browser Tips

1. **Tab Hygiene** - Close tabs you're not actively using
2. **Bookmark Instead** - Bookmark pages rather than keeping tabs open
3. **Use Tab Suspenders** - Consider browser extensions that suspend inactive tabs

### When to Use Force Quit

- App is completely unresponsive
- App's "Quit" command doesn't work
- Spinning beach ball won't stop

**Caution**: Force quitting may cause unsaved work loss.

### Privacy Note

Craig-O-Clean:
- Runs entirely locally on your Mac
- Does not collect or transmit any data
- Does not access file contents
- Only reads process and system metrics

---

## Need Help?

- **Support**: See [SUPPORT.md](SUPPORT.md) for troubleshooting
- **Features**: See [FEATURES.md](FEATURES.md) for detailed feature docs
- **Issues**: Report bugs at the project repository

---

*Craig-O-Clean - Monitor • Optimize • Control*
