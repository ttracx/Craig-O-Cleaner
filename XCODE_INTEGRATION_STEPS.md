# Xcode Integration Steps for Sandbox Support

## Overview
This guide walks through integrating the sandbox support files into the Xcode project.

## Files to Add

### 1. New Swift Files (Core Group)
Add these files to the **Core** group in Xcode:

1. **SandboxMigrationManager.swift**
   - Path: `Craig-O-Clean/Core/SandboxMigrationManager.swift`
   - Purpose: Detects sandbox migration and shows one-time notice

2. **AutomaticPermissionFlow.swift**
   - Path: `Craig-O-Clean/Core/AutomaticPermissionFlow.swift`
   - Purpose: Automated permission granting flow with visual guidance

### 2. Release Entitlements File
Add this file to the **Craig-O-Clean** group (same level as Debug entitlements):

1. **Craig-O-Clean-Release.entitlements**
   - Path: `Craig-O-Clean/Craig-O-Clean-Release.entitlements`
   - Purpose: Sandboxed entitlements for App Store builds

## Step-by-Step Instructions

### Part 1: Add Swift Files to Xcode

1. Open **Craig-O-Clean.xcodeproj** in Xcode
2. In the Project Navigator (left sidebar), locate the **Craig-O-Clean > Core** folder
3. Right-click on **Core** → **Add Files to "Craig-O-Clean"...**
4. Navigate to `/Volumes/VibeStore/Craig-O-Cleaner/Craig-O-Clean/Core/`
5. Select both:
   - `SandboxMigrationManager.swift`
   - `AutomaticPermissionFlow.swift`
6. **IMPORTANT**: Make sure these options are checked:
   - ✅ **Copy items if needed** (UNCHECK - files are already in correct location)
   - ✅ **Create groups** (not folder references)
   - ✅ **Add to targets**: Craig-O-Clean
7. Click **Add**

### Part 2: Add Release Entitlements

1. In Project Navigator, locate the **Craig-O-Clean** folder (top level, where Craig-O-Clean-Debug.entitlements is)
2. Right-click on **Craig-O-Clean** folder → **Add Files to "Craig-O-Clean"...**
3. Navigate to `/Volumes/VibeStore/Craig-O-Cleaner/Craig-O-Clean/`
4. Select `Craig-O-Clean-Release.entitlements`
5. **IMPORTANT**: Make sure these options are checked:
   - ✅ **Copy items if needed** (UNCHECK - file is already in correct location)
   - ✅ **Create groups**
   - ✅ **Add to targets**: Craig-O-Clean
6. Click **Add**

### Part 3: Configure Build Settings for Different Entitlements

1. In Xcode, click on the **Craig-O-Clean** project (blue icon at top of navigator)
2. Select the **Craig-O-Clean** target
3. Click on **Build Settings** tab
4. In the search box, type: **Code Signing Entitlements**
5. You should see **CODE_SIGN_ENTITLEMENTS** setting
6. Click the disclosure triangle next to **CODE_SIGN_ENTITLEMENTS** to expand configurations

7. **Configure Debug Configuration**:
   - For **Debug** row: `Craig-O-Clean/Craig-O-Clean-Debug.entitlements`
   - This keeps Debug builds WITHOUT sandbox (current working state)

8. **Configure Release Configuration**:
   - For **Release** row: `Craig-O-Clean/Craig-O-Clean-Release.entitlements`
   - This enables sandbox for Release builds (App Store ready)

**Visual Example**:
```
CODE_SIGN_ENTITLEMENTS
  ▼ Debug      Craig-O-Clean/Craig-O-Clean-Debug.entitlements
  ▼ Release    Craig-O-Clean/Craig-O-Clean-Release.entitlements
```

### Part 4: Verify Integration

1. Build the project (Cmd+B) in **Debug** configuration
   - Should build successfully
   - Should run WITHOUT sandbox (permissions preserved)

2. Switch to **Release** configuration:
   - Product → Scheme → Edit Scheme...
   - Select **Run** in left sidebar
   - Change **Build Configuration** to **Release**
   - Close scheme editor

3. Build the project (Cmd+B) in **Release** configuration
   - Should build successfully
   - Will run WITH sandbox (permissions will reset)

## Expected Behavior

### Debug Build (No Sandbox)
- Permissions are preserved between runs
- No migration notice shown
- Browser automation works immediately
- Best for development and testing

### Release Build (Sandboxed)
- First launch after upgrade: Shows **SandboxMigrationNotice**
- Permissions must be re-granted (Apple's security requirement)
- Shows **AutomaticPermissionFlowView** to guide users
- Auto-detects when permissions are granted
- Required for App Store submission

## Troubleshooting

### Files Not Found Error
If you see "file not found" errors:
1. Check that files exist at correct paths:
   ```bash
   ls -la /Volumes/VibeStore/Craig-O-Cleaner/Craig-O-Clean/Core/SandboxMigrationManager.swift
   ls -la /Volumes/VibeStore/Craig-O-Cleaner/Craig-O-Clean/Core/AutomaticPermissionFlow.swift
   ls -la /Volumes/VibeStore/Craig-O-Cleaner/Craig-O-Clean/Craig-O-Clean-Release.entitlements
   ```
2. Re-add files using **Add Files to "Craig-O-Clean"...** (NOT copy)

### Build Errors
If you see compilation errors:
1. Clean build folder: **Product → Clean Build Folder** (Cmd+Shift+K)
2. Quit Xcode completely
3. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Craig-O-Clean-*
   ```
4. Reopen Xcode and build again

### Permission Issues
If permissions don't work in Release build:
1. This is expected! Sandbox resets all permissions.
2. The **AutomaticPermissionFlowView** will guide users through re-granting
3. Test the flow:
   - Build in Release configuration
   - Run app
   - Follow automated permission flow
   - Verify permissions are detected automatically

## Next Steps

After completing these integration steps:

1. **Test Debug Build**:
   ```bash
   # Build and run in Debug configuration
   # Verify browser tabs work without permission reset
   ```

2. **Test Release Build**:
   ```bash
   # Build and run in Release configuration
   # Verify migration notice appears (if upgrading from non-sandboxed version)
   # Verify permission flow appears and guides through re-granting
   # Verify auto-detection works when permissions are granted
   ```

3. **Test Automated Permission Flow**:
   - Follow each step in the permission flow
   - Verify System Settings opens to correct panels
   - Verify app auto-detects granted permissions
   - Verify flow advances automatically
   - Verify completion state shows correctly

4. **Commit Changes**:
   ```bash
   git add .
   git commit -m "Add sandbox support with automated permission flow

   - Created SandboxMigrationManager for upgrade detection
   - Created AutomaticPermissionFlow for guided permission granting
   - Added Craig-O-Clean-Release.entitlements with sandbox enabled
   - Configured Debug builds without sandbox (development)
   - Configured Release builds with sandbox (App Store)
   - Fixed NSAppleScript threading for sandbox compatibility
   - Integrated flows into MainAppView and MenuBarContentView

   Closes #[issue-number]"
   ```

## Reference

- **Debug Entitlements**: `Craig-O-Clean/Craig-O-Clean-Debug.entitlements` (no sandbox)
- **Release Entitlements**: `Craig-O-Clean/Craig-O-Clean-Release.entitlements` (sandboxed)
- **Migration Manager**: `Craig-O-Clean/Core/SandboxMigrationManager.swift`
- **Permission Flow**: `Craig-O-Clean/Core/AutomaticPermissionFlow.swift`
- **Migration Guide**: `SANDBOX_MIGRATION_GUIDE.md` (for internal testers)
