<div align="center">
  <img src="https://github.com/user-attachments/assets/485d839f-c025-4db7-94d3-823379e02d77" alt="Craig-O-Clean Logo" width="150"/>
</div>

# Craig-O-Clean Quick Start Guide

Get Craig-O-Clean running on your Mac in under 5 minutes!

---

## Prerequisites

| Requirement | Version |
|-------------|---------|
| macOS | 14 (Sonoma) or later |
| Xcode | 15.0 or later |
| Mac | Apple Silicon (M1/M2/M3) |

---

## Installation

### Option 1: Build from Source (Recommended for Developers)

```bash
# 1. Clone the repository
git clone https://github.com/your-repo/Craig-O-Cleaner.git
cd Craig-O-Cleaner

# 2. Open in Xcode
open Craig-O-Clean.xcodeproj

# 3. Build and Run
# Press ⌘R or click the Play button
```

### Option 2: Download Release

1. Download the latest `.dmg` from [Releases](https://github.com/your-repo/Craig-O-Cleaner/releases)
2. Open the DMG file
3. Drag Craig-O-Clean to your Applications folder
4. Launch from Applications or Spotlight

---

## First Launch

### 1. Find the Menu Bar Icon

After launching, look for the Craig-O-Clean icon in your menu bar (top-right of screen).

```
┌─────────────────────────────────────────────────┐
│  WiFi   Battery   [Craig-O-Clean]   Time   ... │
└─────────────────────────────────────────────────┘
```

### 2. Click to Open

**Left-click** the icon to open the mini dashboard:

```
┌─────────────────────────────┐
│  Memory: 68% (10.8/16 GB)   │
│  ████████████░░░░ Normal    │
│                             │
│  Top Memory Users:          │
│  • Chrome        2.1 GB     │
│  • Xcode         1.8 GB     │
│  • Safari        850 MB     │
│                             │
│  [Smart Cleanup] [Settings] │
└─────────────────────────────┘
```

### 3. Grant Permissions (Optional but Recommended)

For full functionality, grant these permissions when prompted:

| Permission | What It Enables |
|------------|-----------------|
| **Automation** | Control browser tabs |
| **Accessibility** | Advanced features |

---

## Quick Actions

### From Menu Bar (Right-Click)

| Action | What It Does |
|--------|--------------|
| **Smart Cleanup** | Automatically close memory-heavy apps |
| **Close Background Apps** | Close apps running in background |
| **Close Heavy Apps** | Close top 3 memory consumers |
| **Memory Clean** | Flush buffers & purge inactive memory |
| **Open Control Center** | Launch full application window |

### From Mini Dashboard (Left-Click)

1. **View Stats** - See memory, CPU, disk at a glance
2. **Top Processes** - See what's using the most memory
3. **Quick Cleanup** - One-click memory optimization
4. **Expand** - Open full Control Center

---

## Control Center Overview

Click "Open Control Center" to access all features:

```
┌────────────────────────────────────────────────────────┐
│  Craig-O-Clean Control Center                          │
├──────────┬─────────────────────────────────────────────┤
│          │                                             │
│ Dashboard│  [CPU]  [Memory]  [Disk]  [Network]        │
│          │                                             │
│ Processes│  Real-time gauges and metrics              │
│          │                                             │
│ Memory   │  ────────────────────────────────────      │
│          │                                             │
│ Browser  │  Detailed breakdowns and history           │
│          │                                             │
│ Settings │                                             │
│          │                                             │
└──────────┴─────────────────────────────────────────────┘
```

### Navigation

| Section | Purpose |
|---------|---------|
| **Dashboard** | System health overview with gauges |
| **Processes** | List, search, and manage running apps |
| **Memory** | Cleanup suggestions and optimization |
| **Browser** | Manage tabs across all browsers |
| **Settings** | Permissions and preferences |

---

## Common Tasks

### Close a Heavy App

1. **Right-click** menu bar icon
2. Select **Force Quit App**
3. Choose the app from the submenu
4. Confirm the action

### Free Up Memory

1. **Right-click** menu bar icon
2. Select **Smart Cleanup**
3. Review what will be closed
4. Confirm to proceed

### Manage Browser Tabs

1. Open **Control Center** (right-click → Open Control Center)
2. Navigate to **Browser Tabs**
3. Grant permission when prompted (first time only)
4. View all tabs across browsers
5. Close individual tabs or by domain

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Click menu icon | Open mini dashboard |
| Right-click icon | Open context menu |
| ⌘O | Open Control Center (from popover) |
| ⌘R | Refresh data |
| ⌘Q | Quit Craig-O-Clean |

---

## Troubleshooting Quick Fixes

### Menu bar icon not visible?

1. Check if app is running (Activity Monitor → search "Craig")
2. Restart the app
3. Check System Settings → Control Center → Menu Bar Only

### Can't control browser tabs?

1. Open System Settings
2. Go to Privacy & Security → Automation
3. Enable Craig-O-Clean for your browser

### Force quit not working?

Some processes require elevated privileges:
1. Try the standard Quit first
2. If that fails, use Force Quit
3. For system processes, restart may be needed

---

## Next Steps

| Resource | Description |
|----------|-------------|
| [USER_GUIDE.md](USER_GUIDE.md) | Complete usage documentation |
| [FEATURES.md](FEATURES.md) | Detailed feature descriptions |
| [SUPPORT.md](SUPPORT.md) | FAQ and troubleshooting |
| [README.md](README.md) | Project overview |

---

## Get Help

- **Documentation**: Check the docs folder
- **Issues**: Open a GitHub issue
- **Support**: See [SUPPORT.md](SUPPORT.md)

---

<div align="center">

**Craig-O-Clean** - Monitor • Optimize • Control

*Made with ❤️ for macOS*

</div>
