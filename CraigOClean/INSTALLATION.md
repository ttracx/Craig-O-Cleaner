# Craig-O-Clean - Installation Guide

## Prerequisites

Before you begin, ensure you have:

- **macOS 13.0 (Ventura) or later**
- **Xcode 15.0 or later** - [Download from App Store](https://apps.apple.com/us/app/xcode/id497799835)
- **Apple Developer Account** (free account works) - For code signing

### Check Your macOS Version

```bash
sw_vers
```

Should show ProductVersion 13.0 or higher.

### Check Xcode Installation

```bash
xcodebuild -version
```

Should show Xcode 15.0 or higher.

## Installation Methods

### Method 1: Xcode (Recommended)

#### Step 1: Navigate to Project

```bash
cd CraigOClean
```

#### Step 2: Open in Xcode

```bash
open CraigOClean.xcodeproj
```

Or double-click `CraigOClean.xcodeproj` in Finder.

#### Step 3: Configure Code Signing

1. Click on **CraigOClean** project in the left sidebar
2. Select **CraigOClean** target (under TARGETS)
3. Click **Signing & Capabilities** tab
4. In the **Team** dropdown:
   - If you see your name/team → Select it
   - If empty → Click "Add Account" and sign in with Apple ID
   - Free accounts work fine for personal use

**Xcode will automatically:**
- Generate provisioning profile
- Create certificates
- Configure bundle identifier

#### Step 4: Build and Run

Press **⌘ + R** or click the **▶️ Play** button

**Wait 10-20 seconds** for initial build, then:
- App launches automatically
- Menu bar icon appears (memory chip 📟)
- Ready to use!

### Method 2: Command Line Build

#### Step 1: Ensure Xcode Command Line Tools

```bash
xcode-select --install
```

If already installed, you'll see: "command line tools are already installed"

#### Step 2: Build Using Script

```bash
cd CraigOClean
./build.sh
```

#### Step 3: Run the App

```bash
open ./build/Build/Products/Release/CraigOClean.app
```

#### Step 4: Copy to Applications (Optional)

```bash
cp -r ./build/Build/Products/Release/CraigOClean.app /Applications/
```

Then launch from Applications folder.

## Post-Installation Setup

### Configure Sudo Access (Recommended)

For passwordless memory purge:

```bash
cd CraigOClean
./setup_sudo.sh
```

**Follow the prompts:**
1. Review what will be configured
2. Type `y` to confirm
3. Enter your password
4. Script validates configuration
5. Test completes automatically

**What this does:**
- Adds passwordless sudo for `/usr/bin/purge` and `/bin/sync`
- Creates file: `/etc/sudoers.d/craig-o-clean`
- Safe and reversible

**To remove later:**
```bash
sudo rm /etc/sudoers.d/craig-o-clean
```

### First Launch

1. **Find the app** - Look for memory chip icon in menu bar (top-right)
2. **Click the icon** - Opens the interface
3. **Grant permissions** - macOS may ask for permissions (allow them)
4. **Test purge** - Click "Purge Memory" button
   - If configured with sudo setup: Works immediately
   - If not: Will prompt for password

### Verify Installation

#### Check App is Running
```bash
ps aux | grep CraigOClean
```

Should show the app process.

#### Check Menu Bar Icon
Look in the menu bar (top-right area near the clock) for 📟

## Troubleshooting Installation

### Problem: "Developer cannot be verified"

**macOS blocks unsigned apps by default.**

**Solution:**
1. Right-click the app → Open
2. Click "Open" in the dialog
3. Or go to: System Settings → Privacy & Security → Allow app

### Problem: "Code signing failed"

**Xcode can't sign the app.**

**Solution:**
1. Open Xcode Preferences (⌘ + ,)
2. Go to Accounts tab
3. Click + to add Apple ID
4. Sign in with your Apple ID
5. Return to project and select your team

### Problem: "No such file or directory"

**Project files not found.**

**Solution:**
```bash
# Verify you're in the right directory
pwd
# Should show: /path/to/CraigOClean

# List files
ls -la
# Should show: CraigOClean.xcodeproj
```

### Problem: Build fails with errors

**Dependencies or configuration issue.**

**Solution:**
1. Clean build folder: `⌘ + Shift + K` in Xcode
2. Restart Xcode
3. Try building again: `⌘ + R`

### Problem: Menu bar icon doesn't appear

**App may not be running properly.**

**Solution:**
1. Check Console.app for errors
2. Try quitting (⌘ + Q) and relaunching
3. Verify app isn't already running:
   ```bash
   pkill -f CraigOClean
   ```
4. Launch again from Xcode

### Problem: Purge button always asks for password

**Sudo not configured.**

**Solution:**
```bash
cd CraigOClean
./setup_sudo.sh
```

Or manually add to sudoers:
```bash
sudo visudo
# Add line:
your_username ALL=(ALL) NOPASSWD: /usr/bin/purge, /bin/sync
```

## Updating the App

### Method 1: Rebuild in Xcode

1. Open project in Xcode
2. Product → Clean Build Folder (⌘ + Shift + K)
3. Product → Build (⌘ + B)
4. Product → Run (⌘ + R)

### Method 2: Command Line

```bash
cd CraigOClean
rm -rf build/
./build.sh
```

## Uninstalling

### Remove the App

**If installed in Applications:**
```bash
rm -rf /Applications/CraigOClean.app
```

**If built from Xcode:**
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/CraigOClean-*
```

### Remove Sudo Configuration

```bash
sudo rm /etc/sudoers.d/craig-o-clean
```

### Remove Project Files

```bash
cd ..
rm -rf CraigOClean/
```

## Advanced Installation

### Install for All Users

```bash
sudo cp -r ./build/Build/Products/Release/CraigOClean.app /Applications/
sudo chmod -R 755 /Applications/CraigOClean.app
```

### Launch at Login

1. Open System Settings
2. Go to General → Login Items
3. Click "+" button
4. Select CraigOClean.app
5. App will auto-start on login

### Distribution Build

For distributing to others:

1. In Xcode: Product → Archive
2. Click "Distribute App"
3. Choose "Copy App"
4. Save the .app bundle
5. Compress: Right-click → Compress

**Note:** For distribution outside your Mac, you need:
- Paid Apple Developer account ($99/year)
- Developer ID certificate
- App notarization

## System Requirements Summary

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| macOS | 13.0 (Ventura) | 14.0+ (Sonoma) |
| Xcode | 15.0 | Latest |
| RAM | 8 GB | 16 GB+ |
| Disk Space | 100 MB | 500 MB |
| Processor | Intel or Apple Silicon | Apple Silicon |

## Security Notes

- App requires disabling App Sandbox (to access system info)
- Sudo access is optional but recommended
- No network access required
- All operations are local

## Getting Help

- **Quick issues**: Check [QUICKSTART.md](QUICKSTART.md)
- **Detailed help**: See [README.md](README.md)
- **Features**: Read [FEATURES.md](FEATURES.md)
- **Build problems**: Check Xcode console output

## Success Checklist

- [ ] Xcode 15.0+ installed
- [ ] Project opened in Xcode
- [ ] Code signing configured
- [ ] Build succeeds (⌘ + R)
- [ ] App appears in menu bar
- [ ] Interface opens when clicked
- [ ] Memory stats display
- [ ] Process list populates
- [ ] Sudo configured (optional)
- [ ] Purge button works

**All checked?** You're ready to use Craig-O-Clean! 🎉

---

**Need more help?** See the [README.md](README.md) or [QUICKSTART.md](QUICKSTART.md)
