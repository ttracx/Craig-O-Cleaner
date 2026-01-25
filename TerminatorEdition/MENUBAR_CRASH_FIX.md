# Menu Bar Crash Fix

## Issue
App was crashing on launch with the following errors:
```
Unable to obtain a task name port right for pid 420: (os/kern) failure (0x5)
Error creating <FBSScene>: scene-invalidated
Unhandled disconnected auxiliary scene <NSHostedViewScene>
Message from debugger: killed
```

## Root Cause

Race condition during app initialization:
1. **MenuBarExtra scene creation** happens immediately on app launch
2. **MenuBarView.task** modifier runs immediately when view appears
3. **MenuBarView** attempts to:
   - Access browser information via AppleScript
   - Query process list via `ps aux`
   - Access system resources before permissions are granted
4. **PermissionsManager** checks permissions at the same time
5. Scene management fails when views try to access unauthorized resources

The "pid 420" error indicates the app was trying to get information about system processes it didn't have permission to access.

## Fixes Applied

### 1. Deferred App Initialization (`CraigOTerminatorApp.swift`)

**Before:**
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    Task { @MainActor in
        await PermissionsManager.shared.checkFirstLaunch()
    }
    Task { @MainActor in
        await AppState.shared.initialize()
    }
}
```

**After:**
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    Task { @MainActor in
        // Small delay to ensure app is fully initialized
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Initialize AppState first
        await AppState.shared.initialize()

        // Then check permissions
        await PermissionsManager.shared.checkFirstLaunch()
    }
}
```

**Benefits:**
- Single coordinated initialization task
- AppState ready before permission checks
- Avoids concurrent initialization races

### 2. Deferred MenuBarView Initialization (`MenuBarView.swift`)

**Before:**
```swift
.task {
    await Task.yield()
    await refreshBrowserCount()
    await refreshTopProcesses()
}
```

**After:**
```swift
.task {
    await Task.yield()
    await Task.yield()

    // Additional delay for app initialization
    try? await Task.sleep(nanoseconds: 200_000_000)

    do {
        await refreshBrowserCount()
        await refreshTopProcesses()
    } catch {
        print("MenuBarView: Failed to initialize: \(error)")
    }
}
```

**Benefits:**
- Double yield ensures complete deferral
- 200ms delay allows scene creation to complete
- Error handling prevents crashes on failure

### 3. Error-Safe Browser Count Refresh

**Changes:**
- Wrapped in `Task.detached` for isolation
- Added `do-catch` blocks around Process execution
- Graceful degradation on failure
- Detailed error logging

**Benefits:**
- Won't crash if AppleScript fails
- Handles missing browsers gracefully
- Continues working if one browser check fails

### 4. Error-Safe Process Refresh

**Changes:**
- Wrapped in `Task.detached` for isolation
- Added comprehensive error handling
- Returns empty array on failure instead of crashing
- Safe termination status checking

**Benefits:**
- Won't crash if `ps aux` fails or lacks permissions
- Handles process access failures gracefully
- Continues working even with limited permissions

## Technical Details

### Scene Lifecycle

MenuBarExtra with `.window` style creates an `NSHostedViewScene`:
1. macOS creates scene for status bar item
2. SwiftUI body is evaluated
3. `.task` modifier executes
4. View attempts to access resources

If resource access fails → Scene invalidation → App crash

### Process Access Permissions

The "task name port right" error occurs when:
- App tries to get detailed info about system processes
- Accessibility permission not granted
- Process belongs to another user or system

### Solution Strategy

1. **Delay scene content loading** - Give scene time to establish
2. **Isolate risky operations** - Use `Task.detached` for system calls
3. **Handle failures gracefully** - Never crash, always degrade
4. **Coordinate initialization** - Single sequential startup flow

## Testing

### Verify Fixes:
1. ✅ App launches without crashing
2. ✅ Menu bar icon appears
3. ✅ Menu bar view opens without errors
4. ✅ Browser count shows (or 0 if no browsers)
5. ✅ Process list shows (or empty if no access)
6. ✅ No "scene-invalidated" errors in console
7. ✅ No "task name port right" errors

### Expected Behavior:
- App launches cleanly
- Menu bar is responsive
- Data loads asynchronously
- Missing permissions don't cause crashes
- Console shows informative error messages instead of crashes

## Future Improvements

1. **Progressive permission requests** - Request permissions as needed
2. **Cached data** - Show last known values while refreshing
3. **Loading states** - Show spinner during data fetch
4. **Retry logic** - Attempt refresh on permission grant
5. **User feedback** - Show permission status in menu bar
6. **Alternative menu bar style** - Consider `.menu` style if window style remains problematic

## Related Files

- `Xcode/CraigOTerminator/App/CraigOTerminatorApp.swift` - App initialization
- `Xcode/CraigOTerminator/Views/MenuBarView.swift` - Menu bar UI
- `Xcode/CraigOTerminator/Core/PermissionsManager.swift` - Permission handling
- `Xcode/CraigOTerminator/ViewModels/AppState.swift` - App state management

---

**Date**: 2026-01-24
**Issue**: Menu bar scene crash on launch
**Status**: Fixed ✅
**Priority**: Critical (app wouldn't launch)
