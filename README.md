# ClearMind Control Center

A powerful, production-ready macOS system utility for Apple Silicon Macs. ClearMind provides comprehensive system monitoring, process management, memory optimization, and browser tab control—all in a beautiful, native SwiftUI interface.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-Optimized-green)

## Features

### 📊 System Dashboard
- **Real-time CPU monitoring** - Total usage, per-core breakdown, load averages
- **Memory metrics** - Used/free RAM, active/inactive/wired/compressed memory, swap usage
- **Memory pressure indicator** - Visual health status (Normal/Warning/Critical)
- **Disk usage** - Total, used, and free space with percentage
- **Network activity** - Download/upload speeds, total traffic
- **Auto-refresh** with configurable intervals (1-10 seconds)

### 📋 Process & App Manager
- **Complete process list** - All running apps and system processes
- **Rich information** - PID, CPU %, memory, threads, bundle ID
- **Smart filtering** - User apps only, system processes, heavy apps (>100MB)
- **Powerful search** - Find processes by name or bundle ID
- **Multiple sort options** - Name, CPU, memory, PID
- **Safe termination** - Graceful quit with confirmation dialogs
- **Force quit** - For unresponsive processes (with warnings for critical processes)
- **Export to CSV** - Save process lists for analysis
- **Process details** - View arguments, path, creation time, and more

### 🧹 Memory Cleanup & Optimization
- **Intelligent analysis** - Identifies cleanup candidates by memory usage
- **Category-based suggestions**:
  - Heavy Memory Users (>500MB)
  - Background Apps
  - Inactive Apps
  - Browser-related processes
- **Quick actions**:
  - Smart Cleanup (automatic best selection)
  - Close Background Apps
  - Close Top 3 Heavy Apps
- **Multi-step workflow** - Review, deselect, then execute
- **Safe operation** - Never terminates protected system processes
- **Advanced purge** - Optional memory purge command (requires admin)

### 🌐 Browser Tab Management
- **Supported browsers**: Safari, Google Chrome, Microsoft Edge, Brave, Arc
- **Complete tab listing** - Window index, tab index, title, URL, domain
- **Bulk operations**:
  - Close individual tabs
  - Close all tabs in a window
  - Close tabs by domain (e.g., all YouTube tabs)
  - Close duplicate tabs
- **Domain statistics** - See which domains have the most tabs
- **Permission guidance** - Step-by-step instructions for enabling Automation

### 🖥️ Menu Bar Mini-App
- **Always accessible** - Brain icon in menu bar
- **Quick stats** - CPU, memory, disk at a glance
- **Memory pressure indicator** - Color-coded health status
- **Quick actions** - Smart Cleanup, Close Background Apps
- **Top processes** - See top 6 memory consumers
- **Right-click menu** - Quick access to actions and settings

### ⚙️ Settings & Permissions
- **General settings** - Dock visibility, launch at login, notifications
- **Monitoring config** - Refresh intervals, warning thresholds
- **Permission management** - View and request Automation permissions
- **Privacy-focused** - No data collection, all processing local
- **Diagnostics** - View system info, export diagnostic reports

## Screenshots

<details>
<summary>Click to view screenshots</summary>

### Dashboard
The main dashboard showing system health at a glance:
- CPU usage gauge with per-core breakdown
- Memory usage with detailed breakdown bar
- Disk space visualization
- Network throughput metrics

### Process Manager
Full process list with filtering and sorting:
- Filter by user apps, system processes, or heavy apps
- Search by name or bundle ID
- Quick terminate and force quit buttons

### Memory Cleanup
Intelligent memory optimization:
- Categorized cleanup candidates
- Select/deselect individual apps
- Potential memory savings estimate

### Browser Tabs
Cross-browser tab management:
- All tabs from all browsers in one view
- Close tabs individually or in bulk
- Domain-based grouping

</details>

## Requirements

- **macOS 14 (Sonoma)** or later
- **Apple Silicon** Mac (M1, M2, M3, or later)
- **Xcode 15+** for building from source

## Installation

### From Source

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-repo/clearmind-control-center.git
   cd clearmind-control-center
   ```

2. **Open in Xcode**:
   ```bash
   open Craig-O-Clean.xcodeproj
   ```

3. **Select your team** in Signing & Capabilities

4. **Build and run** (⌘R)

### From Release

1. Download the latest `.dmg` from Releases
2. Drag ClearMind to Applications
3. Launch and grant requested permissions

## Permissions Required

ClearMind requires certain permissions for full functionality:

### Automation (Required for Browser Tab Management)
Allows ClearMind to control Safari, Chrome, Edge, and other browsers to list and close tabs.

**To enable:**
1. Open System Settings → Privacy & Security → Automation
2. Find ClearMind Control Center
3. Enable access for each browser you want to manage

### Accessibility (Optional)
Enables advanced system interactions and window management.

**To enable:**
1. Open System Settings → Privacy & Security → Accessibility
2. Click the lock to make changes
3. Enable ClearMind Control Center

## Usage

### Menu Bar
- **Left-click**: Open mini-dashboard popover
- **Right-click**: Show context menu with quick actions

### Main Window
Access the full Control Center by:
- Clicking "Open Full App" in the popover
- Right-click → "Open Control Center"
- Keyboard shortcut: ⌘O (when popover is open)

### Keyboard Shortcuts
| Action | Shortcut |
|--------|----------|
| Open Control Center | ⌘O |
| Quit | ⌘Q |
| Refresh | ⌘R (in main window) |

## Project Structure

```
Craig-O-Clean/
├── Core/                          # Core services
│   ├── SystemMetricsService.swift # CPU, RAM, disk, network monitoring
│   ├── BrowserAutomationService.swift # Browser tab management
│   ├── MemoryOptimizerService.swift # Memory cleanup logic
│   └── PermissionsService.swift   # Permission handling
├── UI/                            # SwiftUI views
│   ├── MainAppView.swift          # Main navigation container
│   ├── DashboardView.swift        # System health dashboard
│   ├── ProcessManagerView.swift   # Process list and management
│   ├── MemoryCleanupView.swift    # Memory optimization UI
│   ├── BrowserTabsView.swift      # Browser tab management UI
│   ├── SettingsPermissionsView.swift # Settings and permissions
│   └── MenuBarContentView.swift   # Menu bar popover
├── Tests/
│   ├── ClearMindTests/            # Unit tests
│   └── ClearMindUITests/          # UI tests
├── Craig_O_CleanApp.swift         # App entry point
├── ProcessManager.swift           # Process management
├── SystemMemoryManager.swift      # Legacy memory manager
└── Assets.xcassets/               # App icons and assets
```

## Architecture

ClearMind follows a clean, modular architecture:

- **Services Layer**: Core business logic with Combine publishers
- **UI Layer**: SwiftUI views with environment objects
- **Integration Layer**: AppKit interop for menu bar and system APIs

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed documentation.

## Security

ClearMind is designed with security in mind:

- **No network connections** - All processing happens locally
- **No data collection** - Your data never leaves your Mac
- **Hardened Runtime** - Signed and notarization-ready
- **Safe process termination** - Protects critical system processes

See [SECURITY_NOTES.md](SECURITY_NOTES.md) for security details.

## Testing

### Run Unit Tests
```bash
xcodebuild test -scheme Craig-O-Clean -destination 'platform=macOS'
```

### Run UI Tests
```bash
xcodebuild test -scheme Craig-O-Clean -destination 'platform=macOS' -only-testing:ClearMindUITests
```

## Building for Distribution

1. **Archive**:
   ```bash
   xcodebuild archive -scheme Craig-O-Clean -archivePath build/ClearMind.xcarchive
   ```

2. **Export**:
   ```bash
   xcodebuild -exportArchive -archivePath build/ClearMind.xcarchive \
     -exportPath build/ -exportOptionsPlist ExportOptions.plist
   ```

3. **Notarize** (requires Apple Developer account):
   ```bash
   xcrun notarytool submit build/ClearMind.app.zip --wait
   ```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add/update tests as needed
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with SwiftUI and Combine
- Uses native macOS system APIs
- AppleScript integration for browser automation
- SF Symbols for icons

---

Made with ❤️ for macOS
