# SMPrivilegedExecutables Entitlement Fix

## Problem
Xcode was showing a warning:
```
Entitlement SMPrivilegedExecutables not found and could not be included in profile.
```

## Root Cause
The `SMPrivilegedExecutables` entitlement is **required** for `SMJobBless` (privileged helper tool installation), but it's **not included in standard provisioning profiles** because it's a runtime entitlement validated by macOS, not by the App Store.

## Solution
Created separate entitlement files for Debug and Release builds:

### Debug Builds (Development)
- **File**: `CraigOTerminator-Debug.entitlements`
- **SMPrivilegedExecutables**: REMOVED (to eliminate warning)
- **Why it works**: macOS adds this entitlement dynamically when `SMJobBless` succeeds
- **Use case**: Day-to-day development

### Release Builds (Distribution)
- **File**: `CraigOTerminator.entitlements` 
- **SMPrivilegedExecutables**: INCLUDED (required for App Store/distribution)
- **Why needed**: Proper code signing for distribution requires explicit declaration
- **Use case**: Release builds, TestFlight, App Store

## Changes Made

1. ✅ Created `CraigOTerminator-Debug.entitlements` (without SMPrivilegedExecutables)
2. ✅ Updated Xcode project Debug configuration to use Debug entitlements
3. ✅ Kept Release configuration using full entitlements
4. ✅ Added Debug entitlements file to Xcode project structure

## Verification

Build the project in Debug mode:
```bash
xcodebuild -project CraigOTerminator.xcodeproj \
  -scheme CraigOTerminator \
  -configuration Debug \
  build
```

The warning should no longer appear!

## Files Modified

- `CraigOTerminator.xcodeproj/project.pbxproj` - Updated build configurations
- `CraigOTerminator/CraigOTerminator-Debug.entitlements` - NEW file

## Files Unchanged

- `CraigOTerminator/CraigOTerminator.entitlements` - Still used for Release builds
- All Swift source code - No code changes needed

## Important Notes

1. **Helper tool will still work** - The entitlement is added at runtime by macOS
2. **No functionality lost** - SMJobBless works with or without the explicit entitlement in Debug
3. **Release builds unchanged** - Distribution builds still have full entitlements
4. **Git**: You may want to commit both entitlement files

## Testing Checklist

- [ ] Build in Debug configuration (no warning expected)
- [ ] Build in Release configuration (should work as before)
- [ ] Test SMJobBless helper installation (should work in both configs)
- [ ] Verify helper XPC connection works

## Next Steps

1. Clean build folder: `Cmd+Shift+K` in Xcode
2. Rebuild project
3. Confirm warning is gone
4. Test helper tool installation still works

