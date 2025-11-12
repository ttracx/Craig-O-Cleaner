# Build Instructions for Craig-O-Clean App

This document provides detailed step-by-step instructions for building and running the Craig-O-Clean app.

## Prerequisites

Before you begin, ensure you have:

1. **macOS 13.0 (Ventura) or later**
2. **Xcode 15.0 or later** - Download from the Mac App Store or [Apple Developer](https://developer.apple.com/xcode/)
3. **Command Line Tools** - Run `xcode-select --install` if not already installed

## Quick Start

### Method 1: Build and Run in Xcode (Easiest)

1. **Open the project**:
   ```bash
   open Craig-O-Clean.xcodeproj
   ```

2. **Select the target**:
   - In Xcode, ensure "Craig-O-Clean" is selected in the scheme dropdown (next to the Run/Stop buttons)
   - Select "My Mac" as the destination

3. **Configure Code Signing** (if needed):
   - Click on the project name in the Project Navigator
   - Select the "Craig-O-Clean" target
   - Go to "Signing & Capabilities" tab
   - If you see signing errors:
     - Check "Automatically manage signing"
     - Select your Apple ID from the "Team" dropdown
     - Or choose "Sign to Run Locally" if you don't have an Apple Developer account

4. **Build and Run**:
   - Press `⌘R` (Command + R) or click the Play button
   - The app will build and launch
   - Look for the memory chip icon in your menu bar

### Method 2: Build from Command Line

1. **Navigate to the project directory**:
   ```bash
   cd /path/to/Craig-O-Cleaner
   ```

2. **Build the project**:
   ```bash
   xcodebuild -project Craig-O-Clean.xcodeproj \
              -scheme Craig-O-Clean \
              -configuration Release \
              -derivedDataPath ./build \
              clean build
   ```

3. **Find the built app**:
   ```bash
   ls -la ./build/Build/Products/Release/Craig-O-Clean.app
   ```

4. **Run the app**:
   ```bash
   open ./build/Build/Products/Release/Craig-O-Clean.app
   ```

5. **Optional: Install to Applications folder**:
   ```bash
   cp -r ./build/Build/Products/Release/Craig-O-Clean.app /Applications/
   open -a "Craig-O-Clean"
   ```

## Build Configurations

### Debug Build
- Includes debugging symbols
- No optimization
- Best for development and testing

```bash
xcodebuild -project Craig-O-Clean.xcodeproj \
           -scheme Craig-O-Clean \
           -configuration Debug \
           build
```

### Release Build
- Optimized for performance
- Smaller binary size
- Best for distribution

```bash
xcodebuild -project Craig-O-Clean.xcodeproj \
           -scheme Craig-O-Clean \
           -configuration Release \
           build
```

## Troubleshooting Build Issues

### Issue: "No such module 'SwiftUI'"
**Solution**: Ensure you're targeting macOS 13.0 or later. Check the deployment target in project settings.

### Issue: Code signing errors
**Solutions**:
1. In Xcode, go to Preferences → Accounts → Add your Apple ID
2. Or disable code signing temporarily for local development:
   - Project Settings → Signing & Capabilities → Uncheck "Automatically manage signing"
   - Select "Sign to Run Locally"

### Issue: Build fails with "Command Line Tools not found"
**Solution**: Install Command Line Tools:
```bash
xcode-select --install
```

### Issue: "Cannot find 'NSApplicationDelegate' in scope"
**Solution**: Ensure you're building for macOS (not iOS). Check the destination in Xcode.

### Issue: Derived data corruption
**Solution**: Clean the build folder:
```bash
# In Xcode
# Product → Clean Build Folder (Shift + Command + K)

# Or from command line
rm -rf ~/Library/Developer/Xcode/DerivedData/Craig-O-Clean-*
```

## Build Settings Reference

Key build settings used in this project:

- **Deployment Target**: macOS 13.0
- **Swift Version**: 5.0
- **Architecture**: Universal (Apple Silicon + Intel)
- **SDK**: macOS SDK
- **Code Signing**: Automatic (or Manual as configured)
- **Sandbox**: Disabled (required for process monitoring)

## Verifying the Build

After building, verify the app works correctly:

1. **Check the app launches**:
   - Look for the memory chip icon in the menu bar
   - Click the icon to open the popover

2. **Test process listing**:
   - The popover should show a list of running processes
   - Processes should be sorted by memory usage

3. **Test search**:
   - Type in the search box to filter processes

4. **Test refresh**:
   - Click the refresh button (↻) to update the process list

5. **Test force quit** (be careful):
   - Click "Force Quit" on a non-critical process
   - Verify the process is terminated

6. **Test memory purge**:
   - Click "Purge Memory" button
   - Enter your admin password when prompted
   - You should see a success message

## Advanced Build Options

### Building with specific architecture

For Apple Silicon only:
```bash
xcodebuild -project Craig-O-Clean.xcodeproj \
           -scheme Craig-O-Clean \
           -configuration Release \
           -arch arm64 \
           build
```

For Intel only:
```bash
xcodebuild -project Craig-O-Clean.xcodeproj \
           -scheme Craig-O-Clean \
           -configuration Release \
           -arch x86_64 \
           build
```

### Creating an Archive for Distribution

```bash
xcodebuild -project Craig-O-Clean.xcodeproj \
           -scheme Craig-O-Clean \
           -configuration Release \
           -archivePath ./build/Craig-O-Clean.xcarchive \
           archive
```

## Distribution

### For Personal Use
Simply copy the built app to /Applications:
```bash
cp -r ./build/Build/Products/Release/Craig-O-Clean.app /Applications/
```

### For Distribution to Others
You'll need to:
1. Sign the app with a Developer ID certificate
2. Notarize the app with Apple
3. Create a DMG or PKG installer

These steps require an Apple Developer account ($99/year).

## Clean Build

To perform a clean build from scratch:

```bash
# Remove derived data
rm -rf ./build

# Clean and build
xcodebuild -project Craig-O-Clean.xcodeproj \
           -scheme Craig-O-Clean \
           -configuration Release \
           clean build
```

## Need Help?

If you encounter issues not covered here:
1. Check the main README.md for additional troubleshooting
2. Verify your Xcode version: `xcodebuild -version`
3. Check macOS version: `sw_vers`
4. Open an issue on GitHub with:
   - Your macOS version
   - Your Xcode version
   - The complete error message
   - Steps to reproduce the issue
