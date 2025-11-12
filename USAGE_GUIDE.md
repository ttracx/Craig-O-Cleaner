# Craig-O-Clean Usage Guide

Complete guide to using the Craig-O-Clean app for macOS memory management.

## Getting Started

### Launching the App

After building and installing Craig-O-Clean:

1. Open the app from `/Applications/Craig-O-Clean.app` or Spotlight
2. The app will not appear in the Dock (it's a menu bar app)
3. Look for the memory chip icon (📟) in your macOS menu bar (top-right area)
4. Click the icon to open the main interface

### First Launch

On first launch, you may see security prompts:
- macOS may ask if you want to open the app (if downloaded or unsigned)
- Click "Open" to proceed
- The app will request access to monitor processes (this is normal)

## Main Interface

The Craig-O-Clean interface consists of four main sections:

### 1. Header Section
- **App Title**: "Craig-O-Clean" with memory chip icon
- **Refresh Button**: Manual refresh button (↻)
- **Memory Statistics**:
  - Total memory usage across displayed processes
  - Total number of processes being monitored
- **Last Update Time**: Shows when the process list was last refreshed

### 2. Search Bar
- **Search Field**: Type to filter processes by name
- **Clear Button**: X button appears when text is entered
- Real-time filtering as you type

### 3. Process List
- **Scrollable List**: Shows up to 50 processes
- **Process Information**:
  - Process name (in monospaced font)
  - Process ID (PID)
  - Memory usage (in MB or GB)
  - Force Quit button for each process

### 4. Footer Section
- **Purge Memory Button**: Executes `sync && sudo purge`
- **Warning Text**: Reminds you about admin privileges

## Features in Detail

### Process Monitoring

**What You See**:
- Processes are sorted by memory usage (highest first)
- Only processes using more than 10 MB are shown
- Top 50 memory consumers are displayed
- Includes both apps and system processes

**Auto-Refresh**:
- Process list updates every 5 seconds automatically
- No manual intervention needed
- Manual refresh available via the ↻ button

**Process Information**:
- **Name**: The executable name or app name
- **PID**: Unique process identifier
- **Memory**: RAM usage in MB (megabytes) or GB (gigabytes)

### Searching for Processes

1. Click in the search field
2. Type any part of the process name
3. Results filter in real-time
4. Search is case-insensitive
5. Click the X button to clear search

**Example Searches**:
- "Safari" - shows all Safari-related processes
- "python" - shows Python processes
- "Google" - shows Google Chrome and related processes

### Force Quitting Processes

**How to Force Quit**:
1. Find the process you want to terminate
2. Click the red "Force Quit" button next to it
3. A confirmation alert appears
4. The process is immediately terminated (SIGKILL)
5. Process list refreshes automatically after 0.5 seconds

**Important Notes**:
- ⚠️ Force quit is immediate and doesn't save data
- You can only quit processes owned by your user account
- System processes may require admin privileges
- Some critical processes are protected and cannot be killed
- Use with caution - unsaved work will be lost

**What Can You Quit**:
- ✅ Your own applications
- ✅ User-level background processes
- ✅ Stuck or frozen apps
- ❌ System processes (unless you're admin)
- ❌ Protected system daemons

### Memory Purge

**What It Does**:
The Purge Memory button executes two system commands:
1. `sync` - Flushes file system buffers to disk
2. `sudo purge` - Frees inactive memory

**How to Use**:
1. Click the "Purge Memory (sync && sudo purge)" button
2. macOS will prompt for your administrator password
3. Enter your password and click OK
4. Wait for the operation to complete
5. A success or error message appears

**When to Use**:
- System feels sluggish
- Memory pressure is high
- After closing large applications
- Before starting memory-intensive tasks
- To free up inactive memory

**Effects**:
- Frees inactive/cached memory
- May cause temporary slowdown as caches rebuild
- Useful for reclaiming memory without restarting
- Not a substitute for proper memory management
- Effects are temporary

**Important**:
- ⚠️ Requires administrator password
- May take 5-30 seconds to complete
- System may briefly slow down
- Caches will rebuild over time
- Not recommended during heavy workloads

## Tips and Best Practices

### Memory Management

1. **Regular Monitoring**: Check the app periodically to identify memory-hogging apps
2. **Force Quit Wisely**: Only quit apps you're sure aren't needed
3. **Purge Sparingly**: Don't purge too frequently (once a day at most)
4. **Identify Patterns**: Note which apps consistently use the most memory

### Troubleshooting Common Issues

**High Memory Usage**:
1. Sort processes by memory (already default)
2. Identify the top consumers
3. Consider:
   - Closing unused browser tabs
   - Quitting unused applications
   - Restarting memory-heavy apps
4. Use Activity Monitor for more detailed analysis

**App Not Responding**:
1. Search for the app name
2. Use Force Quit to terminate it
3. Relaunch the app fresh

**Memory Still High After Purge**:
- Purge only frees inactive memory
- Active memory cannot be freed
- Consider closing some applications
- Restart your Mac if necessary

### Keyboard Shortcuts

When the popover is open:
- **⌘F**: Focus search field (if implemented)
- **Escape**: Close the popover
- **⌘R**: Refresh process list (when focus is on refresh button)

### Understanding Memory Usage

**Memory Display Format**:
- Less than 1024 MB: Shows as "X.XX MB"
- 1024 MB or more: Shows as "X.XX GB"

**What the Numbers Mean**:
- This is RSS (Resident Set Size)
- Actual physical RAM used by the process
- Does not include shared libraries (counted once)
- Does not include swapped memory

**Normal Memory Usage Ranges**:
- Small utilities: 10-100 MB
- Web browsers: 500 MB - 4 GB (depends on tabs)
- IDEs/Development tools: 500 MB - 2 GB
- Large apps (Photoshop, etc.): 1-8 GB

## Advanced Usage

### Automating Memory Management

Since Craig-O-Clean is a menu bar app, it's always accessible:
1. Keep it running in the background
2. Glance at it periodically
3. Quick access via menu bar click

### Monitoring Specific Apps

1. Launch the app you want to monitor
2. Open Craig-O-Clean
3. Search for the app name
4. Watch memory usage over time
5. Refresh manually to see real-time changes

### Using with Activity Monitor

Craig-O-Clean complements macOS Activity Monitor:
- **Craig-O-Clean**: Quick glance, fast actions
- **Activity Monitor**: Detailed analysis, graphs, history

Use both together for comprehensive monitoring.

## Limitations

**By Design**:
- Only shows processes using > 10 MB
- Limited to top 50 processes
- 5-second refresh interval (fixed)
- Cannot monitor memory pressure
- Cannot show swap usage
- Cannot show compressed memory

**System Limitations**:
- Cannot quit protected system processes
- Cannot quit processes owned by other users (without admin)
- Purge requires admin password each time
- May not work in sandboxed environments

## Privacy and Security

**What the App Accesses**:
- Process list (via `ps` command)
- Process IDs and names
- Memory usage information

**What the App Does NOT Access**:
- File contents
- Network traffic
- Keyboard or mouse input
- Screen contents
- Other applications' data

**Permissions Required**:
- No sandbox (to run system commands)
- Admin privileges (only for purge command)

**Your Data**:
- Nothing is stored or transmitted
- No analytics or tracking
- All operations are local
- No network connections

## Frequently Asked Questions

**Q: Why doesn't the app appear in the Dock?**
A: It's designed as a menu bar app (LSUIElement=true). This keeps it lightweight and always accessible.

**Q: Can I change the refresh interval?**
A: Currently fixed at 5 seconds. You can modify the source code to change this.

**Q: Will force quit save my work?**
A: No! Force quit (kill -9) immediately terminates the process. Save first!

**Q: Why do I need admin password for purge?**
A: The `purge` command requires root privileges to flush system memory.

**Q: Can I run this on older macOS versions?**
A: Requires macOS 13.0+ due to SwiftUI requirements.

**Q: Does it work on Intel Macs?**
A: Yes! The app is universal and works on both Apple Silicon and Intel.

**Q: How much memory does Craig-O-Clean use?**
A: Typically 20-40 MB. You can monitor it within itself!

**Q: Can I use this to kill system processes?**
A: Only with admin privileges, and some processes are protected by macOS.

## Getting Help

If something isn't working:

1. **Check the README.md** for troubleshooting
2. **Restart the app**: Quit from Activity Monitor and relaunch
3. **Check permissions**: Ensure the app isn't blocked in System Settings
4. **Review console logs**: Open Console.app and filter for "Craig-O-Clean"
5. **Report issues**: Open an issue on GitHub with details

## Uninstalling

To remove Craig-O-Clean:

1. Quit the app (may need to use Activity Monitor)
2. Delete `/Applications/Craig-O-Clean.app`
3. That's it - no other files are created

---

Enjoy using Craig-O-Clean! For more information, see README.md or BUILD_INSTRUCTIONS.md.
