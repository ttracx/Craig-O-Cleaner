# Craig-O-Clean Internal Distribution Build (No Sandbox)

**Build Date**: January 27, 2026
**Configuration**: Release
**Distribution Type**: Internal (Non-App Store)
**Sandbox**: **DISABLED** - Full system access enabled

## Build Artifacts

- **App Bundle**: `Craig-O-Clean.app` (18 MB)
- **DMG Installer**: `Craig-O-Clean-NoSandbox.dmg` (15 MB)

## Code Signing Details

- **Bundle Identifier**: com.craigoclean.app
- **Signing Authority**: Apple Development: Phamy Xaypanya (G9FQUJ8463)
- **Team ID**: K36LFHM32T
- **Architecture**: Universal Binary (arm64 + x86_64)
- **Hardened Runtime**: Enabled
- **Gatekeeper Status**: Accepted
- **App Sandbox**: **DISABLED**
- **Entitlements**:
  - `com.apple.security.automation.apple-events`: true (AppleScript/automation)
  - `com.apple.security.cs.allow-jit`: true (JIT compilation)
  - `com.apple.security.cs.allow-unsigned-executable-memory`: true (dynamic code)
  - `com.apple.security.cs.disable-library-validation`: true (load plugins)

## System Requirements

- **Minimum macOS Version**: 14.0 (Sonoma)
- **Architecture**: Apple Silicon (arm64) and Intel (x86_64)

## Why No Sandbox?

This build has the App Sandbox **disabled** to provide full system access for:
- **Direct process termination** using kill() system calls
- **Unrestricted file system access** for process monitoring
- **Complete browser control** across all browsers
- **System-level operations** without sandbox restrictions
- **Enhanced debugging** and system monitoring capabilities

⚠️ **Important**: This build is for internal use only and cannot be distributed through the Mac App Store.

## Installation Instructions

### Option 1: DMG Installer (Recommended)
1. Double-click `Craig-O-Clean-NoSandbox.dmg`
2. Drag Craig-O-Clean.app to your Applications folder
3. Right-click the app and select "Open" for first launch
4. Grant required permissions when prompted

### Option 2: Direct App Installation
1. Copy `Craig-O-Clean.app` to your Applications folder
2. Right-click the app and select "Open" for first launch
3. Grant required permissions when prompted

## First Launch

On first launch, you may see a security warning because this is a development-signed app. To open:

1. Right-click (or Control+click) the app
2. Select "Open" from the menu
3. Click "Open" in the dialog that appears

Alternatively, you can allow the app in System Settings:
1. Go to System Settings > Privacy & Security
2. Look for the blocked app message
3. Click "Open Anyway"

## Required Permissions

Craig-O-Clean requires the following permissions to function properly:

- **Accessibility**: For system monitoring and process control
- **Automation**: For browser tab management and application control
- **Full Disk Access**: For comprehensive process monitoring (optional but recommended)

Grant these permissions in: System Settings > Privacy & Security

## Features

- Process monitoring and management
- Browser tab control across Safari, Chrome, Edge, Brave, and Arc
- System cleanup operations
- Memory management
- Menu bar integration

## Support

For issues or questions:
- **Email**: support@craigoclean.com
- **Powered by**: VibeCaaS.com (NeuralQuantum.ai LLC)

---

**Note**: This is an internal development build for testing purposes. Not intended for App Store distribution.
