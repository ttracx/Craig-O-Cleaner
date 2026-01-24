# macOS Terminal Commands Reference

A comprehensive collection of terminal commands for macOS (Apple Silicon) to manage applications, processes, memory, browsers, and system resources. Designed for Craig-O-Clean utility operations.

---

## Table of Contents

1. [Process & Application Management](#1-process--application-management)
2. [Force Quit Commands](#2-force-quit-commands)
3. [Background Tasks & Launch Agents](#3-background-tasks--launch-agents)
4. [Memory Management & Purging](#4-memory-management--purging)
5. [Browser Tab Management](#5-browser-tab-management)
6. [Cache & Temporary File Cleanup](#6-cache--temporary-file-cleanup)
7. [Disk Space Management](#7-disk-space-management)
8. [System Diagnostics](#8-system-diagnostics)
9. [Network Diagnostics](#9-network-diagnostics)
10. [Utility Commands](#10-utility-commands)

---

## 1. Process & Application Management

### List & Monitor Processes

| Command | Description | Notes |
|---------|-------------|-------|
| `ps aux` | List all running processes | Shows user, PID, CPU%, MEM%, command |
| `ps aux \| head -20` | List top 20 processes | Quick overview |
| `ps -eo pid,ppid,%cpu,%mem,comm \| sort -k3 -nr \| head -20` | Top 20 by CPU usage | Sorted descending |
| `ps -eo pid,ppid,%cpu,%mem,comm \| sort -k4 -nr \| head -20` | Top 20 by memory usage | Sorted descending |
| `top -l 1 -n 20 -o cpu` | Snapshot of top 20 processes by CPU | Single iteration |
| `top -l 1 -n 20 -o mem` | Snapshot of top 20 processes by memory | Single iteration |
| `top -l 1 -s 0` | Real-time process monitor (single snapshot) | Non-interactive |
| `htop` | Interactive process viewer | Install via Homebrew |
| `pgrep -l "process_name"` | Find process by name | Returns PID and name |
| `pgrep -f "pattern"` | Find process by full command | Matches arguments too |
| `lsof -c "process_name"` | List files opened by process | Useful for debugging |
| `lsof +D /path/to/directory` | List processes using a directory | Find what's holding files |

### Process Information

| Command | Description | Notes |
|---------|-------------|-------|
| `ps -p PID -o pid,ppid,%cpu,%mem,etime,comm` | Detailed info for specific PID | Elapsed time included |
| `ps -p PID -o args` | Full command line of process | Shows all arguments |
| `lsof -p PID` | All files opened by PID | File descriptors, sockets |
| `sample PID 5` | Profile a process for 5 seconds | CPU sampling |
| `sudo fs_usage -f filesys PID` | Real-time file system activity | Requires sudo |
| `sudo spindump PID 5 -file /tmp/spindump.txt` | Generate spin dump | Hang analysis |

### Application Management

| Command | Description | Notes |
|---------|-------------|-------|
| `open -a "Application Name"` | Launch application by name | Uses Launch Services |
| `open -a "Application Name" --args -arg1 -arg2` | Launch app with arguments | Pass CLI args |
| `open -n -a "Application Name"` | Launch new instance | Multiple windows |
| `mdfind "kMDItemKind == 'Application'"` | List all installed applications | Spotlight search |
| `mdfind -name ".app" -onlyin /Applications` | List apps in /Applications | Faster search |
| `system_profiler SPApplicationsDataType` | Detailed app information | Version, location, etc. |
| `defaults read /Applications/App.app/Contents/Info.plist` | Read app bundle info | CFBundleIdentifier, etc. |
| `osascript -e 'tell app "AppName" to quit'` | Gracefully quit application | AppleScript |
| `osascript -e 'tell app "AppName" to activate'` | Bring app to foreground | AppleScript |

---

## 2. Force Quit Commands

### Terminate Processes

| Command | Description | Notes |
|---------|-------------|-------|
| `kill PID` | Graceful termination (SIGTERM) | Allows cleanup |
| `kill -9 PID` | Force kill (SIGKILL) | Immediate termination |
| `kill -KILL PID` | Force kill (alternative syntax) | Same as -9 |
| `killall "ProcessName"` | Kill all processes by name | Case-sensitive |
| `killall -9 "ProcessName"` | Force kill all by name | No cleanup |
| `killall -KILL "ProcessName"` | Force kill (alternative) | Same as -9 |
| `killall -m "pattern"` | Kill matching regex pattern | Flexible matching |
| `pkill "pattern"` | Kill by pattern match | More flexible than killall |
| `pkill -9 "pattern"` | Force kill by pattern | Immediate termination |
| `pkill -f "full_command"` | Kill by full command line | Matches arguments |
| `pkill -u username` | Kill all processes by user | User-specific |
| `sudo killall -9 "ProcessName"` | Force kill system process | Requires root |

### Application-Specific Force Quit

| Command | Description | Notes |
|---------|-------------|-------|
| `osascript -e 'tell app "AppName" to quit'` | Graceful quit via AppleScript | Preferred method |
| `killall -9 Safari` | Force quit Safari | Loses unsaved data |
| `killall -9 "Google Chrome"` | Force quit Chrome | Process name has space |
| `killall -9 "Microsoft Edge"` | Force quit Edge | Process name has space |
| `killall -9 firefox` | Force quit Firefox | Lowercase |
| `killall -9 Arc` | Force quit Arc | Single word |
| `killall -9 Brave\ Browser` | Force quit Brave | Escape space |
| `killall -9 Opera` | Force quit Opera | Single word |
| `killall -9 Finder && open -a Finder` | Restart Finder | Relaunch immediately |
| `killall Dock` | Restart Dock | Auto-relaunches |
| `killall SystemUIServer` | Restart menu bar | Refresh menu extras |
| `killall ControlCenter` | Restart Control Center | macOS 11+ |

### Batch Force Quit

| Command | Description | Notes |
|---------|-------------|-------|
| `pkill -9 -f "chrome\|firefox\|safari"` | Force quit multiple browsers | Regex OR |
| `pgrep -f "pattern" \| xargs kill -9` | Kill all matching pattern | Pipeline approach |
| `for pid in $(pgrep "AppName"); do kill -9 $pid; done` | Loop kill all instances | Shell loop |

---

## 3. Background Tasks & Launch Agents

### List Background Services

| Command | Description | Notes |
|---------|-------------|-------|
| `launchctl list` | List all loaded launch jobs | User agents |
| `sudo launchctl list` | List all system launch jobs | Requires root |
| `launchctl list \| grep -v "^-"` | List only running jobs | Filter by PID |
| `launchctl print gui/$(id -u)` | Detailed user domain info | macOS 10.11+ |
| `launchctl print system` | Detailed system domain info | Requires sudo |
| `ls ~/Library/LaunchAgents/` | List user launch agents | Per-user services |
| `ls /Library/LaunchAgents/` | List global launch agents | All users |
| `ls /Library/LaunchDaemons/` | List launch daemons | System-wide |
| `ls /System/Library/LaunchAgents/` | List Apple launch agents | System components |
| `ls /System/Library/LaunchDaemons/` | List Apple daemons | System components |

### Manage Launch Services

| Command | Description | Notes |
|---------|-------------|-------|
| `launchctl load ~/Library/LaunchAgents/com.example.plist` | Load a launch agent | Start service |
| `launchctl unload ~/Library/LaunchAgents/com.example.plist` | Unload a launch agent | Stop service |
| `launchctl start com.example.service` | Start a loaded service | By label |
| `launchctl stop com.example.service` | Stop a running service | By label |
| `launchctl enable gui/$(id -u)/com.example.service` | Enable service | macOS 10.11+ |
| `launchctl disable gui/$(id -u)/com.example.service` | Disable service | macOS 10.11+ |
| `launchctl bootout gui/$(id -u)/com.example.service` | Remove from domain | Modern unload |
| `launchctl bootstrap gui/$(id -u) /path/to/plist` | Add to domain | Modern load |
| `launchctl kickstart -k gui/$(id -u)/com.example.service` | Restart service | Force restart |

### XPC Services

| Command | Description | Notes |
|---------|-------------|-------|
| `launchctl print system/com.apple.xpc.launchd` | XPC domain info | System XPC |
| `sudo launchctl plist /Library/PrivilegedHelperTools/` | List privileged helpers | SMJobBless helpers |

### Login Items

| Command | Description | Notes |
|---------|-------------|-------|
| `osascript -e 'tell app "System Events" to get name of login items'` | List login items | Via AppleScript |
| `sfltool list` | List login items (modern) | macOS 13+ |
| `defaults read com.apple.loginitems` | Read login items plist | May be empty |

---

## 4. Memory Management & Purging

### Memory Information

| Command | Description | Notes |
|---------|-------------|-------|
| `vm_stat` | Virtual memory statistics | Page-based stats |
| `vm_stat \| perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+(\w+)[^\d]+(\d+)/ and printf("%-16s % 16.2f MB\n", "$1:", $2 * $size / 1048576);'` | Human-readable memory stats | Formatted output |
| `top -l 1 -s 0 \| grep PhysMem` | Physical memory summary | Single line |
| `sysctl hw.memsize` | Total physical memory (bytes) | Hardware info |
| `sysctl hw.memsize \| awk '{print $2/1073741824 " GB"}'` | Total memory in GB | Formatted |
| `memory_pressure` | Memory pressure status | System recommendation |
| `sudo fs_usage -f cachehit` | Cache hit/miss ratio | Real-time monitoring |

### Memory Purging & Cleanup

| Command | Description | Notes |
|---------|-------------|-------|
| `sudo purge` | Purge inactive memory | Frees cached memory |
| `sync` | Flush file system buffers | Write pending data |
| `sync && sudo purge` | Full memory cleanup | Combined operation |
| `sudo sysctl -w vm.swappiness=0` | Reduce swap usage | Linux-style (limited on macOS) |
| `sudo nvram boot-args="vm_compressor=2"` | Configure memory compressor | Requires reboot |

### Swap Management

| Command | Description | Notes |
|---------|-------------|-------|
| `sysctl vm.swapusage` | Current swap usage | Encrypted swap |
| `ls -lh /private/var/vm/` | Swap file locations | Sleep image included |
| `sudo rm /private/var/vm/sleepimage` | Remove sleep image | Recreated on sleep |
| `sudo pmset -a hibernatemode 0` | Disable hibernation | Saves disk space |
| `sudo pmset -a hibernatemode 3` | Enable hibernation | Default for laptops |

### Memory Pressure Simulation

| Command | Description | Notes |
|---------|-------------|-------|
| `memory_pressure -l critical` | Simulate critical pressure | Testing only |
| `memory_pressure -l warn` | Simulate warning pressure | Testing only |
| `memory_pressure -l normal` | Return to normal | Reset state |

---

## 5. Browser Tab Management

### Safari

| Command | Description | Notes |
|---------|-------------|-------|
| `osascript -e 'tell app "Safari" to get URL of every tab of every window'` | List all tab URLs | Returns list |
| `osascript -e 'tell app "Safari" to get name of every tab of every window'` | List all tab titles | Returns list |
| `osascript -e 'tell app "Safari" to count tabs of window 1'` | Count tabs in window 1 | Single window |
| `osascript -e 'tell app "Safari" to close tab 1 of window 1'` | Close specific tab | By index |
| `osascript -e 'tell app "Safari" to close (tabs of window 1 whose URL contains "example.com")'` | Close tabs by domain | Filtered close |
| `osascript -e 'tell app "Safari" to close every tab of every window'` | Close all tabs | All windows |
| `osascript -e 'tell app "Safari" to close window 1'` | Close window with tabs | Single window |
| `osascript -e 'tell app "Safari" to make new document with properties {URL:"https://example.com"}'` | Open URL in new tab | New tab |
| `osascript -e 'tell app "Safari" to set URL of current tab of window 1 to "https://example.com"'` | Navigate current tab | Change URL |

### Safari - Tab Groups (macOS Monterey+)

| Command | Description | Notes |
|---------|-------------|-------|
| `osascript -e 'tell app "Safari" to get name of every tab group of window 1'` | List tab groups | Monterey+ |
| `osascript -e 'tell app "Safari" to get tabs of tab group "GroupName" of window 1'` | Tabs in specific group | By name |

### Google Chrome

| Command | Description | Notes |
|---------|-------------|-------|
| `osascript -e 'tell app "Google Chrome" to get URL of every tab of every window'` | List all tab URLs | Returns list |
| `osascript -e 'tell app "Google Chrome" to get title of every tab of every window'` | List all tab titles | Returns list |
| `osascript -e 'tell app "Google Chrome" to count tabs of window 1'` | Count tabs in window 1 | Single window |
| `osascript -e 'tell app "Google Chrome" to close tab 1 of window 1'` | Close specific tab | By index |
| `osascript -e 'tell app "Google Chrome" to close (tabs of window 1 whose URL contains "example.com")'` | Close tabs by domain | Filtered close |
| `osascript -e 'tell app "Google Chrome" to close every tab of every window'` | Close all tabs | All windows |
| `osascript -e 'tell app "Google Chrome" to make new tab at end of tabs of window 1 with properties {URL:"https://example.com"}'` | Open URL in new tab | New tab |
| `osascript -e 'tell app "Google Chrome" to tell window 1 to set active tab index to 1'` | Switch to tab 1 | Change active tab |
| `osascript -e 'tell app "Google Chrome" to reload active tab of window 1'` | Reload active tab | Refresh |

### Microsoft Edge

| Command | Description | Notes |
|---------|-------------|-------|
| `osascript -e 'tell app "Microsoft Edge" to get URL of every tab of every window'` | List all tab URLs | Returns list |
| `osascript -e 'tell app "Microsoft Edge" to get title of every tab of every window'` | List all tab titles | Returns list |
| `osascript -e 'tell app "Microsoft Edge" to close tab 1 of window 1'` | Close specific tab | By index |
| `osascript -e 'tell app "Microsoft Edge" to close (tabs of window 1 whose URL contains "example.com")'` | Close tabs by domain | Filtered close |
| `osascript -e 'tell app "Microsoft Edge" to make new tab at end of tabs of window 1 with properties {URL:"https://example.com"}'` | Open URL in new tab | New tab |

### Brave Browser

| Command | Description | Notes |
|---------|-------------|-------|
| `osascript -e 'tell app "Brave Browser" to get URL of every tab of every window'` | List all tab URLs | Returns list |
| `osascript -e 'tell app "Brave Browser" to get title of every tab of every window'` | List all tab titles | Returns list |
| `osascript -e 'tell app "Brave Browser" to close tab 1 of window 1'` | Close specific tab | By index |
| `osascript -e 'tell app "Brave Browser" to close (tabs of window 1 whose URL contains "example.com")'` | Close tabs by domain | Filtered close |
| `osascript -e 'tell app "Brave Browser" to make new tab at end of tabs of window 1 with properties {URL:"https://example.com"}'` | Open URL in new tab | New tab |

### Arc Browser

| Command | Description | Notes |
|---------|-------------|-------|
| `osascript -e 'tell app "Arc" to get URL of every tab of every window'` | List all tab URLs | Arc-specific |
| `osascript -e 'tell app "Arc" to get title of every tab of every window'` | List all tab titles | Arc-specific |
| `osascript -e 'tell app "Arc" to close tab 1 of window 1'` | Close specific tab | By index |
| `osascript -e 'tell app "Arc" to make new tab with properties {URL:"https://example.com"}'` | Open URL in new tab | New tab |

### Firefox (Limited AppleScript Support)

| Command | Description | Notes |
|---------|-------------|-------|
| `osascript -e 'tell app "Firefox" to activate'` | Bring Firefox to front | Limited scripting |
| `osascript -e 'tell app "Firefox" to open location "https://example.com"'` | Open URL | Basic support |
| `killall -9 firefox` | Force quit Firefox | No tab control |

### Opera

| Command | Description | Notes |
|---------|-------------|-------|
| `osascript -e 'tell app "Opera" to get URL of every tab of every window'` | List all tab URLs | Chromium-based |
| `osascript -e 'tell app "Opera" to close tab 1 of window 1'` | Close specific tab | By index |

### Browser Resource Monitoring

| Command | Description | Notes |
|---------|-------------|-------|
| `ps aux \| grep -i "google chrome helper" \| sort -k4 -nr \| head -10` | Top Chrome processes by memory | Per-tab processes |
| `ps aux \| grep -i "safari" \| sort -k4 -nr` | Safari processes by memory | WebContent processes |
| `ps aux \| grep -i "microsoft edge helper" \| sort -k4 -nr \| head -10` | Top Edge processes by memory | Per-tab processes |
| `ps aux \| grep -i "brave browser helper" \| sort -k4 -nr \| head -10` | Top Brave processes by memory | Per-tab processes |
| `top -l 1 -o mem \| grep -i "chrome\|safari\|firefox\|edge\|brave\|arc"` | Browser memory snapshot | All browsers |

### Close Resource-Heavy Browser Tabs (Advanced)

```bash
# Find and optionally kill Chrome helper processes using >500MB
ps aux | grep "Google Chrome Helper" | awk '$4 > 5.0 {print $2, $4"%", $11}'

# Kill Chrome tabs using excessive memory (>1GB estimated)
ps aux | grep "Google Chrome Helper (Renderer)" | awk '$6 > 1000000 {print $2}' | xargs kill -9
```

---

## 6. Cache & Temporary File Cleanup

### User Cache Directories

| Command | Description | Notes |
|---------|-------------|-------|
| `rm -rf ~/Library/Caches/*` | Clear all user caches | Regenerated as needed |
| `rm -rf ~/Library/Caches/com.apple.Safari/*` | Clear Safari cache | Browser cache |
| `rm -rf ~/Library/Caches/Google/Chrome/*` | Clear Chrome cache | Browser cache |
| `rm -rf ~/Library/Caches/com.microsoft.Edge/*` | Clear Edge cache | Browser cache |
| `rm -rf ~/Library/Caches/com.brave.Browser/*` | Clear Brave cache | Browser cache |
| `rm -rf ~/Library/Caches/Firefox/*` | Clear Firefox cache | Browser cache |
| `rm -rf ~/Library/Caches/Arc/*` | Clear Arc cache | Browser cache |
| `rm -rf ~/Library/Caches/com.apple.dt.Xcode/*` | Clear Xcode cache | Developer cache |
| `rm -rf ~/Library/Caches/Homebrew/*` | Clear Homebrew cache | Package cache |
| `rm -rf ~/Library/Caches/pip/*` | Clear pip cache | Python packages |
| `rm -rf ~/Library/Caches/yarn/*` | Clear Yarn cache | Node packages |
| `rm -rf ~/Library/Caches/CocoaPods/*` | Clear CocoaPods cache | iOS dependencies |

### System Cache Directories

| Command | Description | Notes |
|---------|-------------|-------|
| `sudo rm -rf /Library/Caches/*` | Clear system caches | Requires root |
| `sudo rm -rf /System/Library/Caches/*` | Clear Apple system caches | Use with caution |
| `sudo rm -rf /private/var/folders/*/*/C/*` | Clear per-user temp caches | System temp |
| `sudo rm -rf /private/var/folders/*/*/T/*` | Clear temp files | System temp |

### Application-Specific Caches

| Command | Description | Notes |
|---------|-------------|-------|
| `rm -rf ~/Library/Application\ Support/Slack/Cache/*` | Clear Slack cache | Electron app |
| `rm -rf ~/Library/Application\ Support/discord/Cache/*` | Clear Discord cache | Electron app |
| `rm -rf ~/Library/Application\ Support/Spotify/PersistentCache/*` | Clear Spotify cache | Music cache |
| `rm -rf ~/Library/Application\ Support/Code/Cache/*` | Clear VS Code cache | Editor cache |
| `rm -rf ~/Library/Group\ Containers/*.Office/OfficeFileCache/*` | Clear Office cache | Microsoft Office |
| `rm -rf ~/Library/Containers/com.docker.docker/Data/vms/*` | Clear Docker VM cache | Docker Desktop |

### Temporary Files

| Command | Description | Notes |
|---------|-------------|-------|
| `rm -rf /tmp/*` | Clear /tmp directory | System temp |
| `rm -rf /private/tmp/*` | Clear private tmp | Same as /tmp |
| `rm -rf ~/Downloads/*.dmg` | Clear downloaded disk images | Installer files |
| `rm -rf ~/Downloads/*.pkg` | Clear downloaded packages | Installer files |
| `rm -rf ~/Downloads/*.zip` | Clear downloaded archives | Archive files |
| `sudo periodic daily weekly monthly` | Run periodic maintenance | System cleanup |

### Log Files

| Command | Description | Notes |
|---------|-------------|-------|
| `sudo rm -rf /private/var/log/*.log` | Clear system logs | Regenerated |
| `sudo rm -rf /private/var/log/asl/*.asl` | Clear ASL logs | Apple System Log |
| `rm -rf ~/Library/Logs/*` | Clear user logs | Application logs |
| `sudo log erase --all` | Erase unified log | macOS 10.12+ |

### DNS Cache

| Command | Description | Notes |
|---------|-------------|-------|
| `sudo dscacheutil -flushcache` | Flush DNS cache | Directory services |
| `sudo killall -HUP mDNSResponder` | Restart mDNSResponder | Modern macOS |
| `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder` | Complete DNS flush | Combined |

---

## 7. Disk Space Management

### Disk Usage Analysis

| Command | Description | Notes |
|---------|-------------|-------|
| `df -h` | Disk space summary | Human-readable |
| `df -h /` | Root volume space | Boot volume |
| `du -sh ~/*` | Size of home directory items | Summary view |
| `du -sh ~/Library/*` | Size of Library folders | Find large items |
| `du -sh /Applications/*` | Size of applications | App sizes |
| `du -d 1 -h ~ \| sort -hr \| head -20` | Top 20 largest home dirs | Sorted |
| `sudo du -d 1 -h / \| sort -hr \| head -20` | Top 20 largest root dirs | System-wide |
| `ncdu /` | Interactive disk usage | Install via Homebrew |
| `find ~ -type f -size +100M -exec ls -lh {} \;` | Files larger than 100MB | Large file search |
| `find ~ -type f -size +1G -exec ls -lh {} \;` | Files larger than 1GB | Very large files |
| `mdfind -onlyin ~ "kMDItemFSSize > 100000000"` | Spotlight large files | Fast search |

### Storage Management

| Command | Description | Notes |
|---------|-------------|-------|
| `tmutil listlocalsnapshotdates` | List Time Machine snapshots | Local snapshots |
| `sudo tmutil deletelocalsnapshots YYYY-MM-DD` | Delete specific snapshot | Frees space |
| `sudo tmutil thinlocalsnapshots / 10000000000 4` | Thin snapshots to free 10GB | Space recovery |
| `xcrun simctl delete unavailable` | Delete unavailable iOS simulators | Developer cleanup |
| `rm -rf ~/Library/Developer/Xcode/DerivedData/*` | Clear Xcode derived data | Build artifacts |
| `rm -rf ~/Library/Developer/Xcode/Archives/*` | Clear Xcode archives | Old builds |
| `rm -rf ~/Library/Developer/CoreSimulator/Devices/*` | Clear iOS simulators | All simulators |
| `docker system prune -a -f` | Clean Docker resources | All unused data |
| `docker volume prune -f` | Clean Docker volumes | Unused volumes |
| `brew cleanup --prune=all` | Clean Homebrew | Remove old versions |
| `npm cache clean --force` | Clean npm cache | Node.js packages |
| `yarn cache clean` | Clean Yarn cache | Node.js packages |
| `pip cache purge` | Clean pip cache | Python packages |
| `gem cleanup` | Clean Ruby gems | Old versions |

### Trash Management

| Command | Description | Notes |
|---------|-------------|-------|
| `rm -rf ~/.Trash/*` | Empty user Trash | Permanent delete |
| `sudo rm -rf /Volumes/*/.Trashes/*` | Empty all volume Trashes | External drives |
| `osascript -e 'tell app "Finder" to empty trash'` | Empty Trash via Finder | Animated |
| `du -sh ~/.Trash` | Check Trash size | Before emptying |

### Mail & Message Attachments

| Command | Description | Notes |
|---------|-------------|-------|
| `du -sh ~/Library/Mail` | Check Mail storage | Email data |
| `rm -rf ~/Library/Mail/V*/MailData/Envelope\ Index*` | Rebuild Mail index | Forces reindex |
| `du -sh ~/Library/Messages/Attachments` | Check iMessage attachments | Attachment size |
| `rm -rf ~/Library/Messages/Attachments/*` | Clear iMessage attachments | Frees space |

---

## 8. System Diagnostics

### System Information

| Command | Description | Notes |
|---------|-------------|-------|
| `system_profiler SPHardwareDataType` | Hardware overview | Model, CPU, RAM |
| `system_profiler SPSoftwareDataType` | Software overview | macOS version |
| `system_profiler SPStorageDataType` | Storage information | Volumes, space |
| `system_profiler SPMemoryDataType` | Memory modules | RAM details |
| `sysctl -a \| grep machdep.cpu` | CPU details | Architecture, features |
| `sysctl hw.ncpu` | Number of CPU cores | Logical cores |
| `sysctl hw.physicalcpu` | Physical CPU cores | Physical cores |
| `sysctl hw.memsize` | Total RAM | In bytes |
| `sw_vers` | macOS version info | Version, build |
| `uname -a` | Kernel information | Darwin version |
| `arch` | CPU architecture | arm64 for Apple Silicon |
| `ioreg -l \| grep -i "battery capacity"` | Battery capacity | Laptop battery |
| `pmset -g batt` | Battery status | Charge level |
| `pmset -g` | Power management settings | Sleep, hibernate |

### CPU Diagnostics

| Command | Description | Notes |
|---------|-------------|-------|
| `top -l 1 -s 0 \| grep "CPU usage"` | CPU usage summary | Snapshot |
| `iostat -c 5` | CPU statistics | 5 samples |
| `sysctl -n machdep.cpu.brand_string` | CPU model name | Full name |
| `powermetrics --samplers cpu_power -n 1` | CPU power usage | Apple Silicon |
| `sudo powermetrics --samplers all -n 1` | All power metrics | Detailed |

### Memory Diagnostics

| Command | Description | Notes |
|---------|-------------|-------|
| `vm_stat` | Virtual memory stats | Page-level |
| `memory_pressure` | Memory pressure state | System status |
| `top -l 1 -s 0 \| grep PhysMem` | Physical memory summary | Quick check |
| `sysctl vm.swapusage` | Swap usage | Encrypted swap |
| `sudo leaks PID` | Check for memory leaks | Debugging |
| `sudo heap PID` | Heap analysis | Memory allocation |

### Disk Diagnostics

| Command | Description | Notes |
|---------|-------------|-------|
| `diskutil list` | List all disks | Partitions |
| `diskutil info /` | Root volume info | Details |
| `diskutil verifyVolume /` | Verify volume integrity | File system check |
| `sudo diskutil repairVolume /` | Repair volume | Fix errors |
| `iostat -d 5` | Disk I/O statistics | 5 samples |
| `fs_usage -f diskio` | Real-time disk I/O | Live monitoring |
| `sudo smartctl -a /dev/disk0` | SMART status | Install via Homebrew |

### Process Diagnostics

| Command | Description | Notes |
|---------|-------------|-------|
| `sudo sysdiagnose` | Full system diagnostic | Creates archive |
| `sudo spindump` | Spin dump (hangs) | CPU sampling |
| `sample PID 10` | Sample process 10 sec | Profiling |
| `sudo vm_stat -c 5` | VM stats 5 samples | Continuous |
| `sudo fs_usage PID` | File system activity | Real-time |
| `sudo dtruss -p PID` | System call trace | Debugging |
| `sudo opensnoop -p PID` | File open tracking | DTrace |

---

## 9. Network Diagnostics

### Connection Status

| Command | Description | Notes |
|---------|-------------|-------|
| `networksetup -listallhardwareports` | List network interfaces | Hardware info |
| `networksetup -getinfo "Wi-Fi"` | Wi-Fi interface info | IP, router |
| `ifconfig` | All interface details | Full config |
| `ifconfig en0` | Specific interface (usually Wi-Fi) | Single interface |
| `netstat -i` | Interface statistics | Packet counts |
| `netstat -nr` | Routing table | Network routes |
| `route get default` | Default gateway | Internet route |
| `scutil --nwi` | Network interface state | Current status |
| `scutil --dns` | DNS configuration | Resolvers |

### Connection Testing

| Command | Description | Notes |
|---------|-------------|-------|
| `ping -c 5 8.8.8.8` | Ping test | 5 packets |
| `ping -c 5 google.com` | DNS + ping test | Name resolution |
| `traceroute google.com` | Trace route | Path to host |
| `mtr google.com` | Enhanced traceroute | Install via Homebrew |
| `nc -zv host port` | Test port connectivity | Netcat |
| `curl -I https://google.com` | HTTP headers | Response check |
| `curl -o /dev/null -s -w "%{time_total}\n" https://google.com` | Response time | Performance |

### Port & Connection Monitoring

| Command | Description | Notes |
|---------|-------------|-------|
| `netstat -an \| grep LISTEN` | Listening ports | Open ports |
| `netstat -an \| grep ESTABLISHED` | Active connections | Current connections |
| `lsof -i -P` | Processes with network | All network activity |
| `lsof -i :80` | Processes on port 80 | Specific port |
| `lsof -i tcp` | TCP connections | Protocol filter |
| `sudo lsof -i -P -n` | Detailed network list | Numeric output |
| `nettop` | Real-time network monitor | Interactive |
| `nettop -m tcp` | TCP connections only | Protocol filter |

### Wi-Fi Diagnostics

| Command | Description | Notes |
|---------|-------------|-------|
| `/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I` | Wi-Fi status | Signal strength |
| `/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -s` | Scan networks | Available networks |
| `networksetup -setairportpower en0 off && networksetup -setairportpower en0 on` | Toggle Wi-Fi | Quick reset |
| `sudo wdutil diagnose` | Wi-Fi diagnostics | Creates report |

### Bandwidth Testing

| Command | Description | Notes |
|---------|-------------|-------|
| `networkQuality` | Network quality test | macOS 12+ |
| `networkQuality -v` | Verbose network test | Detailed output |

---

## 10. Utility Commands

### Permissions & Security

| Command | Description | Notes |
|---------|-------------|-------|
| `tccutil reset All` | Reset all TCC permissions | Requires SIP disable |
| `tccutil reset Accessibility` | Reset Accessibility permissions | Specific category |
| `tccutil reset AppleEvents` | Reset Automation permissions | AppleScript access |
| `sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT * FROM access"` | View TCC database | Read permissions |
| `spctl --status` | Gatekeeper status | Security check |
| `csrutil status` | SIP status | System Integrity |
| `sudo spctl --master-disable` | Disable Gatekeeper | Allow all apps |
| `sudo spctl --master-enable` | Enable Gatekeeper | Restore security |

### Spotlight & Indexing

| Command | Description | Notes |
|---------|-------------|-------|
| `mdutil -s /` | Spotlight status | Indexing state |
| `sudo mdutil -E /` | Reindex Spotlight | Rebuild index |
| `sudo mdutil -i off /` | Disable Spotlight | Stop indexing |
| `sudo mdutil -i on /` | Enable Spotlight | Resume indexing |
| `mdfind "kMDItemKind == 'Application'"` | Find apps via Spotlight | Quick search |
| `mdfind -name "filename"` | Find file by name | Fast search |

### System Maintenance

| Command | Description | Notes |
|---------|-------------|-------|
| `sudo periodic daily` | Daily maintenance | Cleanup scripts |
| `sudo periodic weekly` | Weekly maintenance | Cleanup scripts |
| `sudo periodic monthly` | Monthly maintenance | Cleanup scripts |
| `sudo periodic daily weekly monthly` | All maintenance | Combined |
| `sudo update_dyld_shared_cache` | Update dyld cache | System libraries |
| `sudo kextcache -system-prelinked-kernel` | Rebuild kernel cache | Boot optimization |
| `sudo kextcache -system-caches` | Rebuild system caches | All caches |

### Defaults & Preferences

| Command | Description | Notes |
|---------|-------------|-------|
| `defaults read` | All user defaults | Preferences dump |
| `defaults read com.apple.finder` | Finder preferences | App-specific |
| `defaults write com.apple.finder AppleShowAllFiles -bool true` | Show hidden files | Finder setting |
| `defaults write com.apple.screencapture location ~/Screenshots` | Change screenshot location | Custom path |
| `defaults write com.apple.dock autohide-delay -float 0` | Instant Dock hide | UI tweak |
| `defaults delete com.apple.finder` | Reset Finder prefs | Factory reset |
| `killall cfprefsd` | Restart preferences daemon | Apply changes |

### NVRAM & SMC

| Command | Description | Notes |
|---------|-------------|-------|
| `nvram -p` | Print NVRAM contents | Boot settings |
| `sudo nvram -c` | Clear NVRAM | Factory reset |
| `sudo shutdown -r now` | Reboot system | Restart |
| `sudo shutdown -h now` | Shutdown system | Power off |

### Quick Look & Preview

| Command | Description | Notes |
|---------|-------------|-------|
| `qlmanage -r` | Reset Quick Look | Fix preview issues |
| `qlmanage -r cache` | Clear Quick Look cache | Free space |
| `qlmanage -p file.pdf` | Preview file | Quick Look CLI |

### Clipboard

| Command | Description | Notes |
|---------|-------------|-------|
| `pbcopy < file.txt` | Copy file to clipboard | Pipe content |
| `pbpaste` | Paste clipboard content | Output content |
| `pbpaste > file.txt` | Save clipboard to file | Export |

### Notification Center

| Command | Description | Notes |
|---------|-------------|-------|
| `killall NotificationCenter` | Restart Notification Center | Clear stuck notifications |
| `defaults write com.apple.notificationcenterui bannerTime 2` | Set banner duration | Seconds |

---

## Quick Reference: Common Cleanup Workflow

```bash
# 1. Check disk space before cleanup
df -h /

# 2. Memory cleanup
sync && sudo purge

# 3. Clear user caches
rm -rf ~/Library/Caches/*

# 4. Clear system temporary files
sudo rm -rf /private/var/folders/*/*/C/*
sudo rm -rf /private/var/folders/*/*/T/*

# 5. Empty Trash
rm -rf ~/.Trash/*

# 6. Flush DNS cache
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder

# 7. Run periodic maintenance
sudo periodic daily weekly monthly

# 8. Clear Xcode derived data (developers)
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 9. Clear Homebrew cache
brew cleanup --prune=all

# 10. Check disk space after cleanup
df -h /
```

---

## Quick Reference: Browser Resource Cleanup

```bash
# Close all browser tabs via AppleScript (choose your browser)
osascript -e 'tell app "Safari" to close every tab of every window'
osascript -e 'tell app "Google Chrome" to close every tab of every window'
osascript -e 'tell app "Microsoft Edge" to close every tab of every window'

# Force quit all browsers
killall Safari "Google Chrome" "Microsoft Edge" firefox "Brave Browser" Arc 2>/dev/null

# Clear all browser caches
rm -rf ~/Library/Caches/com.apple.Safari/*
rm -rf ~/Library/Caches/Google/Chrome/*
rm -rf ~/Library/Caches/com.microsoft.Edge/*
rm -rf ~/Library/Caches/com.brave.Browser/*
rm -rf ~/Library/Caches/Firefox/*
rm -rf ~/Library/Caches/Arc/*
```

---

## Notes

- **Apple Silicon Compatibility**: All commands are compatible with Apple Silicon (M1/M2/M3/M4) Macs
- **Permissions**: Commands with `sudo` require administrator password
- **Safety**: Always verify paths before running `rm -rf` commands
- **Backups**: Create backups before major cleanup operations
- **Testing**: Test commands in a safe environment before automation
- **AppleScript Permissions**: Browser automation requires Automation permissions in System Settings > Privacy & Security > Automation
