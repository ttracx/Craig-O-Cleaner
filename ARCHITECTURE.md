# Craig-O-Clean Architecture

This document describes the technical architecture and design of the Craig-O-Clean application.

## Overview

Craig-O-Clean is a native macOS menu bar application built using SwiftUI and AppKit. It provides real-time process monitoring and memory management capabilities.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        macOS System                          │
│  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌──────────────┐ │
│  │   ps    │  │   kill   │  │  sync   │  │osascript     │ │
│  │ command │  │ command  │  │ command │  │(AppleScript) │ │
│  └────┬────┘  └────┬─────┘  └────┬────┘  └──────┬───────┘ │
└───────┼────────────┼─────────────┼───────────────┼─────────┘
        │            │             │               │
        │            │             │               │
┌───────┼────────────┼─────────────┼───────────────┼─────────┐
│       │            │             │               │         │
│  ┌────▼─────────────────────────────────────────▼──────┐  │
│  │           ProcessManager (ObservableObject)         │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │ • fetchProcesses()                           │  │  │
│  │  │ • parseProcessOutput()                       │  │  │
│  │  │ • refreshProcesses()                         │  │  │
│  │  │ • forceQuitProcess(pid)                      │  │  │
│  │  │ • purgeMemory(completion)                    │  │  │
│  │  │ • calculateTotalMemory()                     │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  │  Published Properties:                              │  │
│  │  • @Published var processes: [ProcessInfo]         │  │
│  │  • @Published var isRefreshing: Bool                │  │
│  │  • @Published var lastUpdateTime: Date?            │  │
│  │  • @Published var totalMemoryUsage: Double         │  │
│  └─────────────────────┬───────────────────────────────┘  │
│                        │                                   │
│  ┌────────────────────▼────────────────────────────────┐  │
│  │              ProcessInfo (Model)                    │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │ • id: UUID                                   │  │  │
│  │  │ • pid: Int                                   │  │  │
│  │  │ • name: String                               │  │  │
│  │  │ • memoryUsage: Double                        │  │  │
│  │  │ • formattedMemory: String (computed)         │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └─────────────────────┬───────────────────────────────┘  │
│                        │                                   │
│  ┌────────────────────▼────────────────────────────────┐  │
│  │           ContentView (SwiftUI View)                │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │ Components:                                  │  │  │
│  │  │ • headerView                                 │  │  │
│  │  │ • searchBar                                  │  │  │
│  │  │ • ScrollView with LazyVStack                 │  │  │
│  │  │ • footerView                                 │  │  │
│  │  │                                              │  │  │
│  │  │ @StateObject var processManager              │  │  │
│  │  │ @State var selectedProcess                   │  │  │
│  │  │ @State var searchText                        │  │  │
│  │  │ @State var showingAlert                      │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └─────────────────────┬───────────────────────────────┘  │
│                        │                                   │
│  ┌────────────────────▼────────────────────────────────┐  │
│  │            ProcessRow (SwiftUI View)                │  │
│  │  • Displays individual process information          │  │
│  │  • Force Quit button                                │  │
│  │  • Selection state                                  │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌─────────────────────────────────────────────────────┐  │
│  │      AppDelegate (NSApplicationDelegate)            │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │ • NSStatusItem (menu bar icon)               │  │  │
│  │  │ • NSPopover (popup window)                   │  │  │
│  │  │ • togglePopover() - show/hide popup          │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌─────────────────────────────────────────────────────┐  │
│  │         Craig_O_CleanApp (@main)                    │  │
│  │  • App entry point                                  │  │
│  │  • @NSApplicationDelegateAdaptor                    │  │
│  └─────────────────────────────────────────────────────┘  │
│                  Craig-O-Clean Application                 │
└────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Craig_O_CleanApp (Main Entry Point)

**File**: `Craig_O_CleanApp.swift`

**Purpose**: Application entry point and lifecycle management

**Key Features**:
- SwiftUI `@main` entry point
- Uses `@NSApplicationDelegateAdaptor` to integrate with AppKit
- Creates empty Settings scene (app doesn't appear in Dock)

```swift
@main
struct Craig_O_CleanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

### 2. AppDelegate (Menu Bar Integration)

**File**: `Craig_O_CleanApp.swift`

**Purpose**: Manages menu bar icon and popover

**Key Components**:
- `NSStatusItem`: The menu bar icon
- `NSPopover`: The popup window containing ContentView
- `NSHostingController`: Bridges SwiftUI to AppKit

**Responsibilities**:
- Create and configure status bar item
- Handle popover show/hide logic
- Set up menu bar icon and action

### 3. ProcessManager (Business Logic)

**File**: `ProcessManager.swift`

**Purpose**: Core business logic for process monitoring and management

**Pattern**: Observable Object (MVVM pattern)

**Published Properties**:
```swift
@Published var processes: [ProcessInfo] = []
@Published var isRefreshing = false
@Published var lastUpdateTime: Date?
@Published var totalMemoryUsage: Double = 0
```

**Methods**:

| Method | Purpose | Implementation |
|--------|---------|----------------|
| `refreshProcesses()` | Fetch and update process list | Async dispatch, calls fetchProcesses() |
| `fetchProcesses()` | Execute `ps` command | Process API with pipe for output |
| `parseProcessOutput()` | Parse ps output into ProcessInfo | String parsing, filtering, sorting |
| `forceQuitProcess()` | Terminate a process | Execute `kill -9` command |
| `purgeMemory()` | Free inactive memory | Execute `sync` then `osascript` for `purge` |
| `startAutoRefresh()` | Begin auto-refresh timer | 5-second Timer |
| `calculateTotalMemory()` | Sum memory usage | Reduce operation on processes |

**Auto-Refresh**:
- Timer-based: 5 seconds interval
- Background thread for fetching
- Main thread for UI updates

### 4. ProcessInfo (Data Model)

**File**: `ProcessInfo.swift`

**Purpose**: Data model for process information

**Properties**:
```swift
struct ProcessInfo: Identifiable, Hashable {
    let id = UUID()           // Unique identifier
    let pid: Int              // Process ID
    let name: String          // Process name
    let memoryUsage: Double   // Memory in MB
    
    var formattedMemory: String {
        // Computed property: formats as MB or GB
    }
}
```

**Protocols**:
- `Identifiable`: For SwiftUI ForEach loops
- `Hashable`: For Set operations and comparison

### 5. ContentView (Main UI)

**File**: `ContentView.swift`

**Purpose**: Primary user interface

**Architecture**: SwiftUI declarative UI with MVVM pattern

**Structure**:
```
ContentView
├── headerView
│   ├── Title and icon
│   ├── Refresh button
│   └── Statistics (memory, count)
├── searchBar
│   ├── Search field
│   └── Clear button
├── ScrollView
│   └── LazyVStack
│       └── ProcessRow (foreach)
└── footerView
    ├── Purge button
    └── Warning text
```

**State Management**:
- `@StateObject`: Owns ProcessManager instance
- `@State`: Local UI state (search, selection, alerts)

**Computed Properties**:
- `filteredProcesses`: Filters processes based on search text

### 6. ProcessRow (List Item)

**File**: `ContentView.swift`

**Purpose**: Individual process list item

**Features**:
- Process name (monospaced font)
- Process ID
- Memory usage (formatted)
- Force Quit button
- Selection highlight
- Tap gesture handling

## Data Flow

### Process List Update Flow

```
Timer (5s)
    ↓
ProcessManager.refreshProcesses()
    ↓
DispatchQueue.global (background)
    ↓
fetchProcesses() → Execute 'ps -axm -o pid,rss,comm'
    ↓
parseProcessOutput() → Parse string, create ProcessInfo array
    ↓
Filter (> 10 MB) → Sort (by memory) → Take top 50
    ↓
DispatchQueue.main (UI thread)
    ↓
@Published processes = newProcesses
    ↓
SwiftUI observes change
    ↓
ContentView re-renders
    ↓
User sees updated list
```

### Force Quit Flow

```
User taps "Force Quit" button
    ↓
ProcessRow.onForceQuit() called
    ↓
ContentView.forceQuitProcess(process) called
    ↓
Shows alert
    ↓
ProcessManager.forceQuitProcess(pid: Int)
    ↓
Execute 'kill -9 <pid>'
    ↓
Wait 0.5 seconds
    ↓
Trigger refreshProcesses()
    ↓
UI updates automatically
```

### Memory Purge Flow

```
User taps "Purge Memory" button
    ↓
ContentView.purgeMemory() called
    ↓
ProcessManager.purgeMemory(completion:)
    ↓
Execute 'sync' command
    ↓
Execute 'osascript -e "do shell script \"purge\" with administrator privileges"'
    ↓
macOS prompts for password
    ↓
User enters password
    ↓
Command executes
    ↓
Completion handler called with result
    ↓
Show success/error alert
    ↓
Refresh process list
    ↓
UI updates
```

## Threading Model

### Main Thread
- All UI updates
- SwiftUI view rendering
- Timer scheduling
- Alert presentation

### Background Thread (QoS: .userInitiated)
- Process list fetching
- Command execution
- String parsing
- Data processing

### Synchronization
- `DispatchQueue.main.async` for UI updates
- `@Published` properties trigger main thread updates
- Process API handles its own threading

## Memory Management

### Process Manager
- Weak references in closures to prevent retain cycles
- Timer invalidation in `deinit`
- Cleanup of resources

### SwiftUI
- Automatic view lifecycle management
- `@StateObject` ownership semantics
- `@ObservedObject` reference semantics

## Security Considerations

### Sandboxing
- **Disabled**: Required for `ps`, `kill`, `purge` commands
- Configured in `Craig-O-Clean.entitlements`

### Privilege Escalation
- Only for `purge` command
- Uses AppleScript for secure password prompt
- User explicitly authorizes each time

### Process Access
- Can only quit user-owned processes without admin
- System processes require elevated privileges
- Protected processes cannot be terminated

## File Organization

```
Craig-O-Clean/
├── Craig_O_CleanApp.swift      # Entry point + AppDelegate
├── ContentView.swift            # Main UI + ProcessRow
├── ProcessManager.swift         # Business logic
├── ProcessInfo.swift            # Data model
├── Assets.xcassets/            # Icons and assets
├── Info.plist                  # App configuration
└── Craig-O-Clean.entitlements  # Permissions
```

## Build Configuration

### Targets
- **Craig-O-Clean**: Main application target

### Configurations
- **Debug**: Development builds with symbols
- **Release**: Optimized production builds

### Key Settings
- Minimum Deployment: macOS 13.0
- Swift Version: 5.0
- LSUIElement: true (menu bar app)
- Sandbox: false (requires system access)

## Dependencies

### System Frameworks
- SwiftUI (UI framework)
- AppKit (NSStatusItem, NSPopover, NSApplicationDelegate)
- Foundation (Process, Timer, String, etc.)
- Combine (ObservableObject, @Published)

### External Dependencies
- None (100% native)

## Performance Characteristics

### Memory Usage
- Typical: 20-40 MB
- Lightweight due to SwiftUI
- Process list cached in memory

### CPU Usage
- Idle: Near 0%
- During refresh: Brief spike (< 1 second)
- Timer overhead: Negligible

### Refresh Performance
- `ps` command: ~50-100ms
- Parsing: ~10-50ms
- UI update: ~10ms
- Total: ~100-200ms per refresh

## Testing Strategy

### Manual Testing
- Launch and menu bar appearance
- Process list accuracy
- Search functionality
- Force quit operations
- Memory purge
- Error handling

### Potential Unit Tests (Future)
- ProcessInfo model validation
- Process output parsing
- Memory calculation accuracy
- Search filtering logic

### Integration Tests (Future)
- Command execution
- Process monitoring
- Memory operations

## Future Architecture Improvements

### Potential Enhancements
1. **Dependency Injection**: Make ProcessManager injectable
2. **Repository Pattern**: Abstract command execution
3. **Unit Testing**: Add testable architecture
4. **Protocol-Oriented**: Define protocols for better testing
5. **Modular Design**: Separate concerns into modules
6. **Configuration**: User preferences system
7. **Logging**: Structured logging framework

### Scalability Considerations
- Currently optimized for single window/instance
- Could support multiple windows with shared ProcessManager
- Could add background modes for continuous monitoring

## Technical Decisions

### Why SwiftUI?
- Modern, declarative UI
- Less code than AppKit
- Automatic state management
- Great performance

### Why NSStatusItem?
- Standard macOS menu bar API
- Reliable and well-supported
- Easy integration with SwiftUI via NSHostingController

### Why No Sandbox?
- Required for `ps`, `kill`, `purge` commands
- No alternative APIs available
- Security handled via macOS permissions

### Why 5-Second Refresh?
- Balance between responsiveness and resource usage
- Frequent enough for monitoring
- Infrequent enough to avoid overhead

### Why Top 50 Processes?
- Sufficient for identifying memory hogs
- Keeps UI performant
- Reduces parsing overhead

## Conclusion

Craig-O-Clean uses a clean, layered architecture that separates concerns:
- **Presentation Layer**: SwiftUI views
- **Business Logic**: ProcessManager
- **Data Layer**: ProcessInfo model
- **Integration Layer**: AppDelegate

This design makes the app maintainable, testable, and easy to extend.
