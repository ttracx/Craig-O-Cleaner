# SwiftUI State Management Fixes

## Issues Fixed

### 1. Ollama Detection Issue
**Problem**: Ollama showing as "Not Installed" despite being installed locally.

**Root Cause**: `SettingsView.swift:404-420` was using `/usr/bin/which ollama` to detect installation, but this doesn't work reliably in GUI app contexts where PATH may not be fully configured.

**Fix**: Modified `checkOllamaInstallation()` to:
- First check directly for file existence at `/usr/local/bin/ollama`
- Fall back to `which` command only if direct check fails

**Files Modified**: `Xcode/CraigOTerminator/Views/SettingsView.swift`

---

### 2. Menu Bar "Purge Memory" Freezing Issue
**Problem**: Clicking "Purge Memory" from menu bar froze the app and showed "Publishing changes during view updates" warnings.

**Root Cause**: `MenuBarView.swift:570-584` was running `osascript` with administrator privileges synchronously on the main thread, blocking the UI while waiting for the password prompt.

**Fix**: Modified `purgeMemory()` and `flushDNS()` to:
- Run privileged operations in `Task.detached` to avoid blocking main thread
- Defer state updates until after operation completes
- Show success messages after completion

**Files Modified**: `Xcode/CraigOTerminator/Views/MenuBarView.swift`

---

### 3. "Publishing Changes During View Updates" Warnings
**Problem**: SwiftUI runtime warnings about publishing changes within view updates appearing throughout the app.

**Root Cause**: Multiple `.task` modifiers and lifecycle callbacks were updating `@Published` properties immediately during view rendering cycles.

**Fixes Applied**:

#### SettingsView.swift (AISettingsView)
- Added `await Task.yield()` at start of `.task` modifier to defer initialization
- Prevents state updates during initial view rendering

#### MenuBarView.swift
- Added `await Task.yield()` to `.task` modifier
- Defers browser count and process list refreshes

#### BrowsersView.swift
- Added `await Task.yield()` to `.task` modifier
- Defers initial browser data loading

#### PermissionsManager.swift
- Replaced `Task.sleep()` calls with double `Task.yield()` for more reliable deferral
- Applied to:
  - `checkFirstLaunch()` - prevents sheet showing during view updates
  - `checkAllPermissions()` - defers permission status updates
  - `setupAppLifecycleObserver()` - defers re-checks when app becomes active

**Files Modified**:
- `Xcode/CraigOTerminator/Views/SettingsView.swift`
- `Xcode/CraigOTerminator/Views/MenuBarView.swift`
- `Xcode/CraigOTerminator/Views/BrowsersView.swift`
- `Xcode/CraigOTerminator/Core/PermissionsManager.swift`

---

### 4. ProgressView Configuration Warning
**Issue**: `AppKitPlatformViewHost` constraint warning about maximum length not satisfying constraints.

**Note**: This is likely a SwiftUI internal issue related to ProgressView scaling. Shouldn't affect functionality, but worth monitoring.

---

## Technical Details

### Why Task.yield() Works Better Than Task.sleep()

`Task.yield()` is specifically designed to:
1. Suspend the current task momentarily
2. Allow other pending tasks to run
3. Resume after the current run loop iteration

This is more reliable than `Task.sleep()` for deferring state updates because:
- It's explicitly meant for cooperative task switching
- It doesn't introduce arbitrary delays
- It guarantees the task continues after the current event loop pass
- Double yielding (`await Task.yield(); await Task.yield()`) ensures we're completely outside any nested view update cycles

### Why Task.detached() for Privileged Operations

Using `Task.detached` for operations requiring `osascript` with admin privileges:
1. Breaks inheritance from current actor context
2. Runs on a background thread
3. Prevents main thread blocking when password prompt appears
4. Allows UI to remain responsive during privileged operations

---

## Testing Recommendations

1. **Ollama Detection**:
   - Verify Ollama shows as "Installed" when installed at `/usr/local/bin/ollama`
   - Test with Ollama in custom locations

2. **Menu Bar Actions**:
   - Click "Purge Memory" - should not freeze UI
   - Admin password prompt should appear without blocking
   - Success message should appear after completion

3. **SwiftUI Warnings**:
   - Monitor console for "Publishing changes during view updates" warnings
   - Should be significantly reduced or eliminated
   - Pay attention to app launch, tab switching, and returning from System Settings

4. **Permission Checks**:
   - Launch app first time - permissions sheet should appear cleanly
   - Switch to System Settings and back - no UI freezing
   - Grant permissions - status should update smoothly

---

## Future Improvements

1. Consider extracting privileged command execution to a dedicated manager
2. Add loading indicators to menu bar buttons during long operations
3. Implement proper cancellation for background tasks
4. Add error handling and user feedback for failed operations
5. Consider using PermissionsKit or similar library for more robust permission handling

---

**Date**: 2026-01-24
**Issue**: Menu bar freezing and SwiftUI state update warnings
**Status**: Fixed ✅
