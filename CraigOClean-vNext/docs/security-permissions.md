# Security and Permissions Guide

This document describes the security model and permission requirements for Craig-O-Clean.

## Edition Security Comparison

| Aspect | Lite (App Store) | Pro (Direct) |
|--------|------------------|--------------|
| Sandbox | Yes | No |
| Hardened Runtime | No | Yes |
| Full Disk Access | Not available | Optional |
| Privileged Helper | Not available | Optional |
| Code Signing | Apple Distribution | Developer ID |
| Notarization | Via App Store | Required |

## App Store Lite Security

### Sandbox Entitlements

```xml
<!-- Required -->
<key>com.apple.security.app-sandbox</key>
<true/>

<!-- User file access -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<!-- Downloads folder -->
<key>com.apple.security.files.downloads.read-write</key>
<true/>

<!-- Network (for website links) -->
<key>com.apple.security.network.client</key>
<true/>
```

### What Lite CAN Access

- User's home directory caches: `~/Library/Caches/`
- User's logs: `~/Library/Logs/`
- Downloads folder (with permission)
- Temporary directory
- Application Support (own container)

### What Lite CANNOT Access

- System caches: `/Library/Caches/`
- System logs: `/Library/Logs/`, `/var/log/`
- Other users' directories
- Protected system directories
- Keychain data
- SSH keys
- Other sensitive locations

### Path Validation

All paths are validated before access:

```swift
func isPathAllowed(_ path: String) -> Bool {
    let home = NSHomeDirectory()

    // Must be within user home
    guard path.hasPrefix(home) else { return false }

    // Block sensitive subdirectories
    let blocked = [
        "/.ssh",
        "/.gnupg",
        "/Library/Keychains",
        "/Library/Accounts",
        "/Library/Cookies"
    ]

    return !blocked.any { path.contains($0) }
}
```

## DirectPro Security

### Hardened Runtime

Pro uses hardened runtime for notarization:

```xml
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<false/>

<key>com.apple.security.cs.disable-library-validation</key>
<false/>
```

### Full Disk Access

Pro requests Full Disk Access for:
- System-wide cache inspection
- Reading protected directories
- Complete disk usage analysis

User grants via: System Settings → Privacy & Security → Full Disk Access

Detection:
```swift
func hasFullDiskAccess() -> Bool {
    let testPath = "\(NSHomeDirectory())/Library/Mail"
    return FileManager.default.isReadableFile(atPath: testPath)
}
```

### Privileged Helper

For system-wide cleanup, Pro uses a privileged helper:

```
┌─────────────────────────────────────────────────────────────┐
│                        Main App                              │
│                    (User privileges)                         │
└─────────────────────────┬───────────────────────────────────┘
                          │ XPC
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                   Privileged Helper                          │
│                    (Root privileges)                         │
│  - Installed via SMJobBless                                 │
│  - Runs as LaunchDaemon                                     │
│  - Validates client identity                                │
└─────────────────────────────────────────────────────────────┘
```

Security measures:
- Code signature validation for connecting clients
- Minimal capabilities (no shell execution)
- Audit logging of all operations
- Uninstall capability

## Code Signing Requirements

### Lite (App Store)

- Certificate: Apple Distribution
- Provisioning: Mac App Store
- Entitlements: Sandbox required

### Pro (Direct)

- Certificate: Developer ID Application
- Notarization: Required
- Entitlements: Hardened runtime

### Privileged Helper

- Certificate: Developer ID Application
- SMAuthorizedClients: Must match main app signature
- Embedded Info.plist with authorization requirements

## Permission Request Flow

### Full Disk Access (Pro)

```
App needs FDA for operation
    │
    ▼
Check hasFullDiskAccess()
    │
    ├── true → Proceed with operation
    │
    └── false → Show permission request UI
                    │
                    ▼
                "Grant Full Disk Access" button
                    │
                    ▼
                Opens System Settings
                    │
                    ▼
                User grants access
                    │
                    ▼
                App detects change, retries
```

### Helper Installation (Pro)

```
App needs privileged operation
    │
    ▼
Check helperStatus
    │
    ├── installed → Connect via XPC
    │
    └── notInstalled → Show install prompt
                           │
                           ▼
                       SMJobBless()
                           │
                           ▼
                       Authorization prompt
                           │
                           ▼
                       Helper installed
```

## Logging and Audit

All operations are logged:

```swift
logger.info("Deleting file: \(path)", category: .cleanup, metadata: [
    "operation": "delete",
    "path": path,
    "size": "\(size)"
])
```

Log files stored at:
- Lite: `~/Library/Containers/.../Application Support/CraigOClean/logs/`
- Pro: `~/Library/Application Support/CraigOClean/logs/`

## Data Protection

### No Sensitive Data Collection

The app does not:
- Collect personal information
- Send data to external servers
- Store passwords or credentials
- Access Keychain data
- Read encrypted files

### Local-Only Processing

All cleanup operations are local:
- No cloud sync
- No telemetry
- No analytics by default
- No remote configuration

## Security Best Practices

### File Operations

1. Always validate paths before access
2. Use `trashItem(at:)` instead of `removeItem(at:)` when possible
3. Check file existence before operations
4. Handle permission errors gracefully
5. Never follow symlinks outside allowed paths

### User Communication

1. Explain why permissions are needed
2. Provide fallback for denied permissions
3. Log all significant operations
4. Show clear error messages

## Threat Model

### Considered Threats

1. **Accidental data loss**: Mitigated by dry-run previews, trash usage
2. **Privilege escalation**: Helper validates client identity
3. **Malicious file paths**: All paths validated against allowlist
4. **Symlink attacks**: Symlinks not followed outside user home

### Out of Scope

1. Malicious modifications to app binary (code signing handles)
2. Kernel-level attacks
3. Physical access attacks

## Compliance

- GDPR: No personal data collection
- CCPA: No sale of user data
- Apple Privacy: Minimal data access, local processing only
