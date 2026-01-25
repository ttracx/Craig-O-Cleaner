# Craig-O Terminator - Testing Guide After Code Signing Fix

## ✅ What We Just Fixed

**Code Signing Issue - RESOLVED**
- ✅ App re-signed with proper entitlements
- ✅ Hardened runtime enabled
- ✅ TCC permissions reset (fresh start)
- ✅ Signature verified and valid

**Expected Results**: The `-67034` error should no longer appear, and browser automation should work.

---

## 🧪 Testing Checklist

### Step 1: Launch the App (Fresh Start)

```bash
# Launch from terminal to see console output
open /Users/knightdev/Library/Developer/Xcode/DerivedData/CraigOTerminator-egrmfutydaepxjecwdxiiemsdeyl/Build/Products/Debug/CraigOTerminator.app
```

**Expected**:
- Menu bar icon appears
- Permission dialogs may appear (grant them!)
- No crash, no errors

### Step 2: Grant Permissions

When prompted, grant:

1. **Accessibility** ✅
   - System Settings → Privacy & Security → Accessibility
   - Enable "CraigOTerminator"

2. **Full Disk Access** ✅
   - System Settings → Privacy & Security → Full Disk Access
   - Enable "CraigOTerminator"

3. **Automation** ✅
   - System Settings → Privacy & Security → Automation
   - Enable "CraigOTerminator" for Safari, Chrome, etc.

### Step 3: Test Browser Automation

1. **Open multiple browsers**:
   - Safari with 3-4 tabs
   - Chrome with 3-4 tabs

2. **Make some tabs inactive**:
   - Leave some tabs idle for a minute

3. **Test "Close Inactive Browsers"**:
   - Click menu bar icon
   - Choose "Browsers" section
   - Click "Close Inactive Browsers"

**Expected Results**:
- ✅ Inactive tabs close successfully
- ✅ No `-67034` error in Console.app
- ✅ Success message appears

**If it fails**:
- Check Console.app for errors
- Verify Automation permission is granted
- Try closing/reopening browsers

### Step 4: Test Process Monitoring

1. **Open Processes view**:
   - Click menu bar icon
   - Navigate to "Processes"

2. **Verify process list**:
   - Should show 200 processes
   - CPU % and Memory should be populated
   - Updates every 3 seconds

**Expected Results**:
- ✅ 200 processes displayed
- ✅ Metrics updating
- ✅ No timeout errors

### Step 5: Monitor Console for Errors

Open Console.app and filter for your app:

```
process == "CraigOTerminator" OR subsystem == "ai.neuralquantum.CraigOTerminator"
```

**Good signs** (should see):
```
ProcessMonitorService: ps completed with status 0
ProcessMonitorService: Fetched 200 processes
PermissionsManager: Accessibility: Granted
```

**Bad signs** (should NOT see):
```
❌ Failed to copy signing info for 13322: #-67034
❌ Not authorized to send Apple events
❌ ps command timed out
```

---

## 📊 Expected Test Results

### ✅ **What Should Work Now**

| Feature | Status | Notes |
|---------|--------|-------|
| Process Monitoring | ✅ Working | Already confirmed working |
| Browser Tab Fetching | ✅ Should work | Test with automation permission |
| Close Inactive Browsers | ✅ Should work | Main fix target |
| Permission Detection | ✅ Should work | After granting permissions |
| Shell Command Execution | ✅ Working | ps, lsof, osascript |
| Menu Bar Interface | ✅ Working | Tested earlier |

### ⚠️ **Known Issues Still Remaining**

1. **"Publishing changes" warnings** (18+ per interaction)
   - **Impact**: Undefined behavior, potential crashes
   - **Priority**: HIGH
   - **Fix**: Add `await Task.yield()` before @Published updates
   - **ETA**: 30 minutes

2. **Health Check not in menu**
   - **Impact**: Users can't access diagnostics
   - **Priority**: MEDIUM
   - **Fix**: Add menu item + window presentation
   - **ETA**: 15 minutes

3. **OSLog migration incomplete**
   - **Impact**: Less structured logging
   - **Priority**: LOW
   - **Fix**: Replace print() with Logger
   - **ETA**: 1 hour

---

## 🐛 Troubleshooting

### Issue: Permission Dialogs Don't Appear

**Solution**:
```bash
# Reset TCC and relaunch
tccutil reset All
killall CraigOTerminator
open /path/to/CraigOTerminator.app
```

### Issue: Still Getting `-67034` Error

**Verify signature**:
```bash
codesign --verify --verbose=4 /path/to/CraigOTerminator.app
```

**Should output**: `satisfies its Designated Requirement`

**If not**, re-run fix script:
```bash
./fix-code-signing.sh
```

### Issue: Browser Automation Still Fails

1. **Check Automation permission**:
   ```bash
   # Check if permission is granted
   sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
       "SELECT * FROM access WHERE service='kTCCServiceAppleEvents';"
   ```

2. **Test manually with AppleScript**:
   ```bash
   osascript -e 'tell application "Safari" to get name of every window'
   ```

   Should return window names, not an error.

3. **Reset browser-specific automation**:
   - Remove Craig-O Terminator from Automation
   - Relaunch app
   - Grant permission fresh

### Issue: App Crashes on Launch

1. **Check crash log**:
   ```bash
   ls -lt ~/Library/Logs/DiagnosticReports/ | head -5
   ```

2. **Run with debugger**:
   - Open in Xcode
   - Product → Run (⌘R)
   - Check Xcode console for errors

---

## 📝 Test Report Template

After testing, fill this out:

```
Craig-O Terminator Test Report
Date: 2026-01-24
Build: Debug (Code Signing Fixed)
Tester: [Your Name]

## Environment
- macOS Version: 15.3
- Xcode Version: 17.0
- Code Signature: Valid ✅

## Test Results

### Browser Automation
- [ ] Safari tab fetching: PASS/FAIL
- [ ] Chrome tab fetching: PASS/FAIL
- [ ] Close inactive browsers: PASS/FAIL
- [ ] Console errors: YES/NO

### Process Monitoring
- [ ] Process list populated: PASS/FAIL
- [ ] Metrics updating: PASS/FAIL
- [ ] ps command success: PASS/FAIL

### Permissions
- [ ] Accessibility granted: YES/NO
- [ ] Full Disk Access granted: YES/NO
- [ ] Automation granted: YES/NO
- [ ] Permission detection accurate: YES/NO

### Console Errors
- [ ] No -67034 errors: PASS/FAIL
- [ ] No timeout errors: PASS/FAIL
- [ ] "Publishing changes" warnings: COUNT

## Issues Found
1. [Description]
2. [Description]

## Notes
[Any additional observations]
```

---

## 🎯 Next Steps After Testing

### If All Tests Pass ✅

**Priority Order**:
1. Fix "Publishing changes" warnings (critical for stability)
2. Add Health Check to menu bar
3. Complete OSLog migration
4. Test with Archive build

### If Tests Fail ❌

**Debug Process**:
1. Check Console.app for specific errors
2. Verify signature: `codesign --verify --verbose=4`
3. Check TCC permissions in System Settings
4. Review TESTING_GUIDE.md troubleshooting section
5. Re-run code signing script if needed

---

## 📞 Getting Help

### Check These First

1. **CODE_SIGNING_GUIDE.md** - Comprehensive code signing documentation
2. **HEALTH_CHECK_AND_DIAGNOSTICS.md** - Health check system details
3. **Console.app** - Real-time error logs

### Information to Gather

When reporting issues, include:
- Console.app output (filter: `process == "CraigOTerminator"`)
- Code signature verification output
- TCC permission status
- Specific steps to reproduce

---

**Last Updated**: 2026-01-24 22:40 MST
**Code Signing**: Fixed ✅
**TCC Reset**: Complete ✅
**Ready for Testing**: YES ✅
