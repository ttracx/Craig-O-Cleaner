# Permission Center - Slice C

## Overview

The Permission Center is the security and permission layer for Craig-O-Clean. It gates all command execution based on macOS permissions and validates that required permissions are granted before allowing operations to proceed.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      PermissionCenter                        │
│  Central manager for all permission checks and remediation  │
└────────────────┬────────────────────────────────────────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
    ▼            ▼            ▼
┌─────────┐  ┌─────────┐  ┌─────────┐
│Automation│  │Full Disk│  │ Helper  │
│ Checker  │  │ Access  │  │Install  │
└─────────┘  └─────────┘  └─────────┘
                 │
                 ▼
         ┌──────────────┐
         │   Preflight  │
         │    Engine    │
         └──────────────┘
                 │
                 ▼
         ┌──────────────┐
         │UserExecutor  │
         │(Slice B)     │
         └──────────────┘
```

## Components

### 1. PermissionCenter (@Observable)

**File:** `Core/Permissions/PermissionCenter.swift`

Central singleton that manages all permission state:

- Tracks automation permission for each browser (Safari, Chrome, Edge, Brave, Firefox, Arc)
- Monitors full disk access status
- Checks privileged helper installation
- Provides async permission checking
- Observable for SwiftUI integration

**Key Methods:**
```swift
// Check specific browser automation
await permissionCenter.checkAutomationPermission(for: .safari)

// Request permission (triggers macOS dialog)
await permissionCenter.requestAutomationPermission(for: .chrome)

// Check full disk access
await permissionCenter.checkFullDiskAccess()

// Refresh all permissions
await permissionCenter.refreshAll()

// Get remediation steps
let steps = permissionCenter.remediationSteps(for: .automation(.safari))

// Open System Settings
permissionCenter.openSystemSettings(for: .fullDiskAccess)
```

### 2. AutomationChecker

**File:** `Core/Permissions/AutomationChecker.swift`

Specialized checker for browser automation permissions using AppleScript:

- Tests automation permission by sending no-op AppleScript
- Handles error -1743 (permission denied)
- Detects browser installation status
- Launches browsers to trigger permission dialogs
- Generates System Settings deep links

**Error Codes:**
- `-1743`: Permission explicitly denied
- `-1728`: App not running (permission unknown)
- `-1700`: App not open yet (permission unknown)

### 3. PreflightEngine

**File:** `Core/Permissions/PreflightEngine.swift`

Validates capability preconditions before execution:

**Check Types:**
- `pathExists`: Verify file/directory exists
- `pathWritable`: Check write permissions
- `appRunning`: Ensure app is running
- `appNotRunning`: Ensure app is not running
- `diskSpaceAvailable`: Parse size requirements (e.g., "1GB", "500MB")
- `sipStatus`: Check System Integrity Protection
- `automationPermission`: Validate browser automation

**Usage:**
```swift
let engine = PreflightEngine()
let result = await engine.validate(capability)

if result.canExecute {
    // Proceed with execution
} else {
    // Show user result.summary
    for failed in result.failedChecks {
        print(failed.reason)
    }
    for missing in result.missingPermissions {
        print(missing.displayName)
    }
}
```

### 4. PermissionStatusView

**File:** `Features/Permissions/PermissionStatusView.swift`

SwiftUI view showing all permission statuses:

- Lists all 6 supported browsers
- Shows automation permission state for each
- Displays full disk access status
- Shows helper installation status
- Provides "Fix" buttons for denied permissions
- "Request" buttons for undetermined permissions
- Auto-refreshes when app becomes active

**States:**
- ✅ **Granted**: Permission approved
- ❌ **Denied**: Permission explicitly denied
- ❓ **Not Determined**: macOS hasn't asked yet
- ⚪ **Unknown**: Unable to determine

### 5. RemediationSheet

**File:** `Features/Permissions/RemediationSheet.swift`

Modal sheet with step-by-step instructions:

- Numbered step-by-step instructions
- System Settings path breadcrumbs
- "Open System Settings" button
- Permission-specific guidance
- Context about why permission is needed

## Integration with UserExecutor

The PreflightEngine is integrated into UserExecutor (Slice B):

```swift
func execute(_ capability: Capability, arguments: [String: String]) async throws -> ExecutionResultWithOutput {
    // Run preflight validation
    let preflightResult = await preflightEngine.validate(capability)

    guard preflightResult.canExecute else {
        throw UserExecutorError.preflightValidationFailed(preflightResult)
    }

    // Continue with execution...
}
```

## Supported Browsers

| Browser | Bundle ID | Automation Support |
|---------|-----------|-------------------|
| Safari | com.apple.Safari | ✅ Full |
| Chrome | com.google.Chrome | ✅ Full |
| Edge | com.microsoft.edgemac | ✅ Full |
| Brave | com.brave.Browser | ✅ Full |
| Firefox | org.mozilla.firefox | ⚠️ Limited |
| Arc | company.thebrowser.Browser | ✅ Full |

**Note:** Firefox has limited AppleScript support compared to other browsers.

## Permission Types

### Automation Permission
Required to control browsers via AppleScript for operations like:
- Closing tabs
- Clearing browser history
- Managing downloads
- Reading tab information

**System Settings Path:** Privacy & Security > Automation

### Full Disk Access
Required to access protected files like:
- `~/Library/Safari/History.db`
- `~/Library/Safari/CloudTabs.db`
- `~/Library/Application Support/Google/Chrome/Default/History`

**System Settings Path:** Privacy & Security > Full Disk Access

### Privileged Helper
Required for elevated operations that need administrator privileges:
- System cache cleanup
- Protected file deletion
- Service management

**Installation:** Requires user to authenticate with admin password

## Testing

Comprehensive test suite in `Tests/PermissionTests/PermissionSystemTests.swift`:

- PermissionCenter refresh tests
- AutomationChecker detection tests
- PreflightEngine validation tests (all check types)
- PreflightResult summary tests
- BrowserApp property tests
- PermissionType display tests
- RemediationStep generation tests
- UserExecutor integration tests
- Performance benchmarks

**Run Tests:**
```bash
xcodebuild test -scheme CraigOTerminator -destination 'platform=macOS'
```

## Security Considerations

### Never Disable SIP
The system can check SIP status but will never recommend disabling it. SIP (System Integrity Protection) is a critical macOS security feature.

### Client Secrets
No client secrets or API keys are stored client-side. All sensitive operations go through the privileged helper with proper authentication.

### Permission Prompts
Users must explicitly grant permissions through macOS System Settings. We cannot bypass or circumvent the permission system.

### Audit Trail
All permission checks and execution attempts are logged for security auditing.

## Common Error Scenarios

### Error: -1743 (Permission Denied)
**Cause:** User explicitly denied automation permission or never granted it.
**Solution:** Show RemediationSheet with steps to enable in System Settings.

### Error: Browser Not Running
**Cause:** Cannot test permission when browser is not running.
**Solution:** Launch browser first, then retry permission check.

### Error: Browser Not Installed
**Cause:** User doesn't have the browser installed.
**Solution:** Show "Not installed" badge, disable permission check.

### Error: Helper Not Installed
**Cause:** Privileged helper binary not installed at `/Library/PrivilegedHelperTools/`.
**Solution:** Show helper installation dialog with authentication prompt.

## Future Enhancements

1. **Permission Request Scheduling**: Intelligently time permission requests to avoid overwhelming users
2. **Batch Permission Requests**: Request multiple permissions in one flow
3. **Permission Analytics**: Track which permissions users grant/deny
4. **Graceful Degradation**: Offer reduced functionality when permissions denied
5. **Permission Caching**: Cache permission state with expiration
6. **Helper Auto-Update**: Automatically update privileged helper when needed

## References

- [Apple Documentation: Authorization Services](https://developer.apple.com/documentation/security/authorization_services)
- [TN3127: Inside Code Signing: Provisioning](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-provisioning)
- [System Settings URL Schemes](https://developer.apple.com/documentation/xcode/running-your-app-in-the-simulator-or-on-a-device)
- [AppleScript Error Codes](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_error_codes.html)

## Changelog

### v1.0.0 (2026-01-27)
- Initial implementation of Slice C
- PermissionCenter with 6 browser support
- AutomationChecker with AppleScript testing
- PreflightEngine with 7 check types
- PermissionStatusView with live updates
- RemediationSheet with step-by-step guidance
- Integration with UserExecutor
- Comprehensive test suite
