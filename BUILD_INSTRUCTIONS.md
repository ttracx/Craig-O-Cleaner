# Craig-O-Clean - Build Instructions

This document provides detailed instructions for building Craig-O-Clean from source.

## Prerequisites

- **macOS 14 (Sonoma)** or later
- **Xcode 15.0** or later
- **Apple Silicon Mac** (M1/M2/M3) or Intel Mac with Rosetta 2
- **Command Line Tools**: `xcode-select --install`

## Quick Start

### Option 1: Open in Xcode (Recommended)

1. Open the project:
   ```bash
   open Craig-O-Clean.xcodeproj
   ```

2. In Xcode:
   - Select your development team in Signing & Capabilities
   - Select the "Craig-O-Clean" scheme
   - Press ⌘R to build and run

### Option 2: Command Line Build

```bash
# Build for development
xcodebuild -scheme Craig-O-Clean -configuration Debug build

# Build for release
xcodebuild -scheme Craig-O-Clean -configuration Release build
```

## Project Structure

After cloning, your project should have this structure:

```
Craig-O-Clean/
├── Core/                          # Core services
│   ├── SystemMetricsService.swift
│   ├── BrowserAutomationService.swift
│   ├── MemoryOptimizerService.swift
│   └── PermissionsService.swift
├── UI/                            # SwiftUI views
│   ├── MainAppView.swift
│   ├── DashboardView.swift
│   ├── ProcessManagerView.swift
│   ├── MemoryCleanupView.swift
│   ├── BrowserTabsView.swift
│   ├── SettingsPermissionsView.swift
│   └── MenuBarContentView.swift
├── Tests/
│   ├── Craig-O-CleanTests/            # Unit tests
│   └── Craig-O-CleanUITests/          # UI tests
├── Assets.xcassets/               # App icons and assets
├── Craig_O_CleanApp.swift         # App entry point
├── ProcessManager.swift           # Process management
├── SystemMemoryManager.swift      # Memory manager
├── Info.plist                     # App configuration
└── Craig-O-Clean.entitlements     # Permissions
```

## Adding New Files to Xcode Project

If you've added new Swift files, you need to add them to the Xcode project:

### Using Xcode

1. In Xcode, right-click on the appropriate group (e.g., "Core" or "UI")
2. Select "Add Files to 'Craig-O-Clean'..."
3. Navigate to and select the new files
4. Ensure "Copy items if needed" is unchecked (files are already in place)
5. Click "Add"

### Using XcodeGen (Alternative)

If you have XcodeGen installed:

```bash
# Install XcodeGen (if not installed)
brew install xcodegen

# Regenerate project from project.yml
xcodegen generate
```

## Configuration

### Code Signing

For development:
1. Open project settings in Xcode
2. Select "Craig-O-Clean" target
3. Go to "Signing & Capabilities"
4. Select your development team
5. Ensure "Automatically manage signing" is checked

For distribution:
1. Create an App ID in Apple Developer portal
2. Configure provisioning profiles
3. Select appropriate team and profiles in Xcode

### Entitlements

The app uses these entitlements (`Craig-O-Clean.entitlements`):

- `com.apple.security.automation.apple-events` - AppleScript for browser control
- `com.apple.security.files.user-selected.read-write` - File export

### Build Settings

Key build settings (already configured):

| Setting | Value |
|---------|-------|
| Swift Version | 5.9 |
| Deployment Target | macOS 14.0 |
| Hardened Runtime | YES |
| App Sandbox | NO (required for system access) |

## Running Tests

### Unit Tests

```bash
# Run all unit tests
xcodebuild test -scheme Craig-O-Clean -destination 'platform=macOS' -only-testing:Craig-O-CleanTests

# Run specific test file
xcodebuild test -scheme Craig-O-Clean -destination 'platform=macOS' \
  -only-testing:Craig-O-CleanTests/SystemMetricsServiceTests
```

### UI Tests

```bash
# Run UI tests
xcodebuild test -scheme Craig-O-Clean -destination 'platform=macOS' -only-testing:Craig-O-CleanUITests
```

### In Xcode

1. Press ⌘U to run all tests
2. Or use Test Navigator (⌘6) to run specific tests

## Building for Distribution

### Create Archive

```bash
# Clean build folder
xcodebuild clean -scheme Craig-O-Clean

# Create archive
xcodebuild archive \
  -scheme Craig-O-Clean \
  -archivePath build/Craig-O-Clean.xcarchive \
  -configuration Release
```

### Export for Distribution

Create `ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
```

Export:
```bash
xcodebuild -exportArchive \
  -archivePath build/Craig-O-Clean.xcarchive \
  -exportPath build/ \
  -exportOptionsPlist ExportOptions.plist
```

### Notarization

```bash
# Create ZIP for notarization
ditto -c -k --keepParent "build/Craig-O-Clean.app" build/Craig-O-Clean.zip

# Submit for notarization
xcrun notarytool submit build/Craig-O-Clean.zip \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "@keychain:AC_PASSWORD" \
  --wait

# Staple the ticket
xcrun stapler staple "build/Craig-O-Clean.app"
```

### Create DMG

```bash
# Create DMG installer
hdiutil create -volname "Craig-O-Clean" \
  -srcfolder "build/Craig-O-Clean.app" \
  -ov -format UDZO \
  build/Craig-O-Clean.dmg
```

## Troubleshooting

### Build Errors

**"No signing certificate found"**
- Open Xcode preferences → Accounts
- Add your Apple ID
- Select team in project settings

**"Symbol not found"**
- Clean build folder (⌘⇧K)
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`

**"Cannot find module"**
- Ensure all source files are added to the target
- Check file membership in File Inspector

### Runtime Issues

**"Automation permission denied"**
- Grant permission in System Settings → Privacy & Security → Automation

**"Process access denied"**
- The app needs to run without sandbox for full process access
- Verify entitlements are correct

**Menu bar icon not appearing**
- Check that `LSUIElement` is `true` in Info.plist
- Ensure `NSStatusBar` code runs on main thread

## Development Tips

### Live Preview

SwiftUI Previews work for most views:
1. Open a view file
2. Press ⌥⌘P to show/hide preview
3. Click "Resume" if preview is paused

### Debug Process Information

To debug process APIs:
```swift
print("PID: \(getpid())")
print("Running apps: \(NSWorkspace.shared.runningApplications.count)")
```

### Debug AppleScript

Test AppleScript in Script Editor first:
```applescript
tell application "Safari"
    return count of windows
end tell
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Build and Test

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-14
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode_15.0.app
    
    - name: Build
      run: xcodebuild build -scheme Craig-O-Clean -configuration Release
    
    - name: Test
      run: xcodebuild test -scheme Craig-O-Clean -destination 'platform=macOS'
```

## Support

If you encounter issues:
1. Check this document for solutions
2. Search existing issues on GitHub
3. Open a new issue with:
   - macOS version
   - Xcode version
   - Build logs
   - Steps to reproduce
