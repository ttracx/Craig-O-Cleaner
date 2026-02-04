# Craig-O-Clean Lite - Quick Start Guide

Get up and running with Craig-O-Clean Lite in under 5 minutes! ⚡

## Prerequisites

- macOS 14 (Sonoma) or later
- Xcode 15+ installed
- 5 minutes of your time

## Build & Run (3 Steps)

### Step 1: Open Project
The project is already open in Xcode! If not:
```bash
open Craig-O-Clean-Lite.xcodeproj
```

### Step 2: Select Your Team
1. Click on the project in the navigator (blue icon)
2. Select the "Craig-O-Clean-Lite" target
3. Go to "Signing & Capabilities" tab
4. Select your "Team" from the dropdown

### Step 3: Build & Run
Press **⌘R** (or click the Play button)

That's it! Look for the 🧠 brain icon in your menu bar.

## First Use

### Click the Menu Bar Icon
You'll see:
- CPU usage percentage
- Memory usage in GB
- Disk usage in GB
- Top 10 memory-consuming processes

### Try Quick Clean
1. Click the "Quick Clean" button
2. Enter your password if prompted
3. See the cleanup results

## Features at a Glance

| Feature | How to Use |
|---------|------------|
| **View Stats** | Click menu bar icon |
| **Refresh** | Click ↻ button or wait 5 seconds |
| **Quick Clean** | Click "Quick Clean" button |
| **Quit** | Click "Quit" button or ⌘Q |

## What Makes it "Lite"?

Craig-O-Clean Lite includes only the essentials:

✅ **Included:**
- Real-time system monitoring
- Top 10 memory users
- Quick memory cleanup
- Auto-refresh (every 5 seconds)
- Menu bar access

❌ **Not Included (use full version):**
- Browser tab management
- Force quit individual processes
- Detailed process information
- Customizable settings
- CSV export
- Advanced filtering

## Troubleshooting

### Can't see the app?
The app runs in the menu bar only (no dock icon). Look for 🧠 in the top-right of your screen.

### Quick Clean requires password?
Memory purge requires admin privileges. This is normal and safe.

### Stats not updating?
- Click the refresh button (↻)
- Wait 5 seconds for auto-refresh
- Quit and restart the app

## Next Steps

### Want More Features?
Check out the full Craig-O-Clean in the parent directory:
```bash
cd ..
open Craig-O-Clean.xcodeproj
```

The full version includes:
- Browser tab management (Safari, Chrome, Edge, Brave, Arc)
- Force quit with safety checks
- Detailed process information
- Smart memory cleanup with categories
- Customizable refresh intervals
- And much more!

### Customize the App
Edit these files in Xcode:
- `ContentView.swift` - Main UI
- `SystemMonitor.swift` - Monitoring logic
- `Craig_O_Clean_LiteApp.swift` - Menu bar setup

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘Q | Quit app |
| ⌘R | Build & Run (in Xcode) |

## Project Structure

```
Craig-O-Clean-Lite/
├── Craig-O-Clean-Lite/          # Source code
│   ├── Craig_O_Clean_LiteApp.swift    # App entry & menu bar
│   ├── ContentView.swift               # Main UI
│   ├── SystemMonitor.swift             # Monitoring logic
│   ├── Info.plist                      # App configuration
│   └── Assets.xcassets/                # App icons
├── Craig-O-Clean-Lite.xcodeproj/       # Xcode project
├── project.yml                         # XcodeGen config
├── README.md                           # Full documentation
└── QUICKSTART.md                       # This file
```

## Performance

- **App size**: ~2MB
- **Memory usage**: ~15-20MB
- **CPU usage**: <1% idle, ~2% when refreshing
- **Refresh rate**: Every 5 seconds

## Tips & Tricks

1. **Position the Popover**: Click and drag to reposition when open
2. **Quick Access**: Use Spotlight to relaunch (⌘Space, type "Craig")
3. **Monitor Background**: App updates even when popover is closed
4. **Save Memory**: Quit when not needed (app is lightweight to restart)

## Getting Help

- **Issues**: Check README.md for detailed documentation
- **Code Questions**: All code is in 3 simple Swift files
- **Feature Requests**: Consider using the full version first

## What's Next?

You're all set! Craig-O-Clean Lite is now running in your menu bar.

**Enjoy your cleaner, faster Mac! 🚀**

---

Built with ❤️ using SwiftUI | NeuralQuantum.ai
