# Craig-O-Clean Sandbox Edition

A **fully sandboxed** macOS system utility designed for Mac App Store distribution. This version implements Apple's App Sandbox requirements while maintaining powerful system optimization features.

## Architecture Overview

```
Craig-O-Clean-Sandbox/
├── Configuration/
│   └── SandboxConfiguration.swift      # App config, feature flags, capability matrix
├── Core/
│   ├── Permissions/
│   │   └── SandboxPermissionsManager.swift  # TCC permission handling
│   ├── Metrics/
│   │   └── SandboxMetricsProvider.swift     # Native API system metrics
│   ├── Bookmarks/
│   │   └── SecurityScopedBookmarkManager.swift  # User-selected file access
│   ├── Process/
│   │   └── SandboxProcessManager.swift      # Process monitoring & termination
│   ├── Browser/
│   │   └── SandboxBrowserAutomation.swift   # AppleScript browser control
│   └── Cleanup/
│       └── SandboxCleaner.swift             # User-scoped file cleanup
├── UI/
│   └── Views/
│       ├── SandboxMainAppView.swift         # Main navigation
│       ├── SandboxDashboardView.swift       # System overview
│       ├── SandboxProcessListView.swift     # Process management
│       ├── SandboxBrowserTabsView.swift     # Browser tab management
│       ├── SandboxCleanupView.swift         # File cleanup
│       └── PermissionSetupView.swift        # Permission onboarding
├── Craig_O_Clean_SandboxApp.swift           # App entry point
└── Craig-O-Clean-Sandbox.entitlements       # Sandbox entitlements
```

## Sandbox Compliance

### What Works in Sandbox

| Feature | Implementation | API Used |
|---------|---------------|----------|
| Process Monitoring | ✅ Full | BSD proc APIs, NSRunningApplication |
| CPU Metrics | ✅ Full | Mach host_processor_info |
| Memory Metrics | ✅ Full | Mach host_statistics64 |
| Memory Pressure | ✅ Full | DispatchSource.makeMemoryPressureSource |
| Disk Metrics | ✅ Full | FileManager attributesOfFileSystem |
| Network Stats | ✅ Full | BSD getifaddrs |
| App Termination | ✅ Full | NSRunningApplication.terminate/forceTerminate |
| Browser Tabs | ✅ Permission-gated | NSAppleScript (Automation) |
| File Cleanup | ✅ User-scoped | Security-scoped bookmarks |

### What's NOT Available in Sandbox

| Feature | Reason | Alternative |
|---------|--------|-------------|
| Memory Purge | Requires admin privileges | Guidance to close apps |
| Global Cache Cleanup | Requires Full Disk Access | User-selected folders only |
| System-wide File Access | Sandbox restriction | Security-scoped bookmarks |
| Privileged Helper | Not MAS-compatible | AppleScript with admin (for non-MAS) |

## Entitlements Required

```xml
<!-- Core Sandbox -->
com.apple.security.app-sandbox = true

<!-- File Access -->
com.apple.security.files.user-selected.read-write = true
com.apple.security.files.bookmarks.app-scope = true

<!-- Network (for subscriptions/updates) -->
com.apple.security.network.client = true

<!-- Browser Automation -->
com.apple.security.automation.apple-events = true
com.apple.security.scripting-targets = {
    com.apple.Safari,
    com.google.Chrome,
    com.microsoft.edgemac,
    com.brave.Browser,
    company.thebrowser.Browser,
    com.apple.systemevents
}
```

## Permission Flow

### 1. Accessibility (Optional)
- **Purpose**: Enhanced window management
- **How**: User enables in System Settings > Privacy & Security > Accessibility
- **Trigger**: `AXIsProcessTrustedWithOptions`

### 2. Automation (Per-Browser)
- **Purpose**: Browser tab management
- **How**: User grants when prompted by macOS
- **Trigger**: First AppleScript execution to that app

### 3. File Access (User-Selected)
- **Purpose**: Cache cleanup in specific folders
- **How**: NSOpenPanel + security-scoped bookmarks
- **Persists**: Across app launches via saved bookmarks

## Key Design Patterns

### "Observer + User-Mediated Actions"

The sandbox isn't "no power" — it's "no **silent** power." This app follows the pattern:

1. **Read** only what the sandbox allows
2. **Ask** the user when touching their data (open panel, bookmarks)
3. **Use** Apple-approved surfaces for app control (Automation, Accessibility)
4. **Avoid** "kill/clean everything" features requiring root

### Permission-Gated Features

```swift
// Example: Browser tab access is gated
func fetchTabs(for browser: Browser) async throws -> [Tab] {
    guard permissionsManager.automationStatus[browser] == .authorized else {
        throw BrowserAutomationError.permissionDenied(browser)
    }
    // ... proceed with AppleScript
}
```

### Security-Scoped Bookmarks

```swift
// User must explicitly select folders
let bookmark = await bookmarkManager.selectAndSaveFolder()

// Access is scoped and must be started/stopped
try await bookmarkManager.withAccess(to: bookmark) { url in
    // Perform file operations within granted scope
}
```

## Building for Mac App Store

1. **Xcode Configuration**
   - Set bundle identifier to `com.craigoclean.sandbox`
   - Enable "App Sandbox" capability
   - Add required entitlements from `.entitlements` file

2. **Code Signing**
   - Use Apple Developer certificate
   - Enable Hardened Runtime
   - Sign with `--options runtime`

3. **Review Guidelines**
   - No claims of "freeing RAM" without legitimate mechanism
   - Transparent about what permissions are needed and why
   - No hidden automation or file access
   - Clear user consent flow for all actions

## Testing Checklist

- [ ] App launches without any permissions granted
- [ ] Dashboard shows metrics (no permissions needed)
- [ ] Process list works (no permissions needed)
- [ ] Browser tabs show permission prompt correctly
- [ ] File cleanup requires folder selection
- [ ] Terminating apps works for user-owned processes
- [ ] Memory pressure notifications work
- [ ] App survives permission denial gracefully

## Differences from Non-Sandboxed Version

| Aspect | Non-Sandboxed | Sandboxed |
|--------|---------------|-----------|
| Memory Purge | `purge` command | Not available |
| Cache Cleanup | ~/Library/Caches/* | User-selected only |
| Process Kill | SIGKILL any | User-owned only |
| Shell Commands | Full access | Restricted |
| Helper Tool | SMJobBless | Not available |
| Distribution | Developer ID / Direct | Mac App Store |

## Future Enhancements

- [ ] System Extension for enhanced monitoring (if Apple allows)
- [ ] CloudKit sync for settings
- [ ] Shortcuts integration for automation
- [ ] Widgets for quick status
