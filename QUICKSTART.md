# Quick Start Guide

Get Craig-O-Clean up and running in 5 minutes!

## 🚀 Build & Run (3 Steps)

### 1. Open in Xcode
```bash
cd Craig-O-Cleaner
open Craig-O-Clean.xcodeproj
```

### 2. Press Play
- Click the ▶️ button in Xcode (or press ⌘R)
- Accept any code signing prompts

### 3. Use the App
- Look for 📟 icon in your menu bar
- Click it to see memory usage
- Done! 🎉

## 📋 What You Need

- ✅ macOS 13.0+ (Ventura or newer)
- ✅ Xcode 15.0+ (from Mac App Store)
- ✅ 5 minutes of your time

## 🎯 First Time Using?

**After launching:**
1. Click the memory chip icon in your menu bar
2. See processes using the most memory
3. Click "Force Quit" to close any app
4. Click "Purge Memory" to free up RAM (needs password)

## ⚡ Quick Commands

**Build from terminal:**
```bash
xcodebuild -project Craig-O-Clean.xcodeproj \
           -scheme Craig-O-Clean \
           -configuration Release \
           build
```

**Run the built app:**
```bash
open ./build/Build/Products/Release/Craig-O-Clean.app
```

**Install to Applications:**
```bash
cp -r ./build/Build/Products/Release/Craig-O-Clean.app /Applications/
```

## 🔧 Troubleshooting

**Can't build?**
- Make sure Xcode 15+ is installed
- Try: Product → Clean Build Folder (⇧⌘K)

**Code signing error?**
- Xcode → Preferences → Accounts → Add your Apple ID
- Or choose "Sign to Run Locally"

**Don't see the menu bar icon?**
- Check if the app is running in Activity Monitor
- Restart the app

## 📚 Learn More

- **Full details**: See [README.md](README.md)
- **Build help**: See [BUILD_INSTRUCTIONS.md](BUILD_INSTRUCTIONS.md)
- **How to use**: See [USAGE_GUIDE.md](USAGE_GUIDE.md)

## 💡 Key Features

| Feature | What It Does |
|---------|--------------|
| **Process Monitor** | Shows top 50 memory-hungry apps |
| **Force Quit** | Instantly close any app |
| **Memory Purge** | Free up inactive memory |
| **Search** | Find specific processes fast |
| **Auto-Refresh** | Updates every 5 seconds |

## 🎉 That's It!

You're ready to manage your Mac's memory like a pro. Questions? Check the full [README.md](README.md).

---

**Need help?** Open an issue on GitHub.
