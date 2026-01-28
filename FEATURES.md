# Craig-O-Clean Features

A comprehensive guide to all features available in Craig-O-Clean.

---

## Table of Contents

1. [Menu Bar App](#menu-bar-app)
2. [System Dashboard](#system-dashboard)
3. [Process Manager](#process-manager)
4. [Memory Optimizer](#memory-optimizer)
5. [Browser Tab Manager](#browser-tab-manager)
6. [Settings & Preferences](#settings--preferences)
7. [Auto Cleanup](#auto-cleanup)
8. [Feature Comparison](#feature-comparison)

---

## Menu Bar App

Craig-O-Clean lives in your menu bar for instant access without cluttering your Dock.

### Menu Bar Icon

| State | Appearance | Meaning |
|-------|------------|---------|
| Normal | Default template | System healthy |
| Warning | Orange tint | Memory/CPU elevated |
| Critical | Red tint | High memory pressure |

### Left-Click Popover

The mini dashboard provides at-a-glance information:

```
┌─────────────────────────────────────┐
│  Memory Usage                        │
│  ████████████░░░░░░  68% (10.8 GB)  │
│  [Normal] Active: 6.2GB Wired: 2.1GB│
│                                      │
│  CPU: 23%    Disk: 45%              │
│                                      │
│  Top Memory Users                    │
│  ┌───────────────────────────┐      │
│  │ 🌐 Chrome          2.1 GB │      │
│  │ 🔨 Xcode           1.8 GB │      │
│  │ 🧭 Safari          850 MB │      │
│  │ 💬 Slack           420 MB │      │
│  │ 📧 Mail            380 MB │      │
│  │ 🎵 Spotify         320 MB │      │
│  └───────────────────────────┘      │
│                                      │
│  [Smart Cleanup]  [Open Full App]   │
└─────────────────────────────────────┘
```

**Features:**
- Real-time memory, CPU, and disk usage
- Memory pressure indicator with color coding
- Top 6 memory-consuming processes
- Quick action buttons

### Right-Click Context Menu

```
┌────────────────────────────┐
│ About Craig-O-Clean        │
├────────────────────────────┤
│ Quick Actions            ▶ │
│   ├─ Smart Cleanup         │
│   ├─ Close Background Apps │
│   ├─ Close Heavy Apps      │
│   └─ Memory Clean          │
├────────────────────────────┤
│ Force Quit App           ▶ │
│   ├─ Chrome                │
│   ├─ Safari                │
│   └─ [All running apps]    │
├────────────────────────────┤
│ Open Control Center        │
├────────────────────────────┤
│ Quit                       │
└────────────────────────────┘
```

---

## System Dashboard

The Dashboard provides a comprehensive view of your Mac's health.

### CPU Metrics

| Metric | Description | Data Source |
|--------|-------------|-------------|
| **Total Usage** | Combined CPU usage percentage | `host_processor_info()` |
| **Per-Core** | Individual core utilization | Per-CPU statistics |
| **Load Average** | 1, 5, 15 minute averages | `getloadavg()` |
| **User vs System** | Time in user vs kernel mode | CPU state counters |

**Visual Elements:**
- Circular gauge showing total CPU %
- Bar chart for per-core breakdown
- Historical trend line (optional)

### Memory Metrics

| Metric | Description | Visual |
|--------|-------------|--------|
| **Active** | Memory in active use | Blue bar segment |
| **Wired** | System-reserved memory | Purple bar segment |
| **Compressed** | Compressed pages in RAM | Green bar segment |
| **Inactive** | Cached, reclaimable | Gray bar segment |
| **Free** | Immediately available | Empty space |
| **Swap** | Virtual memory on disk | Separate indicator |

**Memory Pressure:**
- **Normal** (Green): < 60% - No action needed
- **Warning** (Yellow): 60-80% - Consider cleanup
- **Critical** (Red): > 80% - Cleanup recommended

### Disk Metrics

| Metric | Description |
|--------|-------------|
| **Total Capacity** | Full disk size |
| **Used Space** | Space occupied by files |
| **Free Space** | Available for new data |
| **Purgeable** | Space reclaimable by system |

**Visual:** Horizontal bar showing used vs. free with percentage.

### Network Metrics

| Metric | Description |
|--------|-------------|
| **Download Speed** | Current incoming data rate (KB/s, MB/s) |
| **Upload Speed** | Current outgoing data rate |
| **Total Downloaded** | Session cumulative download |
| **Total Uploaded** | Session cumulative upload |

**Updates:** Every refresh interval (configurable 1-10 seconds).

---

## Process Manager

Complete visibility and control over running processes.

### Process List

Each process entry includes:

| Field | Description | Example |
|-------|-------------|---------|
| **Icon** | App icon or generic | 🌐 |
| **Name** | Process/app name | "Google Chrome" |
| **PID** | Process identifier | 12345 |
| **CPU %** | Current CPU usage | 5.2% |
| **Memory** | RAM consumption | 1.2 GB |
| **Threads** | Thread count | 42 |
| **Bundle ID** | App identifier | com.google.Chrome |

### Filtering Options

| Filter | Shows |
|--------|-------|
| **All** | Every running process |
| **User Apps** | Apps with UI (activation policy: regular) |
| **System** | Background daemons and helpers |
| **Heavy (>100MB)** | Memory-intensive processes |

### Search

- Search by process name
- Search by bundle identifier
- Search by PID
- Case-insensitive matching
- Real-time filtering

### Sorting

| Sort By | Order |
|---------|-------|
| **Name** | Alphabetical A-Z |
| **CPU** | Highest usage first |
| **Memory** | Largest first |
| **PID** | Lowest first |

### Process Actions

| Action | Method | Use Case |
|--------|--------|----------|
| **Quit** | `NSRunningApplication.terminate()` | Normal app closure |
| **Force Quit** | `NSRunningApplication.forceTerminate()` + SIGKILL | Unresponsive apps |
| **View Details** | Inspection popover | Debug information |

### Process Details View

Clicking a process reveals:
- Full executable path
- Command line arguments
- Working directory
- Parent process
- Creation time
- User owner

### Export

Export process list to CSV including all visible columns.

---

## Memory Optimizer

Intelligent memory management with smart suggestions.

### Analysis Categories

| Category | Criteria | Risk Level |
|----------|----------|------------|
| **Heavy Memory Users** | > 500 MB RAM | Low |
| **Background Apps** | No visible UI | Low |
| **Inactive Apps** | Not recently used | Low |
| **Browser Processes** | Browser helpers/renderers | Medium |
| **System Helpers** | App helper processes | Medium |

### Smart Cleanup

Automatically selects optimal cleanup candidates based on:
1. Memory consumption
2. User interaction recency
3. Process importance
4. System dependencies

**Algorithm:**
1. Exclude protected processes
2. Prioritize background apps
3. Weight by memory usage
4. Respect user exclusions

### Quick Actions

| Action | Effect |
|--------|--------|
| **Smart Cleanup** | Close best candidates automatically |
| **Close Background** | Terminate all background apps |
| **Close Top 3 Heavy** | Close three largest memory users |
| **Memory Clean** | Run sync + purge commands |

### Protected Processes

Never terminated automatically:
- `kernel_task`
- `launchd`
- `Finder`
- `Dock`
- `WindowServer`
- `loginwindow`
- `SystemUIServer`
- `coreauthd`
- Craig-O-Clean itself

### Results Summary

After cleanup:
- Apps terminated count
- Estimated memory freed
- Remaining memory pressure
- Any errors encountered

---

## Browser Tab Manager

Cross-browser tab management from a single interface.

### Supported Browsers

| Browser | Support Level | Scripting Method |
|---------|--------------|------------------|
| **Safari** | Full | Native AppleScript |
| **Google Chrome** | Full | Chrome AppleScript dictionary |
| **Microsoft Edge** | Full | Chromium-based scripting |
| **Brave Browser** | Full | Chromium-based scripting |
| **Arc** | Partial | Limited AppleScript support |

### Tab Information

Each tab displays:
- Browser icon
- Tab title
- Full URL
- Domain name
- Window and tab index
- Active tab indicator

### Tab Actions

| Action | Scope | Method |
|--------|-------|--------|
| **Close Tab** | Single tab | AppleScript close command |
| **Close Window Tabs** | All tabs in window | Batch close |
| **Close by Domain** | All tabs from domain | Domain filter + batch |
| **Close Heavy Tabs** | Resource-intensive sites | Predefined domain list |

### Heavy Tab Detection

Sites flagged as heavy:
- YouTube
- Netflix
- Twitch
- Facebook
- Twitter/X
- Instagram
- Reddit
- Discord
- Figma
- Google Maps

### Domain Statistics

View tab distribution by domain:
- Tab count per domain
- Sorted by frequency
- Quick "Close All" per domain

### Permission Flow

```
First access to browser
        │
        ▼
┌───────────────────────────────────┐
│ "Craig-O-Clean would like to      │
│  control Safari. Allow?"          │
│                                   │
│  [Don't Allow]     [OK]           │
└───────────────────────────────────┘
        │
        ▼ (if OK)
Tabs loaded and displayed
```

---

## Settings & Preferences

### General Settings

| Setting | Options | Default |
|---------|---------|---------|
| **Show in Dock** | On/Off | Off |
| **Launch at Login** | On/Off | Off |
| **Enable Notifications** | On/Off | On |
| **Theme** | System/Light/Dark | System |

### Monitoring Settings

| Setting | Range | Default |
|---------|-------|---------|
| **Refresh Interval** | 1-10 seconds | 2 seconds |
| **Memory Warning** | 50-95% | 80% |
| **CPU Warning** | 50-100% | 90% |
| **Show Per-Core** | On/Off | Off |

### Permissions Management

View and configure:
- Automation permission status per browser
- Accessibility permission status
- Links to System Settings
- Permission request buttons

### Diagnostics

- System information display
- App version and build
- Export diagnostic report
- View recent errors

---

## Auto Cleanup

Automated memory management (configurable).

### Triggers

| Trigger | Condition | Action |
|---------|-----------|--------|
| **Memory Pressure** | Critical for > 30 seconds | Smart Cleanup |
| **Scheduled** | User-defined interval | Background cleanup |
| **App Launch** | On Craig-O-Clean start | Optional analysis |

### Configuration

| Setting | Options |
|---------|---------|
| **Enable Auto Cleanup** | On/Off (default: Off) |
| **Trigger Threshold** | Memory pressure level |
| **Excluded Apps** | Apps to never close |
| **Notification** | Alert before/after cleanup |

### Safety Features

- **Disabled by default** - User must opt-in
- **Confirmation option** - Ask before each cleanup
- **Protected processes** - Never auto-terminated
- **Rate limiting** - Minimum interval between cleanups

---

## Feature Comparison

### Standard vs. Sandbox Edition

| Feature | Standard | Sandbox (MAS) |
|---------|----------|---------------|
| System Metrics | ✅ Full | ✅ Full |
| Process Monitoring | ✅ Full | ✅ Full |
| Process Termination | ✅ All user processes | ✅ User processes only |
| Browser Tab Management | ✅ Full | ✅ With permission |
| Memory Purge | ✅ With admin | ❌ Not available |
| Global Cache Cleanup | ✅ Available | ❌ User-scoped only |
| File Cleanup | ✅ System-wide | ✅ Selected folders only |
| Auto Cleanup | ✅ Full | ✅ Limited |

### Editions

| Edition | Distribution | Features |
|---------|--------------|----------|
| **Standard** | Direct / Developer ID | Full functionality |
| **Sandbox** | Mac App Store | App Store compliant |
| **Terminator** | Direct | Advanced + Agent system |

---

## Technical Specifications

### APIs Used

| Function | API |
|----------|-----|
| CPU Metrics | `host_processor_info()` |
| Memory Metrics | `host_statistics64()` |
| Disk Metrics | `FileManager.attributesOfFileSystem()` |
| Network Metrics | `getifaddrs()` |
| Process List | `proc_listpids()`, `NSWorkspace` |
| Process Info | `proc_pidinfo()` |
| Process Control | `NSRunningApplication`, POSIX signals |
| Browser Automation | `NSAppleScript` |

### Performance

| Metric | Typical Value |
|--------|---------------|
| Memory Usage | 50-150 MB |
| CPU Usage (idle) | < 1% |
| CPU Usage (active) | 2-5% |
| Refresh Overhead | < 10ms |

---

*For usage instructions, see [USER_GUIDE.md](USER_GUIDE.md)*
*For troubleshooting, see [SUPPORT.md](SUPPORT.md)*
