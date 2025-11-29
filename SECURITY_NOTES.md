# ClearMind Control Center - Security Notes

This document describes the security architecture, permission requirements, and privacy considerations for ClearMind Control Center.

## Overview

ClearMind Control Center is designed with security and privacy as core principles:

- **No network connections** - All data stays on your Mac
- **No data collection** - No analytics, telemetry, or crash reporting
- **Minimal permissions** - Only requests what's necessary
- **Safe operations** - Protects system processes from termination
- **Hardened Runtime** - Ready for notarization and distribution

## Permissions Required

### 1. Automation Permission

**Purpose:** Control browsers (Safari, Chrome, Edge, Brave, Arc) to list and close tabs.

**Scope:** Specific to each browser application.

**How it works:**
- Uses AppleScript to communicate with browsers
- Each browser requires separate Automation permission
- User explicitly grants access via System Settings

**Security implications:**
- ClearMind can read tab titles and URLs when permission is granted
- ClearMind can close tabs in permitted browsers
- Cannot access browser history, passwords, or cookies
- Cannot access files or data beyond tab information

**To enable:**
1. Open System Settings → Privacy & Security → Automation
2. Find ClearMind Control Center
3. Enable each browser you want to manage

### 2. Accessibility Permission (Optional)

**Purpose:** Advanced system interactions (future features).

**Scope:** System-wide accessibility access.

**Current usage:** Not actively used, but may be requested for future window management features.

**Security implications:**
- When granted, could theoretically observe UI elements
- ClearMind does NOT use this to monitor user activity
- Only used for legitimate system control features

**To enable:**
1. Open System Settings → Privacy & Security → Accessibility
2. Enable ClearMind Control Center

## Process Management Security

### Protected Processes

ClearMind maintains a list of critical system processes that are protected from termination:

```swift
private let criticalProcessNames: Set<String> = [
    "kernel_task",      // macOS kernel
    "launchd",          // System init
    "WindowServer",     // Display server
    "loginwindow",      // Login UI
    "SystemUIServer",   // System UI
    "Dock",             // Dock
    "Finder",           // Finder
    "mds",              // Spotlight
    "mds_stores",       // Spotlight storage
    "coreauthd",        // Authentication
    "securityd",        // Security daemon
    "cfprefsd",         // Preferences daemon
    "UserEventAgent"    // User event handling
]
```

### Termination Safeguards

1. **Confirmation dialogs** - All terminations require user confirmation
2. **Critical process warnings** - Extra warning for system-related processes
3. **Graceful first** - Always attempts graceful termination before force quit
4. **Permission checking** - Respects macOS process permissions

### Termination Methods

| Method | Signal | Use Case |
|--------|--------|----------|
| `NSRunningApplication.terminate()` | SIGTERM | Graceful app termination |
| `NSRunningApplication.forceTerminate()` | SIGKILL | Force quit for apps |
| `kill(pid, SIGKILL)` | SIGKILL | Force quit for processes |

## Memory Cleanup Security

### Safe Cleanup

The Memory Optimizer service follows these security principles:

1. **User consent required** - All cleanups require explicit user selection
2. **Protected exclusions** - Critical processes and apps are never suggested
3. **Transparent selection** - User sees exactly what will be terminated
4. **Cancellable** - User can deselect any app before execution

### Purge Command

The optional `purge` command requires administrator privileges:

```swift
let script = """
do shell script "purge" with administrator privileges
"""
```

**Security measures:**
- Requires explicit user initiation
- Shows system password prompt
- Cannot be executed without user authentication
- Documented as "advanced feature" with warnings

## AppleScript Execution

### Sandboxed Scripts

AppleScript execution is sandboxed to specific operations:

**Allowed:**
- Query browser windows and tabs (with Automation permission)
- Close specific tabs (with Automation permission)
- Open System Settings to specific panes

**Not allowed:**
- Execute arbitrary shell commands (except purge with explicit admin)
- Access file system beyond app sandbox
- Modify system settings
- Access other apps without explicit permission

### Script Validation

All AppleScript is:
1. Statically defined in source code (no user input in scripts)
2. Limited to documented browser scripting APIs
3. Executed in a controlled context

## Data Privacy

### Data Collection: None

ClearMind Control Center does **NOT**:
- Collect any user data
- Send any data over the network
- Track usage patterns
- Log user activity
- Store browsing history
- Access passwords or credentials

### Data Retention: None

All data displayed is:
- Fetched in real-time from system APIs
- Displayed but not persisted
- Discarded when app closes

### Local Storage

The only data stored locally:
- User preferences (AppStorage/UserDefaults)
- No sensitive data is stored

## Network Security

### No Network Access

ClearMind Control Center:
- Makes zero network connections
- Has no network code
- Does not check for updates online
- Does not send crash reports

### Entitlements

The app entitlements do NOT include:
- `com.apple.security.network.client`
- `com.apple.security.network.server`

## Code Signing & Notarization

### Hardened Runtime

The app is built with:
- Hardened Runtime enabled
- Code signing required
- Notarization-ready build settings

### Entitlements

Minimal entitlements configuration:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

## Best Practices Followed

### Apple Security Guidelines

1. **Principle of least privilege** - Only requests necessary permissions
2. **Explicit user consent** - All sensitive operations require confirmation
3. **Transparent behavior** - Users can see exactly what the app will do
4. **No silent operations** - All actions are visible and reversible

### Secure Coding

1. **No force unwrapping** - Safe optional handling throughout
2. **Error handling** - All operations have proper error handling
3. **Input validation** - No user input in system commands
4. **Memory safety** - Swift's automatic memory management

## Threat Model

### In Scope

| Threat | Mitigation |
|--------|------------|
| Accidental process termination | Confirmation dialogs, protected list |
| Browser tab data exposure | Automation permission required |
| Unauthorized system access | macOS permission system |
| Malicious script injection | Static scripts, no user input |

### Out of Scope

| Threat | Reason |
|--------|--------|
| Network-based attacks | No network access |
| Data exfiltration | No data collection or transmission |
| Persistent malware | No system modifications |

## Incident Response

If you discover a security vulnerability:

1. **Do not** publicly disclose the issue
2. Contact the maintainers privately
3. Provide detailed reproduction steps
4. Allow reasonable time for a fix

## Compliance

### Privacy Regulations

ClearMind Control Center is compliant with:
- **GDPR** - No personal data processing
- **CCPA** - No personal information collection
- **Apple App Store Guidelines** - Follows all privacy requirements

### App Store Requirements

The app meets Apple's requirements for:
- Hardened Runtime
- App Sandbox (where applicable)
- Notarization
- Privacy Manifest (no tracking)

## Audit Trail

### Logging

The app uses `os.Logger` for debugging:
- Logs are stored in system Console
- No sensitive data is logged
- Logs do not persist between sessions

### User Transparency

All operations are visible:
- Process list shows all accessed processes
- Browser tabs view shows all accessed tabs
- Memory cleanup shows all affected apps
- Settings shows all permissions and their status

## Contact

For security-related inquiries:
- Open an issue marked `[SECURITY]`
- Contact maintainers directly
- Use responsible disclosure practices
