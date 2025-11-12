<div align="center">
  <img src="https://github.com/user-attachments/assets/485d839f-c025-4db7-94d3-823379e02d77" alt="Craig-O-Clean Logo" width="200"/>
  
  # Craig-O-Clean App
  
  A native macOS SwiftUI application for monitoring and managing system memory usage. Craig-O-Clean provides a menu bar utility that displays running processes sorted by memory usage and allows users to force quit applications or purge system memory.
  
  ![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
  ![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
  ![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)
</div>

## Features

- **Menu Bar Integration**: Lightweight menu bar app that stays out of your way
- **Real-time Process Monitoring**: Displays processes sorted by memory usage
- **Memory Usage Statistics**: Shows total memory usage and process count
- **Process Management**: Force quit any process with a single click
- **Memory Purge**: Execute `sync && sudo purge` command to flush inactive memory
- **Search Functionality**: Quickly find specific processes
- **Auto-refresh**: Process list updates automatically every 5 seconds
- **Native SwiftUI Interface**: Modern macOS design with smooth animations

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building from source)
- Apple Silicon or Intel-based Mac

## Installation & Building

### Option 1: Build from Xcode (Recommended)

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ttracx/Craig-O-Cleaner.git
   cd Craig-O-Cleaner
   ```

2. **Open the project in Xcode**:
   ```bash
   open Craig-O-Clean.xcodeproj
   ```

3. **Configure signing** (if needed):
   - Select the `Craig-O-Clean` project in the Project Navigator
   - Select the `Craig-O-Clean` target
   - Go to the "Signing & Capabilities" tab
   - Choose your development team or use "Sign to Run Locally"

4. **Build and run**:
   - Press `⌘R` or click the "Run" button in Xcode
   - The app will build and launch automatically
   - Look for the memory chip icon (📟) in your menu bar

### Option 2: Build from Command Line

1. **Clone and navigate to the repository**:
   ```bash
   git clone https://github.com/ttracx/Craig-O-Cleaner.git
   cd Craig-O-Cleaner
   ```

2. **Build the app**:
   ```bash
   xcodebuild -project Craig-O-Clean.xcodeproj \
              -scheme Craig-O-Clean \
              -configuration Release \
              -derivedDataPath ./build
   ```

3. **Locate the built app**:
   The compiled app will be located at:
   ```
   ./build/Build/Products/Release/Craig-O-Clean.app
   ```

4. **Run the app**:
   ```bash
   open ./build/Build/Products/Release/Craig-O-Clean.app
   ```

5. **Optional: Copy to Applications folder**:
   ```bash
   cp -r ./build/Build/Products/Release/Craig-O-Clean.app /Applications/
   ```

## Usage

### Launching the App

- After building, the app appears as a menu bar icon (memory chip symbol)
- Click the menu bar icon to open the process list
- The app runs in the background and doesn't appear in the Dock

### Managing Processes

1. **View Processes**: Click the menu bar icon to see all processes sorted by memory usage
2. **Search**: Use the search bar to filter processes by name
3. **Refresh**: Click the refresh icon (↻) to manually update the process list
4. **Force Quit**: Click "Force Quit" next to any process to terminate it immediately
5. **Purge Memory**: Click the "Purge Memory" button at the bottom to run `sync && sudo purge`

### Memory Purge

The "Purge Memory" button executes the system command `sync && sudo purge`:
- `sync`: Flushes file system buffers
- `purge`: Frees up inactive memory

**Note**: The purge command requires administrator privileges. macOS will prompt you to enter your password when you click this button.

## Project Structure

```
Craig-O-Cleaner/
├── Craig-O-Clean.xcodeproj/       # Xcode project file
│   └── project.pbxproj
├── Craig-O-Clean/                 # Source code
│   ├── Craig_O_CleanApp.swift    # Main app entry point and menu bar setup
│   ├── ContentView.swift         # Main UI interface
│   ├── ProcessManager.swift      # Process monitoring and management logic
│   ├── ProcessInfo.swift         # Process data model
│   ├── Assets.xcassets/          # App icons and assets
│   ├── Preview Content/          # SwiftUI preview assets
│   ├── Craig-O-Clean.entitlements # App permissions
│   └── Info.plist               # App configuration
├── README.md                     # This file
└── .gitignore                   # Git ignore rules
```

## Technical Details

### Architecture

- **SwiftUI**: Modern declarative UI framework
- **AppDelegate Pattern**: Custom app delegate for menu bar integration
- **ObservableObject**: Reactive state management for process list
- **Process API**: Uses macOS Process class to execute shell commands
- **Auto-refresh Timer**: Scheduled timer for automatic updates

### Permissions

The app requires the following permissions:
- **No Sandbox**: Disabled to allow process monitoring and management
- **File Access**: Required for executing system commands

These are configured in `Craig-O-Clean.entitlements`.

### Memory Monitoring

The app uses the `ps` command to gather process information:
```bash
ps -axm -o pid,rss,comm
```

This provides:
- `pid`: Process ID
- `rss`: Resident Set Size (memory in KB)
- `comm`: Command name

### Security Notes

- The app runs **without** sandbox restrictions to function properly
- Administrator privileges are only requested when using the "Purge Memory" feature
- Force quit functionality works on user-owned processes without admin privileges
- The app uses AppleScript to request admin privileges securely when needed

## Troubleshooting

### App doesn't appear in menu bar
- Make sure the app is actually running (check Activity Monitor)
- Restart the app
- Check System Settings → Desktop & Dock → Menu Bar to ensure menu bar icons are visible

### "Permission Denied" when force quitting
- You can only force quit processes owned by your user
- System processes require administrator privileges
- Some protected processes cannot be terminated

### Purge command fails
- Ensure you enter your administrator password when prompted
- The account must have admin privileges
- Some system configurations may restrict the purge command

### Build errors in Xcode
- Ensure you're using Xcode 15.0 or later
- Clean the build folder: Product → Clean Build Folder (⇧⌘K)
- Delete derived data: Window → Organizer → Delete Derived Data
- Restart Xcode

### Code signing issues
- Go to Signing & Capabilities in Xcode
- Select "Automatically manage signing"
- Choose your Apple Developer account or "Sign to Run Locally"

## Development

### Prerequisites for Development

- Xcode 15.0 or later
- macOS 13.0 SDK or later
- Swift 5.9 or later

### Building for Development

```bash
# Build in Debug mode
xcodebuild -project Craig-O-Clean.xcodeproj \
           -scheme Craig-O-Clean \
           -configuration Debug

# Run tests (if available)
xcodebuild test -project Craig-O-Clean.xcodeproj \
                -scheme Craig-O-Clean
```

### Customization

You can customize the app by modifying:
- **Refresh interval**: Change the timer interval in `ProcessManager.swift`
- **Process filter**: Adjust the memory threshold filter (currently 10 MB)
- **UI appearance**: Modify colors and layout in `ContentView.swift`
- **Menu bar icon**: Change the SF Symbol in `Craig_O_CleanApp.swift`

## Known Limitations

- Auto-refresh interval is fixed at 5 seconds (can be modified in code)
- Only displays top 50 memory-consuming processes
- Processes using less than 10 MB are filtered out
- Some system processes may not be terminable without admin rights

## Future Enhancements

Potential features for future versions:
- CPU usage monitoring
- Customizable refresh intervals
- Export process list to CSV
- Process history and trends
- Memory usage alerts/notifications
- Dark mode optimizations
- Preference window for settings

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is provided as-is for educational and personal use.

## Credits

Created as a macOS utility for monitoring and managing system memory usage.

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check existing issues for solutions

---

**Note**: This application is designed for macOS and leverages native system commands. Use the force quit and memory purge features responsibly as they can affect system stability if misused.

---

© 2025 Craig-O-Cleaner powered by VibeCaaS.com a division of NeuralQuantum.ai LLC. All rights reserved.