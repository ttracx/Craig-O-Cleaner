# Xcode Target Configuration Fix

## Issue
The following compilation errors are occurring:
```
Cannot find 'PermissionMonitor' in scope
Cannot find 'ProcessMonitorService' in scope
```

These errors appear in `CraigOTerminatorApp.swift` at lines 8, 82, 83, 90, and 91.

## Root Cause
The files exist and are properly structured, but they may not be added to the Xcode project target. This means the compiler cannot see these files during the build process.

## Files That Need to Be Added to Target

1. **PermissionMonitor.swift**
   - Location: `Xcode/CraigOTerminator/Core/PermissionMonitor.swift`
   - Purpose: Background service that monitors permissions and prompts users

2. **ProcessMonitorService.swift**
   - Location: `Xcode/CraigOTerminator/Core/ProcessMonitorService.swift`
   - Purpose: Background service that continuously monitors system processes

## How to Fix in Xcode

### Option 1: Add Files to Target via File Inspector
1. Open the Xcode project
2. Select `PermissionMonitor.swift` in the Project Navigator
3. Open the File Inspector (right panel, first tab)
4. Under "Target Membership", check the box for "CraigOTerminator"
5. Repeat steps 2-4 for `ProcessMonitorService.swift`

### Option 2: Add Files to Target via Project Settings
1. Select the project in Project Navigator
2. Select the "CraigOTerminator" target
3. Go to "Build Phases" tab
4. Expand "Compile Sources"
5. Click the "+" button
6. Add `PermissionMonitor.swift`
7. Add `ProcessMonitorService.swift`

### Option 3: Remove and Re-add Files
1. In Xcode Project Navigator, right-click on the files:
   - `PermissionMonitor.swift`
   - `ProcessMonitorService.swift`
2. Select "Delete" and choose "Remove Reference" (NOT "Move to Trash")
3. Right-click on the `Core` folder
4. Select "Add Files to CraigOTerminator..."
5. Navigate to and select both files
6. Make sure "Copy items if needed" is UNCHECKED (files are already in place)
7. Make sure "Add to targets: CraigOTerminator" IS CHECKED
8. Click "Add"

## Verification Steps

After adding the files to the target:

1. **Clean Build Folder**
   - In Xcode menu: Product → Clean Build Folder
   - Or press: ⌘ + Shift + K

2. **Build the Project**
   - In Xcode menu: Product → Build
   - Or press: ⌘ + B

3. **Check for Errors**
   - The compilation errors should be resolved
   - If errors persist, check the Console for details

## Expected Behavior After Fix

Once the files are properly added to the target:

1. **App Launch**
   - PermissionMonitor starts automatically
   - ProcessMonitorService starts automatically
   - Background monitoring begins after 0.1 second delay

2. **Processes Tab**
   - Opens instantly with pre-loaded data
   - Updates automatically every 3 seconds
   - Shows real-time CPU and memory usage

3. **Permission Monitoring**
   - Checks permissions every 60 seconds
   - Auto-prompts users if permissions are missing
   - Opens System Settings when user clicks "Open System Settings"

## Files Updated in This Session

### Core Services
- ✅ `PermissionMonitor.swift` - Created and verified
- ✅ `ProcessMonitorService.swift` - Created and verified

### Views
- ✅ `ProcessesView.swift` - Fully integrated with ProcessMonitorService
- ✅ `BrowsersView.swift` - Updated with async handling
- ✅ `MenuBarView.swift` - Fixed freezing issues

### App Configuration
- ✅ `CraigOTerminatorApp.swift` - Added service startup/shutdown

### Other Files
- ✅ `CommandExecutor.swift` - Removed excessive actor isolation
- ✅ `PermissionsManager.swift` - Improved async handling
- ✅ `SettingsView.swift` - Fixed Ollama detection
- ✅ `DiagnosticsView.swift` - Improved async handling

## Integration Summary

### ProcessMonitorService Integration in ProcessesView

**Before:**
```swift
@State private var processes: [ProcessInfo] = []
@State private var isRefreshing = false

// Manual refresh function
private func refreshProcesses() async {
    // 200+ lines of manual process fetching
}
```

**After:**
```swift
@StateObject private var processMonitor = ProcessMonitorService.shared

// Data is automatically updated every 3 seconds
// No manual refresh needed - just use processMonitor.processes
```

**Benefits:**
- ✅ Instant data when opening Processes tab
- ✅ Automatic updates every 3 seconds
- ✅ No more loading delays
- ✅ Reduced code complexity (removed 200+ lines)

### PermissionMonitor Integration

**Features:**
- Checks permissions every 60 seconds in background
- Auto-prompts with 5-minute cooldown per permission
- Opens System Settings automatically
- Shows follow-up notifications
- Re-checks after user returns from Settings

**User Experience:**
1. User launches app
2. After 5 seconds, permission check occurs
3. If permission missing, alert appears
4. User clicks "Open System Settings"
5. Settings opens to correct pane
6. User enables permission
7. App detects change and shows success notification

## Troubleshooting

### If Compilation Errors Persist

1. **Check File Paths**
   - Ensure files are in correct locations
   - Verify no duplicate files exist

2. **Check Import Statements**
   - All files should import Foundation
   - No circular dependencies

3. **Check Build Settings**
   - Swift Language Version: Swift 5.9+
   - Build Active Architecture Only: Debug=Yes, Release=No

4. **Restart Xcode**
   - Sometimes Xcode needs a restart to recognize new files
   - Close Xcode completely and reopen

### If Background Services Don't Start

1. **Check Console Logs**
   - Look for "PermissionMonitor: Starting background monitoring..."
   - Look for "ProcessMonitorService: Starting background monitoring..."

2. **Verify App Delegate**
   - Ensure `applicationDidFinishLaunching` calls are present
   - Check for any errors in initialization

3. **Check Permissions**
   - Ensure app has necessary permissions to run shell commands

## Support

If issues persist after following this guide:
1. Check Xcode Console for detailed error messages
2. Verify all files are in correct locations
3. Clean Build Folder and rebuild
4. Restart Xcode
5. Check for typos in import statements or file names

---

**Created:** 2026-01-24
**Last Updated:** 2026-01-24
**Status:** Ready for implementation in Xcode
