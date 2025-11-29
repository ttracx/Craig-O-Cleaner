# ClearMind Control Center - Security Notes

This document describes the security model, permission requirements, and privacy practices of ClearMind Control Center.

## Overview

ClearMind Control Center is designed with security and privacy as core principles:

- **No data collection**: All monitoring happens locally on your Mac
- **No network requests**: The app doesn't send any data externally
- **Minimal permissions**: Only requests permissions necessary for features
- **Transparent operation**: Open source code for review

## Permission Model

### Required Permissions

#### 1. Automation Permission

**What it does**: Allows the app to control other applications via AppleScript.

**Why it's needed**: To manage browser tabs, the app must send commands to Safari, Chrome, Edge, and Brave.

**How it works**:
```applescript
tell application "Safari"
    get name of current tab of front window
end tell
```

**What it CAN do**:
- Get list of open tabs
- Close tabs
- Get tab URLs and titles

**What it CANNOT do**:
- Read page content
- Access passwords
- Modify bookmarks
- Access browsing history

**How to grant**:
1. Open System Settings → Privacy & Security → Automation
2. Find ClearMind Control Center
3. Enable toggles for desired browsers

### Optional Permissions

#### 2. Accessibility Permission

**What it does**: Allows enhanced system interaction.

**Why it's needed**: Some advanced features may require accessibility access.

**Current usage**: Not actively used in current version.

**How to grant**:
1. Open System Settings → Privacy & Security → Accessibility
2. Click the lock to make changes
3. Add ClearMind Control Center
4. Enable the toggle

#### 3. Administrator Privileges

**What it does**: Allows running commands that require elevated access.

**Why it's needed**: The "purge" command requires admin privileges.

**How it works**: Uses AppleScript with administrator privileges:
```applescript
do shell script "purge" with administrator privileges
```

**When requested**: Only when you explicitly click "Purge Memory"

**What it does**:
- Runs the macOS `purge` command
- Clears inactive memory cache
- Requires your password each time

## Security Architecture

### Sandboxing

ClearMind Control Center runs **without** the macOS App Sandbox for the following reasons:

1. **Process monitoring**: Reading process information requires access to system APIs
2. **AppleScript execution**: Automation requires inter-process communication
3. **System metrics**: Accessing CPU, memory, and disk stats requires system calls

**Mitigations in place**:
- Hardened Runtime is enabled
- Code is signed
- No unnecessary entitlements

### Hardened Runtime

The app uses macOS Hardened Runtime with these settings:

```xml
<!-- Enabled -->
<key>com.apple.security.automation.apple-events</key>
<true/>

<!-- Disabled (secure defaults) -->
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<false/>
<key>com.apple.security.cs.disable-library-validation</key>
<false/>
```

### Code Signing

The app is code-signed with:
- Apple Developer certificate (for distribution)
- Or ad-hoc signing (for local builds)

This ensures:
- Code hasn't been tampered with
- Gatekeeper will allow it to run
- Other apps can verify its identity

## Data Handling

### What the app accesses

| Data Type | Purpose | Storage |
|-----------|---------|---------|
| Process list | Display in UI | Memory only |
| CPU/Memory metrics | Dashboard display | Memory only |
| Browser tabs | Tab management | Memory only |
| Settings | User preferences | UserDefaults |

### What the app does NOT access

- ❌ Network activity (no outbound connections)
- ❌ File contents
- ❌ User documents
- ❌ Keychain/passwords
- ❌ Browsing history
- ❌ Email
- ❌ Messages
- ❌ Contacts

### Data storage

All data is stored locally using:
- `UserDefaults` for settings
- Memory for metrics and process data
- No files created outside app container

## Process Termination Safety

### Protected Processes

The app prevents termination of critical system processes:

```swift
private let protectedApps = [
    "com.apple.finder",
    "com.apple.dock",
    "com.apple.loginwindow",
    "com.apple.WindowServer",
    "com.apple.systemuiserver"
]
```

### Termination Methods

1. **Graceful termination** (`NSRunningApplication.terminate()`)
   - Sends quit request to app
   - App can save data before quitting
   - Used first

2. **Force termination** (`NSRunningApplication.forceTerminate()`)
   - Immediately stops process
   - Data may be lost
   - Used only when requested

### Confirmation Dialogs

Before terminating any process:
- User must confirm action
- Warning shown for system processes
- Clear indication of consequences

## AppleScript Security

### Script Execution

AppleScript is executed using `NSAppleScript`:

```swift
var error: NSDictionary?
let appleScript = NSAppleScript(source: script)
let result = appleScript?.executeAndReturnError(&error)
```

### Script Sources

All AppleScript is:
- Hard-coded in the app
- Not user-modifiable
- Minimal scope

### Script Permissions

Scripts can only:
- Query browser state (tabs, windows)
- Close tabs/windows
- Cannot access page content

## Network Security

### No Network Access

The app:
- Makes no HTTP requests
- Has no analytics
- Has no update mechanism
- Has no telemetry

### Network Monitoring Feature

The network metrics feature:
- Only reads local network interface statistics
- Uses `getifaddrs()` system call
- Cannot see packet contents
- Cannot see remote addresses

## Privacy Policy

### Data Collection

ClearMind Control Center does **not** collect:
- Personal information
- Usage statistics
- Error reports
- Device identifiers
- Location data

### Third-Party Services

The app uses **no** third-party services:
- No analytics (Google Analytics, Mixpanel, etc.)
- No crash reporting (Crashlytics, Sentry, etc.)
- No advertising
- No cloud storage

### Data Sharing

Your data is **never**:
- Sent to servers
- Shared with third parties
- Used for advertising
- Analyzed remotely

## Security Best Practices

### For Users

1. **Download from trusted sources**
   - GitHub releases
   - Mac App Store (when available)

2. **Verify code signature**
   ```bash
   codesign -dv --verbose=4 /Applications/ClearMind\ Control\ Center.app
   ```

3. **Review permissions**
   - Grant only necessary permissions
   - Revoke if no longer needed

4. **Keep updated**
   - Security fixes in updates
   - Check releases page

### For Developers

1. **Code review**
   - All changes reviewed
   - Security-sensitive code highlighted

2. **Dependency management**
   - No external dependencies
   - All code is first-party

3. **Testing**
   - Unit tests for security logic
   - Manual security review

## Reporting Security Issues

If you discover a security vulnerability:

1. **Do not** create a public issue
2. Email: security@example.com
3. Include:
   - Description of vulnerability
   - Steps to reproduce
   - Potential impact

We will:
- Acknowledge within 48 hours
- Investigate and fix
- Credit you (if desired)

## Compliance

### macOS Security Requirements

- ✅ Hardened Runtime
- ✅ Code Signing
- ✅ Notarization-ready
- ✅ Privacy-respecting

### Apple Guidelines

The app follows Apple's security guidelines for:
- User data protection
- Permission requests
- Process interaction
- System API usage

## Changelog

### Security Updates

| Version | Date | Changes |
|---------|------|---------|
| 2.0 | 2025 | Initial security documentation |

---

## Contact

For security questions or concerns:
- GitHub Issues (non-sensitive)
- Email: security@example.com (sensitive)

---

**Remember**: Security is everyone's responsibility. If something seems suspicious, investigate and report it.
