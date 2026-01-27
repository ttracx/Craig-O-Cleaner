# Slice B: Xcode Project Integration Steps

## Files to Add to Xcode Project

### Step 1: Add Execution Files
Add these files to the project under `CraigOTerminator/Core/Execution`:

1. `ProcessRunner.swift`
2. `UserExecutor.swift`
3. `OutputParsers.swift`
4. `ExecutionExample.swift` (optional, for reference only)

**How to add:**
1. Open `CraigOTerminator.xcodeproj` in Xcode
2. Right-click on the "Core" group in the navigator
3. Select "Add Files to CraigOTerminator..."
4. Navigate to `CraigOTerminator/Core/Execution/`
5. Select all `.swift` files (except `ExecutionExample.swift` if not needed)
6. Ensure "Copy items if needed" is UNCHECKED (files are already in place)
7. Ensure "Create groups" is selected
8. Click "Add"

### Step 2: Add Logging Files
Add these files to the project under `CraigOTerminator/Core/Logging`:

1. `RunRecord.swift`
2. `SQLiteLogStore.swift`

**How to add:**
Follow same process as Step 1, but select files from `CraigOTerminator/Core/Logging/`

### Step 3: Add Test Files
Add test files to the test target:

1. `ExecutionTests.swift`

**How to add:**
1. Right-click on the "Tests" group
2. Add Files → Navigate to `CraigOTerminator/Tests/ExecutionTests/`
3. Select `ExecutionTests.swift`
4. Ensure target membership includes the test target
5. Click "Add"

### Step 4: Link SQLite3 Framework

**Required for SQLiteLogStore to compile:**

1. Select the project in the navigator (top-level)
2. Select the "CraigOTerminator" target
3. Go to "Build Phases" tab
4. Expand "Link Binary With Libraries"
5. Click the "+" button
6. Search for "sqlite3"
7. Select "libsqlite3.tbd"
8. Click "Add"

### Step 5: Import CryptoKit (Already in Swift)

CryptoKit is part of the standard library in macOS 11+, so no additional linking needed. However, ensure your deployment target is set correctly:

1. Select the project → CraigOTerminator target
2. Go to "Build Settings"
3. Search for "macOS Deployment Target"
4. Ensure it's set to **macOS 11.0 or later** (required for CryptoKit)

### Step 6: Build and Test

**Build the project:**
```bash
# From command line
cd /Volumes/VibeStore/Craig-O-Cleaner/TerminatorEdition/Xcode
xcodebuild -project CraigOTerminator.xcodeproj -scheme CraigOTerminator -configuration Debug
```

**Or in Xcode:**
- Press Cmd+B to build

**Run tests:**
```bash
# From command line
xcodebuild test -project CraigOTerminator.xcodeproj -scheme CraigOTerminator
```

**Or in Xcode:**
- Press Cmd+U to run tests

## Expected Compiler Warnings/Errors (and fixes)

### Issue 1: Missing Imports
If you see "Cannot find type 'Capability' in scope", ensure:
- The Slice A files (`Capability.swift`, `CapabilityCatalog.swift`) are in the project
- They are in the same target

### Issue 2: @Observable Not Found
If "@Observable macro not found":
- Ensure project is targeting macOS 14.0+ (Sonata requirement)
- Or change to `@MainActor class` with `@Published` properties

### Issue 3: SQLITE_TRANSIENT Undefined
If you see "Cannot find 'SQLITE_TRANSIENT' in scope":
- Add this at the top of `SQLiteLogStore.swift`:
```swift
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
```

### Issue 4: NSWorkspace Not Found (macOS only)
This should work automatically on macOS, but if missing:
```swift
import AppKit  // Add to UserExecutor.swift if needed
```

## Verification Steps

After integration, verify everything works:

### 1. Run Capability Catalog Tests
```bash
xcodebuild test -project CraigOTerminator.xcodeproj -scheme CraigOTerminator -only-testing:CapabilityTests
```

Should pass all tests from Slice A.

### 2. Run Execution Tests
```bash
xcodebuild test -project CraigOTerminator.xcodeproj -scheme CraigOTerminator -only-testing:ExecutionTests
```

Should pass all 20+ tests from Slice B.

### 3. Quick Integration Test

Add this to your app somewhere (e.g., in a button action):

```swift
Button("Test Execution") {
    Task {
        let catalog = CapabilityCatalog.shared
        let executor = UserExecutor()

        if let capability = catalog.capability(id: "diag.sys.version") {
            do {
                let result = try await executor.execute(capability, arguments: [:])
                print("✅ Execution successful!")
                print("Exit code: \(result.exitCode)")
                print("Output: \(result.stdout)")
            } catch {
                print("❌ Execution failed: \(error)")
            }
        }
    }
}
```

Run the app and click the button. Check Xcode console for output.

### 4. Verify Database Creation

After running a capability, check that the database was created:

```bash
ls -lh ~/Library/Application\ Support/CraigOTerminator/
```

Should show:
- `logs.sqlite` (SQLite database)
- `logs/` directory (for large outputs)

### 5. Query the Database

```bash
sqlite3 ~/Library/Application\ Support/CraigOTerminator/logs.sqlite "SELECT * FROM run_records;"
```

Should show your test execution records.

## Common Integration Issues

### Issue: "Duplicate Symbol" Errors
**Cause:** Files added to both app and test targets
**Fix:** Remove files from test target (they should only be in main target)

### Issue: Tests Can't Find Main Target Classes
**Cause:** Test target doesn't have access to main module
**Fix:** Use `@testable import CraigOTerminator` in test files

### Issue: Runtime Crash - "Database locked"
**Cause:** Multiple SQLiteLogStore instances accessing same DB
**Fix:** Always use `SQLiteLogStore.shared` singleton

### Issue: "Permission denied" Writing to Application Support
**Cause:** Sandbox restrictions
**Fix:** Update `CraigOTerminator.entitlements`:
```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.app-sandbox</key>
<true/>
```

## Alternative: Add via Script

If you prefer automation, save this as `add_slice_b_files.sh`:

```bash
#!/bin/bash

PROJECT_DIR="/Volumes/VibeStore/Craig-O-Cleaner/TerminatorEdition/Xcode"
cd "$PROJECT_DIR"

echo "Adding Slice B files to Xcode project..."

# This would require xcodeproj gem or PlistBuddy manipulation
# Manual addition via Xcode GUI is recommended for first-time integration

echo "Please add files manually via Xcode for now."
echo "See SliceB_Xcode_Integration_Steps.md for instructions."
```

## Post-Integration Checklist

- [ ] All 6 Swift files added to project
- [ ] libsqlite3.tbd linked
- [ ] Project builds without errors
- [ ] Unit tests run and pass
- [ ] Integration test button works
- [ ] Database file created in Application Support
- [ ] No runtime crashes
- [ ] Console shows execution logs

## Next Steps After Integration

Once Slice B is integrated:

1. **Test with Real Capabilities**: Try executing different diagnostic capabilities from the catalog
2. **Check Log Store UI**: Create a view to display execution history
3. **Add Error Handling UI**: Show user-friendly errors if execution fails
4. **Implement Cancellation**: Add UI to cancel long-running operations
5. **Begin Slice C**: Start implementing elevated execution and permission handling

---

**Need Help?**

If you encounter issues during integration, check:
1. Build logs in Xcode (View → Navigators → Report Navigator)
2. Console output when running tests
3. Crash logs in Console.app if runtime errors occur

**Common Success Indicators:**
- ✅ Project builds: "Build Succeeded"
- ✅ Tests pass: "Test Succeeded"
- ✅ Database created in correct location
- ✅ Execution logs visible in Xcode console
- ✅ No memory leaks (run with Instruments → Leaks)
