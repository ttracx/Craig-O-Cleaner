# ClearMind Control Center Architecture

This document describes the technical architecture and design of ClearMind Control Center, a production-ready macOS system utility for Apple Silicon.

## Overview

ClearMind Control Center is a native macOS application built with:
- **SwiftUI** for the user interface
- **Combine** for reactive data flow
- **AppKit interop** for system integration (menu bar, process management)
- **AppleScript** for browser automation

## Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────────┐
│                           ClearMind Control Center                          │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         UI LAYER (SwiftUI)                            │   │
│  │                                                                        │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │   │
│  │  │  Dashboard   │ │   Process    │ │   Memory     │ │   Browser    │ │   │
│  │  │    View      │ │   Manager    │ │   Cleanup    │ │    Tabs      │ │   │
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘ │   │
│  │                                                                        │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────────┐  │   │
│  │  │   Settings   │ │  MainApp     │ │     MenuBar Content          │  │   │
│  │  │    View      │ │    View      │ │        View                   │  │   │
│  │  └──────────────┘ └──────────────┘ └──────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    │ @EnvironmentObject                     │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      SERVICES LAYER (Core)                            │   │
│  │                                                                        │   │
│  │  ┌────────────────────┐  ┌────────────────────┐                      │   │
│  │  │  SystemMetrics     │  │  ProcessManager    │                      │   │
│  │  │    Service         │  │                    │                      │   │
│  │  │                    │  │  • Process list    │                      │   │
│  │  │  • CPU metrics     │  │  • Terminate       │                      │   │
│  │  │  • Memory metrics  │  │  • Force quit      │                      │   │
│  │  │  • Disk metrics    │  │  • Details         │                      │   │
│  │  │  • Network metrics │  │                    │                      │   │
│  │  └────────────────────┘  └────────────────────┘                      │   │
│  │                                                                        │   │
│  │  ┌────────────────────┐  ┌────────────────────┐                      │   │
│  │  │  MemoryOptimizer   │  │  BrowserAutomation │                      │   │
│  │  │    Service         │  │     Service        │                      │   │
│  │  │                    │  │                    │                      │   │
│  │  │  • Analyze usage   │  │  • Detect browsers │                      │   │
│  │  │  • Suggest cleanup │  │  • Fetch tabs      │                      │   │
│  │  │  • Execute cleanup │  │  • Close tabs      │                      │   │
│  │  │  • Purge memory    │  │  • Tab statistics  │                      │   │
│  │  └────────────────────┘  └────────────────────┘                      │   │
│  │                                                                        │   │
│  │  ┌────────────────────┐                                               │   │
│  │  │  Permissions       │                                               │   │
│  │  │    Service         │                                               │   │
│  │  │                    │                                               │   │
│  │  │  • Check status    │                                               │   │
│  │  │  • Request access  │                                               │   │
│  │  │  • Open settings   │                                               │   │
│  │  └────────────────────┘                                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    │ System APIs                            │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      SYSTEM INTEGRATION LAYER                         │   │
│  │                                                                        │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │   │
│  │  │   AppKit     │  │   Process    │  │  AppleScript │               │   │
│  │  │  NSStatusBar │  │    APIs      │  │   NSApple    │               │   │
│  │  │  NSPopover   │  │  proc_*      │  │    Script    │               │   │
│  │  │  NSWindow    │  │  sysctl      │  │              │               │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘
```

## Layer Details

### 1. UI Layer (SwiftUI)

The UI layer consists of SwiftUI views that present data and handle user interactions.

#### Main Views

| View | Purpose | Key Features |
|------|---------|--------------|
| `MainAppView` | Main navigation container | Sidebar navigation, environment setup |
| `DashboardView` | System health overview | CPU/Memory/Disk/Network cards, gauges |
| `ProcessManagerView` | Process management | Filterable list, search, terminate actions |
| `MemoryCleanupView` | Memory optimization | Cleanup candidates, quick actions |
| `BrowserTabsView` | Browser tab control | Tab listing, close operations |
| `SettingsPermissionsView` | Configuration | Settings, permissions, diagnostics |
| `MenuBarContentView` | Menu bar popover | Mini dashboard, quick actions |

#### Design Patterns

- **MVVM**: Views observe `@Published` properties from services
- **Environment Objects**: Services injected via `.environmentObject()`
- **Composable Views**: Reusable components (cards, gauges, rows)

### 2. Services Layer (Core)

The services layer contains business logic and system interactions.

#### SystemMetricsService

Provides real-time system metrics using low-level macOS APIs.

```swift
@MainActor
final class SystemMetricsService: ObservableObject {
    @Published private(set) var cpuMetrics: CPUMetrics?
    @Published private(set) var memoryMetrics: MemoryMetrics?
    @Published private(set) var diskMetrics: DiskMetrics?
    @Published private(set) var networkMetrics: NetworkMetrics?
    
    // Uses host_processor_info, vm_statistics64, statfs, getifaddrs
}
```

**Implementation Details:**
- CPU: `host_processor_info()` for per-core usage, `getloadavg()` for load
- Memory: `host_statistics64()` with `HOST_VM_INFO64`, `sysctlbyname()` for swap
- Disk: `FileManager.attributesOfFileSystem()`, `Darwin.statfs()`
- Network: `getifaddrs()` for interface statistics

#### ProcessManager

Manages running processes using BSD process APIs.

```swift
@MainActor
class ProcessManager: ObservableObject {
    @Published var processes: [ProcessInfo] = []
    
    // Uses NSWorkspace.runningApplications, proc_pidinfo, proc_listpids
}
```

**Implementation Details:**
- User apps: `NSWorkspace.shared.runningApplications`
- System processes: `proc_listpids()`, `proc_pidpath()`
- Process info: `proc_pidinfo()` with `PROC_PIDTBSDINFO`, `PROC_PIDTASKINFO`
- Termination: `NSRunningApplication.terminate()`, `kill()` signals

#### MemoryOptimizerService

Provides intelligent memory cleanup suggestions and execution.

```swift
@MainActor
final class MemoryOptimizerService: ObservableObject {
    @Published private(set) var cleanupCandidates: [CleanupCandidate] = []
    @Published private(set) var selectedCandidates: Set<CleanupCandidate> = []
}
```

**Features:**
- Categorizes apps by memory usage and activity
- Excludes critical system processes
- Supports graceful termination via `NSRunningApplication`
- Optional `purge` command via AppleScript with admin privileges

#### BrowserAutomationService

Controls browser tabs via AppleScript.

```swift
@MainActor
final class BrowserAutomationService: ObservableObject {
    @Published private(set) var browserTabs: [SupportedBrowser: [BrowserWindow]] = [:]
}
```

**Supported Browsers:**
- Safari (native AppleScript support)
- Google Chrome (Chrome AppleScript dictionary)
- Microsoft Edge (Chrome-based scripting)
- Brave Browser (Chrome-based scripting)
- Arc (limited scripting support)

**AppleScript Strategy:**
```applescript
tell application "Safari"
    repeat with w from 1 to (count of windows)
        set tabCount to count of tabs of window w
        repeat with t from 1 to tabCount
            get {title, URL} of tab t of window w
        end repeat
    end repeat
end tell
```

#### PermissionsService

Manages macOS permission states and requests.

```swift
@MainActor
final class PermissionsService: ObservableObject {
    @Published private(set) var accessibilityStatus: PermissionStatus
    @Published private(set) var automationTargets: [AutomationTarget]
}
```

**Permissions Handled:**
- Accessibility: `AXIsProcessTrustedWithOptions()`
- Automation: Detected via AppleScript execution result codes (error -1743)

### 3. System Integration Layer

#### AppKit Integration

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?      // Menu bar icon
    var popover: NSPopover?            // Click popover
    var fullWindow: NSWindow?          // Main window
}
```

**Menu Bar Behavior:**
- Left-click: Toggle popover
- Right-click: Show context menu
- Context menu: About, Quick Actions, Open, Quit

#### Process APIs

Low-level BSD APIs for process information:

| API | Purpose |
|-----|---------|
| `proc_listpids()` | List all process IDs |
| `proc_pidpath()` | Get process executable path |
| `proc_pidinfo()` | Get detailed process info |
| `PROC_PIDTBSDINFO` | BSD info (parent PID, UID, start time) |
| `PROC_PIDTASKINFO` | Task info (memory, threads, CPU time) |
| `PROC_PIDVNODEPATHINFO` | Working directory |

## Data Flow

### System Metrics Update Flow

```
Timer (2s default)
    │
    ▼
SystemMetricsService.refreshAllMetrics()
    │
    ├──► fetchCPUMetrics()     ──► host_processor_info()
    ├──► fetchMemoryMetrics()  ──► host_statistics64()
    ├──► fetchDiskMetrics()    ──► FileManager.attributesOfFileSystem()
    └──► fetchNetworkMetrics() ──► getifaddrs()
    │
    ▼
Update @Published properties
    │
    ▼
SwiftUI observes changes
    │
    ▼
Views re-render with new data
```

### Memory Cleanup Flow

```
User initiates cleanup
    │
    ▼
MemoryOptimizerService.analyzeMemoryUsage()
    │
    ▼
Scan NSWorkspace.runningApplications
    │
    ▼
Filter by memory threshold, exclude protected
    │
    ▼
Categorize candidates
    │
    ▼
User selects candidates
    │
    ▼
Show confirmation dialog
    │
    ▼
Execute cleanup via NSRunningApplication.terminate()
    │
    ▼
Update results, refresh analysis
```

### Browser Tab Management Flow

```
User opens Browser Tabs view
    │
    ▼
BrowserAutomationService.fetchAllTabs()
    │
    ▼
For each running browser:
    │
    ├──► Generate AppleScript
    ├──► Execute via NSAppleScript
    ├──► Parse output (WINDOW:/TAB: format)
    └──► Create BrowserWindow/BrowserTab models
    │
    ▼
Update @Published browserTabs
    │
    ▼
UI displays tabs grouped by browser/window
    │
    ▼
User closes tab
    │
    ▼
Execute AppleScript: "close tab X of window Y"
    │
    ▼
Refresh tab list
```

## Threading Model

### Main Actor
All services are `@MainActor` to ensure:
- UI updates on main thread
- Thread-safe property access
- Consistent state

### Background Work
Heavy operations use `Task { }` with async/await:
```swift
func refreshAllMetrics() async {
    async let cpu = fetchCPUMetrics()
    async let memory = fetchMemoryMetrics()
    // ... parallel fetching
}
```

### AppleScript Execution
Runs on `DispatchQueue.global(qos: .userInitiated)`:
```swift
DispatchQueue.global(qos: .userInitiated).async {
    var error: NSDictionary?
    appleScript.executeAndReturnError(&error)
    // Resume continuation on completion
}
```

## Configuration & Settings

### AppStorage Keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `refreshInterval` | Double | 2.0 | Metrics refresh interval (seconds) |
| `showInDock` | Bool | false | Show in Dock when window open |
| `launchAtLogin` | Bool | false | Start at login |
| `enableNotifications` | Bool | true | Show system alerts |
| `memoryWarningThreshold` | Double | 80.0 | Memory warning percentage |
| `hasCompletedOnboarding` | Bool | false | Onboarding completed |

## Error Handling

### Service Errors

Each service defines specific error types:

```swift
enum BrowserAutomationError: LocalizedError {
    case browserNotInstalled(SupportedBrowser)
    case browserNotRunning(SupportedBrowser)
    case automationPermissionDenied(SupportedBrowser)
    case scriptExecutionFailed(String)
    // ...
}
```

### Error Propagation

1. Services catch and log errors
2. Set `@Published errorMessage` for UI display
3. UI shows appropriate error alerts/states
4. Operations fail gracefully without crashing

## Testing Strategy

### Unit Tests

Test each service in isolation:
- Mock system API responses
- Verify calculations and transformations
- Test edge cases and error handling

### UI Tests

Test user flows with XCUITest:
- Navigation between views
- Search and filtering
- Button interactions
- Accessibility

## Performance Considerations

### Memory
- Lazy loading of process details
- Cleanup of stale data when processes exit
- Efficient SwiftUI list rendering with `LazyVStack`

### CPU
- Configurable refresh intervals
- Async parallel fetching
- Minimal UI updates via `@Published` diffing

### Energy
- Use `.userInitiated` QoS for interactive operations
- Timer-based updates (not continuous polling)
- Efficient AppleScript execution

## Future Enhancements

Potential architectural improvements:
1. **Dependency Injection** - Protocol-based service injection for testing
2. **Repository Pattern** - Abstract system API access
3. **Modular Architecture** - Separate frameworks for services
4. **Plugin System** - Extensible browser support
5. **Widget Extension** - macOS widget for quick stats
