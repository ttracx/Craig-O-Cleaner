# Permission Center - Quick Start Guide

## For Developers

### 1. Check Permission Status

```swift
import SwiftUI

struct MyView: View {
    @Environment(PermissionCenter.self) private var permissions

    var body: some View {
        VStack {
            // Check Safari automation permission
            if permissions.automationPermissions[.safari] == .granted {
                Text("Safari automation enabled")
            } else {
                Button("Enable Safari Automation") {
                    Task {
                        await permissions.requestAutomationPermission(for: .safari)
                    }
                }
            }

            // Check full disk access
            if permissions.fullDiskAccess == .granted {
                Text("Full disk access enabled")
            } else {
                Button("Open System Settings") {
                    permissions.openSystemSettings(for: .fullDiskAccess)
                }
            }
        }
        .task {
            // Refresh permissions when view appears
            await permissions.refreshAll()
        }
    }
}
```

### 2. Add Preflight Checks to Capability

```swift
// In your catalog.json
{
  "id": "safari-clear-history",
  "title": "Clear Safari History",
  "privilegeLevel": "automation",
  "preflightChecks": [
    {
      "type": "automationPermission",
      "target": "Safari",
      "failureMessage": "Safari automation permission required"
    },
    {
      "type": "appRunning",
      "target": "Safari",
      "failureMessage": "Safari must be running"
    }
  ]
}
```

### 3. Execute with Automatic Permission Checking

```swift
let executor = UserExecutor()

do {
    let result = try await executor.execute(capability, arguments: [:])
    print("Success: \(result.stdout)")
} catch let error as UserExecutorError {
    if case .preflightValidationFailed(let result) = error {
        // Show user what's missing
        print(result.summary)

        for permission in result.missingPermissions {
            // Show remediation UI
            showRemediationSheet(for: permission)
        }
    }
}
```

### 4. Show Permission Status View

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            PermissionStatusView()
                .tabItem {
                    Label("Permissions", systemImage: "shield.checkered")
                }
        }
        .environment(PermissionCenter.shared)
    }
}
```

### 5. Manual Permission Checks

```swift
// Check specific browser
let state = await AutomationChecker.checkPermission(for: .chrome)

switch state {
case .granted:
    print("Chrome automation enabled")
case .denied:
    print("Chrome automation denied - show remediation")
case .notDetermined:
    print("Chrome automation not determined - request it")
case .unknown:
    print("Cannot determine Chrome automation state")
}

// Check full disk access
let hasAccess = await PermissionCenter.shared.checkFullDiskAccess()
if hasAccess == .granted {
    // Can access protected files
}

// Check helper installed
let helperInstalled = await PermissionCenter.shared.checkHelperInstalled()
if !helperInstalled {
    // Show helper installation dialog
}
```

## Common Patterns

### Pattern 1: Validate Before Execute

```swift
func cleanupBrowser(_ browser: BrowserApp) async throws {
    let permissions = PermissionCenter.shared

    // Check permission first
    let state = permissions.automationPermissions[browser]

    guard state == .granted else {
        throw CleanupError.permissionDenied(browser)
    }

    // Execute cleanup...
}
```

### Pattern 2: Request Permission on Demand

```swift
func ensurePermission(for browser: BrowserApp) async throws {
    let permissions = PermissionCenter.shared
    let state = permissions.automationPermissions[browser]

    if state != .granted {
        // Request permission
        let newState = await permissions.requestAutomationPermission(for: browser)

        guard newState == .granted else {
            throw PermissionError.userDenied
        }
    }
}
```

### Pattern 3: Graceful Degradation

```swift
func cleanup() async {
    let permissions = PermissionCenter.shared

    // Try cleanup with full disk access
    if permissions.fullDiskAccess == .granted {
        await deepCleanup()
    } else {
        // Fall back to basic cleanup
        await basicCleanup()
    }
}
```

### Pattern 4: Batch Permission Check

```swift
func checkAllBrowserPermissions() async -> [BrowserApp: PermissionState] {
    await PermissionCenter.shared.refreshAll()
    return PermissionCenter.shared.automationPermissions
}
```

### Pattern 5: Permission Change Notification

```swift
@Observable
class MyViewModel {
    @ObservationIgnored
    private var permissionObserver: Task<Void, Never>?

    init() {
        // Watch for permission changes
        permissionObserver = Task {
            while !Task.isCancelled {
                await PermissionCenter.shared.refreshAll()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    deinit {
        permissionObserver?.cancel()
    }
}
```

## Error Handling

### Handle Preflight Failures

```swift
do {
    let result = try await executor.execute(capability)
} catch let error as UserExecutorError {
    switch error {
    case .preflightValidationFailed(let result):
        // Permission or check failed
        handlePreflightFailure(result)

    case .notUserLevel(let message):
        // Wrong privilege level
        print("Requires elevated privileges: \(message)")

    case .executionFailed(let message):
        // Execution error
        print("Execution failed: \(message)")

    default:
        print("Other error: \(error.localizedDescription)")
    }
}

func handlePreflightFailure(_ result: PreflightResult) {
    // Show failed checks
    for failed in result.failedChecks {
        print("Check failed: \(failed.check.type) - \(failed.reason)")
    }

    // Show missing permissions
    for permission in result.missingPermissions {
        showRemediationSheet(for: permission)
    }
}
```

### Handle AppleScript Errors

```swift
// Error codes from AutomationChecker
// -1743: Permission denied
// -1728: App not running
// -1700: App not open yet

do {
    try await executeAppleScript(script)
} catch let error as NSError {
    switch error.code {
    case -1743:
        print("Permission denied - show remediation")
    case -1728, -1700:
        print("Browser not running - launch it first")
    default:
        print("AppleScript error: \(error.localizedDescription)")
    }
}
```

## UI Integration

### SwiftUI View with Permission Checks

```swift
struct BrowserCleanupView: View {
    @Environment(PermissionCenter.self) private var permissions
    @State private var showingRemediation: PermissionType?

    var body: some View {
        VStack {
            ForEach(BrowserApp.allCases, id: \.self) { browser in
                browserRow(browser)
            }
        }
        .sheet(item: $showingRemediation) { permission in
            RemediationSheet(permission: permission)
        }
    }

    func browserRow(_ browser: BrowserApp) -> some View {
        HStack {
            Text(browser.rawValue)
            Spacer()
            permissionBadge(for: browser)
            cleanupButton(for: browser)
        }
    }

    @ViewBuilder
    func permissionBadge(for browser: BrowserApp) -> some View {
        let state = permissions.automationPermissions[browser] ?? .unknown
        Image(systemName: state == .granted ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(state == .granted ? .green : .red)
    }

    func cleanupButton(for browser: BrowserApp) -> some View {
        Button("Clean") {
            Task {
                await cleanup(browser)
            }
        }
        .disabled(permissions.automationPermissions[browser] != .granted)
    }

    func cleanup(_ browser: BrowserApp) async {
        guard permissions.automationPermissions[browser] == .granted else {
            showingRemediation = .automation(browser)
            return
        }

        // Perform cleanup...
    }
}
```

## Testing

### Unit Test Example

```swift
import XCTest
@testable import CraigOTerminator

class MyPermissionTests: XCTestCase {
    func testPreflightEngine() async throws {
        let engine = PreflightEngine()

        let capability = Capability(
            id: "test",
            title: "Test",
            description: "Test capability",
            group: .diagnostics,
            commandTemplate: "/bin/echo test",
            arguments: [],
            workingDirectory: nil,
            timeout: 10,
            privilegeLevel: .user,
            riskClass: .safe,
            outputParser: .text,
            parserPattern: nil,
            preflightChecks: [
                PreflightCheck(
                    type: .pathExists,
                    target: NSHomeDirectory(),
                    failureMessage: "Home not found"
                )
            ],
            requiredPaths: [],
            requiredApps: [],
            icon: "checkmark",
            rollbackNotes: nil,
            estimatedDuration: nil
        )

        let result = await engine.validate(capability)
        XCTAssertTrue(result.canExecute)
    }
}
```

## Debugging

### Enable Verbose Logging

```swift
// View permission state
let permissions = PermissionCenter.shared
await permissions.refreshAll()

print("Safari: \(permissions.automationPermissions[.safari]?.rawValue ?? "unknown")")
print("Chrome: \(permissions.automationPermissions[.chrome]?.rawValue ?? "unknown")")
print("Full Disk Access: \(permissions.fullDiskAccess.rawValue)")
print("Helper Installed: \(permissions.helperInstalled)")
print("Last Check: \(permissions.lastCheckDate?.description ?? "never")")
```

### Test Permission Check

```swift
// Test specific browser
let state = await AutomationChecker.checkPermission(for: .safari)
print("Safari automation: \(state.rawValue)")

// Test full disk access
let fdaState = await PermissionCenter.shared.checkFullDiskAccess()
print("Full disk access: \(fdaState.rawValue)")
```

### View Preflight Results

```swift
let engine = PreflightEngine()
let result = await engine.validate(capability)

print("Can execute: \(result.canExecute)")
print("Failed checks: \(result.failedChecks.count)")
print("Missing permissions: \(result.missingPermissions.count)")
print("\nSummary:\n\(result.summary)")
```

## Best Practices

1. **Check Permissions Early**: Check permissions before showing UI for features that require them
2. **Handle Denials Gracefully**: Always provide remediation UI when permissions denied
3. **Refresh Periodically**: Refresh permission state when app becomes active
4. **Don't Spam Requests**: Respect user decisions, don't repeatedly ask for denied permissions
5. **Clear Communication**: Explain why each permission is needed
6. **Test All Paths**: Test with granted, denied, and not determined states
7. **Graceful Degradation**: Offer reduced functionality when permissions unavailable
8. **User Control**: Always show current permission status in settings

## Troubleshooting

**Problem:** Permission check always returns `.unknown`
- **Solution:** Ensure app has proper entitlements in Xcode project
- Check for AppleScript sandbox restrictions

**Problem:** Browser automation always denied
- **Solution:** User must manually grant in System Settings > Privacy & Security > Automation
- Cannot be programmatically enabled (macOS security requirement)

**Problem:** Full disk access not working
- **Solution:** App must be added to System Settings > Privacy & Security > Full Disk Access
- App must be restarted after granting permission

**Problem:** Helper tool won't install
- **Solution:** Requires admin password
- Check helper binary signature
- Verify SMJobBless entitlements

## Resources

- [Main Documentation](README.md)
- [Implementation Guide](../../../SLICE_C_IMPLEMENTATION.md)
- [Test Examples](../../../Tests/PermissionTests/)
- [Apple: Authorization Services](https://developer.apple.com/documentation/security/authorization_services)
