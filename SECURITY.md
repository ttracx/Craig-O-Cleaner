# Craig-O-Clean Security Model

**Version:** 1.0
**Last Updated:** 2026-01-28

---

## Overview

Craig-O-Clean follows a **least privilege** security model designed for Mac App Store (MAS) compliance. This document describes the command execution policy, data handling practices, permission model, and audit logging.

---

## Distribution Models

### Mac App Store (MAS) Build

The MAS build operates within Apple's App Sandbox with the following restrictions:
- No privileged helper tools
- No administrator privilege escalation
- File access only via user-selected folders (security-scoped bookmarks)
- Browser automation via Apple Events (requires user consent)
- No shell command execution for system operations

### Developer ID Build

The Developer ID build includes additional capabilities:
- Optional privileged helper for memory purge and DNS flush
- Extended process termination capabilities
- System maintenance scripts access

---

## Command Execution Policy

### Prohibited Operations

The following are **never** executed:

1. **Arbitrary shell commands** - No user input is ever interpolated into shell strings
2. **Admin escalation in MAS** - No `with administrator privileges` in App Store builds
3. **Private APIs** - Only public, documented macOS APIs
4. **System path modifications** - No writes to `/System`, `/Library`, or `/private`

### Allowed Operations (MAS)

| Operation | API Used | Permission Required |
|-----------|----------|---------------------|
| Quit application | `NSRunningApplication.terminate()` | None |
| Force quit application | `NSRunningApplication.forceTerminate()` | None |
| Terminate owned process | `kill(pid, SIGTERM/SIGKILL)` | None (same user) |
| Browser tab management | `NSAppleScript` | Automation TCC |
| System metrics | Mach/Darwin APIs | None |
| File cleanup | `FileManager` | Security-scoped bookmark |

### Allowed Operations (Developer ID Only)

| Operation | API Used | Permission Required |
|-----------|----------|---------------------|
| Memory purge | XPC to helper → `/usr/bin/purge` | Admin auth |
| File sync | XPC to helper → `/bin/sync` | Admin auth |
| DNS flush | XPC to helper | Admin auth |
| Force kill any process | XPC to helper → `kill -9` | Admin auth |

---

## Permission Model

### TCC (Transparency, Consent, Control)

Craig-O-Clean requests the following TCC permissions:

| Permission | Purpose | Required? |
|------------|---------|-----------|
| Automation (per browser) | Tab management | Optional |
| Accessibility | Advanced window management | Optional |
| Full Disk Access | Enhanced process monitoring | Optional |
| Notifications | Alerts and status updates | Optional |

### Permission Request Flow

1. **Pre-request explanation** - User sees why permission is needed
2. **System prompt** - macOS shows native permission dialog
3. **Result handling** - Feature enabled or graceful degradation
4. **Audit logging** - Permission request/result logged

### Graceful Degradation

When permissions are denied:
- Features requiring the permission are disabled
- UI shows clear "Enable" button with instructions
- Alternative actions are suggested where possible
- No repeated prompts (respects user choice)

---

## Data Handling

### Data Stored

| Data | Location | Purpose |
|------|----------|---------|
| User preferences | UserDefaults (sandbox) | Settings |
| Security-scoped bookmarks | UserDefaults (sandbox) | Folder access persistence |
| Audit log | SQLite in Application Support | Action history |
| Subscription status | Keychain | Entitlement verification |

### Data NOT Stored

- Browser history or content
- File contents from cleanup operations
- Process memory contents
- Network traffic contents
- Passwords or credentials (except subscription tokens)

### Data Encryption

- Keychain data: System-managed encryption
- SQLite audit log: Not encrypted (local-only, non-sensitive)
- UserDefaults: System-managed protection

---

## Audit Logging

### What's Logged

Every significant action is logged with:
- Timestamp
- Action type
- Target (app name, file path, etc.)
- Success/failure status
- Error message (if failed)
- Session ID

### Log Retention

- Logs stored in app's Application Support directory
- Default retention: 30 days
- User can export logs as JSON
- User can clear logs at any time

### Log Access

- Logs are local-only (no network transmission)
- User can view in Activity Log UI
- User can export for support/debugging

---

## File Cleanup Security

### Security-Scoped Bookmarks

File cleanup requires explicit user authorization:

1. User clicks "Authorize" for a cleanup preset
2. System shows folder picker (NSOpenPanel)
3. User selects folder
4. App creates security-scoped bookmark
5. Bookmark persists across app restarts
6. User can revoke authorization at any time

### Cleanup Flow

1. **Authorization check** - Verify bookmark is valid
2. **Dry run** - Enumerate files, show preview
3. **User confirmation** - Explicit "Delete" button click
4. **Execution** - Delete files within authorized scope
5. **Audit log** - Record operation details

### Protected Paths

Even with authorization, these paths are never cleaned:
- Files outside the authorized folder
- System-protected locations
- Application bundles
- User's home directory root

---

## Process Termination Security

### Protected Processes

These processes are never terminated:
- `kernel_task` (PID 0)
- `launchd` (PID 1)
- `WindowServer`
- `loginwindow`
- `CoreServicesUIAgent`

### Sensitive Processes

These require extra confirmation:
- Finder
- Dock
- SystemUIServer
- ControlCenter
- NotificationCenter

### PID Validation

Before termination:
- PID must be > 1
- Process must exist
- Process name checked against protected list
- User confirmation for sensitive processes

---

## Browser Automation Security

### Scope Limitations

Browser automation can only:
- Enumerate windows and tabs (titles, URLs)
- Close specific tabs or windows
- Quit browser applications

Browser automation **cannot**:
- Read page content
- Inject scripts
- Modify bookmarks or history
- Access passwords or cookies

### Error Handling

AppleScript error codes that indicate permission issues:
- `-1743`: Not authorized to send Apple events
- `-10004`: A privilege violation occurred
- `-1728`: Can't get object (often permission-related)

These errors trigger graceful degradation, not retries.

---

## Network Security

### Outbound Connections

| Destination | Purpose | When |
|-------------|---------|------|
| Stripe API | Subscription management | Purchase/restore |
| Apple App Store | Receipt validation | Purchase/restore |

### No Data Collection

Craig-O-Clean does NOT:
- Send usage analytics
- Transmit audit logs
- Report errors to servers
- Phone home for license checks (beyond App Store)

---

## Build Security

### Code Signing

- Main app: Signed with Developer ID / App Store certificate
- Helper tool (Dev ID only): Signed with same team ID
- Hardened runtime enabled
- Notarization required for Developer ID

### Entitlements

MAS build entitlements:
```xml
com.apple.security.app-sandbox = true
com.apple.security.automation.apple-events = true
com.apple.security.files.user-selected.read-write = true
com.apple.security.network.client = true
com.apple.security.scripting-targets = [specific browsers]
```

---

## Reporting Security Issues

If you discover a security vulnerability:

1. **Do not** create a public GitHub issue
2. Email security concerns to [security contact]
3. Include detailed reproduction steps
4. Allow 90 days for fix before public disclosure

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-28 | 1.0 | Initial security documentation |
