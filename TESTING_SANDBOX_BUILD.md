# Testing Sandbox Build Configuration

## ✅ Configuration Complete

The build settings have been configured as follows:

- **Debug Configuration**: Uses `Craig-O-Clean-Debug.entitlements` (NO sandbox)
  - Permissions preserved between runs
  - Best for development and testing
  - Browser tabs work immediately

- **Release Configuration**: Uses `Craig-O-Clean-Release.entitlements` (WITH sandbox)
  - Sandbox enabled for App Store submission
  - Permissions reset on first sandboxed launch
  - Shows automated migration and permission flow

## Testing Instructions

### Test 1: Debug Build (No Sandbox) - Verify Working State

1. **Build in Debug Configuration**:
   - In Xcode: Product → Scheme → Edit Scheme...
   - Select **Run** in left sidebar
   - Change **Build Configuration** to **Debug**
   - Close scheme editor

2. **Run the App** (Cmd+R):
   - App should launch normally
   - Browser Tabs should show tabs (if permissions already granted)
   - Permissions should remain as they were before
   - No migration notice should appear

3. **Expected Behavior**:
   - ✅ App launches without any permission prompts
   - ✅ Browser automation works immediately
   - ✅ No sandbox restrictions
   - ✅ Same behavior as before sandbox implementation

### Test 2: Release Build (Sandboxed) - First Launch

1. **Clean Build Folder**:
   - Product → Clean Build Folder (Cmd+Shift+K)
   - Or manually delete DerivedData:
     ```bash
     rm -rf ~/Library/Developer/Xcode/DerivedData/Craig-O-Clean-*
     ```

2. **Switch to Release Configuration**:
   - Product → Scheme → Edit Scheme...
   - Select **Run** in left sidebar
   - Change **Build Configuration** to **Release**
   - Close scheme editor

3. **Build and Run** (Cmd+R):
   - App will be built with sandbox enabled
   - Launch will be slower (Release build)

4. **Expected Behavior - Sandbox Migration Notice**:
   - ✅ Should show **"Security Upgrade"** sheet
   - ✅ Explains sandbox benefits and permission reset
   - ✅ Click **"Continue"** to proceed

5. **Expected Behavior - Automatic Permission Flow**:
   After migration notice:
   - ✅ Should show **"Welcome"** screen
   - ✅ Click **"Get Started"**
   - ✅ Shows **Accessibility** step with instructions
   - ✅ Click **"Open System Settings"** - should open to Accessibility panel
   - ✅ Grant permission in System Settings
   - ✅ Flow should **auto-detect** permission and advance automatically
   - ✅ Repeat for **Full Disk Access**
   - ✅ Repeat for **Browser Automation**
   - ✅ Shows **"All Set!"** completion screen
   - ✅ Click **"Done"** to finish

6. **Verify Browser Tabs Work**:
   - Navigate to **Browser Tabs** view
   - Click **"Refresh Tabs"**
   - ✅ Should show browser tabs (Safari, Chrome, etc.)
   - ✅ No crashes or errors

### Test 3: Release Build - Subsequent Launches

1. **Quit and Relaunch** the Release build:
   - Permissions should remain granted
   - No migration notice should appear
   - No permission flow should appear
   - App should work normally

2. **Expected Behavior**:
   - ✅ Direct launch to main app interface
   - ✅ Browser tabs work immediately
   - ✅ All permissions preserved

### Test 4: Permission Auto-Detection

1. **During Permission Flow**:
   - On any permission step (Accessibility, Full Disk Access, or Browser Automation)
   - Click **"Open System Settings"**
   - **While keeping the app open**, grant the permission in System Settings

2. **Expected Behavior**:
   - ✅ Shows "Waiting for permission..." with spinner
   - ✅ After ~1 second, detects permission is granted
   - ✅ Automatically advances to next step
   - ✅ No need to click "Next" button

### Test 5: Switching Between Configurations

1. **Switch back to Debug** and run:
   - Should work without any permission reset
   - Permissions from previous Debug runs preserved

2. **Switch to Release** and run:
   - Should work with sandbox
   - Permissions from previous Release runs preserved
   - No migration notice (already completed)

## Troubleshooting

### Issue: Compilation Errors

**Error**: "File not found" for entitlements
- **Solution**: Verify files exist:
  ```bash
  ls -la Craig-O-Clean/Craig-O-Clean-Debug.entitlements
  ls -la Craig-O-Clean/Craig-O-Clean-Release.entitlements
  ```
- Ensure files are added to Xcode project

**Error**: "Cannot find 'SandboxMigrationManager' in scope"
- **Solution**: Verify Swift files are added:
  ```bash
  ls -la Craig-O-Clean/Core/SandboxMigrationManager.swift
  ls -la Craig-O-Clean/Core/AutomaticPermissionFlow.swift
  ```
- Clean build folder and rebuild

### Issue: Migration Notice Doesn't Appear

**Problem**: Release build doesn't show migration notice
- **Solution**: This is expected if:
  - You've never run a non-sandboxed version before (fresh install)
  - You've already completed migration once
- To reset migration for testing:
  ```bash
  defaults delete com.craigoclean.app hasCompletedSandboxMigration
  ```

### Issue: Permission Flow Doesn't Auto-Detect

**Problem**: Flow shows "Waiting for permission..." but doesn't advance
- **Solution**: Check that:
  - App is still running (don't quit after granting permission)
  - Permission was granted for the correct app (Craig-O-Clean)
  - Check Console.app for permission check logs
  - Try manually clicking "Skip" button if it appears

### Issue: Browser Tabs Still Don't Work

**Problem**: After granting all permissions, browser tabs still show 0
- **Solution**:
  1. Check System Settings → Privacy & Security → Automation
  2. Verify Craig-O-Clean has checkmarks for Safari, Chrome, etc.
  3. Try resetting automation permission:
     ```bash
     tccutil reset AppleEvents com.craigoclean.app
     ```
  4. Relaunch app and go through permission flow again

### Issue: Crash When Clicking "Refresh Tabs"

**Problem**: App crashes with objc_release error
- **Solution**: This should be fixed by the NSAppleScript threading fix
- If still occurs:
  1. Check that `BrowserAutomationService.swift` has the fix
  2. Look for `DispatchQueue.main.async` in `executeAppleScript` method
  3. Clean build and rebuild

## Verification Checklist

Before considering testing complete:

### Debug Build:
- [ ] Builds without errors
- [ ] Launches without permission prompts
- [ ] Browser tabs work immediately
- [ ] No migration notice appears
- [ ] No sandbox restrictions

### Release Build - First Launch:
- [ ] Builds without errors
- [ ] Shows "Security Upgrade" migration notice
- [ ] Shows "Welcome" permission flow screen
- [ ] "Open System Settings" buttons work for all steps
- [ ] Auto-detects granted permissions
- [ ] Advances automatically after each permission
- [ ] Shows "All Set!" completion screen
- [ ] Browser tabs work after completion

### Release Build - Subsequent Launches:
- [ ] No migration notice
- [ ] No permission flow
- [ ] Direct launch to main app
- [ ] Browser tabs work immediately
- [ ] All features functional

### Both Configurations:
- [ ] Can switch between Debug and Release
- [ ] Each maintains its own permission state
- [ ] No crashes or errors
- [ ] Memory and CPU usage normal

## Next Steps After Testing

1. **If all tests pass**:
   - Commit changes to git
   - Update version number
   - Create distribution build for TestFlight/App Store

2. **If issues found**:
   - Document the issue
   - Check relevant source file
   - Review fix and retest

## Files Modified

- `Craig-O-Clean.xcodeproj/project.pbxproj` - Build configuration
- `Craig-O-Clean/Craig-O-Clean-Release.entitlements` - Sandboxed entitlements (NEW)
- `Craig-O-Clean/Core/SandboxMigrationManager.swift` - Migration detection (NEW)
- `Craig-O-Clean/Core/AutomaticPermissionFlow.swift` - Automated permission flow (NEW)
- `Craig-O-Clean/Core/BrowserAutomationService.swift` - Threading fix for sandbox
- `Craig-O-Clean/UI/MainAppView.swift` - Integration of flows
- `Craig-O-Clean/UI/MenuBarContentView.swift` - Integration of flows

## Support

If you encounter issues not covered here:
1. Check Console.app for Craig-O-Clean logs
2. Check `SANDBOX_MIGRATION_GUIDE.md` for additional context
3. Review `XCODE_INTEGRATION_STEPS.md` for setup verification
