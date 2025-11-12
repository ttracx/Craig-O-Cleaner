# Craig-O-Clean App 🧹

A powerful macOS menu bar application for monitoring and managing system memory usage. Built with SwiftUI for macOS Silicon (Apple Silicon) and Intel Macs.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green)

## Features

- **Menu Bar Integration**: Lightweight app that lives in your menu bar
- **Real-time Memory Monitoring**: See total, used, and available memory at a glance
- **Process List**: View the top 20 memory-consuming applications
- **Force Quit**: Easily force quit applications using too much memory
- **Memory Purge**: Execute `sync && sudo purge` command to free up memory
- **Beautiful UI**: Modern SwiftUI interface with smooth animations
- **Low Resource Usage**: Efficient background monitoring

## Screenshots

When you click the menu bar icon, you'll see:
- Total system memory statistics
- Visual memory usage bar
- List of top memory-consuming applications
- Memory usage per application (MB/GB)
- Force quit button for each application
- Purge memory button

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3) or Intel processor
- Xcode 15.0 or later (for building)
- Administrator privileges (for memory purge feature)

## Installation & Setup

### Step 1: Clone or Download the Project

```bash
git clone <your-repo-url>
cd CraigOClean
```

### Step 2: Open in Xcode

```bash
open CraigOClean.xcodeproj
```

Or simply double-click `CraigOClean.xcodeproj` in Finder.

### Step 3: Configure Code Signing

1. In Xcode, select the project in the navigator
2. Select the "CraigOClean" target
3. Go to "Signing & Capabilities" tab
4. Select your development team from the dropdown
5. Xcode will automatically manage signing

### Step 4: Build and Run

1. Select the "CraigOClean" scheme
2. Choose "My Mac" as the destination
3. Press `⌘ + R` or click the Run button

The app will launch and appear in your menu bar as a memory chip icon.

## Configuring Sudo Access for Memory Purge

The memory purge feature requires `sudo` privileges to execute the `purge` command. You have two options:

### Option A: Run with Password Prompt (Simple)

The first time you click "Purge Memory", macOS will prompt you for your administrator password. This is the simplest approach but requires entering your password each time.

### Option B: Configure Passwordless Sudo (Recommended)

For seamless operation without password prompts:

1. Open Terminal
2. Edit the sudoers file:
   ```bash
   sudo visudo
   ```

3. Add this line at the end (replace `YOUR_USERNAME` with your actual username):
   ```
   YOUR_USERNAME ALL=(ALL) NOPASSWD: /usr/bin/purge, /bin/sync
   ```

4. Save and exit (Ctrl+X, then Y, then Enter)

5. Test it:
   ```bash
   sudo -n purge
   ```
   If no password is requested, it's working!

**⚠️ Security Note**: This allows the purge command to run without a password. Only do this on your personal Mac where you're comfortable with this level of access.

### Option C: Alternative Setup Script

We've included a setup script for convenience:

```bash
cd CraigOClean
chmod +x setup_sudo.sh
./setup_sudo.sh
```

This script will guide you through configuring passwordless sudo for the purge command.

## How to Use

### Basic Usage

1. **View Memory Stats**: Click the menu bar icon to open the app
2. **Monitor Processes**: Scroll through the list of applications
3. **Force Quit**: Hover over any process and click "Force Quit"
4. **Purge Memory**: Click the "Purge Memory" button to free up RAM

### Understanding Memory Stats

- **Total Memory**: Your Mac's total RAM
- **Used**: Currently allocated memory
- **Available**: Free memory that can be allocated
- **Memory Bar**: Visual representation with color-coding:
  - Green: Low usage (healthy)
  - Yellow/Orange: Medium usage
  - Red: High usage (consider purging)

### What Does "Purge Memory" Do?

The purge command executes:
```bash
sync && sudo purge
```

- `sync`: Flushes file system buffers to disk
- `purge`: Frees up inactive memory and disk cache

This can significantly improve performance when your Mac is sluggish due to memory pressure.

## Building for Distribution

### Create Release Build

1. In Xcode, select "Product" → "Archive"
2. Once archived, click "Distribute App"
3. Choose "Copy App"
4. Save the .app file to your Applications folder

### Code Signing for Distribution

To distribute outside the App Store:

1. You'll need an Apple Developer account ($99/year)
2. Create a Developer ID Application certificate
3. Configure code signing with your Developer ID
4. Notarize the app with Apple

For personal use, the development build is sufficient.

## Project Structure

```
CraigOClean/
├── CraigOClean/
│   ├── CraigOCleanApp.swift      # Main app entry point
│   ├── Models/
│   │   └── ProcessInfo.swift      # Process data model
│   ├── Services/
│   │   ├── ProcessMonitor.swift   # Memory monitoring service
│   │   └── MemoryManager.swift    # Memory purge operations
│   ├── Views/
│   │   ├── MenuBarView.swift      # Main menu bar interface
│   │   └── ProcessRowView.swift   # Process list item view
│   ├── Info.plist                 # App configuration
│   └── CraigOClean.entitlements   # App permissions
├── CraigOClean.xcodeproj/         # Xcode project file
└── README.md                      # This file
```

## Architecture

### Key Components

- **CraigOCleanApp**: Main app entry point with menu bar setup
- **ProcessMonitor**: Uses `ps` and `vm_stat` commands to gather memory data
- **MemoryManager**: Executes memory purge commands via shell
- **MenuBarView**: SwiftUI view for the popover interface
- **ProcessRowView**: Reusable component for displaying process information

### Technologies Used

- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming for state updates
- **AppKit**: Menu bar integration
- **Process**: Shell command execution
- **NSStatusBar**: Menu bar item management

## Troubleshooting

### App Won't Launch
- Ensure you're running macOS 13.0 or later
- Check that code signing is configured in Xcode
- Try cleaning build folder (⌘ + Shift + K) and rebuilding

### Memory Purge Fails
- Verify sudo access is configured (see above)
- Check that you have administrator privileges
- Try running `sudo purge` manually in Terminal to test

### Process List Is Empty
- The app only shows processes using >10MB of memory
- If nothing appears, your system has very low memory usage (good!)

### App Doesn't Appear in Menu Bar
- The app uses `LSUIElement = true` to hide from the Dock
- Look for a memory chip icon in the menu bar (top-right of screen)
- Try quitting and relaunching the app

### Permission Issues
- macOS may require you to grant permissions in System Settings
- Go to System Settings → Privacy & Security
- Allow any requested permissions for Craig-O-Clean

## Development

### Making Changes

1. Open the project in Xcode
2. Make your changes to the Swift files
3. Build and run to test (⌘ + R)

### Adding Features

The codebase is modular and easy to extend:

- **New monitoring features**: Add to `ProcessMonitor.swift`
- **UI changes**: Modify `MenuBarView.swift` or `ProcessRowView.swift`
- **New commands**: Extend `MemoryManager.swift`

### Debug Mode

To see console output:
1. Run from Xcode (⌘ + R)
2. View the console output in Xcode's debug area
3. Print statements will show command outputs and errors

## Performance

The app is designed to be lightweight:
- Updates every 2 seconds (configurable in `ProcessMonitor`)
- Only tracks top 20 memory-consuming processes
- Minimal CPU usage when popover is closed
- Efficient memory usage (~30-50MB typical)

## Known Limitations

- Requires sudo access for memory purge feature
- Only shows processes using >10MB of memory
- Updates every 2 seconds (real-time monitoring would impact performance)
- Force quit requires proper permissions (works for user-owned processes)

## FAQ

**Q: Is this app safe to use?**
A: Yes! The app only monitors system information and executes standard macOS commands. All code is visible and auditable.

**Q: Will force quitting apps lose my data?**
A: Yes, force quitting doesn't allow apps to save. Only use this for unresponsive applications.

**Q: How often should I purge memory?**
A: Only when your Mac feels sluggish. macOS manages memory well automatically.

**Q: Does this work on Intel Macs?**
A: Yes! It's optimized for Apple Silicon but works on Intel Macs too.

**Q: Can I customize the update frequency?**
A: Yes, edit the `2.0` value in `ProcessMonitor.startMonitoring()` to change the refresh interval.

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## License

This project is provided as-is for educational and personal use.

## Credits

Created with ❤️ for macOS power users who want to keep their systems running smoothly.

---

**Need Help?** Open an issue or check the troubleshooting section above.

**Enjoy using Craig-O-Clean!** 🎉
