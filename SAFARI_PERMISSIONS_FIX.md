# Fix Safari Automation Permissions for Craig-O-Clean

## Problem
Getting error: "Script execution failed: Safari got an error: A privilege violation occurred."

## Solution

### Option 1: Grant Permission via System Settings (Recommended)

1. **Open System Settings**
   - Click the Apple menu () → System Settings

2. **Navigate to Privacy & Security**
   - In the sidebar, click "Privacy & Security"

3. **Find Automation**
   - Scroll down and click "Automation"

4. **Grant Permission**
   - Look for "Craig-O-Clean" in the list
   - Toggle ON the switch for "Safari"
   - If Craig-O-Clean isn't listed, see Option 2 below

5. **Restart Safari** (if needed)
   - Quit Safari completely
   - Relaunch Safari
   - Click the "Refresh" button in Craig-O-Clean's Browser Tabs view

### Option 2: Trigger the Permission Prompt

If Craig-O-Clean doesn't appear in System Settings → Automation yet:

1. **Make sure Safari is running**
   - Open Safari and load a few web pages

2. **Click "Refresh" in Craig-O-Clean**
   - This will trigger the AppleScript and macOS should show a permission dialog
   - Click "OK" or "Allow" when the dialog appears

3. **If no dialog appears**
   - The permission may have been denied previously
   - Go to System Settings → Privacy & Security → Automation
   - Manually toggle the Craig-O-Clean → Safari permission

### Option 3: Reset Automation Permissions (Nuclear Option)

If the above doesn't work:

```bash
# Reset TCC (Transparency, Consent, and Control) database
# WARNING: This resets ALL automation permissions for ALL apps
tccutil reset AppleEvents

# Then restart Craig-O-Clean and try again
```

## Verification

After granting permission:
1. Open Safari with a few tabs
2. Open Craig-O-Clean → Browser Tabs
3. Click "Refresh"
4. You should see your Safari tabs listed

## Troubleshooting

### Still not working?

1. **Check the app's bundle identifier**
   ```bash
   cd /Applications/Craig-O-Clean.app/Contents
   /usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" Info.plist
   ```
   Should show: `com.craigoclean.app`

2. **Verify entitlements**
   ```bash
   codesign -d --entitlements - /Applications/Craig-O-Clean.app
   ```
   Should include `com.apple.security.automation.apple-events`

3. **Check for code signing issues**
   ```bash
   codesign -vvv --deep --strict /Applications/Craig-O-Clean.app
   ```

4. **Make sure you're running the app from the correct location**
   - If running from Xcode's DerivedData, the path changes
   - The permission is tied to the specific app binary path
   - Best practice: Archive and export the app, then run it from Applications

### Safari Technology Preview

If you're using Safari Technology Preview, you need to grant permission for that separately:
- The bundle ID is: `com.apple.SafariTechnologyPreview`
- Grant permission in System Settings for Safari Technology Preview

## Notes

- Each browser requires separate permission (Safari, Chrome, Edge, etc.)
- Permissions are tied to the app's code signature and bundle ID
- Debug builds may have different bundle IDs than release builds
- Permissions need to be re-granted if the app is moved to a different location
