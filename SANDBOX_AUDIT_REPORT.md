# Craig-O-Clean Sandbox Audit Report

**Version:** 1.0
**Date:** 2026-01-28
**Auditor:** Claude Code (Sandbox Architect Agent)
**Target:** Mac App Store (MAS) Sandbox Compliance

---

## Executive Summary

Craig-O-Clean is a macOS menu bar utility providing system monitoring, memory optimization, browser tab management, and cleanup features. The current architecture uses a hybrid approach with a sandboxed main app and an unsandboxed privileged helper (XPC service) for elevated operations.

### Key Findings

| Category | Status | Notes |
|----------|--------|-------|
| App Sandbox | Enabled | `com.apple.security.app-sandbox = true` |
| Native Metrics APIs | Good | SystemMetricsService uses Mach/Darwin APIs |
| Shell Command Execution | Risk | 75+ shell commands in catalog.json |
| Privileged Helper | MAS-Incompatible | XPC helper cannot be distributed via MAS |
| Browser Automation | Compliant | Uses Apple Events with proper entitlements |
| File Access | Mixed | Some operations access protected paths |

### MAS Readiness Score: 45/100

The app requires significant refactoring to achieve MAS compliance. The primary blockers are:
1. Privileged helper tool (SMJobBless) - not allowed in MAS
2. Shell command execution for elevated operations
3. Access to system-protected paths (/Library/*, /private/*)
4. AppleScript `with administrator privileges` fallback

---

## A1. Current Architecture Summary

### UI Layer

| Component | File | Purpose |
|-----------|------|---------|
| App Entry | `Craig_O_CleanApp.swift` | @main entry, AppDelegate, menu bar setup |
| Menu Bar | `MenuBarContentView.swift` | Popover content on click |
| Dashboard | `DashboardView.swift` | System metrics visualization |
| Process Manager | `ProcessManagerView.swift` | Running processes list |
| Browser Tabs | `BrowserTabsView.swift` | Tab management UI |
| Settings | `SettingsView.swift`, `SettingsPermissionsView.swift` | Configuration and permissions |
| Paywall | `PaywallView.swift` | In-app purchase UI |

**Architecture Pattern:** SwiftUI with @EnvironmentObject services, menu bar app (LSUIElement=true)

### Command Layer

| Component | File | Purpose |
|-----------|------|---------|
| ProcessRunner | `Core/Execution/ProcessRunner.swift` | Foundation.Process wrapper for shell execution |
| ElevatedExecutor | `Core/Execution/ElevatedExecutor.swift` | AppleScript `with administrator privileges` fallback |
| UserExecutor | `Core/Execution/UserExecutor.swift` | User-level command execution |
| CommandExecutor | `Core/Execution/CommandExecutor.swift` | Protocol + routing based on privilege level |
| PrivilegeService | `Core/PrivilegeService.swift` | XPC client for helper tool communication |
| HelperXPCImpl | `CraigOCleanHelper/HelperXPCImplementation.swift` | Privileged helper service implementation |

**Command Execution Flow:**
```
User Action → Capability Selected → Preflight Checks → Risk Assessment
    → Confirmation Dialog (if needed) → Execute via Appropriate Executor
    → Capture Output → Log to SQLite → Parse Output → Display Results
```

### Logging & Error Handling

| Component | File | Purpose |
|-----------|------|---------|
| AppLogger | `Core/AppLogger.swift` | High-level logging API |
| DebugLogger | `Core/DebugLogger.swift` | Debug-specific logging |
| SQLiteLogStore | `Core/Logging/SQLiteLogStore.swift` | Persistent audit log storage |
| RunRecord | `Core/Logging/RunRecord.swift` | Execution record model |

### Data Storage

| Storage Type | Location | Purpose |
|--------------|----------|---------|
| UserDefaults | Standard | App preferences, settings |
| SQLite DB | App Container | Audit log, execution history |
| Keychain | System Keychain | Secure credential storage |
| Security-Scoped Bookmarks | App Container | Persistent file access |

---

## A2. Sandbox/TCC Risk Findings

### CRITICAL RISKS (MAS Blockers)

#### Risk 1: Privileged Helper Tool (SMJobBless)
- **Files:** `CraigOCleanHelper/*`, `Core/PrivilegeService.swift`
- **Commands:** `/bin/sync`, `/usr/bin/purge`, `/bin/kill -9`, `/usr/bin/killall -9`
- **API:** SMJobBless, XPC Mach services
- **Violation:** SMJobBless helpers cannot be distributed via Mac App Store
- **Impact:** Memory purge, force kill features will not work in MAS build

#### Risk 2: AppleScript Administrator Privileges
- **Files:** `Core/PrivilegeService.swift:680-720`, `Core/Execution/ElevatedExecutor.swift:36`
- **Commands:** `do shell script "..." with administrator privileges`
- **API:** NSAppleScript with privilege escalation
- **Violation:** MAS apps cannot request admin privileges for shell commands
- **Impact:** All elevated operations fail without alternative

#### Risk 3: System Path Access
- **Files:** `Core/Capabilities/Resources/catalog.json`
- **Paths Accessed:**
  - `/private/var/tmp/*` (deep.system.temp)
  - `/private/var/log/asl/*.asl` (deep.system.asl)
  - `/Library/Caches/*` (TerminatorEdition only)
  - `/System/Library/Caches/*` (TerminatorEdition only)
- **Violation:** Sandbox denies access to system-protected paths
- **Impact:** System-level cleaning features unavailable

### HIGH RISKS (Functionality Impact)

#### Risk 4: Shell Command Execution
- **Files:** `Core/Execution/ProcessRunner.swift`, `catalog.json`
- **Commands:** 75+ commands including `top`, `ps`, `kill`, `killall`, `find`, `rm -rf`
- **API:** Foundation.Process with `/bin/zsh`
- **Violation:** Sandboxed apps cannot execute arbitrary shell commands
- **Impact:** Most diagnostic and cleanup capabilities fail

#### Risk 5: Process Termination via killall/pkill
- **Files:** `catalog.json` (lines 430-530)
- **Commands:** `killall Finder`, `killall Dock`, `killall -9 Safari`, `pkill -9 -f "Chrome Helper"`
- **API:** Shell execution via Process
- **Violation:** Sandbox blocks external process termination via shell
- **Impact:** System restart features (Finder, Dock, MenuBar) unavailable

### MEDIUM RISKS (Partial Functionality)

#### Risk 6: Full Disk Access Detection
- **File:** `Core/PermissionsService.swift:398-476`
- **Paths Probed:**
  - `~/Library/Safari/History.db`
  - `~/Library/Mail`
  - `~/Library/Application Support/com.apple.TCC`
  - `/Library/Application Support/com.apple.TCC/TCC.db`
- **Violation:** Reading TCC database requires FDA, probing protected paths unreliable
- **Impact:** FDA detection may produce false negatives

#### Risk 7: User Library Cleanup Operations
- **Files:** `catalog.json` (deep.* capabilities)
- **Paths:**
  - `~/Library/Caches/*`
  - `~/Library/Logs/*`
  - `~/Library/Application Support/CrashReporter/*`
  - `~/Library/Saved Application State/*`
- **Violation:** Sandbox restricts `~/Library` access without user selection
- **Impact:** Requires security-scoped bookmarks for user-selected folders

### LOW RISKS (MAS Compatible with Changes)

#### Risk 8: Browser Automation
- **Files:** `Core/BrowserAutomationService.swift`, `Automation/BrowserController.swift`
- **API:** NSAppleScript for tab enumeration/closure
- **Entitlements:** `com.apple.security.scripting-targets` properly configured
- **Status:** MAS-compatible with Automation TCC permission
- **Action:** Add graceful degradation when permission denied

#### Risk 9: System Metrics Collection
- **File:** `Core/SystemMetricsService.swift`
- **APIs Used:**
  - `host_processor_info()` - CPU metrics
  - `host_statistics64()` - Memory/VM stats
  - `sysctl()` - System info
  - `getifaddrs()` - Network stats
  - `FileManager.attributesOfFileSystem()` - Disk stats
- **Status:** All native Darwin/Mach APIs - MAS compatible
- **Action:** None required, already sandbox-safe

---

## A3. Feature Inventory

### Feature 1: System Metrics Dashboard

| Aspect | Current State |
|--------|---------------|
| **Implementation** | `SystemMetricsService.swift` using native Mach/Darwin APIs |
| **Dependencies** | `host_processor_info`, `vm_statistics64`, `sysctl`, `getifaddrs` |
| **Failure Modes** | None - native APIs always available |
| **User Behavior** | Real-time CPU, RAM, disk, network stats displayed in dashboard |
| **MAS Status** | Fully compatible |

### Feature 2: Process List & Management

| Aspect | Current State |
|--------|---------------|
| **Implementation** | `ProcessManager.swift` using `NSWorkspace.shared.runningApplications` |
| **Dependencies** | NSRunningApplication API (sandbox-safe), lsof for details |
| **Failure Modes** | lsof unavailable in sandbox; basic info always works |
| **User Behavior** | List running apps, quit/force-quit via NSRunningApplication |
| **MAS Status** | Partially compatible - use native terminate() API only |

**Current Process Termination Methods:**
1. `NSRunningApplication.terminate()` - MAS compatible
2. `NSRunningApplication.forceTerminate()` - MAS compatible
3. `kill(pid, SIGTERM/SIGKILL)` - Works for user-owned processes
4. Shell `killall -9` - Not MAS compatible
5. XPC helper `forceKillProcess()` - Not MAS compatible

### Feature 3: Browser Tab Management

| Aspect | Current State |
|--------|---------------|
| **Implementation** | `BrowserAutomationService.swift` using NSAppleScript |
| **Dependencies** | Automation TCC permission per browser |
| **Failure Modes** | Error -1743 when permission denied |
| **User Behavior** | View tabs, close heavy tabs, close by domain |
| **MAS Status** | Compatible with proper permission UI |

**Supported Browsers:**
- Safari (com.apple.Safari)
- Google Chrome (com.google.Chrome)
- Microsoft Edge (com.microsoft.edgemac)
- Brave Browser (com.brave.Browser)
- Arc (company.thebrowser.Browser)
- Firefox (org.mozilla.firefox) - limited support

### Feature 4: Memory Optimization

| Aspect | Current State |
|--------|---------------|
| **Implementation** | `MemoryOptimizerService.swift` + XPC helper |
| **Dependencies** | `/bin/sync`, `/usr/bin/purge` via helper or AppleScript |
| **Failure Modes** | Requires admin privileges; fails without helper |
| **User Behavior** | "Smart cleanup" button purges inactive memory |
| **MAS Status** | NOT compatible - requires privileged helper |

**MAS Alternative:** Remove system memory purge; offer:
- Quit high-memory apps (NSRunningApplication)
- Display memory pressure warnings
- Link to Activity Monitor for manual action

### Feature 5: File/Cache Cleanup

| Aspect | Current State |
|--------|---------------|
| **Implementation** | Shell `rm -rf` commands via ProcessRunner |
| **Dependencies** | Direct ~/Library access, shell execution |
| **Failure Modes** | Sandbox denies access to ~/Library without bookmark |
| **User Behavior** | Clean caches, logs, crash reports, temp files |
| **MAS Status** | NOT compatible in current form |

**Cleanup Targets (from catalog.json):**
- `~/Library/Caches/*` - Requires user selection
- `~/Library/Logs/*` - Requires user selection
- `~/Library/Application Support/CrashReporter/*` - Requires user selection
- `~/Library/Developer/Xcode/DerivedData/*` - Requires user selection
- `~/.Trash/*` - Special handling (use Finder AppleScript)

### Feature 6: System Service Restarts

| Aspect | Current State |
|--------|---------------|
| **Implementation** | Shell `killall` commands (Finder, Dock, SystemUIServer) |
| **Dependencies** | Shell execution, process termination |
| **Failure Modes** | Sandbox blocks killall |
| **User Behavior** | Restart Finder/Dock/MenuBar to fix glitches |
| **MAS Status** | NOT compatible |

**MAS Alternative:**
- For Finder: Use AppleScript `tell application "Finder" to quit` (with Automation permission)
- For Dock/SystemUIServer: Display instructions for user to use Activity Monitor
- Link to Force Quit dialog (Cmd+Opt+Esc)

### Feature 7: Developer Tools Cleanup

| Aspect | Current State |
|--------|---------------|
| **Implementation** | Shell `rm -rf` on Xcode/npm/Docker paths |
| **Dependencies** | Direct file access, shell execution |
| **Failure Modes** | Sandbox denies unselected folder access |
| **User Behavior** | Clear DerivedData, Simulators, npm cache, Docker prune |
| **MAS Status** | Partially compatible with user folder selection |

### Feature 8: Diagnostic Commands

| Aspect | Current State |
|--------|---------------|
| **Implementation** | Shell commands (top, ps, df, du, vm_stat, etc.) |
| **Dependencies** | Shell execution |
| **Failure Modes** | Some commands work; parsing output is fragile |
| **User Behavior** | View detailed system info in capability panels |
| **MAS Status** | Replace with native APIs where possible |

---

## Privilege Levels in Catalog

| Privilege Level | Count | MAS Status |
|-----------------|-------|------------|
| `user` | 48 | Partially compatible (native APIs preferred) |
| `elevated` | 11 | NOT compatible (requires admin) |
| `automation` | 16 | Compatible (requires TCC permission) |

### Commands by Risk Class

| Risk Class | Count | Description |
|------------|-------|-------------|
| `safe` | 41 | Read-only diagnostics |
| `moderate` | 26 | Restarts, cache clearing |
| `destructive` | 8 | Archive deletion, trash emptying |

---

## Current Entitlements Analysis

```xml
<!-- Craig-O-Clean.entitlements -->
com.apple.security.app-sandbox = true              <!-- Required for MAS -->
com.apple.security.automation.apple-events = true  <!-- Browser automation -->
com.apple.security.files.user-selected.read-write = true  <!-- File picker access -->
com.apple.security.network.client = true           <!-- Stripe API, updates -->
com.apple.security.scripting-targets = {           <!-- Browser-specific automation -->
    com.apple.Safari, com.google.Chrome, com.microsoft.edgemac,
    com.brave.Browser, company.thebrowser.Browser, com.apple.systemevents
}
com.apple.security.temporary-exception.mach-lookup.global-name = [
    com.apple.coreservices.launchservicesd         <!-- App detection -->
]
```

**Missing for Full MAS Compliance:**
- Remove temporary-exception (may cause rejection)
- No Full Disk Access required in MAS version
- No admin privileges possible

---

## Recommendations Summary

1. **Remove privileged helper entirely for MAS build** - Use graceful degradation
2. **Replace shell commands with native APIs** - See implementation plan
3. **Implement security-scoped bookmarks** - For user-selected cleanup folders
4. **Add comprehensive permission status UI** - Explain each permission's purpose
5. **Create "Developer ID Only" feature toggle** - For advanced features
6. **Add dry-run preview for all destructive operations** - With audit logging
7. **Replace killall with NSRunningApplication APIs** - Where possible

---

## Next Steps

1. Review Capability Matrix (CAPABILITY_MATRIX.md)
2. Review Architecture Blueprint (ARCHITECTURE_BLUEPRINT.md)
3. Begin Implementation Plan execution
