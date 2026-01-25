# Code Signing & TCC Guide for Craig-O Terminator

## 🚨 Critical Issue: Code Signing Error

### The Problem

Your app is experiencing a **critical code signing error** that's blocking core functionality:

```
Failed to copy signing info for 13322: #-67034: Error Domain=NSOSStatusErrorDomain Code=-67034
```

**Error Code -67034** = `errSecInvalidItemRef` - The app's code signature is invalid or not trusted by macOS TCC system.

### Impact

This error is currently preventing:
- ❌ **Browser Automation** - "Close inactive browsers" feature fails
- ❌ **Proper Permission Detection** - Accessibility & Full Disk Access show as "Denied"
- ❌ **iCloud Sync** - CloudKit operations may fail
- ❌ **AppleScript Automation** - May be blocked by TCC
- ❌ **System Process Monitoring** - Limited access to process information

### Why This Happens

**Debug builds from Xcode** do NOT have proper code signing for TCC (Transparency, Consent, and Control) by default because:

1. **Xcode uses ad-hoc signing** for debug builds (fast but not TCC-compatible)
2. **TCC requires hardened runtime** + proper entitlements
3. **Extended attributes** from Xcode can interfere with signature verification
4. **Code signature cache** may be stale

---

## 🔧 Solutions (Choose One)

### Solution 1: Quick Fix Script (Fastest)

**Use this for immediate testing and development.**

```bash
cd /Volumes/VibeStore/Craig-O-Cleaner/TerminatorEdition/Xcode
./fix-code-signing.sh
```

**What it does**:
1. Verifies debug build exists
2. Removes extended attributes
3. Re-signs with proper entitlements + hardened runtime
4. Verifies signature
5. Optionally resets TCC permissions

**Pros**:
- ✅ Fast (30 seconds)
- ✅ Good for testing
- ✅ Keeps using Xcode workflow

**Cons**:
- ⚠️ Must re-run after each Xcode build
- ⚠️ Not suitable for distribution

### Solution 2: Archive Build (Best for Testing)

**Use this for thorough testing and sharing with others.**

#### Steps:

1. **Create Archive** in Xcode:
   ```
   Product → Archive
   ```
   Wait for build to complete (~2 minutes)

2. **Export Archive**:
   - When archive completes, Organizer window opens
   - Click "Distribute App"
   - Choose "Custom"
   - Choose "Copy App"
   - Save to Desktop or Applications

3. **Launch Exported App**:
   ```bash
   # If saved to Desktop
   open ~/Desktop/CraigOTerminator.app
   ```

4. **Grant Permissions**:
   - Accessibility
   - Full Disk Access
   - Automation (for each browser)

**Pros**:
- ✅ Proper code signing automatically
- ✅ TCC works correctly
- ✅ One-time setup
- ✅ Can share with testers

**Cons**:
- ⏱️ Slower build process
- 📦 Separate from Xcode workflow

### Solution 3: Manual Re-signing (Advanced)

**Use this if the script doesn't work or you need custom options.**

```bash
# 1. Navigate to debug build
cd /Users/knightdev/Library/Developer/Xcode/DerivedData/CraigOTerminator-egrmfutydaepxjecwdxiiemsdeyl/Build/Products/Debug

# 2. Kill running app
killall CraigOTerminator 2>/dev/null || true

# 3. Remove extended attributes
xattr -cr CraigOTerminator.app

# 4. Re-sign with entitlements
codesign --force \
    --deep \
    --sign "Apple Development: Phamy Xaypanya (G9FQUJ8463)" \
    --entitlements /Volumes/VibeStore/Craig-O-Cleaner/TerminatorEdition/Xcode/CraigOTerminator/CraigOTerminator.entitlements \
    --options runtime \
    --timestamp \
    CraigOTerminator.app

# 5. Verify signature
codesign --verify --verbose=4 CraigOTerminator.app

# 6. Reset TCC (optional but recommended)
tccutil reset All com.vibecaas.CraigOTerminator
```

---

## 🧪 Testing After Fix

### 1. Verify Code Signature

```bash
codesign --display --verbose=4 /Users/knightdev/Library/Developer/Xcode/DerivedData/CraigOTerminator-egrmfutydaepxjecwdxiiemsdeyl/Build/Products/Debug/CraigOTerminator.app
```

**Expected output should include**:
```
Format=app bundle with Mach-O universal (arm64)
CodeDirectory v=20500 size=... flags=0x10000(runtime) hashes=...
Signature size=...
Authority=Apple Development: Phamy Xaypanya (G9FQUJ8463)
Sealed Resources version=2 rules=13 files=...
```

**Key indicators of success**:
- ✅ `flags=0x10000(runtime)` - Hardened runtime enabled
- ✅ `Authority=Apple Development: ...` - Proper signing identity
- ✅ No errors or warnings

### 2. Verify Entitlements

```bash
codesign --display --entitlements - /Users/knightdev/Library/Developer/Xcode/DerivedData/CraigOTerminator-egrmfutydaepxjecwdxiiemsdeyl/Build/Products/Debug/CraigOTerminator.app
```

**Expected to see**:
```xml
<key>com.apple.security.automation.apple-events</key>
<true/>
<key>com.apple.security.app-sandbox</key>
<false/>
...
```

### 3. Test TCC Integration

```bash
# Launch the app
open /Users/knightdev/Library/Developer/Xcode/DerivedData/CraigOTerminator-egrmfutydaepxjecwdxiiemsdeyl/Build/Products/Debug/CraigOTerminator.app

# Watch TCC logs in real-time
log stream --predicate 'subsystem == "com.apple.TCC"' --level debug
```

**Look for**:
- ✅ No more `-67034` errors
- ✅ Permission prompts appearing
- ✅ `AUTHREQ_ATTRIBUTION` messages (normal)

### 4. Test Browser Automation

1. Open Safari and Chrome with multiple tabs
2. In Craig-O Terminator, click "Close inactive browsers"
3. **Expected**: Inactive browser tabs should close
4. **Check Console.app** for:
   ```
   No more: Failed to copy signing info for 13322: #-67034
   ```

### 5. Test Permission Detection

1. Run Health Check (when menu item is added)
2. Check "Permissions" category
3. **Expected**:
   - ✅ Accessibility: Granted (if granted in System Settings)
   - ✅ Full Disk Access: Granted (if granted in System Settings)
   - ✅ Automation: Granted

---

## 🔍 Debugging Code Signing Issues

### Check Current Signature Status

```bash
# Basic verification
codesign --verify --verbose=4 CraigOTerminator.app

# Deep verification (checks frameworks, plugins, etc.)
codesign --verify --deep --verbose=4 CraigOTerminator.app

# Display all signature info
codesign --display --verbose=4 CraigOTerminator.app
```

### Common Error Messages

#### `-67034` (errSecInvalidItemRef)
**Meaning**: Code signature is invalid or not trusted
**Fix**: Re-sign with proper identity and entitlements (use script above)

#### `code object is not signed at all`
**Meaning**: App has no signature
**Fix**: Run code signing script

#### `signature not valid for use in process using Library Validation`
**Meaning**: Hardened runtime enabled but signature invalid
**Fix**: Re-sign with `--options runtime`

#### `a sealed resource is missing or invalid`
**Meaning**: Files modified after signing
**Fix**: Re-sign after any file modifications

### Check TCC Database

```bash
# Query TCC database for your app (requires SIP disabled or special access)
# This is informational only

# Check if app is registered
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
    "SELECT * FROM access WHERE client='com.vibecaas.CraigOTerminator';"

# Note: On modern macOS, this may be restricted
```

### Monitor TCC in Real-Time

```bash
# Terminal 1: Watch TCC logs
log stream --predicate 'subsystem == "com.apple.TCC"' --level debug

# Terminal 2: Watch app logs
log stream --predicate 'subsystem == "ai.neuralquantum.CraigOTerminator"'

# Then launch and use your app
```

---

## 🎯 Best Practices Going Forward

### During Development

1. **After each Xcode build**, run the fix script if you need TCC features:
   ```bash
   ./fix-code-signing.sh
   ```

2. **Use Archive builds** for serious testing sessions

3. **Monitor Console.app** for code signing errors

### Xcode Build Settings

Add a **Run Script Phase** to auto-fix signing (optional):

1. In Xcode, select your target
2. Build Phases → + → New Run Script Phase
3. Add this script:

```bash
# Auto-fix code signing after build
if [ "$CONFIGURATION" = "Debug" ]; then
    echo "Re-signing debug build for TCC compatibility..."
    codesign --force \
        --deep \
        --sign "Apple Development: Phamy Xaypanya (G9FQUJ8463)" \
        --entitlements "$SRCROOT/CraigOTerminator/CraigOTerminator.entitlements" \
        --options runtime \
        "$BUILT_PRODUCTS_DIR/$FULL_PRODUCT_NAME"
fi
```

4. Drag this phase to **after** "Embed Frameworks"

### For Distribution

1. **Always use Archive builds**
2. **Notarize the app** for distribution outside App Store:
   ```bash
   xcrun notarytool submit CraigOTerminator.zip \
       --apple-id your@email.com \
       --team-id K36LFHM32T \
       --password app-specific-password \
       --wait
   ```

3. **Staple the notarization ticket**:
   ```bash
   xcrun stapler staple CraigOTerminator.app
   ```

---

## 📋 Checklist: Fixing Code Signing

Use this checklist to verify everything is working:

### Pre-Flight
- [ ] App builds successfully in Xcode
- [ ] Debug build exists at DerivedData path
- [ ] Entitlements file exists

### Code Signing
- [ ] Run `./fix-code-signing.sh` OR create Archive build
- [ ] No errors during signing process
- [ ] Signature verification passes: `codesign --verify --verbose=4`
- [ ] Entitlements are embedded: `codesign --display --entitlements -`

### TCC Integration
- [ ] Reset TCC permissions: `tccutil reset All`
- [ ] Launch app fresh
- [ ] Grant Accessibility permission
- [ ] Grant Full Disk Access permission
- [ ] Grant Automation permission for browsers

### Functional Testing
- [ ] No `-67034` errors in Console.app
- [ ] Browser automation works (close inactive tabs)
- [ ] Permission detection shows correct status
- [ ] Health Check passes all TCC tests
- [ ] ProcessMonitorService fetches full process list

### Verification
- [ ] Check Console.app for TCC errors
- [ ] Run Health Check and review results
- [ ] Export Health Check report
- [ ] Save report for reference

---

## 🆘 Still Having Issues?

### If the script fails:

1. **Check signing identity**:
   ```bash
   security find-identity -v -p codesigning
   ```
   Make sure "Apple Development: Phamy Xaypanya (G9FQUJ8463)" is listed

2. **Verify Xcode Command Line Tools**:
   ```bash
   xcode-select --print-path
   # Should output: /Applications/Xcode.app/Contents/Developer
   ```

3. **Clean and rebuild**:
   ```bash
   # In Xcode
   Product → Clean Build Folder (⌘⇧K)
   Product → Build (⌘B)
   # Then run fix script again
   ```

4. **Nuclear option** - Reset everything:
   ```bash
   # Kill Xcode and simulators
   killall Xcode
   killall Simulator

   # Clean derived data
   rm -rf ~/Library/Developer/Xcode/DerivedData/*

   # Rebuild in Xcode
   # Run fix script
   ```

### If TCC still shows Denied:

1. **Check System Settings**:
   - System Settings → Privacy & Security → Accessibility
   - System Settings → Privacy & Security → Full Disk Access
   - System Settings → Privacy & Security → Automation
   - Make sure "CraigOTerminator" is listed and enabled

2. **Reset TCC completely**:
   ```bash
   tccutil reset All
   sudo killall tccd
   # Relaunch app
   ```

3. **Check for multiple app copies**:
   ```bash
   # Find all copies of the app
   mdfind "kMDItemDisplayName == 'CraigOTerminator'"

   # Make sure you're launching the right one
   ```

---

## 📚 Additional Resources

### Apple Documentation
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [TCC Technical Note](https://developer.apple.com/documentation/technotes/tn3150-understanding-privacy-preferences)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
- [App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)

### Tools
- `codesign` - Code signing utility
- `tccutil` - TCC database management
- `security` - Keychain and identity management
- `log stream` - Real-time log monitoring

### Debugging
- Console.app - System logs and errors
- Activity Monitor - Check app status
- Xcode Organizer - Manage archives and provisioning

---

**Last Updated**: 2026-01-24
**App Version**: Development Build
**macOS**: 15.3 (Sequoia)
**Xcode**: 17.0
