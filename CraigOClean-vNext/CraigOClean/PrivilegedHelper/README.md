# Craig-O-Clean Privileged Helper

This directory contains stubs for the privileged helper tool used in the DirectPro edition.

## Overview

The privileged helper runs as a separate daemon with root privileges, enabling operations that the main app cannot perform due to sandbox restrictions:

- System-wide cache cleanup
- Access to protected directories
- DNS cache flushing
- Other privileged operations

## Architecture

```
┌─────────────────────┐     XPC      ┌─────────────────────┐
│  Craig-O-Clean App  │ ──────────── │  Privileged Helper  │
│  (User privileges)  │              │  (Root privileges)  │
└─────────────────────┘              └─────────────────────┘
```

## Components

### HelperProtocol.swift
Defines the XPC interface for communication between the app and helper.

### HelperClient.swift
Client-side wrapper for XPC communication with async/await support.

### HelperTool/main.swift
Stub implementation of the helper daemon.

## Implementation Guide

### 1. Create Helper Target

Add a new "Command Line Tool" target in Xcode:
- Name: `com.craigosoft.CraigOClean.Helper`
- Language: Swift

### 2. Configure Code Signing

The helper must be signed with:
- Hardened Runtime enabled
- Same Team ID as the main app

### 3. Create Info.plist for Helper

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.craigosoft.CraigOClean.Helper</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>SMAuthorizedClients</key>
    <array>
        <string>identifier "com.craigosoft.CraigOClean" and anchor apple generic and certificate leaf[subject.CN] = "Developer ID Application: Your Name (TEAM_ID)"</string>
    </array>
</dict>
</plist>
```

### 4. Create launchd.plist for Helper

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.craigosoft.CraigOClean.Helper</string>
    <key>MachServices</key>
    <dict>
        <key>com.craigosoft.CraigOClean.Helper</key>
        <true/>
    </dict>
</dict>
</plist>
```

### 5. Configure Main App Info.plist

Add to the main app's Info.plist:

```xml
<key>SMPrivilegedExecutables</key>
<dict>
    <key>com.craigosoft.CraigOClean.Helper</key>
    <string>identifier "com.craigosoft.CraigOClean.Helper" and anchor apple generic and certificate leaf[subject.CN] = "Developer ID Application: Your Name (TEAM_ID)"</string>
</dict>
```

### 6. Embed Helper in App Bundle

The helper binary must be placed at:
```
CraigOClean.app/Contents/Library/LaunchServices/com.craigosoft.CraigOClean.Helper
```

### 7. Install with SMJobBless

```swift
import ServiceManagement

func installHelper() throws {
    var authRef: AuthorizationRef?
    var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value: nil, flags: 0)
    var authRights = AuthorizationRights(count: 1, items: &authItem)

    let status = AuthorizationCreate(&authRights, nil, [.interactionAllowed, .extendRights], &authRef)
    guard status == errAuthorizationSuccess else {
        throw HelperError.permissionDenied
    }

    var error: Unmanaged<CFError>?
    let success = SMJobBless(kSMDomainSystemLaunchd, "com.craigosoft.CraigOClean.Helper" as CFString, authRef, &error)

    if !success {
        throw HelperError.operationFailed(reason: error?.takeRetainedValue().localizedDescription ?? "Unknown")
    }
}
```

## Security Considerations

1. **Validate Client Identity**: Always verify the connecting client's code signature
2. **Minimize Privileges**: Only perform necessary operations
3. **Audit Logging**: Log all privileged operations
4. **Input Validation**: Validate all paths and parameters
5. **Rate Limiting**: Prevent abuse of privileged operations

## Testing

1. Build the helper as a standalone target
2. Code sign with your Developer ID
3. Install manually for testing:
   ```bash
   sudo cp Helper /Library/PrivilegedHelperTools/
   sudo cp launchd.plist /Library/LaunchDaemons/
   sudo launchctl load /Library/LaunchDaemons/com.craigosoft.CraigOClean.Helper.plist
   ```

## Troubleshooting

### Helper Won't Install
- Check code signing requirements match
- Verify Team ID in both plists
- Check Console.app for SMJobBless errors

### XPC Connection Fails
- Verify MachServices in launchd.plist
- Check helper is running: `launchctl list | grep craigosoft`
- Check system logs for XPC errors

### Permission Denied
- Verify helper is running as root
- Check file permissions on helper binary
