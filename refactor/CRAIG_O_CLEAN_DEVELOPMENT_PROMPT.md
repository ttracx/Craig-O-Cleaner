# Craig-O-Clean (macOS) — Production Development Prompt

**Target:** macOS Menu Bar Application for Apple Silicon  
**Stack:** Swift 5.9+, SwiftUI, Xcode 15+  
**Architecture:** Capability-Based Command Execution with Privilege Separation

---

## Executive Summary

You are building a production-grade macOS menu bar utility that provides safe, intuitive system cleanup, diagnostics, and browser management. The current implementation suffers from:

- Ad-hoc bash command execution with permission failures
- Brittle AppleScript behavior without proper error handling
- Missing confirmation flows for destructive operations
- Inconsistent logging and no audit trail

Your deliverable is a hardened, permission-aware application that eliminates these failures while maintaining fast, intuitive UX.

---

## 1. Non-Negotiable Constraints

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SECURITY MODEL — HARD REQUIREMENTS                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│ ✗ NO default admin/sudo execution                                           │
│ ✗ NO arbitrary shell command input from users                               │
│ ✗ NO background privileged operations without explicit approval             │
│ ✗ NO SIP disable recommendations                                            │
│                                                                             │
│ ✓ Least-privilege with explicit escalation per-operation                    │
│ ✓ All destructive operations require: confirm UI + dry-run + audit log     │
│ ✓ Code signed, notarized, graceful degradation on permission denial        │
│ ✓ Allowlist-only command execution                                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Architecture Overview

### 2.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CRAIG-O-CLEAN ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                     Menu Bar App (SwiftUI)                          │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌──────────────┐  │   │
│  │  │ Status View │ │ Quick Acts  │ │ Deep Clean  │ │ Permissions  │  │   │
│  │  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └──────┬───────┘  │   │
│  └─────────┼───────────────┼───────────────┼───────────────┼──────────┘   │
│            │               │               │               │              │
│            ▼               ▼               ▼               ▼              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Capability Coordinator                           │   │
│  │  • Preflight Checks    • Permission Gating    • Confirmation Flow  │   │
│  └─────────────────────────────────┬───────────────────────────────────┘   │
│                                    │                                       │
│            ┌───────────────────────┼───────────────────────┐              │
│            ▼                       ▼                       ▼              │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐       │
│  │  User Executor  │    │ Elevated Helper │    │ Automation Layer│       │
│  │  (Process API)  │    │ (XPC + AuthSvc) │    │ (Apple Events)  │       │
│  │                 │    │                 │    │                 │       │
│  │ • Non-privileged│    │ • SMJobBless    │    │ • Safari tabs   │       │
│  │ • Streaming I/O │    │ • Signed helper │    │ • Chrome tabs   │       │
│  │ • Timeout mgmt  │    │ • Audit chain   │    │ • Permission UI │       │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘       │
│           │                      │                      │                 │
│           └──────────────────────┼──────────────────────┘                 │
│                                  ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Unified Logging System                           │   │
│  │  • RunRecord Model    • SQLite Persistence    • Export/Audit       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow

```
User Action → Capability Lookup → Preflight Check → Permission Gate
                                                          │
                   ┌──────────────────────────────────────┤
                   │                                      │
              [Permission OK]                    [Permission Missing]
                   │                                      │
                   ▼                                      ▼
          Risk Class Check                    Show Remediation UI
                   │                          (System Settings path)
        ┌──────────┴──────────┐
        │                     │
   [Safe/Moderate]      [Destructive]
        │                     │
        ▼                     ▼
   Direct Execute      Confirm Dialog + Dry-Run Preview
        │                     │
        └──────────┬──────────┘
                   ▼
            Execute Command
                   │
        ┌──────────┴──────────┐
        │                     │
   [User Level]        [Elevated Level]
        │                     │
        ▼                     ▼
   Process API          XPC → Helper
        │                     │
        └──────────┬──────────┘
                   ▼
            Stream Output → Log Record → UI Update
```

---

## 3. Capability Catalog Specification

### 3.1 Capability Model

```swift
// MARK: - Capability Definition

/// Privilege level required for command execution
enum PrivilegeLevel: String, Codable {
    case user           // No elevation needed
    case elevated       // Requires Authorization Services
    case automation     // Requires Apple Events permission
    case fullDiskAccess // Optional, enhances functionality
}

/// Risk classification for UI flow
enum RiskClass: String, Codable {
    case safe           // No confirmation, instant execute
    case moderate       // Single confirmation
    case destructive    // Confirm + dry-run preview required
}

/// Output parsing strategy
enum OutputParser: String, Codable {
    case text           // Raw text display
    case json           // Parse as JSON
    case regex          // Apply pattern extraction
    case table          // Parse tabular output
    case memoryPressure // Special: memory_pressure format
    case diskUsage      // Special: df/du format
    case processTable   // Special: ps aux format
}

/// UI grouping for menu organization
enum CapabilityGroup: String, Codable, CaseIterable {
    case diagnostics    = "Diagnostics"
    case quickClean     = "Quick Clean"
    case deepClean      = "Deep Clean"
    case browsers       = "Browser Management"
    case disk           = "Disk Utilities"
    case memory         = "Memory Management"
    case devTools       = "Developer Tools"
    case system         = "System Utilities"
}

/// Complete capability definition
struct Capability: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let group: CapabilityGroup
    
    // Execution
    let commandTemplate: String
    let arguments: [String]
    let workingDirectory: String?
    let timeout: TimeInterval
    
    // Security
    let privilegeLevel: PrivilegeLevel
    let riskClass: RiskClass
    
    // Parsing
    let outputParser: OutputParser
    let parserPattern: String?
    
    // Preflight
    let preflightChecks: [PreflightCheck]
    let requiredPaths: [String]
    let requiredApps: [String]
    
    // UI
    let icon: String
    let rollbackNotes: String?
    let estimatedDuration: TimeInterval?
}

/// Preflight validation rules
struct PreflightCheck: Codable {
    enum CheckType: String, Codable {
        case pathExists
        case pathWritable
        case appRunning
        case appNotRunning
        case diskSpaceAvailable
        case sipStatus
        case automationPermission
    }
    
    let type: CheckType
    let target: String
    let failureMessage: String
}
```

### 3.2 Catalog Categories

The capability catalog must include entries organized by group:

| Group | Capabilities | Privilege | Risk |
|-------|-------------|-----------|------|
| **Diagnostics** | System info, memory pressure, disk usage, top processes | user | safe |
| **Quick Clean** | Flush DNS, clear temp files, restart Finder/Dock | user/elevated | safe/moderate |
| **Deep Clean** | Cache cleanup, log rotation, developer cleanup | user | moderate/destructive |
| **Browsers** | List tabs, close by pattern, close all, clear cache | automation | moderate |
| **Disk** | Find large files, empty trash, analyze usage | user | safe/moderate |
| **Memory** | Purge inactive, show pressure, identify hogs | user/elevated | safe/moderate |
| **Dev Tools** | Clear DerivedData, simulators, package caches | user | moderate |
| **System** | Restart services, rebuild indexes, maintenance | elevated | moderate/destructive |

---

## 4. Core Implementation Requirements

### 4.1 Command Execution Service

```swift
// MARK: - Execution Protocol

protocol CommandExecutor {
    /// Execute a capability and stream results
    func execute(
        _ capability: Capability,
        arguments: [String: String],
        progress: @escaping (ExecutionProgress) -> Void
    ) async throws -> ExecutionResult
    
    /// Validate capability can execute with current permissions
    func canExecute(_ capability: Capability) async -> PreflightResult
    
    /// Cancel running execution
    func cancel() async
}

struct ExecutionProgress {
    let phase: ExecutionPhase
    let stdout: String?
    let stderr: String?
    let percentage: Double?
}

enum ExecutionPhase {
    case preparing
    case requestingPermission
    case executing
    case parsing
    case complete
    case failed(Error)
    case cancelled
}

struct ExecutionResult {
    let capabilityId: String
    let startTime: Date
    let endTime: Date
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let parsedOutput: ParsedOutput?
    let record: RunRecord
}

struct PreflightResult {
    let canExecute: Bool
    let missingPermissions: [PermissionRequirement]
    let failedChecks: [PreflightCheck]
    let remediationSteps: [RemediationStep]
}
```

### 4.2 Permission Center

```swift
// MARK: - Permission Management

@Observable
final class PermissionCenter {
    
    // MARK: - Observable State
    var automationPermissions: [BrowserApp: PermissionState] = [:]
    var fullDiskAccess: PermissionState = .unknown
    var helperInstalled: Bool = false
    
    // MARK: - Permission Checking
    
    /// Check automation permission for a specific app
    func checkAutomationPermission(for app: BrowserApp) async -> PermissionState {
        // Use Apple Events to test permission
        // Return .granted, .denied, or .notDetermined
    }
    
    /// Request automation permission (triggers system prompt if needed)
    func requestAutomationPermission(for app: BrowserApp) async -> PermissionState {
        // Attempt to send a no-op Apple Event to trigger permission dialog
    }
    
    /// Get remediation steps for denied permission
    func remediationSteps(for permission: PermissionType) -> [RemediationStep] {
        // Return step-by-step instructions to fix in System Settings
    }
}

enum PermissionState {
    case unknown
    case notDetermined
    case granted
    case denied
}

enum BrowserApp: String, CaseIterable {
    case safari = "Safari"
    case chrome = "Google Chrome"
    case edge = "Microsoft Edge"
    case firefox = "Firefox"
    case brave = "Brave Browser"
    case arc = "Arc"
}

struct RemediationStep {
    let instruction: String
    let systemSettingsPath: String?  // e.g., "Privacy & Security > Automation"
    let canOpenAutomatically: Bool
}
```

### 4.3 Browser Automation Layer

```swift
// MARK: - Browser Controller Protocol

protocol BrowserController {
    var app: BrowserApp { get }
    
    /// Check if browser is running
    func isRunning() async -> Bool
    
    /// Get all open tabs across all windows
    func getAllTabs() async throws -> [BrowserTab]
    
    /// Close tabs matching URL pattern
    func closeTabs(matching pattern: String) async throws -> Int
    
    /// Close all tabs (with optional whitelist)
    func closeAllTabs(except whitelist: [String]) async throws -> Int
    
    /// Get tab count
    func tabCount() async throws -> Int
    
    /// Estimate "heavy" tabs (best effort)
    func getHeavyTabs(threshold: HeavyTabCriteria) async throws -> [BrowserTab]
}

struct BrowserTab {
    let windowIndex: Int
    let tabIndex: Int
    let title: String
    let url: String
    let estimatedMemoryMB: Int?  // nil if unavailable
}

struct HeavyTabCriteria {
    let urlPatterns: [String]  // Video sites, social media, etc.
    let estimatedMemoryThresholdMB: Int
}
```

### 4.4 Unified Logging

```swift
// MARK: - Run Record Model

struct RunRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let capabilityId: String
    let capabilityTitle: String
    let privilegeLevel: PrivilegeLevel
    let arguments: [String: String]
    
    // Execution metadata
    let durationMs: Int
    let exitCode: Int32
    let status: ExecutionStatus
    
    // Output references
    let stdoutPath: String?
    let stderrPath: String?
    let outputSizeBytes: Int
    
    // Parsed summary
    let parsedSummary: String?
    let parsedData: Data?  // JSON-encoded structured output
    
    // Audit chain (optional)
    let previousRecordHash: String?
    let recordHash: String
}

enum ExecutionStatus: String, Codable {
    case success
    case partialSuccess  // Completed with warnings
    case failed
    case cancelled
    case permissionDenied
    case timeout
}

// MARK: - Log Store

protocol LogStore {
    func save(_ record: RunRecord) async throws
    func fetch(limit: Int, offset: Int) async throws -> [RunRecord]
    func fetch(capabilityId: String, limit: Int) async throws -> [RunRecord]
    func fetchRecent(hours: Int) async throws -> [RunRecord]
    func exportLogs(from: Date, to: Date) async throws -> URL
    func getLastError() async throws -> RunRecord?
}
```

---

## 5. User Interface Requirements

### 5.1 Menu Structure

```
┌─────────────────────────────────────┐
│ 🧹 Craig-O-Clean                    │
├─────────────────────────────────────┤
│ ▼ Status                            │
│   Memory: 12.4 GB / 16 GB (78%)     │
│   Disk: 234 GB free                 │
│   Top CPU: Safari (45%)             │
├─────────────────────────────────────┤
│ ▼ Quick Actions                     │
│   ⚡ Quick Clean (Safe)             │
│   🔄 Flush DNS Cache                │
│   🔄 Restart Finder                 │
│   🔄 Restart Dock                   │
│   🌐 Close Heavy Tabs...            │
├─────────────────────────────────────┤
│ ▼ Deep Clean                        │
│   🗑️ Clear User Caches              │
│   🗑️ Clear Browser Caches           │
│   🛠️ Developer Cleanup...           │
├─────────────────────────────────────┤
│ ▼ Browser Management                │
│   Safari: 23 tabs                   │
│   Chrome: 47 tabs ⚠️                │
│   • Close All Safari Tabs           │
│   • Close All Chrome Tabs           │
│   • Close Tabs by Pattern...        │
├─────────────────────────────────────┤
│ 📋 Activity Log                     │
│ ⚙️ Permissions                      │
│ ─────────────────────────────────── │
│ ⚙️ Preferences...                   │
│ 🚪 Quit Craig-O-Clean               │
└─────────────────────────────────────┘
```

### 5.2 Permission Status View

```swift
struct PermissionStatusView: View {
    @Environment(PermissionCenter.self) var permissions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)
            
            ForEach(BrowserApp.allCases, id: \.self) { app in
                PermissionRow(
                    app: app,
                    state: permissions.automationPermissions[app] ?? .unknown,
                    onFix: { await requestPermission(for: app) }
                )
            }
            
            Divider()
            
            HStack {
                Label("Privileged Helper", systemImage: permissions.helperInstalled ? "checkmark.shield.fill" : "xmark.shield")
                Spacer()
                if !permissions.helperInstalled {
                    Button("Install") { installHelper() }
                }
            }
        }
    }
}
```

### 5.3 Confirmation Flow

All destructive operations must follow this flow:

```
User Clicks Action
        │
        ▼
┌───────────────────────────────────────┐
│         Confirmation Dialog           │
├───────────────────────────────────────┤
│ ⚠️ Clear User Caches                  │
│                                       │
│ This will remove:                     │
│ • ~/Library/Caches/* (2.3 GB)        │
│ • Temporary files (145 MB)           │
│                                       │
│ Apps may rebuild caches on next use. │
│                                       │
│ [Preview Changes]  [Cancel] [Proceed] │
└───────────────────────────────────────┘
        │
        ▼ (User clicks Preview)
┌───────────────────────────────────────┐
│         Dry Run Preview               │
├───────────────────────────────────────┤
│ Files to be removed:                  │
│                                       │
│ ~/Library/Caches/                     │
│   ├── com.apple.Safari/ (456 MB)     │
│   ├── com.google.Chrome/ (1.2 GB)    │
│   ├── com.microsoft.VSCode/ (234 MB) │
│   └── ... (12 more folders)          │
│                                       │
│ Total: 2.3 GB in 847 files           │
│                                       │
│              [Cancel] [Confirm Delete]│
└───────────────────────────────────────┘
```

---

## 6. Build Slices (Implementation Order)

### Slice A: App Shell + Capability Catalog (Days 1-2)

**Deliverables:**
- SwiftUI menu bar app with basic structure
- Capability model and JSON catalog loader
- Status view with mock data
- Basic UI navigation

**Acceptance:**
- App appears in menu bar
- Catalog loads from bundled JSON
- Menu sections render correctly

### Slice B: Non-Privileged Executor (Days 3-4)

**Deliverables:**
- Process-based command runner
- Streaming stdout/stderr
- Timeout management
- Basic logging (RunRecord)

**Acceptance:**
- Can run `user` privilege commands
- Output streams to UI in real-time
- Logs persist to SQLite

### Slice C: Permission Center (Days 5-6)

**Deliverables:**
- Automation permission detection
- Permission status UI
- Remediation instructions
- Preflight gating

**Acceptance:**
- App detects Safari/Chrome automation permission
- Shows clear "how to fix" for denied permissions
- Blocks execution when permission missing

### Slice D: Browser Operations (Days 7-9)

**Deliverables:**
- Safari tab controller
- Chrome/Edge/Brave tab controllers
- Tab listing and closing by pattern
- "Heavy tab" heuristic

**Acceptance:**
- Can list tabs from all supported browsers
- Can close tabs matching URL pattern
- Shows tab count in menu
- Handles permission denial gracefully

### Slice E: Privileged Helper (Days 10-12)

**Deliverables:**
- SMJobBless helper tool
- XPC communication protocol
- Authorization Services integration
- Elevated command execution

**Acceptance:**
- Helper installs via standard macOS flow
- Elevated commands work without sudo prompts
- Audit log captures who/when/what

### Slice F: AI Orchestration (Days 13-15, Optional)

**Deliverables:**
- Local Ollama client
- PlannerAgent + SafetyAgent
- Workflow proposal UI
- Strict capability-only execution

**Acceptance:**
- AI suggests workflows using capability IDs only
- Destructive operations require confirmation
- AI cannot execute arbitrary commands

---

## 7. Test Requirements

### 7.1 Unit Tests

```swift
// Capability validation
func testCapabilitySchemaValid()
func testArgumentValidation()
func testPreflightCheckParsing()

// Preflight gating
func testUserPrivilegeAllowed()
func testElevatedPrivilegeBlocked_WhenNoHelper()
func testAutomationBlocked_WhenPermissionDenied()

// Command execution
func testCommandTimeout()
func testOutputParsing()
func testGracefulCancellation()
```

### 7.2 Integration Tests

```swift
// Process runner
func testProcessRunner_SuccessfulCommand()
func testProcessRunner_FailedCommand()
func testProcessRunner_StreamingOutput()

// Logging
func testLogPersistence()
func testLogExport()
func testAuditChainIntegrity()
```

### 7.3 Manual QA Checklist

- [ ] First launch permission prompts appear correctly
- [ ] Denied automation permission shows remediation UI
- [ ] Quick Clean executes without any prompts
- [ ] Elevated operations show authorization dialog
- [ ] Browser tab close works for each supported browser
- [ ] Activity log shows accurate history
- [ ] Export logs produces valid file
- [ ] App handles browser not installed gracefully
- [ ] App handles browser not running gracefully

---

## 8. Project Structure

```
CraigOClean/
├── App/
│   ├── CraigOCleanApp.swift           # App entry point
│   ├── AppDelegate.swift              # Menu bar lifecycle
│   └── Environment/
│       ├── AppEnvironment.swift       # Dependency container
│       └── Configuration.swift        # Build settings
│
├── Features/
│   ├── MenuBar/
│   │   ├── MenuBarView.swift
│   │   ├── StatusSection.swift
│   │   ├── QuickActionsSection.swift
│   │   └── BrowserSection.swift
│   │
│   ├── Permissions/
│   │   ├── PermissionStatusView.swift
│   │   └── RemediationSheet.swift
│   │
│   ├── Confirmation/
│   │   ├── ConfirmationDialog.swift
│   │   └── DryRunPreview.swift
│   │
│   └── ActivityLog/
│       ├── ActivityLogView.swift
│       └── RunRecordDetail.swift
│
├── Core/
│   ├── Capabilities/
│   │   ├── Capability.swift           # Model
│   │   ├── CapabilityCatalog.swift    # Loader + registry
│   │   └── Resources/
│   │       └── catalog.json           # Bundled catalog
│   │
│   ├── Execution/
│   │   ├── CommandExecutor.swift      # Protocol
│   │   ├── UserExecutor.swift         # Non-privileged
│   │   ├── ElevatedExecutor.swift     # XPC to helper
│   │   ├── ProcessRunner.swift        # Foundation.Process wrapper
│   │   └── OutputStreamer.swift       # Async output handling
│   │
│   ├── Permissions/
│   │   ├── PermissionCenter.swift
│   │   ├── AutomationChecker.swift
│   │   └── FullDiskAccessChecker.swift
│   │
│   └── Logging/
│       ├── RunRecord.swift
│       ├── LogStore.swift             # Protocol
│       ├── SQLiteLogStore.swift       # Implementation
│       └── LogExporter.swift
│
├── Automation/
│   ├── BrowserController.swift        # Protocol
│   ├── SafariController.swift
│   ├── ChromiumController.swift       # Chrome, Edge, Brave
│   └── Scripts/
│       ├── safari_tabs.applescript
│       └── chromium_tabs.applescript
│
├── PrivilegedHelper/
│   ├── HelperMain.swift
│   ├── HelperProtocol.swift           # XPC interface
│   ├── HelperConnection.swift         # App-side XPC client
│   └── Info.plist
│
├── AI/ (Optional)
│   ├── Agents/
│   │   ├── PlannerAgent.swift
│   │   ├── SafetyAgent.swift
│   │   └── ExecutorAgent.swift
│   ├── OllamaClient.swift
│   └── WorkflowSchema.swift
│
├── Resources/
│   ├── Assets.xcassets
│   ├── Info.plist
│   └── CraigOClean.entitlements
│
└── Tests/
    ├── CapabilityTests/
    ├── ExecutionTests/
    ├── PermissionTests/
    └── BrowserTests/
```

---

## 9. Implementation Notes

### 9.1 Execution Guidelines

- Prefer Swift-native implementations over shell scripts
- Shell scripts only when:
  - Bundled as signed resources
  - Executed through allowlisted wrapper
  - Arguments validated against schema
- Use `Foundation.Process` with explicit environment
- Always set working directory explicitly
- Capture both stdout and stderr

### 9.2 AppleScript Best Practices

- Wrap all AppleScript in `try` blocks
- Detect permission errors specifically (error -1743)
- Provide specific remediation for each browser
- Test with browser both running and quit
- Handle Chromium variants consistently

### 9.3 Memory/Performance Considerations

- Cache `system_profiler` results (expensive)
- Use `OperationQueue` with 2-3 concurrency max
- Stream output instead of buffering
- Debounce rapid UI updates
- Profile on lowest-spec Apple Silicon

---

## 10. Acceptance Criteria

| Scenario | Expected Behavior |
|----------|-------------------|
| Run "Quick Clean" | Executes without any password prompts, completes successfully |
| Run elevated command | Shows macOS authorization dialog, executes after approval |
| Browser tab operation (permission granted) | Lists/closes tabs correctly |
| Browser tab operation (permission denied) | Shows remediation UI with System Settings path |
| First launch | Permission prompts appear in correct order |
| Command fails | Error shown with specific cause and remediation |
| View activity log | Shows all runs with status, duration, expandable details |
| Export logs | Creates readable file with all recent activity |

---

## 11. Review Checklist (For Existing Codebase)

When reviewing existing code, evaluate against these criteria:

1. **Command Execution Audit**
   - [ ] List all locations where commands execute (bash, Process, AppleScript)
   - [ ] Identify commands that fail due to permissions
   - [ ] Flag any SIP-protected path access attempts
   - [ ] Note any `rm -rf` without path validation

2. **Security Issues**
   - [ ] Any arbitrary command execution from user input?
   - [ ] Any sudo/admin escalation without explicit approval?
   - [ ] Any missing confirmation for destructive operations?
   - [ ] Any credentials or secrets in logs?

3. **UX Issues**
   - [ ] Silent failures (no user feedback)?
   - [ ] Missing permission remediation guidance?
   - [ ] Unclear what operation will do before execution?
   - [ ] Missing progress indication for long operations?

4. **Refactoring Priorities**
   - [ ] Convert ad-hoc commands to capability catalog
   - [ ] Implement centralized executor
   - [ ] Add preflight checks
   - [ ] Add confirmation flows
   - [ ] Implement proper logging

---

## Appendix A: VibeCaaS Branding

Apply consistent VibeCaaS theming:

```swift
extension Color {
    // VibeCaaS Brand Colors
    static let vibePrimary = Color(hex: "#6366F1")      // Indigo
    static let vibeSecondary = Color(hex: "#8B5CF6")    // Violet
    static let vibeAccent = Color(hex: "#EC4899")       // Pink
    static let vibeSuccess = Color(hex: "#10B981")      // Emerald
    static let vibeWarning = Color(hex: "#F59E0B")      // Amber
    static let vibeError = Color(hex: "#EF4444")        // Red
    
    // Semantic Colors
    static let vibeSafe = vibeSuccess
    static let vibeModerate = vibeWarning
    static let vibeDestructive = vibeError
}
```

---

*Document Version: 2.0*  
*Last Updated: January 2026*  
*Author: NeuralQuantum.ai / VibeCaaS Team*
