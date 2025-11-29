# ClearMind Control Center - Architecture

This document describes the technical architecture and design of ClearMind Control Center.

## Overview

ClearMind Control Center is a native macOS application built with SwiftUI, designed for Apple Silicon and Intel Macs running macOS 14 (Sonoma) or later. It provides comprehensive system monitoring, process management, memory optimization, and browser tab management through an intuitive, modern interface.

## High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           ClearMind Control Center                            │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │
│  │   Menu Bar UI   │  │   Main Window   │  │    Popover      │              │
│  │  (NSStatusItem) │  │  (NSWindow)     │  │  (NSPopover)    │              │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘              │
│           │                    │                    │                        │
│           └────────────────────┼────────────────────┘                        │
│                                │                                             │
│  ┌─────────────────────────────┴─────────────────────────────────┐          │
│  │                     SwiftUI View Layer                         │          │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐         │          │
│  │  │Dashboard │ │Processes │ │ Memory   │ │ Browser  │         │          │
│  │  │  View    │ │  View    │ │ Cleanup  │ │  Tabs    │         │          │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘         │          │
│  └───────┼────────────┼────────────┼────────────┼────────────────┘          │
│          │            │            │            │                            │
│  ┌───────┴────────────┴────────────┴────────────┴────────────────┐          │
│  │                      Service Layer                             │          │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐      │          │
│  │  │  System       │  │  Memory       │  │  Browser      │      │          │
│  │  │  Metrics      │  │  Optimizer    │  │  Automation   │      │          │
│  │  │  Service      │  │  Service      │  │  Service      │      │          │
│  │  └───────────────┘  └───────────────┘  └───────────────┘      │          │
│  │  ┌───────────────┐  ┌───────────────┐                         │          │
│  │  │  Process      │  │  Permissions  │                         │          │
│  │  │  Manager      │  │  Service      │                         │          │
│  │  └───────────────┘  └───────────────┘                         │          │
│  └────────────────────────────────────────────────────────────────┘          │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                              macOS System APIs                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ host_info   │  │ NSWorkspace │  │ AppleScript │  │ proc_*      │         │
│  │ vm_stat     │  │ NSRunningApp│  │ NSAppleScript│  │ APIs        │         │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘         │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
Craig-O-Clean/
├── Craig_O_CleanApp.swift        # App entry point & AppDelegate
├── Services/
│   ├── SystemMetricsService.swift    # CPU, RAM, disk, network monitoring
│   ├── MemoryOptimizerService.swift  # Memory cleanup workflows
│   ├── BrowserAutomationService.swift # Browser tab management
│   └── PermissionsService.swift      # Permission management
├── Views/
│   ├── MainAppView.swift             # Sidebar navigation container
│   ├── DashboardView.swift           # System metrics dashboard
│   ├── BrowserTabsView.swift         # Tab management interface
│   ├── MemoryCleanupView.swift       # Guided cleanup UI
│   ├── PermissionsView.swift         # Settings & permissions
│   └── EnhancedMenuBarView.swift     # Menu bar popover
├── ProcessManager.swift              # Process monitoring (existing)
├── ContentView.swift                 # Process list view (existing)
├── SystemMemoryManager.swift         # Memory stats (existing)
├── Tests/
│   ├── SystemMetricsServiceTests.swift
│   ├── BrowserAutomationServiceTests.swift
│   └── MemoryOptimizerServiceTests.swift
├── Assets.xcassets/
├── Info.plist
└── Craig-O-Clean.entitlements
```

## Service Layer

### SystemMetricsService

**Purpose**: Provides real-time system metrics monitoring.

**Key Features**:
- CPU usage (overall, per-core, user/system breakdown)
- Memory metrics (used, free, active, wired, compressed, swap)
- Disk usage (total, used, free, volume name)
- Network activity (bytes sent/received, rates)
- Historical data for charting

**Implementation**:
```swift
@MainActor
class SystemMetricsService: ObservableObject {
    @Published var memoryMetrics: MemoryMetrics?
    @Published var cpuMetrics: CPUMetrics?
    @Published var diskMetrics: DiskMetrics?
    @Published var networkMetrics: NetworkMetrics?
    @Published var healthSummary: SystemHealthSummary?
    @Published var cpuHistory: [CPUHistoryPoint] = []
    @Published var memoryHistory: [MemoryHistoryPoint] = []
    
    func updateAllMetrics()
    func startAutoUpdate(interval: TimeInterval)
    func stopAutoUpdate()
}
```

**System APIs Used**:
- `host_statistics64` for memory statistics
- `host_processor_info` for CPU metrics
- `FileManager` resource values for disk info
- `getifaddrs` for network statistics

### MemoryOptimizerService

**Purpose**: Provides guided memory cleanup workflows.

**Key Features**:
- Analyze running applications for cleanup suggestions
- Multi-step cleanup workflow (Analyze → Review → Confirm → Execute)
- Safe app termination with user consent
- Memory purge command (admin required)

**Implementation**:
```swift
@MainActor
class MemoryOptimizerService: ObservableObject {
    @Published var cleanupCandidates: [CleanupCandidate] = []
    @Published var suggestions: [CleanupSuggestion] = []
    @Published var selectedForCleanup: Set<String> = []
    @Published var currentStep: CleanupStep = .analyze
    
    func analyzeForCleanup() async
    func executeCleanup() async -> CleanupResult
    func quickCleanup() async -> CleanupResult
    func runPurge() async throws
}
```

### BrowserAutomationService

**Purpose**: Manages browser tabs across multiple browsers using AppleScript.

**Supported Browsers**:
- Safari
- Google Chrome
- Microsoft Edge
- Brave Browser

**Key Features**:
- Detect installed and running browsers
- Fetch all open tabs with window/tab indices
- Close individual tabs, windows, or by domain
- Permission status checking

**Implementation**:
```swift
@MainActor
class BrowserAutomationService: ObservableObject {
    @Published var installedBrowsers: [BrowserType] = []
    @Published var runningBrowsers: [BrowserType] = []
    @Published var browserWindows: [BrowserWindow] = []
    @Published var allTabs: [BrowserTab] = []
    @Published var permissionStatus: [BrowserType: Bool] = [:]
    
    func fetchAllTabs() async
    func closeTab(_ tab: BrowserTab) async -> BrowserOperationResult
    func closeTabsByDomain(_ domain: String) async -> BrowserOperationResult
}
```

**AppleScript Integration**:
```applescript
-- Safari tab fetching
tell application "Safari"
    repeat with w in windows
        repeat with t in tabs of w
            get name of t
            get URL of t
        end repeat
    end repeat
end tell

-- Chrome/Edge tab fetching
tell application "Google Chrome"
    repeat with w in windows
        repeat with t in tabs of w
            get title of t
            get URL of t
        end repeat
    end repeat
end tell
```

### PermissionsService

**Purpose**: Manages app permissions and provides user guidance.

**Key Features**:
- Check automation permissions for browsers
- Check accessibility permission
- Provide step-by-step enable instructions
- Open System Settings directly

**Implementation**:
```swift
@MainActor
class PermissionsService: ObservableObject {
    @Published var permissions: [PermissionInfo] = []
    @Published var automationPermissions: [AutomationPermissionDetail] = []
    
    func checkAllPermissions() async
    func openSettings(for permission: PermissionType)
    func requestAccessibilityPermission()
}
```

## View Layer

### MainAppView

The primary application container with sidebar navigation.

**Components**:
- Sidebar with navigation items
- Detail view container
- Quick stats footer

**Navigation Tabs**:
1. Dashboard
2. Processes
3. Memory Cleanup
4. Browser Tabs
5. Settings

### DashboardView

Real-time system metrics visualization.

**Components**:
- System health summary card
- CPU, Memory, Disk, Network metric cards
- CPU history chart
- Memory history chart

### MemoryCleanupView

Guided multi-step cleanup workflow.

**Steps**:
1. **Analyze**: Scan running applications
2. **Review**: Select apps to close
3. **Confirm**: Final confirmation
4. **Execute**: Close selected apps
5. **Complete**: Show results

### BrowserTabsView

Browser tab management interface.

**Components**:
- Browser sidebar (list of browsers)
- Tab list with search/filter
- Domain grouping
- Bulk actions menu

## Data Flow

### Metrics Update Flow

```
Timer (2s interval)
       │
       ▼
SystemMetricsService.updateAllMetrics()
       │
       ├──► fetchMemoryMetrics() ──► vm_statistics64
       ├──► fetchCPUMetrics() ──► host_processor_info
       ├──► fetchDiskMetrics() ──► FileManager
       └──► fetchNetworkMetrics() ──► getifaddrs
       │
       ▼
@Published properties updated
       │
       ▼
SwiftUI observes changes
       │
       ▼
Views re-render
```

### Memory Cleanup Flow

```
User clicks "Analyze"
       │
       ▼
analyzeForCleanup()
       │
       ├──► Get NSWorkspace.runningApplications
       ├──► Get memory usage per process
       └──► Generate suggestions
       │
       ▼
User reviews & selects apps
       │
       ▼
User confirms
       │
       ▼
executeCleanup()
       │
       ├──► NSRunningApplication.terminate()
       └──► or forceTerminate()
       │
       ▼
Display results
```

### Browser Tab Flow

```
fetchAllTabs()
       │
       ├──► Safari: Execute AppleScript
       ├──► Chrome: Execute AppleScript
       └──► Edge: Execute AppleScript
       │
       ▼
Parse results into BrowserTab models
       │
       ▼
User selects tab to close
       │
       ▼
closeTab() ──► Execute AppleScript
       │
       ▼
Update local state
```

## Threading Model

### Main Thread (MainActor)
- All UI updates
- SwiftUI view rendering
- Published property changes
- Timer scheduling

### Background Thread
- System API calls (vm_stat, host_info)
- AppleScript execution
- File system operations

### Synchronization
- Services are marked `@MainActor`
- Background work uses `Task` with `@MainActor` callback
- `DispatchQueue.global(qos: .userInitiated)` for heavy work

## Memory Management

### Automatic Reference Counting
- `[weak self]` in closures to prevent retain cycles
- `@StateObject` for view-owned services
- `@ObservedObject` for passed-in services

### Timer Management
```swift
deinit {
    updateTimer?.invalidate()
    updateTimer = nil
}
```

### History Pruning
```swift
if cpuHistory.count > maxHistoryPoints {
    cpuHistory.removeFirst(cpuHistory.count - maxHistoryPoints)
}
```

## Error Handling

### AppleScript Errors
```swift
enum BrowserOperationResult {
    case success
    case permissionDenied
    case browserNotRunning
    case scriptError(String)
    case timeout
    case unsupported
}
```

### Graceful Degradation
- Missing permissions show guidance UI
- Unavailable metrics display "--" or placeholders
- Browser closed mid-operation handled gracefully

## Testing Strategy

### Unit Tests
- Service logic with mocked dependencies
- Model calculations and parsing
- State transitions

### Integration Tests
- AppleScript execution (when permissions granted)
- System API calls
- Process enumeration

### UI Tests
- Navigation between tabs
- User interaction flows
- Error state displays

## Build Configuration

### Targets
- **ClearMind Control Center**: Main app target
- **ClearMind Control Center Tests**: Unit tests

### Configurations
- **Debug**: Development builds
- **Release**: Optimized production builds

### Key Settings
```
MACOSX_DEPLOYMENT_TARGET = 14.0
SWIFT_VERSION = 5.9
ENABLE_HARDENED_RUNTIME = YES
ENABLE_APP_SANDBOX = NO
```

## Dependencies

### System Frameworks
- SwiftUI
- AppKit
- Combine
- Charts (iOS 16+)
- ServiceManagement

### External Dependencies
- None (100% native)

## Performance Characteristics

### Memory Usage
- Base: ~30-50 MB
- With history tracking: +10-20 MB
- Menu bar only: ~20 MB

### CPU Usage
- Idle: <1%
- During refresh: 2-5% spike
- During cleanup: 5-10% spike

### Refresh Performance
- Metrics update: ~50-100ms
- Browser tab fetch: ~200-500ms (depends on tab count)
- Full analysis: ~500ms-1s

## Future Considerations

### Potential Enhancements
1. **Notifications**: Alert for high memory/CPU
2. **Widgets**: macOS desktop widgets
3. **Shortcuts**: Siri Shortcuts integration
4. **iCloud Sync**: Settings sync across devices
5. **Profiles**: Different monitoring profiles

### Scalability
- Current design supports single-window use
- Could add multiple windows with shared services
- Background monitoring mode possible with notifications
