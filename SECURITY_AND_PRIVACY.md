# Security and Privacy

This document outlines the security model, privacy considerations, and permission requirements for Craig-O-Clean.

## Overview

Craig-O-Clean is designed with security and privacy as core principles. The app operates entirely offline and never transmits any user data, system information, or telemetry to external servers.

## No Data Leaves Your Device

**Craig-O-Clean operates 100% offline.** Here's what this means:

- **No Telemetry**: We do not collect analytics, crash reports, or usage statistics
- **No Network Requests**: The app makes no outbound network connections for core functionality
- **No Cloud Sync**: All settings and preferences are stored locally on your Mac
- **No Account Required**: You don't need to create an account or sign in to use the app
- **No External Dependencies**: All functionality is built using Apple's native frameworks

The only network functionality (optional) is:
- Subscription management through the App Store (handled entirely by Apple)
- Stripe checkout for web subscriptions (only if you explicitly choose this payment method)

## Permissions Required

Craig-O-Clean requires certain macOS permissions to function. Here's what each permission is used for:

### 1. Accessibility Permission (Optional but Recommended)

**Purpose**: Enhanced process management and system monitoring

**What it enables**:
- Advanced process control beyond NSRunningApplication
- Window management features
- System-wide keyboard shortcuts (if implemented)

**What we DO with this permission**:
- Enumerate running processes with detailed information
- Gracefully terminate or force quit applications at your request
- Monitor resource usage of applications

**What we DO NOT do**:
- Monitor your keyboard input
- Record screen content
- Access sensitive application data
- Control your computer without your explicit action

### 2. Automation Permission (Required for Browser Tab Management)

**Purpose**: Browser tab management across Safari, Chrome, Edge, Brave, and Arc

**What it enables**:
- Viewing open browser tabs and windows
- Closing individual tabs or groups of tabs
- Detecting duplicate tabs
- Calculating per-tab memory estimates

**What we DO with this permission**:
- Send AppleScript commands to enumerate browser tabs
- Close tabs that you specifically select for cleanup

**What we DO NOT do**:
- Read page content or URLs beyond what's displayed
- Access browser history or bookmarks
- Modify browser settings
- Execute JavaScript in browser pages

### 3. Administrator Privileges (Optional - for Memory Purge)

**Purpose**: Running the `sync` and `purge` system commands

**What it enables**:
- The "Memory Clean" quick action that flushes file system buffers and purges inactive memory

**What we DO with this permission**:
- Execute `/bin/sync` to flush file system buffers
- Execute `/usr/bin/purge` to release inactive memory (if available)

**What we DO NOT do**:
- Make any system modifications
- Access protected system files
- Install system extensions
- Modify system preferences

## Protected Processes

Craig-O-Clean maintains a list of protected system processes that cannot be terminated, even if you try. This protects system stability:

**Protected Process List**:
- `kernel_task` - macOS kernel
- `launchd` - System initialization
- `WindowServer` - Display management
- `loginwindow` - Login interface
- `SystemUIServer` - Menu bar and system UI
- `Dock` - Application dock
- `Finder` - File management
- `mds` / `mds_stores` - Spotlight indexing
- `coreauthd` - Authentication services
- `securityd` - Security services
- `cfprefsd` - Preferences daemon
- `UserEventAgent` - User event handling

For these processes:
- The "Force Quit" option is disabled
- A tooltip explains why the action is unavailable
- The app will never send termination signals to these processes

## Privileged Helper Tool

Craig-O-Clean uses a privileged helper tool (CraigOCleanHelper) for operations requiring root access:

### What the Helper Can Do

The helper is strictly limited to executing only these commands:
1. `/bin/sync` - Flush file system buffers
2. `/usr/bin/purge` - Purge inactive memory (if available on your system)

### What the Helper Cannot Do

- Execute any other commands
- Access files or directories
- Modify system settings
- Install or remove software
- Access network resources
- Run user-provided scripts or commands

### Helper Security Model

1. **SMJobBless Installation**: The helper is installed using Apple's SMJobBless API, which requires:
   - Proper code signing
   - Matching bundle identifiers
   - User authorization

2. **XPC Communication**: The helper communicates via XPC (secure IPC):
   - All connections are validated
   - Authorization is checked for each privileged operation
   - The helper only accepts connections from the signed main app

3. **Command Allowlist**: The helper maintains a hardcoded list of allowed commands:
   ```swift
   private let allowedCommands: Set<String> = ["/bin/sync", "/usr/bin/purge"]
   ```
   Any attempt to execute other commands is rejected.

4. **Authorization Verification**: Each privileged operation requires fresh authorization:
   - Authorization data is passed with each request
   - The helper verifies the authorization before executing
   - Authorization expires and cannot be reused

### Debug Mode Fallback

In debug builds where the helper cannot be installed (due to code signing requirements), the app falls back to using AppleScript:
- This is clearly labeled as "Debug Mode" in all UI and logs
- The fallback is disabled in Release builds
- Users still see the standard macOS administrator password prompt

## Termination Actions

### End Task (Graceful)

When you use "End Task" on an application:
1. If it's a GUI app, we call `NSRunningApplication.terminate()`
2. This sends a standard quit request to the app
3. The app can save unsaved work and clean up
4. If the app doesn't respond, you can use Force Quit

### Force Quit

When you use "Force Quit" on an application:
1. A confirmation dialog is always shown
2. If it's a GUI app, we call `NSRunningApplication.forceTerminate()`
3. For processes, we send `SIGKILL`
4. The process is immediately terminated
5. Unsaved work may be lost

**Force Quit is disabled for**:
- Protected system processes (listed above)
- The Craig-O-Clean app itself
- Critical system services

## Data Storage

Craig-O-Clean stores the following data locally:

### User Preferences (UserDefaults)
- UI settings (refresh interval, theme preference)
- Window positions and sizes
- Feature toggles

### No Sensitive Data Storage
We do not store:
- Process history or logs
- Browser tab history
- System metrics history
- Cleanup action history
- Personal information

## Code Signing and Notarization

For distribution, Craig-O-Clean is:
1. **Code Signed**: With a valid Apple Developer ID
2. **Notarized**: Verified by Apple's notary service
3. **Hardened Runtime**: Enabled to prevent code injection

This ensures:
- The app has not been tampered with
- The developer identity is verified
- The app meets Apple's security requirements

## Reporting Security Issues

If you discover a security vulnerability in Craig-O-Clean:

1. **Do not** open a public GitHub issue
2. Email security concerns to: [security contact - add your email]
3. Provide detailed steps to reproduce
4. Allow time for a fix before public disclosure

## Third-Party Auditing

The complete source code is available for review. We welcome security audits from:
- Independent security researchers
- Corporate security teams considering deployment
- The developer community

## Summary

| Feature | Data Access | Network | Storage |
|---------|-------------|---------|---------|
| Process List | Read-only | None | None |
| Process Termination | Write (local) | None | None |
| Browser Tabs | Read-only | None | None |
| Memory Purge | System command | None | None |
| Settings | User prefs | None | Local only |

**Craig-O-Clean respects your privacy. Your data stays on your device.**
