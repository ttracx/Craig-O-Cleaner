# Craig-O-Clean - Quick Start Guide

Get up and running with Craig-O-Clean in 5 minutes!

## 🚀 Quick Setup

### 1. Open the Project (30 seconds)

```bash
cd CraigOClean
open CraigOClean.xcodeproj
```

### 2. Configure Code Signing (1 minute)

In Xcode:
1. Click on "CraigOClean" project in the left sidebar
2. Select "CraigOClean" target
3. Go to "Signing & Capabilities" tab
4. Select your Apple ID from "Team" dropdown
   - If you don't see your Apple ID, add it in Xcode → Settings → Accounts

### 3. Build & Run (30 seconds)

Press `⌘ + R` or click the ▶️ button

The app will appear as a memory chip icon (📟) in your menu bar!

### 4. Setup Sudo Access (Optional but Recommended) (2 minutes)

For seamless memory purging without password prompts:

```bash
cd CraigOClean
./setup_sudo.sh
```

Enter your password when prompted, and follow the instructions.

## ✅ That's It!

You're ready to use Craig-O-Clean!

### How to Use

1. **Click the menu bar icon** - Opens the memory monitor
2. **View memory stats** - See total, used, and available RAM
3. **Browse running apps** - See which apps use the most memory
4. **Force quit apps** - Hover over any app and click "Force Quit"
5. **Purge memory** - Click "Purge Memory" button to free up RAM

## 🎯 Common Actions

### See Memory Stats
Just click the menu bar icon - instant overview!

### Free Up Memory
1. Click menu bar icon
2. Click "Purge Memory" button
3. Wait 2-3 seconds
4. Done! Memory freed

### Force Quit Frozen App
1. Click menu bar icon
2. Find the app in the list
3. Hover over it
4. Click "Force Quit"

## 🔧 Troubleshooting

### Can't Build?
- Make sure you're running macOS 13.0+
- Check that Xcode 15+ is installed
- Try: Product → Clean Build Folder (⌘ + Shift + K)

### Purge Button Fails?
- Run the sudo setup script: `./setup_sudo.sh`
- Or manually test: `sudo purge` in Terminal

### Don't See Menu Bar Icon?
- Look in the top-right area of your screen
- The icon is a memory chip (📟)
- Try quitting and reopening the app

## 📚 Need More Help?

See the full [README.md](README.md) for:
- Detailed installation instructions
- Architecture overview
- Advanced configuration
- Development guide

## 🎉 Enjoy!

Craig-O-Clean is now keeping your Mac running smoothly!
