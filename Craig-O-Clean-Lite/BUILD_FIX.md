# Build Fix - UpgradeView Not Found

## Issue
Xcode shows: "Cannot find 'UpgradeView' in scope"

## Solution

The project has been regenerated. **You need to close and reopen Xcode:**

### Method 1: Restart Xcode (Recommended)

1. **Quit Xcode** (⌘Q)
2. **Reopen the project:**
   ```bash
   open Craig-O-Clean-Lite.xcodeproj
   ```
3. **Clean build folder:** Product → Clean Build Folder (⇧⌘K)
4. **Build:** ⌘B
5. **Run:** ⌘R

### Method 2: Force Clean

If Method 1 doesn't work:

```bash
# Close Xcode first, then:
cd "/Volumes/VibeStore/Craig-O-Cleaner/Craig-O-Clean-Lite"

# Remove derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Craig-O-Clean-Lite-*

# Regenerate project
xcodegen generate

# Reopen
open Craig-O-Clean-Lite.xcodeproj
```

Then in Xcode:
- Clean Build Folder (⇧⌘K)
- Build (⌘B)

### Method 3: Manual File Check

In Xcode:
1. **Project Navigator** (⌘1)
2. Verify these files are listed:
   - ✅ Craig_O_Clean_LiteApp.swift
   - ✅ ContentView.swift
   - ✅ SystemMonitor.swift
   - ✅ UpgradeView.swift ← Should be here!
   - ✅ UpgradeService.swift

If `UpgradeView.swift` is missing:
1. Right-click on `Craig-O-Clean-Lite` folder
2. Add Files to "Craig-O-Clean-Lite"
3. Select `UpgradeView.swift`
4. ✅ Ensure "Craig-O-Clean-Lite" target is checked

## Verification

All files exist:
```
✅ Craig-O-Clean-Lite/Craig_O_Clean_LiteApp.swift
✅ Craig-O-Clean-Lite/ContentView.swift
✅ Craig-O-Clean-Lite/SystemMonitor.swift
✅ Craig-O-Clean-Lite/UpgradeView.swift
✅ Craig-O-Clean-Lite/UpgradeService.swift
```

Project has been regenerated. Just restart Xcode!

## Still Having Issues?

Run this complete reset:

```bash
# Close Xcode completely
osascript -e 'tell application "Xcode" to quit'

# Wait a moment
sleep 3

# Clean everything
cd "/Volumes/VibeStore/Craig-O-Cleaner/Craig-O-Clean-Lite"
rm -rf ~/Library/Developer/Xcode/DerivedData/Craig-O-Clean-Lite-*
rm -rf .build
rm -rf build

# Regenerate
xcodegen generate

# Reopen
open Craig-O-Clean-Lite.xcodeproj
```

Then in Xcode:
1. Product → Clean Build Folder (⇧⌘K)
2. File → Close Workspace
3. Reopen project
4. Build (⌘B)

**This should fix it!** ✅
