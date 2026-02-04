# Craig-O-Clean Lite

A lightweight, streamlined version of Craig-O-Clean for macOS. Perfect for users who want essential system monitoring without the complexity.

## Features ✨

- **System Monitoring** - CPU, Memory, and Disk usage at a glance
- **Process List** - Top 10 memory-consuming processes
- **Quick Cleanup** - One-click memory purge
- **Menu Bar** - Always accessible from your menu bar
- **Lightweight** - Minimal resource usage

## What's Different from Full Version?

Craig-O-Clean Lite focuses on essentials:

| Feature | Lite | Full |
|---------|------|------|
| System Monitoring | ✅ Basic | ✅ Advanced |
| Process List | ✅ Top 10 | ✅ All processes |
| Memory Cleanup | ✅ Quick Clean | ✅ Smart Categories |
| Browser Tab Management | ❌ | ✅ |
| Auto-refresh | ✅ 5 seconds | ✅ Configurable |
| Process Details | ❌ | ✅ |
| Force Quit | ❌ | ✅ |
| CSV Export | ❌ | ✅ |

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (M1/M2/M3) or Intel Mac
- Xcode 15+ (for building)

## Installation

### Option 1: Build from Source

```bash
# Navigate to lite version
cd Craig-O-Clean-Lite

# Open in Xcode
open Craig-O-Clean-Lite.xcodeproj

# Press ⌘R to build and run
```

### Option 2: Command Line Build

```bash
xcodebuild -project Craig-O-Clean-Lite.xcodeproj \
           -scheme Craig-O-Clean-Lite \
           -configuration Release \
           build
```

## Usage

1. **Launch the app** - Look for the brain icon (🧠) in your menu bar
2. **Click the icon** - See system stats and top processes
3. **Quick Clean** - Click to free up memory
4. **Auto-refresh** - Stats update every 5 seconds

## Keyboard Shortcuts

- **⌘Q** - Quit application

## Why Choose Lite?

Choose Craig-O-Clean Lite if you:
- Want simple system monitoring
- Don't need browser tab management
- Prefer a smaller app footprint
- Like minimal, focused tools
- Are new to system monitoring

Choose the full version if you:
- Need advanced process management
- Want browser tab control
- Require detailed process information
- Need customizable settings
- Want comprehensive system insights

## Project Structure

```
Craig-O-Clean-Lite/
├── Craig-O-Clean-Lite/
│   ├── Craig_O_Clean_LiteApp.swift    # App entry & menu bar
│   ├── ContentView.swift               # Main UI
│   ├── SystemMonitor.swift             # Monitoring logic
│   └── Assets.xcassets/                # Icons
├── Craig-O-Clean-Lite.xcodeproj/       # Xcode project
└── README.md                           # This file
```

## Code Size

- **3 Swift files** (~400 lines total)
- **Zero dependencies** - Pure Swift
- **Small footprint** - ~2MB app size

## Performance

- **Memory usage**: ~15-20 MB
- **CPU usage**: < 1% idle, ~2% when refreshing
- **Refresh rate**: Every 5 seconds

## Security & Privacy

- ✅ No network access
- ✅ No data collection
- ✅ All processing local
- ✅ Open source code
- ⚠️ Requires sudo for memory purge

## Troubleshooting

### App doesn't appear in menu bar
- Check System Settings → Login Items
- Ensure app is running (Activity Monitor)

### Quick Clean doesn't work
- May require sudo password
- Try running from Terminal first: `sudo purge`

### Stats not updating
- Click refresh button manually
- Restart the app

## Upgrading to Full Version

Want more features? The full Craig-O-Clean includes:

1. **Browser Tab Management** - Control Safari, Chrome, Edge, Brave, Arc
2. **Advanced Process Control** - Force quit, detailed info, CSV export
3. **Smart Memory Cleanup** - Categorized suggestions, multi-step workflow
4. **Customizable Settings** - Refresh intervals, warning thresholds
5. **Detailed Monitoring** - Per-core CPU, memory pressure, network activity

Simply open the main `Craig-O-Clean.xcodeproj` in the parent directory.

## Contributing

Found a bug or have a suggestion? Open an issue on GitHub!

## License

MIT License - Same as full version

---

**Craig-O-Clean Lite** - Essential system monitoring, nothing more. 🚀

Made with ❤️ for macOS
