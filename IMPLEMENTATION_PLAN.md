# Craig-O-Clean Implementation Plan

**Version:** 1.0
**Date:** 2026-01-28
**Methodology:** Vertical Slices with Incremental Delivery

---

## Overview

This plan implements the sandbox-compliant refactor in 5 vertical slices. Each slice delivers working, testable functionality that builds toward full MAS compliance.

---

## Slice 1: Foundation (Priority: CRITICAL)

**Goal:** Establish core infrastructure for audit logging, structured errors, permission management, and native metrics.

### Tasks

#### 1.1 Create Structured Error Types
**Files:** `Core/Errors/CraigOCleanError.swift`

```swift
enum CraigOCleanError: Error, LocalizedError {
    case permissionDenied(PermissionType)
    case accessDenied(URL)
    case operationCancelled
    case operationFailed(underlying: Error)
    case notConfirmed
    case featureUnavailable(reason: String)
    case bookmarkStale(URL)
    case scriptExecutionFailed(errorCode: Int, description: String)

    var errorDescription: String? { ... }
}

enum PermissionType {
    case automation(bundleId: String)
    case accessibility
    case fullDiskAccess
    case fileAccess(URL)
}
```

**Acceptance:** Error types compile, have descriptive messages, are used consistently.

#### 1.2 Create Result Envelope Types
**Files:** `Core/Types/ActionResult.swift`

```swift
struct ActionResult<T> {
    let success: Bool
    let value: T?
    let error: CraigOCleanError?
    let timestamp: Date
    let duration: TimeInterval
}

extension ActionResult {
    static func success(_ value: T) -> ActionResult<T>
    static func failure(_ error: CraigOCleanError) -> ActionResult<T>
}
```

**Acceptance:** All service methods return ActionResult or Swift Result types.

#### 1.3 Implement AuditLogService
**Files:**
- `Core/Services/AuditLogService.swift`
- `Core/Services/AuditEntry.swift`
- Update `Core/Logging/SQLiteLogStore.swift`

**Requirements:**
- Append-only audit log
- All actions logged with timestamp, action type, target, metadata
- Export as JSON
- UI to view recent entries
- 100 most recent entries in memory

**Acceptance:** All destructive operations create audit entries. Export works.

#### 1.4 Implement PermissionManager
**Files:** `Core/Permissions/PermissionManager.swift`

**Requirements:**
- Check/request automation permission per bundle ID
- Check accessibility permission
- Check Full Disk Access (heuristic)
- Published state for UI binding
- Open System Settings URLs

**Acceptance:** Permission states correctly detected. UI reflects state.

#### 1.5 Implement FileAccessManager
**Files:** `Core/Permissions/FileAccessManager.swift`

**Requirements:**
- Create security-scoped bookmarks via NSOpenPanel
- Persist bookmarks to UserDefaults
- Start/stop accessing resources
- Handle stale bookmarks
- List authorized folders

**Acceptance:** Folder picker works. Bookmarks persist across app restart. Access works.

#### 1.6 Refactor MetricsService to Pure Native APIs
**Files:** `Core/Services/MetricsService.swift` (refactor from SystemMetricsService)

**Requirements:**
- Remove any shell command fallbacks
- Ensure all metrics use Mach/Darwin APIs
- Add memory pressure source monitoring
- Add per-app memory usage (where available)

**Current Status:** Already mostly native. Verify and clean up.

**Acceptance:** No shell commands. All metrics display correctly.

#### 1.7 Create Permissions Status UI
**Files:**
- `UI/Permissions/PermissionStatusView.swift`
- `UI/Permissions/PermissionRowView.swift`
- `UI/Permissions/PermissionGuideView.swift`

**Requirements:**
- Traffic light indicators for each permission
- "Learn how to enable" button → explanation sheet
- Refresh button to re-check
- Integration in Settings

**Acceptance:** Permissions visible in Settings. Guide opens correct System Settings pane.

### Slice 1 Definition of Done
- [ ] All error types defined and used
- [ ] AuditLogService logging all actions
- [ ] PermissionManager detecting all permission states
- [ ] FileAccessManager creating/restoring bookmarks
- [ ] MetricsService 100% native APIs
- [ ] Permissions UI integrated in Settings
- [ ] Unit tests for services
- [ ] App compiles and runs sandboxed

---

## Slice 2: Safe Actions (Priority: HIGH)

**Goal:** Implement process management using only sandbox-safe APIs.

### Tasks

#### 2.1 Implement ActionsService
**Files:** `Core/Services/ActionsService.swift`

**Requirements:**
- Quit app via NSRunningApplication.terminate()
- Force quit via NSRunningApplication.forceTerminate()
- Quit via AppleScript (with automation check)
- Open Activity Monitor
- Open Force Quit dialog instructions

**Acceptance:** Apps can be quit from process list. Audit logged.

#### 2.2 Refactor ProcessManager for Sandbox
**Files:** `ProcessManager.swift`

**Changes:**
- Remove shell-based kill methods
- Remove lsof calls (or make optional with graceful failure)
- Use only NSRunningApplication and proc_* APIs
- Add ActionsService integration

**Acceptance:** Process list works. Quit/Force Quit work. No shell commands.

#### 2.3 Update Process Manager UI
**Files:** `UI/Processes/ProcessManagerView.swift`

**Changes:**
- "Quit" button uses ActionsService
- "Force Quit" with confirmation dialog
- Memory info from native APIs
- Gray out unavailable actions with explanation

**Acceptance:** UI works with new services. Unavailable actions explained.

#### 2.4 Implement "High Memory Consumer" Feature
**Files:**
- `Core/Services/MemoryAnalysisService.swift`
- `UI/Memory/HighMemoryAppsView.swift`

**Requirements:**
- List top memory-consuming apps
- "Quit" buttons for each
- Exclude system processes
- Refresh on demand

**Acceptance:** High memory apps listed. Quit buttons work.

#### 2.5 Add "Open Activity Monitor" Action
**Files:** `Core/Services/ActionsService.swift`

**Requirements:**
- One-click to open Activity Monitor
- Shown as alternative when advanced features unavailable

**Acceptance:** Activity Monitor opens.

### Slice 2 Definition of Done
- [ ] Apps quit via native API
- [ ] Force quit with confirmation
- [ ] No shell commands for process management
- [ ] High memory apps feature working
- [ ] Activity Monitor shortcut
- [ ] Unit tests for ActionsService

---

## Slice 3: Browser Control via Automation (Priority: HIGH)

**Goal:** Implement browser tab management with proper permission handling.

### Tasks

#### 3.1 Refactor BrowserService
**Files:** `Core/Services/BrowserService.swift`

**Changes:**
- Integrate PermissionManager for automation checks
- Return permission-required errors gracefully
- Add per-browser permission status
- Audit log tab operations

**Acceptance:** Tab enumeration works when permitted. Clear error when denied.

#### 3.2 Create Browser Permission Request Flow
**Files:**
- `UI/Browser/BrowserPermissionSheet.swift`
- `UI/Browser/BrowserPermissionExplanation.swift`

**Requirements:**
- Explanation of why automation needed
- "Request Permission" button triggers system prompt
- Status updates after prompt
- Link to System Settings if denied

**Acceptance:** User can grant automation permission with clear guidance.

#### 3.3 Update BrowserTabsView for Permission States
**Files:** `UI/Browser/BrowserTabsView.swift`

**Changes:**
- Show permission status per browser
- "Enable" button for unpermitted browsers
- Graceful empty state when all denied
- Loading states during tab fetch

**Acceptance:** UI reflects permission states. Clear path to enable.

#### 3.4 Implement Tab Closing with Confirmation
**Files:** `UI/Browser/TabCloseConfirmationView.swift`

**Requirements:**
- Preview of tabs to close
- Confirmation dialog
- Audit log entry
- Success/failure feedback

**Acceptance:** Tab closing requires confirmation. Audit logged.

#### 3.5 Implement "Close by Domain" Feature
**Files:** `Core/Services/BrowserService.swift`

**Requirements:**
- Find tabs matching domain
- Dry run: show count
- Confirm: close tabs
- Audit log

**Acceptance:** Domain-based tab closure works with preview.

### Slice 3 Definition of Done
- [ ] Browser tabs visible when permitted
- [ ] Permission request flow complete
- [ ] Tab closing with confirmation
- [ ] Close by domain feature
- [ ] All operations audit logged
- [ ] Graceful degradation when denied
- [ ] Tests for BrowserService

---

## Slice 4: Sandbox Cleaning (Priority: HIGH)

**Goal:** Implement user-scoped file cleanup with security-scoped bookmarks.

### Tasks

#### 4.1 Implement CleanerService
**Files:** `Core/Services/CleanerService.swift`

**Requirements:**
- Folder authorization via NSOpenPanel
- Dry run: enumerate files, calculate sizes
- Execute: delete files within scope
- Return detailed results
- Audit log operations

**Acceptance:** Cleanup works within authorized folders only.

#### 4.2 Create Folder Selection UI
**Files:** `UI/Cleanup/FolderSelectionView.swift`

**Requirements:**
- List of preset cleanup targets (Caches, Logs, etc.)
- "Authorize" button for each
- Show authorized status
- Remove authorization option

**Acceptance:** User can authorize folders. Status visible.

#### 4.3 Implement Dry Run Preview
**Files:** `UI/Cleanup/DryRunPreviewView.swift`

**Requirements:**
- List files to be deleted
- Show total size
- File type breakdown
- Cancel option
- Proceed to confirmation

**Acceptance:** User sees exactly what will be deleted.

#### 4.4 Implement Cleanup Confirmation
**Files:** `UI/Cleanup/CleanupConfirmationView.swift`

**Requirements:**
- Clear warning about irreversibility
- Checkbox confirmation
- Execute button
- Progress indicator
- Result summary

**Acceptance:** Cleanup requires explicit confirmation.

#### 4.5 Implement Cleanup Results View
**Files:** `UI/Cleanup/CleanupResultsView.swift`

**Requirements:**
- Files deleted count
- Space freed
- Errors (if any)
- View audit log link
- Done button

**Acceptance:** Clear feedback after cleanup.

#### 4.6 Add Cleanup Presets
**Files:** `Core/Data/CleanupPresets.swift`

**Presets:**
- User Caches (`~/Library/Caches`)
- User Logs (`~/Library/Logs`)
- Crash Reports (`~/Library/Application Support/CrashReporter`)
- Xcode DerivedData (`~/Library/Developer/Xcode/DerivedData`)
- Downloads (`~/Downloads`)
- Trash (`~/.Trash` - via Finder automation)

**Acceptance:** Presets show in UI with descriptions.

### Slice 4 Definition of Done
- [ ] Folder authorization working
- [ ] Dry run preview working
- [ ] Cleanup with confirmation
- [ ] Results display
- [ ] Presets defined
- [ ] Audit logging complete
- [ ] Tests for CleanerService

---

## Slice 5: Polish & Reliability (Priority: MEDIUM)

**Goal:** Background monitoring, settings, performance, edge cases.

### Tasks

#### 5.1 Implement Background Memory Pressure Monitoring
**Files:** `Core/Services/MetricsService.swift`

**Requirements:**
- Use DispatchSource.makeMemoryPressureSource
- Notify user on warning/critical
- Opt-in via settings
- Respect Do Not Disturb

**Acceptance:** Notification appears on memory pressure.

#### 5.2 Implement User Notifications
**Files:** `Core/Services/NotificationService.swift`

**Requirements:**
- Request notification permission
- Memory pressure alerts
- Cleanup completion alerts
- Configurable in settings

**Acceptance:** Notifications work when enabled.

#### 5.3 Settings Panel Completion
**Files:** `UI/Settings/SettingsView.swift`

**Sections:**
- General (launch at login, etc.)
- Permissions (status, guides)
- Notifications (toggles)
- Cleanup (auto-cleanup schedule)
- Advanced (Developer ID features)
- About

**Acceptance:** All settings functional.

#### 5.4 Implement Auto-Cleanup Scheduling (Optional)
**Files:** `Core/Services/AutoCleanupService.swift`

**Requirements:**
- Schedule cleanup of authorized folders
- Configurable interval
- Dry run → auto confirm if size < threshold
- Notification on completion

**Acceptance:** Scheduled cleanup works for authorized folders.

#### 5.5 Performance Profiling
**Tasks:**
- Profile CPU/memory usage
- Optimize timer intervals
- Reduce unnecessary refreshes
- Test with many running apps

**Acceptance:** App uses < 1% CPU idle, < 50MB memory.

#### 5.6 Error Handling Hardening
**Tasks:**
- Handle all permission denied cases
- Handle all file access errors
- Handle AppleScript failures
- User-friendly error messages

**Acceptance:** No crashes on permission/access errors.

#### 5.7 Accessibility Audit
**Tasks:**
- VoiceOver compatibility
- Keyboard navigation
- Dynamic type support
- High contrast support

**Acceptance:** App usable with VoiceOver.

### Slice 5 Definition of Done
- [ ] Memory pressure notifications
- [ ] All settings working
- [ ] Auto-cleanup optional feature
- [ ] Performance acceptable
- [ ] Error handling complete
- [ ] Accessibility audit passed

---

## Development Queue (Prioritized)

Calculated using: `Priority = (Market Value × 0.4) + (Technical Feasibility × 0.3) + (Time-to-Market × 0.2) + (Strategic Importance × 0.1)`

| Rank | Task | Priority Score | Slice |
|------|------|----------------|-------|
| 1 | Implement AuditLogService | 9.2 | 1 |
| 2 | Implement PermissionManager | 9.0 | 1 |
| 3 | Create Structured Error Types | 8.8 | 1 |
| 4 | Implement FileAccessManager | 8.7 | 1 |
| 5 | Refactor MetricsService to Native | 8.5 | 1 |
| 6 | Create Permissions Status UI | 8.3 | 1 |
| 7 | Implement ActionsService | 8.2 | 2 |
| 8 | Refactor ProcessManager for Sandbox | 8.0 | 2 |
| 9 | Refactor BrowserService | 7.8 | 3 |
| 10 | Browser Permission Request Flow | 7.6 | 3 |
| 11 | Implement CleanerService | 7.5 | 4 |
| 12 | Dry Run Preview UI | 7.3 | 4 |
| 13 | Update Process Manager UI | 7.2 | 2 |
| 14 | High Memory Consumer Feature | 7.0 | 2 |
| 15 | Tab Closing with Confirmation | 6.8 | 3 |
| 16 | Folder Selection UI | 6.7 | 4 |
| 17 | Cleanup Confirmation UI | 6.5 | 4 |
| 18 | Background Memory Monitoring | 6.3 | 5 |
| 19 | Notification Service | 6.0 | 5 |
| 20 | Settings Panel Completion | 5.8 | 5 |
| 21 | Auto-Cleanup Scheduling | 5.5 | 5 |
| 22 | Performance Profiling | 5.2 | 5 |
| 23 | Accessibility Audit | 5.0 | 5 |

---

## Testing Strategy

### Unit Tests

| Service | Test File | Coverage Target |
|---------|-----------|-----------------|
| AuditLogService | `AuditLogServiceTests.swift` | 90% |
| PermissionManager | `PermissionManagerTests.swift` | 80% |
| FileAccessManager | `FileAccessManagerTests.swift` | 85% |
| MetricsService | `MetricsServiceTests.swift` (exists) | 80% |
| ActionsService | `ActionsServiceTests.swift` | 85% |
| BrowserService | `BrowserServiceTests.swift` (exists) | 80% |
| CleanerService | `CleanerServiceTests.swift` | 90% |

### Integration Tests

| Test | Description |
|------|-------------|
| Permission Flow | Grant/deny automation, verify state |
| Bookmark Flow | Authorize folder, persist, restore |
| Cleanup Flow | Dry run → confirm → execute |
| Browser Flow | Enumerate tabs → close → verify |

### Mocks

| Mock | Purpose |
|------|---------|
| MockLogStore | Test audit logging without SQLite |
| MockFileManager | Test file operations without disk |
| MockAppleScript | Test browser automation without apps |
| MockNSRunningApplication | Test process management |

### CI Script

```bash
#!/bin/bash
# ci-test.sh

set -e

echo "Building Craig-O-Clean..."
xcodebuild -scheme "Craig-O-Clean" -destination "platform=macOS" build

echo "Running unit tests..."
xcodebuild -scheme "Craig-O-Clean" -destination "platform=macOS" test

echo "Running UI tests..."
xcodebuild -scheme "Craig-O-CleanUITests" -destination "platform=macOS" test

echo "All tests passed!"
```

---

## File Changes Summary

### New Files

| Path | Purpose |
|------|---------|
| `Core/Errors/CraigOCleanError.swift` | Structured error types |
| `Core/Types/ActionResult.swift` | Result envelope |
| `Core/Services/AuditLogService.swift` | Audit logging (refactored) |
| `Core/Services/AuditEntry.swift` | Audit entry model |
| `Core/Services/ActionsService.swift` | Safe action execution |
| `Core/Services/CleanerService.swift` | Sandbox cleaning |
| `Core/Services/NotificationService.swift` | User notifications |
| `Core/Permissions/PermissionManager.swift` | Central permission management |
| `Core/Permissions/FileAccessManager.swift` | Security-scoped bookmarks |
| `Core/Data/CleanupPresets.swift` | Cleanup target presets |
| `UI/Permissions/PermissionStatusView.swift` | Permission status UI |
| `UI/Permissions/PermissionRowView.swift` | Permission row component |
| `UI/Permissions/PermissionGuideView.swift` | Enable guide |
| `UI/Browser/BrowserPermissionSheet.swift` | Browser permission UI |
| `UI/Cleanup/FolderSelectionView.swift` | Folder picker UI |
| `UI/Cleanup/DryRunPreviewView.swift` | Cleanup preview |
| `UI/Cleanup/CleanupConfirmationView.swift` | Cleanup confirm |
| `UI/Cleanup/CleanupResultsView.swift` | Cleanup results |
| `UI/Memory/HighMemoryAppsView.swift` | High memory apps |
| `Tests/Services/AuditLogServiceTests.swift` | Tests |
| `Tests/Services/ActionsServiceTests.swift` | Tests |
| `Tests/Services/CleanerServiceTests.swift` | Tests |
| `Tests/Services/FileAccessManagerTests.swift` | Tests |

### Modified Files

| Path | Changes |
|------|---------|
| `Core/SystemMetricsService.swift` | Rename to MetricsService, verify pure native |
| `Core/BrowserAutomationService.swift` | Integrate PermissionManager, audit logging |
| `ProcessManager.swift` | Remove shell commands, use ActionsService |
| `UI/ProcessManagerView.swift` | Use new services |
| `UI/BrowserTabsView.swift` | Permission-aware UI |
| `UI/SettingsView.swift` | Add permissions section |
| `Craig_O_CleanApp.swift` | Add service injection |

### Removed/Deprecated (MAS Build)

| Path | Reason |
|------|--------|
| `Core/Execution/ElevatedExecutor.swift` | No admin in MAS |
| `Core/PrivilegeService.swift` | XPC helper not in MAS |
| `CraigOCleanHelper/*` | Not bundled in MAS |
| `Core/Capabilities/Resources/catalog.json` | Reduce to MAS-safe capabilities |

---

## Timeline Estimate

| Slice | Estimated Effort | Dependencies |
|-------|-----------------|--------------|
| Slice 1: Foundation | 3-4 days | None |
| Slice 2: Safe Actions | 2-3 days | Slice 1 |
| Slice 3: Browser Control | 2-3 days | Slice 1 |
| Slice 4: Sandbox Cleaning | 3-4 days | Slice 1 |
| Slice 5: Polish | 2-3 days | Slices 1-4 |

**Total Estimate:** 12-17 days

---

## Next Steps

1. Begin Slice 1 implementation
2. Create test infrastructure
3. Set up CI pipeline
