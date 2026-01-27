# Privileged Helper - Quick Reference Card

## Installation

### Check Status
```swift
await HelperInstaller.shared.checkStatus()
// Returns: .installed(version) | .outdated | .notInstalled | .unknown
```

### Install Helper
```swift
try await HelperInstaller.shared.install()
// Prompts for admin password, installs via SMJobBless
```

### Uninstall Helper
```swift
try await HelperInstaller.shared.uninstall()
// Removes helper from system
```

## Execution

### Execute Elevated Capability
```swift
let executor = ElevatedExecutor()
let result = try await executor.execute(capability, arguments: [:])
// Returns: ExecutionResultWithOutput
```

### Check if Can Execute
```swift
let canExecute = await executor.canExecute(capability)
// Returns: true if capability.privilegeLevel == .elevated
```

## Debugging

### View Helper Logs
```bash
# Stream logs in real-time
log stream --predicate 'subsystem == "ai.neuralquantum.CraigOTerminator.helper"' --level debug

# View last 5 minutes
log show --predicate 'subsystem == "ai.neuralquantum.CraigOTerminator.helper"' --last 5m

# View specific time range
log show --predicate 'subsystem == "ai.neuralquantum.CraigOTerminator.helper"' --start '2026-01-27 10:00:00'
```

### Check Helper Status
```bash
# Is helper running?
launchctl list | grep CraigOTerminator

# Helper details
launchctl print system/ai.neuralquantum.CraigOTerminator.helper

# Verify signature
codesign -dv --verbose=4 /Library/PrivilegedHelperTools/ai.neuralquantum.CraigOTerminator.helper
```

### Manual Helper Management
```bash
# Unload (stop) helper
sudo launchctl unload /Library/LaunchDaemons/ai.neuralquantum.CraigOTerminator.helper.plist

# Load (start) helper
sudo launchctl load /Library/LaunchDaemons/ai.neuralquantum.CraigOTerminator.helper.plist

# Remove helper completely
sudo launchctl unload /Library/LaunchDaemons/ai.neuralquantum.CraigOTerminator.helper.plist
sudo rm /Library/LaunchDaemons/ai.neuralquantum.CraigOTerminator.helper.plist
sudo rm /Library/PrivilegedHelperTools/ai.neuralquantum.CraigOTerminator.helper
```

## Command Allowlist

The helper only executes these commands:

```
/usr/sbin/diskutil          # Disk utilities
/usr/bin/purge              # Memory purge
/usr/bin/dscacheutil        # DNS cache
/usr/bin/mdutil             # Spotlight
/usr/sbin/periodic          # Maintenance scripts
/usr/bin/killall            # Process control
/bin/rm                     # File operations
/usr/bin/log                # System logs
/usr/sbin/sysctl            # System control
```

## Elevated Capabilities

| ID | Command | Description |
|----|---------|-------------|
| `quick.dns.flush` | `dscacheutil -flushcache` | Flush DNS cache |
| `quick.mem.purge` | `purge` | Purge inactive memory |
| `quick.mem.sync_purge` | `sync && purge` | Sync and purge |
| `sys.maintenance.daily` | `periodic daily` | Daily maintenance |
| `sys.maintenance.weekly` | `periodic weekly` | Weekly maintenance |
| `sys.maintenance.monthly` | `periodic monthly` | Monthly maintenance |
| `sys.maintenance.all` | `periodic daily weekly monthly` | All maintenance |
| `sys.spotlight.status` | `mdutil -s /` | Spotlight status |
| `sys.spotlight.rebuild` | `mdutil -E /` | Rebuild Spotlight |
| `sys.audio.restart` | `killall coreaudiod` | Restart Core Audio |
| `deep.system.temp` | `rm -rf /private/var/tmp/*` | Clear system temp |
| `deep.system.asl` | `rm -rf /private/var/log/asl/*.asl` | Clear ASL logs |
| `disk.trash.empty_all` | `rm -rf /Volumes/*/.Trashes/*` | Empty all trashes |

## Common Issues

### "Helper Not Installed"
```swift
// Show installation UI
HelperInstallView()
    .environment(HelperInstaller.shared)
```

### "Helper Outdated"
```swift
// Reinstall helper
try await HelperInstaller.shared.install()
```

### "Authorization Denied"
- User must be administrator
- Check authorization prompt appears
- Verify entitlements are correct

### "XPC Connection Failed"
- Helper may not be installed
- Check: `launchctl list | grep CraigOTerminator`
- Try reinstalling

### "Command Not Allowed"
- Verify command is in allowlist
- Check capability.privilegeLevel == .elevated
- Review HelperTool/main.swift allowlist

## File Locations

### App Bundle
```
CraigOTerminator.app/
└── Contents/
    ├── Library/
    │   └── LaunchServices/
    │       └── ai.neuralquantum.CraigOTerminator.helper
    └── Info.plist (with SMPrivilegedExecutables)
```

### System Locations
```
/Library/PrivilegedHelperTools/
└── ai.neuralquantum.CraigOTerminator.helper

/Library/LaunchDaemons/
└── ai.neuralquantum.CraigOTerminator.helper.plist
```

## Security Checklist

- [ ] Helper signed with same certificate as app
- [ ] SMAuthorizedClients matches app bundle ID
- [ ] SMPrivilegedExecutables matches helper bundle ID
- [ ] Command in allowlist
- [ ] Authorization checked
- [ ] Operation logged
- [ ] No shell interpretation
- [ ] Absolute paths used
- [ ] Arguments validated

## Code Signing

### Verify App Signature
```bash
codesign -dv --verbose=4 CraigOTerminator.app
codesign -d --entitlements - CraigOTerminator.app
```

### Verify Helper Signature
```bash
codesign -dv --verbose=4 CraigOTerminator.app/Contents/Library/LaunchServices/ai.neuralquantum.CraigOTerminator.helper
codesign -d --entitlements - CraigOTerminator.app/Contents/Library/LaunchServices/ai.neuralquantum.CraigOTerminator.helper
```

### Re-sign (Development)
```bash
codesign --force --deep --sign "Apple Development" CraigOTerminator.app
```

## Production Checklist

- [ ] Switch to "Developer ID" certificate
- [ ] Update signature requirements in Info.plist
- [ ] Update SMAuthorizedClients
- [ ] Update SMPrivilegedExecutables
- [ ] Enable hardened runtime
- [ ] Notarize app bundle
- [ ] Test installation on clean system
- [ ] Verify Gatekeeper accepts app
- [ ] Test all elevated capabilities
- [ ] Review security audit logs

## Support

**Documentation:**
- Full Guide: `HelperTool/README.md`
- Security Model: `HelperTool/SECURITY.md`
- Xcode Setup: `HELPER_XCODE_SETUP.md`

**Logs:**
- System: `log show --predicate 'subsystem == "ai.neuralquantum.CraigOTerminator.helper"'`
- App: SQLite database in Application Support

**Testing:**
```bash
# Quick test
sudo -u $(whoami) /Library/PrivilegedHelperTools/ai.neuralquantum.CraigOTerminator.helper

# Should fail (requires launchd)
# If helper runs, there's a problem
```

---

**Version:** 1.0.0
**Last Updated:** January 27, 2026
