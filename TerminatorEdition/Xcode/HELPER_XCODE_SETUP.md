# Xcode Project Configuration for Privileged Helper

This document provides step-by-step instructions for configuring the Xcode project to properly build and embed the privileged helper tool.

## Prerequisites

- Xcode 15.0 or later
- Valid Apple Developer certificate
- macOS 14.0+ deployment target
- Project file: `CraigOTerminator.xcodeproj`

## Step 1: Create Helper Tool Target

1. Open `CraigOTerminator.xcodeproj` in Xcode

2. **Add New Target**:
   - File → New → Target
   - Select **macOS** tab
   - Choose **Command Line Tool**
   - Click **Next**

3. **Configure Target**:
   - **Product Name**: `HelperTool`
   - **Team**: Select your development team
   - **Organization Identifier**: `ai.neuralquantum`
   - **Bundle Identifier**: `ai.neuralquantum.CraigOTerminator.helper`
   - **Language**: Swift
   - Click **Finish**

4. **Delete Default main.swift**:
   - Xcode creates a default `main.swift`
   - Delete it (Move to Trash)
   - We'll use our custom `HelperTool/main.swift`

## Step 2: Add Helper Files to Target

1. **Add main.swift**:
   - Select `HelperTool` target in project navigator
   - Right-click → Add Files to "CraigOTerminator"
   - Navigate to `HelperTool/main.swift`
   - **Important**: Check "HelperTool" target membership
   - Uncheck "CraigOTerminator" target membership
   - Click **Add**

2. **Add HelperProtocol.swift**:
   - Select `CraigOTerminator/Core/Execution/HelperProtocol.swift`
   - In File Inspector (right panel), under **Target Membership**:
     - ✅ Check both `CraigOTerminator` AND `HelperTool`
   - This file is shared between app and helper

3. **Add Info.plist**:
   - Select `HelperTool` target
   - Build Settings → Packaging
   - **Info.plist File**: `HelperTool/Info.plist`

4. **Add launchd.plist**:
   - Will be embedded via Copy Files phase (next step)

## Step 3: Configure Build Phases

### Add Copy Files Phase

1. **Select HelperTool Target**:
   - Click `HelperTool` in Targets list
   - Go to **Build Phases** tab

2. **Add Copy Files Phase**:
   - Click **+** button
   - Select **New Copy Files Phase**
   - Name it: "Copy launchd.plist"

3. **Configure Copy Files**:
   - **Destination**: Wrapper
   - **Subpath**: `Contents`
   - **Copy only when installing**: ❌ Unchecked
   - Click **+** to add files
   - Add `HelperTool/launchd.plist`

### Verify Build Phases Order

Correct order:
1. Dependencies
2. Compile Sources (main.swift)
3. Link Binary With Libraries
4. Copy launchd.plist

## Step 4: Embed Helper in Main App

1. **Select CraigOTerminator Target**:
   - Click `CraigOTerminator` in Targets list
   - Go to **Build Phases** tab

2. **Add Copy Files Phase**:
   - Click **+** button
   - Select **New Copy Files Phase**
   - Name it: "Embed Helper Tool"

3. **Configure Embedding**:
   - **Destination**: Wrapper
   - **Subpath**: `Contents/Library/LaunchServices`
   - **Copy only when installing**: ❌ Unchecked
   - Click **+** to add files
   - Select **HelperTool** (the built product)
   - Check **Code Sign On Copy**

### Verify App Build Phases

Key phases:
1. Compile Sources
2. Link Binary With Libraries
3. **Embed Helper Tool** (newly added)
4. Copy Bundle Resources

## Step 5: Configure Code Signing

### Helper Tool Signing

1. **Select HelperTool Target**:
   - Build Settings → Signing

2. **Configure Signing**:
   - **Code Signing Identity**: Apple Development
   - **Development Team**: Select your team
   - **Code Signing Entitlements**: `HelperTool/HelperTool.entitlements`
   - **Enable Hardened Runtime**: ✅ YES
   - **Other Code Signing Flags**: (leave empty)

### Main App Signing

1. **Select CraigOTerminator Target**:
   - Build Settings → Signing

2. **Verify Signing**:
   - **Code Signing Identity**: Apple Development
   - **Development Team**: Same as helper
   - **Code Signing Entitlements**: `CraigOTerminator/CraigOTerminator.entitlements`
   - **Enable Hardened Runtime**: ✅ YES

**CRITICAL**: Both app and helper MUST use the same development team and signing certificate.

## Step 6: Configure Build Settings

### Helper Tool Settings

1. **Select HelperTool Target** → Build Settings

2. **Product Settings**:
   - **Product Name**: `ai.neuralquantum.CraigOTerminator.helper`
   - **Product Bundle Identifier**: `ai.neuralquantum.CraigOTerminator.helper`
   - **Info.plist File**: `HelperTool/Info.plist`

3. **Deployment**:
   - **macOS Deployment Target**: 14.0
   - **Skip Install**: NO

4. **Linking**:
   - **Other Linker Flags**: `-sectcreate __TEXT __info_plist $(SRCROOT)/HelperTool/Info.plist -sectcreate __TEXT __launchd_plist $(SRCROOT)/HelperTool/launchd.plist`

### Main App Settings

1. **Select CraigOTerminator Target** → Build Settings

2. **Verify Settings**:
   - **Info.plist File**: `CraigOTerminator/Info.plist`
   - **Code Signing Entitlements**: `CraigOTerminator/CraigOTerminator.entitlements`

## Step 7: Update Info.plist Files

### Helper Info.plist

Located at `HelperTool/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>ai.neuralquantum.CraigOTerminator.helper</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>SMAuthorizedClients</key>
    <array>
        <string>identifier "ai.neuralquantum.CraigOTerminator" and anchor apple generic and certificate leaf[subject.CN] = "Apple Development: * (*)" and certificate 1[field.1.2.840.113635.100.6.2.1] /* exists */</string>
    </array>
</dict>
</plist>
```

**Key Points**:
- `CFBundleIdentifier` must match helper bundle ID
- `SMAuthorizedClients` restricts which apps can use helper
- Certificate requirement matches development certificate

### App Info.plist

No changes needed to main app's Info.plist.

## Step 8: Update Entitlements

### App Entitlements

File: `CraigOTerminator/CraigOTerminator.entitlements`

Already updated with:
```xml
<key>SMPrivilegedExecutables</key>
<dict>
    <key>ai.neuralquantum.CraigOTerminator.helper</key>
    <string>identifier "ai.neuralquantum.CraigOTerminator.helper" and anchor apple generic and certificate leaf[subject.CN] = "Apple Development: * (*)" and certificate 1[field.1.2.840.113635.100.6.2.1] /* exists */</string>
</dict>
```

**Key Points**:
- Key name is helper bundle ID
- Value is code signature requirement (must match `SMAuthorizedClients`)
- Sandboxing must be enabled (`com.apple.security.app-sandbox`)

### Helper Entitlements

File: `HelperTool/HelperTool.entitlements`

Minimal entitlements for helper:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
</dict>
</plist>
```

**Note**: Helper is NOT sandboxed (it needs full system access).

## Step 9: Build and Verify

### Clean Build

1. Product → Clean Build Folder (Cmd+Shift+K)
2. Product → Build (Cmd+B)
3. Check for errors

### Verify Helper Embedding

1. **Build the app**
2. **Show in Finder**: Right-click on CraigOTerminator.app → Show in Finder
3. **Show Package Contents**: Right-click → Show Package Contents
4. **Verify structure**:
   ```
   CraigOTerminator.app/
   └── Contents/
       ├── MacOS/
       │   └── CraigOTerminator
       ├── Library/
       │   └── LaunchServices/
       │       └── ai.neuralquantum.CraigOTerminator.helper
       ├── Resources/
       └── Info.plist
   ```

5. **Verify helper contents**:
   ```bash
   cd CraigOTerminator.app/Contents/Library/LaunchServices/
   codesign -dv --verbose=4 ai.neuralquantum.CraigOTerminator.helper
   ```

   Should show:
   - Identifier: `ai.neuralquantum.CraigOTerminator.helper`
   - Signed with valid certificate
   - Hardened runtime enabled

### Verify Code Signatures

```bash
# Verify app signature
codesign -dv --verbose=4 CraigOTerminator.app

# Verify helper signature
codesign -dv --verbose=4 CraigOTerminator.app/Contents/Library/LaunchServices/ai.neuralquantum.CraigOTerminator.helper

# Verify entitlements
codesign -d --entitlements - CraigOTerminator.app
codesign -d --entitlements - CraigOTerminator.app/Contents/Library/LaunchServices/ai.neuralquantum.CraigOTerminator.helper
```

## Step 10: Test Installation

### Run App

1. **Run the app**: Product → Run (Cmd+R)
2. **Open Settings** (if implemented) or trigger helper installation
3. **Click "Install Helper"**
4. **Enter administrator password** when prompted
5. **Verify installation success**

### Verify Installation

```bash
# Check if helper is installed
launchctl list | grep CraigOTerminator

# Should show:
# PID    Status    Label
# -      0         ai.neuralquantum.CraigOTerminator.helper

# Check helper registration
launchctl print system/ai.neuralquantum.CraigOTerminator.helper
```

### Test Elevated Capability

1. In the app, try an elevated capability (e.g., "Purge Memory")
2. Should execute successfully via helper
3. Check logs:
   ```bash
   log show --predicate 'subsystem == "ai.neuralquantum.CraigOTerminator.helper"' --last 5m
   ```

## Troubleshooting

### Build Errors

#### "No such file or directory: HelperTool/main.swift"
- Verify file is added to HelperTool target
- Check Target Membership in File Inspector

#### "Undefined symbol: _main"
- Ensure main.swift is in Compile Sources build phase
- Check that main.swift has proper entry point

#### "Code signing entitlements file not found"
- Verify entitlements file path in Build Settings
- Ensure entitlements file is in project

### Installation Errors

#### "SMJobBless returned false"
- Check that both app and helper are signed with same team
- Verify `SMAuthorizedClients` matches helper bundle ID
- Ensure launchd.plist is embedded in helper

#### "Authorization failed"
- User must be administrator
- Check that authorization prompt appears
- Verify entitlements are correct

#### "Helper not found in app bundle"
- Check that helper is embedded via Copy Files phase
- Verify path: `Contents/Library/LaunchServices/`
- Ensure "Code Sign On Copy" is enabled

### Runtime Errors

#### "XPC connection failed"
- Helper may not be installed correctly
- Try uninstalling and reinstalling
- Check launchctl list for helper

#### "Command not allowed"
- Verify command is in helper's allowlist
- Check command path is absolute
- Ensure capability has correct privilege level

## Production Release

For production releases:

1. **Use Release Signing**:
   - Switch to "Mac Developer ID" certificate
   - Update signature requirements in entitlements
   - Update `SMAuthorizedClients` with production certificate

2. **Notarization**:
   - App must be notarized for Gatekeeper
   - Helper is notarized as part of app bundle
   - Use `xcrun notarytool` for submission

3. **Archive**:
   - Product → Archive
   - Distribute via Developer ID
   - Include helper in distribution package

## References

- [Apple: Installing a Privileged Helper Tool](https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecureCodingGuide/Articles/AccessControl.html)
- [Apple: EvenBetterAuthorizationSample](https://developer.apple.com/library/archive/samplecode/EvenBetterAuthorizationSample/)
- [Apple: Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Apple: Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

## Summary Checklist

Before committing:
- ✅ Helper target created
- ✅ main.swift added to helper target
- ✅ HelperProtocol.swift shared between targets
- ✅ Info.plist configured correctly
- ✅ launchd.plist embedded in helper
- ✅ Helper embedded in app bundle
- ✅ Code signing configured (same team for both)
- ✅ Entitlements updated
- ✅ Build succeeds without errors
- ✅ Helper visible in app bundle
- ✅ Signatures verified
- ✅ Installation tested
- ✅ Elevated command tested
- ✅ Logs verified

---

**Important**: This configuration must be done manually in Xcode. The project file changes cannot be scripted reliably. Follow these steps carefully to ensure proper helper integration.
