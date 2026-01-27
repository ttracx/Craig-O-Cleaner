# Craig-O-Clean Privileged Helper Tool

## Overview

The privileged helper tool enables Craig-O-Clean to execute system-level maintenance operations that require elevated privileges. It implements Apple's recommended SMJobBless architecture for secure privilege escalation.

## Architecture

### Components

1. **Helper Tool** (`HelperTool/main.swift`)
   - XPC service running with elevated privileges
   - Validates all commands against an allowlist
   - Logs all operations to system log
   - Runs as launchd daemon

2. **XPC Protocol** (`HelperProtocol.swift`)
   - Defines communication interface between app and helper
   - Supports command execution with authorization
   - Version checking and health monitoring

3. **Helper Installer** (`HelperInstaller.swift`)
   - Manages helper installation via SMJobBless
   - Version checking and updates
   - XPC connection management

4. **Elevated Executor** (`ElevatedExecutor.swift`)
   - Executes capabilities with `privilegeLevel: .elevated`
   - Integrates with PermissionCenter and logging
   - Delegates to helper for actual execution

## Installation Flow

```
User clicks elevated capability
         ↓
Check if helper installed
         ↓
    [Not Installed]
         ↓
Show HelperInstallView
         ↓
User clicks "Install Helper"
         ↓
Request administrator password
         ↓
SMJobBless installs helper
         ↓
Helper registers with launchd
         ↓
Execute elevated command
```

## Elevated Capabilities

The helper tool supports these operations from `catalog.json`:

### Memory Management
- `quick.mem.purge` - Purge inactive memory
- `quick.mem.sync_purge` - Sync and purge memory

### Network
- `quick.dns.flush` - Flush DNS cache

### System Maintenance
- `sys.maintenance.daily` - Run daily maintenance scripts
- `sys.maintenance.weekly` - Run weekly maintenance scripts
- `sys.maintenance.monthly` - Run monthly maintenance scripts
- `sys.maintenance.all` - Run all maintenance scripts

### Spotlight
- `sys.spotlight.status` - Check Spotlight indexing status
- `sys.spotlight.rebuild` - Rebuild Spotlight index

### System Services
- `sys.audio.restart` - Restart Core Audio daemon

### Disk Operations
- `deep.system.temp` - Clear system temporary files
- `deep.system.asl` - Clear Apple System Log files
- `disk.trash.empty_all` - Empty trash on all volumes

## Security Model

### Command Allowlist

The helper tool only executes commands in this allowlist:

```swift
let allowedCommands: Set<String> = [
    "/usr/sbin/diskutil",          // Disk utilities
    "/usr/bin/purge",              // Memory purge
    "/usr/bin/dscacheutil",        // DNS cache
    "/usr/bin/mdutil",             // Spotlight
    "/usr/sbin/periodic",          // Maintenance scripts
    "/usr/bin/killall",            // Process control
    "/bin/rm",                     // File operations
    "/usr/bin/log",                // System logs
    "/usr/sbin/sysctl"             // System control
]
```

### Authorization

- Uses macOS Authorization Services
- Requires administrator password for installation
- Each command execution requires valid authorization
- No credential caching
- Authorization token passed via XPC

### Audit Trail

All operations are logged:
- System log (via `os_log` and ASL)
- Application SQLite log store
- Includes command, arguments, exit code, timestamp

### Code Signing

- Helper tool must be signed with same certificate as main app
- Signature validated during installation
- `SMAuthorizedClients` restricts which apps can use helper
- `Info.plist` must match launchd.plist configuration

## XPC Communication

### Connection Setup

```swift
let connection = NSXPCConnection(
    machServiceName: "ai.neuralquantum.CraigOTerminator.helper",
    options: .privileged
)
connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
connection.resume()
```

### Command Execution

```swift
helper.executeCommand(
    "/usr/bin/purge",
    arguments: [],
    workingDirectory: nil,
    authData: authorizationData
) { exitCode, stdout, stderr, error in
    // Handle result
}
```

## Development

### Building the Helper

1. Add HelperTool as Command Line Tool target in Xcode
2. Configure bundle identifier: `ai.neuralquantum.CraigOTerminator.helper`
3. Set code signing certificate (must match app)
4. Add `launchd.plist` to Copy Files build phase
5. Embed helper in app bundle at `Contents/Library/LaunchServices`

### Testing

The helper cannot be fully tested in unit tests because:
- Requires administrator privileges
- Must be properly installed via SMJobBless
- XPC connection only works with installed helper

Manual testing steps:
1. Build and run app
2. Navigate to Settings → Helper
3. Click "Install Helper"
4. Enter administrator password
5. Verify installation successful
6. Execute an elevated capability (e.g., "Purge Memory")
7. Check system log: `log show --predicate 'subsystem == "ai.neuralquantum.CraigOTerminator.helper"' --last 5m`

### Debugging

Enable helper logging:
```bash
# View helper logs
log stream --predicate 'subsystem == "ai.neuralquantum.CraigOTerminator.helper"' --level debug

# Check if helper is running
launchctl list | grep CraigOTerminator

# Check helper registration
launchctl print system/ai.neuralquantum.CraigOTerminator.helper
```

Uninstall helper manually (for testing):
```bash
sudo launchctl unload /Library/LaunchDaemons/ai.neuralquantum.CraigOTerminator.helper.plist
sudo rm /Library/LaunchDaemons/ai.neuralquantum.CraigOTerminator.helper.plist
sudo rm /Library/PrivilegedHelperTools/ai.neuralquantum.CraigOTerminator.helper
```

## Troubleshooting

### Installation Fails

1. Check code signing: `codesign -dv --verbose=4 /path/to/app`
2. Verify entitlements: `codesign -d --entitlements - /path/to/app`
3. Check `SMAuthorizedClients` matches helper bundle ID
4. Verify launchd.plist is embedded in helper

### Helper Not Responding

1. Check if helper is running: `launchctl list | grep CraigOTerminator`
2. View helper logs: `log show --predicate 'subsystem == "ai.neuralquantum.CraigOTerminator.helper"'`
3. Try reinstalling helper
4. Check system permissions: System Settings → Privacy & Security

### Command Not Allowed

- Verify command is in helper's allowlist
- Check command path is absolute and correct
- Ensure capability has `privilegeLevel: "elevated"`

## Version History

- **1.0.0** (2026-01-27)
  - Initial implementation
  - Support for 13 elevated capabilities
  - SMJobBless installation
  - XPC communication
  - Command allowlist validation
  - Audit logging

## References

- [Apple: EvenBetterAuthorizationSample](https://developer.apple.com/library/archive/samplecode/EvenBetterAuthorizationSample/)
- [Apple: SMJobBless Documentation](https://developer.apple.com/documentation/servicemanagement/smjobbless)
- [Apple: Authorization Services](https://developer.apple.com/documentation/security/authorization_services)
- [Apple: XPC Documentation](https://developer.apple.com/documentation/xpc)
