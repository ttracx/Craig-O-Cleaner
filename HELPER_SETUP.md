e# Helper Tool Setup Guide

This document explains how to set up the CraigOCleanHelper privileged helper tool for development and production.

## Overview

Craig-O-Clean uses a privileged helper tool (`CraigOCleanHelper`) to execute commands that require root privileges, specifically:
- `/bin/sync` - Flush file system buffers to disk
- `/usr/bin/purge` - Purge inactive memory (if available)

The helper is installed using Apple's `SMJobBless` API, which is the modern, approved method for installing privileged helper tools on macOS.

## How SMJobBless Works

1. **Installation Request**: When the user triggers "Memory Clean", the app checks if the helper is installed
2. **Authorization**: If not installed, the app requests authorization using the Security framework
3. **Blessing**: `SMJobBless` is called with the helper's bundle identifier
4. **Launchd Registration**: The system installs the helper to `/Library/PrivilegedHelperTools/` and registers it with launchd
5. **XPC Connection**: The app communicates with the helper via XPC using the Mach service name

## Project Structure

```
CraigOCleanHelper/
├── HelperMain.swift           # Entry point for the helper
├── HelperXPCProtocol.swift    # XPC protocol definition
├── HelperXPCImplementation.swift  # Protocol implementation
├── Info.plist                 # Helper bundle configuration
├── launchd.plist              # Launchd configuration
└── CraigOCleanHelper.entitlements  # Helper entitlements
```

## Code Signing Requirements

### For Development (Debug Builds)

In debug builds, SMJobBless typically fails due to code signing requirements. The app automatically falls back to using AppleScript with administrator privileges. This fallback:
- Is clearly labeled as "Debug Mode"
- Still requires the user to enter their admin password
- Works without any special signing configuration

### For Production (Release Builds)

For SMJobBless to work in production, both the main app and helper must be properly code signed with matching requirements.

#### 1. Main App Info.plist

Add `SMPrivilegedExecutables` to your app's Info.plist:

```xml
<key>SMPrivilegedExecutables</key>
<dict>
    <key>com.CraigOClean.helper</key>
    <string>identifier "com.CraigOClean.helper" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "YOUR_TEAM_ID"</string>
</dict>
```

Replace `YOUR_TEAM_ID` with your actual Apple Developer Team ID.

#### 2. Helper Info.plist

The helper's Info.plist must have `SMAuthorizedClients`:

```xml
<key>SMAuthorizedClients</key>
<array>
    <string>identifier "com.CraigOClean.app" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "YOUR_TEAM_ID"</string>
</array>
```

#### 3. Code Signing Identity

Both targets must be signed with a valid Developer ID certificate:
- Main App: Developer ID Application certificate
- Helper: Developer ID Application certificate (same identity)

## Adding the Helper Target to Xcode

### Step 1: Create New Target

1. In Xcode, select File > New > Target
2. Choose "macOS" > "Command Line Tool"
3. Name it `CraigOCleanHelper`
4. Set the bundle identifier to `com.CraigOClean.helper`

### Step 2: Configure Build Settings

For the helper target:

1. **Deployment Target**: macOS 14.0
2. **Skip Install**: Yes
3. **Installation Directory**: `$(CONTENTS_FOLDER_PATH)/Library/LaunchServices`
4. **Code Sign on Copy**: Yes
5. **Hardened Runtime**: Enabled

### Step 3: Add Source Files

Add these files to the helper target:
- `HelperMain.swift`
- `HelperXPCProtocol.swift`
- `HelperXPCImplementation.swift`

### Step 4: Add Info.plist and Launchd.plist

1. Add `CraigOCleanHelper/Info.plist` to the helper target
2. Add a "Copy Files" build phase:
   - Destination: Resources
   - Copy: `launchd.plist` (rename to `com.CraigOClean.helper.plist`)

### Step 5: Configure Main App Target

1. Add a "Copy Files" build phase to the main app
2. Destination: Wrapper
3. Subpath: `Contents/Library/LaunchServices`
4. Add the helper product: `CraigOCleanHelper`

### Step 6: Link to ServiceManagement

In the main app target, add the `ServiceManagement` framework to "Link Binary With Libraries".

## Testing the Helper

### Debug Mode Testing

1. Build and run the app in Debug configuration
2. Trigger "Memory Clean" from the menu bar or UI
3. The app will detect the helper isn't installed
4. It will use the AppleScript fallback
5. Enter your admin password when prompted
6. Verify the operation completes

### Release Mode Testing

1. Sign both targets with your Developer ID
2. Export or archive the app
3. Run from the exported location (not Xcode)
4. Trigger "Memory Clean"
5. The app should prompt for admin authorization
6. SMJobBless should install the helper
7. Subsequent calls should work without reinstalling

## Troubleshooting

### "Code signature invalid" Error

- Verify both targets are signed with the same team ID
- Check the code signing requirement strings match exactly
- Ensure the helper's Info.plist bundle identifier matches

### Helper Not Responding

1. Check if the helper is installed:
   ```bash
   ls /Library/PrivilegedHelperTools/
   ```

2. Check launchd:
   ```bash
   sudo launchctl list | grep CraigOClean
   ```

3. Check helper logs:
   ```bash
   sudo cat /var/log/com.CraigOClean.helper.log
   ```

### Removing Installed Helper

To completely remove the helper for testing:

```bash
# Unload from launchd
sudo launchctl unload /Library/LaunchDaemons/com.CraigOClean.helper.plist

# Remove the helper
sudo rm /Library/PrivilegedHelperTools/com.CraigOClean.helper

# Remove the launchd plist
sudo rm /Library/LaunchDaemons/com.CraigOClean.helper.plist
```

## Security Considerations

### Helper Command Allowlist

The helper only executes commands from a hardcoded allowlist:

```swift
private let allowedCommands: Set<String> = ["/bin/sync", "/usr/bin/purge"]
```

Any attempt to execute other commands is rejected.

### Authorization Verification

Every privileged operation requires valid authorization:
1. Authorization is requested per-operation
2. The helper verifies the authorization data
3. Authorization cannot be cached or reused improperly

### XPC Security

- The helper validates connecting clients
- Only the signed main app can communicate with the helper
- Connections from other processes are rejected

## Debug Fallback Behavior

When the helper cannot be installed (Debug builds), the app uses AppleScript:

```swift
#if DEBUG
private var useDebugFallback: Bool = true
#else
private var useDebugFallback: Bool = false
#endif
```

The fallback:
- Uses `NSAppleScript` to run commands with `administrator privileges`
- Triggers the standard macOS password dialog
- Is clearly marked as "Debug Mode" in UI and logs
- Is completely disabled in Release builds

## Version Compatibility

The helper and main app maintain version compatibility:
- The app checks the helper version on launch
- If versions don't match, the app can reinstall the helper
- Version is returned via the `getVersion()` XPC method

## Summary

| Build Config | Helper Installation | Privilege Mechanism |
|--------------|---------------------|---------------------|
| Debug | Skipped | AppleScript fallback |
| Release | SMJobBless | XPC to helper |

For development, no special setup is required - the Debug fallback handles everything. For production distribution, follow the code signing steps above to enable the full SMJobBless flow.
