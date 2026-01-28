# Craig-O-Clean Sandbox Capability Matrix

**Version:** 1.0
**Date:** 2026-01-28
**Distribution Target:** Mac App Store (Primary) | Developer ID (Extended)

---

## Legend

| Symbol | Meaning |
|--------|---------|
| MAS | Mac App Store compatible |
| DevID | Developer ID distribution only |
| Native | Replace shell with native API |
| Bookmark | Requires security-scoped bookmark |
| Automation | Requires Apple Events/Automation TCC |
| Remove | Feature not possible in sandbox |
| Degrade | Show instructions instead of action |

---

## Diagnostics Capabilities

| ID | Feature | Current Implementation | MAS Compatible? | Required Permission(s) | Refactor Strategy | Degrade Behavior |
|----|---------|------------------------|-----------------|------------------------|-------------------|------------------|
| `diag.mem.pressure` | Memory Pressure | `memory_pressure` shell | **Partial** | None | Native: `DispatchSource.makeMemoryPressureSource` | N/A |
| `diag.mem.vmstat` | VM Statistics | `vm_stat` shell | **Yes** | None | Native: Already uses `vm_statistics64` in SystemMetricsService | N/A |
| `diag.mem.top` | Physical Memory Summary | `top -l 1 \| grep PhysMem` | **Yes** | None | Native: Use existing `MemoryMetrics` from service | N/A |
| `diag.mem.total` | Total Physical Memory | `sysctl hw.memsize` | **Yes** | None | Native: `ProcessInfo.processInfo.physicalMemory` | N/A |
| `diag.mem.top_processes` | Top Memory Processes | `ps -eo pid,rss,comm` | **Partial** | None | Native: `NSWorkspace.runningApplications` + `proc_pid_rusage` | Show running apps only |
| `diag.disk.free` | Disk Free Space | `df -h /` | **Yes** | None | Native: `FileManager.attributesOfFileSystem` | N/A |
| `diag.disk.usage_home` | Home Directory Usage | `du -sh ~/*` | **Partial** | User-selected | Bookmark: Require folder selection | Prompt for folder |
| `diag.disk.usage_library` | Library Folder Usage | `du -sh ~/Library/*` | **No** | Bookmark | Bookmark: Use security-scoped bookmark | Show "Select folder" |
| `diag.disk.large_files` | Find Large Files | `find ~ -type f -size +100M` | **Partial** | User-selected | Bookmark: Scan within user-selected scope | Prompt for folder |
| `diag.disk.info` | Disk List | `diskutil list` | **Yes** | None | Native: IOKit disk enumeration or keep shell | N/A |
| `diag.cpu.top` | Top CPU Processes | `ps aux --sort=-%cpu` | **Partial** | None | Native: `NSWorkspace.runningApplications` | Show running apps only |
| `diag.cpu.info` | CPU Information | `sysctl -n machdep.cpu.brand_string` | **Yes** | None | Native: `sysctl()` direct call | N/A |
| `diag.sys.version` | macOS Version | `sw_vers` | **Yes** | None | Native: `ProcessInfo.operatingSystemVersion` | N/A |
| `diag.sys.uptime` | System Uptime | `uptime` | **Yes** | None | Native: `sysctl(KERN_BOOTTIME)` - already in service | N/A |
| `diag.sys.hardware` | Hardware Overview | `system_profiler SPHardwareDataType` | **Partial** | None | Native: IOKit + sysctl for hardware info | Limited info |
| `diag.net.interfaces` | Network Interfaces | `networksetup -listallhardwareports` | **Partial** | None | Native: `getifaddrs()` - already in service | Show interfaces only |
| `diag.net.wifi` | Wi-Fi Information | `networksetup -getinfo Wi-Fi` | **No** | None | Remove: Network config not accessible | Show "Use System Settings" |
| `diag.battery.status` | Battery Status | `pmset -g batt` | **Partial** | None | Native: IOKit `IOPSCopyPowerSourcesInfo` | Use IOKit |

---

## Quick Clean Capabilities

| ID | Feature | Current Implementation | MAS Compatible? | Required Permission(s) | Refactor Strategy | Degrade Behavior |
|----|---------|------------------------|-----------------|------------------------|-------------------|------------------|
| `quick.dns.flush` | Flush DNS Cache | `dscacheutil -flushcache && killall -HUP mDNSResponder` | **No** (elevated) | Admin | Remove/Degrade | Show terminal command |
| `quick.temp.user` | Clear Temp Files | `rm -rf ~/Library/Caches/TemporaryItems/*` | **Partial** | Bookmark | Bookmark: User selects ~/Library | Prompt selection |
| `quick.ql.reset` | Reset Quick Look | `qlmanage -r cache` | **Partial** | None | Keep: May work in sandbox | Try, degrade if fails |
| `quick.restart.finder` | Restart Finder | `killall Finder` | **Partial** | Automation | Automation: `tell app "Finder" to quit` | Instruct user |
| `quick.restart.dock` | Restart Dock | `killall Dock` | **No** | None | Remove | Show Activity Monitor |
| `quick.restart.menubar` | Restart Menu Bar | `killall SystemUIServer` | **No** | None | Remove | Show Activity Monitor |
| `quick.restart.controlcenter` | Restart Control Center | `killall ControlCenter` | **No** | None | Remove | Show Activity Monitor |
| `quick.restart.notifications` | Restart Notification Center | `killall NotificationCenter` | **No** | None | Remove | Show Activity Monitor |

---

## Memory Capabilities

| ID | Feature | Current Implementation | MAS Compatible? | Required Permission(s) | Refactor Strategy | Degrade Behavior |
|----|---------|------------------------|-----------------|------------------------|-------------------|------------------|
| `quick.mem.purge` | Purge Inactive Memory | `purge` (elevated) | **No** | Admin | Remove | Suggest quit heavy apps |
| `quick.mem.sync_purge` | Sync & Purge Memory | `sync && purge` (elevated) | **No** | Admin | Remove | Suggest quit heavy apps |

**MAS Alternative for Memory:**
- Display memory pressure via native APIs
- List high-memory apps with "Quit" buttons (NSRunningApplication)
- Link to Activity Monitor
- Provide educational content about macOS memory management

---

## Deep Clean Capabilities

| ID | Feature | Current Implementation | MAS Compatible? | Required Permission(s) | Refactor Strategy | Degrade Behavior |
|----|---------|------------------------|-----------------|------------------------|-------------------|------------------|
| `deep.cache.user` | Clear User Caches | `rm -rf ~/Library/Caches/*` | **Partial** | Bookmark | Bookmark: User must select folder | Prompt selection |
| `deep.cache.apple` | Clear Apple App Caches | `rm -rf ~/Library/Caches/com.apple.*` | **Partial** | Bookmark | Bookmark: Within selected scope | Prompt selection |
| `deep.cache.old` | Clear Old Caches (7+ days) | `find ~/Library/Caches -atime +7 -delete` | **Partial** | Bookmark | Bookmark: Age filter within scope | Prompt selection |
| `deep.logs.user` | Clear User Logs | `rm -rf ~/Library/Logs/*` | **Partial** | Bookmark | Bookmark: User must select folder | Prompt selection |
| `deep.logs.old` | Clear Old Logs (7+ days) | `find ~/Library/Logs -mtime +7 -delete` | **Partial** | Bookmark | Bookmark: Age filter within scope | Prompt selection |
| `deep.logs.crashreports` | Clear Crash Reports | `rm -rf ~/Library/Application Support/CrashReporter/*` | **Partial** | Bookmark | Bookmark: User must select folder | Prompt selection |
| `deep.app.savedstate` | Clear Saved App State | `rm -rf ~/Library/Saved Application State/*` | **Partial** | Bookmark | Bookmark: User must select folder | Prompt selection |
| `deep.system.temp` | Clear System Temp | `rm -rf /private/var/tmp/*` | **No** | Admin | Remove | Show terminal command |
| `deep.system.asl` | Clear ASL Logs | `rm -rf /private/var/log/asl/*.asl` | **No** | Admin | Remove | Show terminal command |

---

## Browser Capabilities

| ID | Feature | Current Implementation | MAS Compatible? | Required Permission(s) | Refactor Strategy | Degrade Behavior |
|----|---------|------------------------|-----------------|------------------------|-------------------|------------------|
| `browser.safari.tabs.count` | Safari Tab Count | AppleScript | **Yes** | Automation (Safari) | Keep: NSAppleScript | Permission prompt |
| `browser.safari.tabs.list` | List Safari Tabs | AppleScript | **Yes** | Automation (Safari) | Keep: NSAppleScript | Permission prompt |
| `browser.safari.tabs.close_all` | Close All Safari Tabs | AppleScript | **Yes** | Automation (Safari) | Keep: NSAppleScript + confirm | Permission prompt |
| `browser.safari.quit` | Quit Safari | AppleScript | **Yes** | Automation (Safari) | Keep: NSAppleScript | Permission prompt |
| `browser.safari.force_quit` | Force Quit Safari | `killall -9 Safari` | **Partial** | None | Native: NSRunningApplication.forceTerminate() | Use native API |
| `browser.safari.cache` | Clear Safari Cache | `rm -rf ~/Library/Caches/com.apple.Safari/*` | **Partial** | Bookmark | Bookmark: User selects Safari cache folder | Prompt selection |
| `browser.chrome.tabs.count` | Chrome Tab Count | AppleScript | **Yes** | Automation (Chrome) | Keep: NSAppleScript | Permission prompt |
| `browser.chrome.tabs.list` | List Chrome Tabs | AppleScript | **Yes** | Automation (Chrome) | Keep: NSAppleScript | Permission prompt |
| `browser.chrome.tabs.close_all` | Close All Chrome Tabs | AppleScript | **Yes** | Automation (Chrome) | Keep: NSAppleScript + confirm | Permission prompt |
| `browser.chrome.quit` | Quit Chrome | AppleScript | **Yes** | Automation (Chrome) | Keep: NSAppleScript | Permission prompt |
| `browser.chrome.force_quit` | Force Quit Chrome | `killall -9 "Google Chrome"` | **Partial** | None | Native: NSRunningApplication.forceTerminate() | Use native API |
| `browser.chrome.helpers.kill` | Kill Chrome Helpers | `pkill -9 -f "Google Chrome Helper"` | **No** | None | Remove | Show Activity Monitor |
| `browser.chrome.cache` | Clear Chrome Cache | `rm -rf ~/Library/Caches/Google/Chrome/*` | **Partial** | Bookmark | Bookmark: User selects Chrome data folder | Prompt selection |
| `browser.edge.quit` | Quit Edge | AppleScript | **Yes** | Automation (Edge) | Keep: NSAppleScript | Permission prompt |
| `browser.brave.quit` | Quit Brave | AppleScript | **Yes** | Automation (Brave) | Keep: NSAppleScript | Permission prompt |
| `browser.firefox.quit` | Quit Firefox | AppleScript | **Yes** | Automation (Firefox) | Keep: NSAppleScript | Permission prompt |
| `browser.arc.quit` | Quit Arc | AppleScript | **Yes** | Automation (Arc) | Keep: NSAppleScript | Permission prompt |
| `browser.all.quit` | Quit All Browsers | AppleScript (multiple) | **Yes** | Automation (all) | Keep: NSAppleScript | Permission prompt |
| `browser.heavy.list` | Find Heavy Browser Processes | `ps aux \| grep` | **Partial** | None | Native: Filter runningApplications by bundle | Limited info |

---

## Developer Tools Capabilities

| ID | Feature | Current Implementation | MAS Compatible? | Required Permission(s) | Refactor Strategy | Degrade Behavior |
|----|---------|------------------------|-----------------|------------------------|-------------------|------------------|
| `dev.xcode.deriveddata` | Clear Xcode Derived Data | `rm -rf ~/Library/Developer/Xcode/DerivedData/*` | **Partial** | Bookmark | Bookmark: User selects DerivedData folder | Prompt selection |
| `dev.xcode.archives` | Clear Xcode Archives | `rm -rf ~/Library/Developer/Xcode/Archives/*` | **Partial** | Bookmark | Bookmark: User selects Archives folder | Prompt selection |
| `dev.xcode.devicesupport` | Clear iOS Device Support | `rm -rf ~/Library/Developer/Xcode/iOS DeviceSupport/*` | **Partial** | Bookmark | Bookmark: User selects folder | Prompt selection |
| `dev.simulator.caches` | Clear Simulator Caches | `rm -rf ~/Library/Developer/CoreSimulator/Caches/*` | **Partial** | Bookmark | Bookmark: User selects folder | Prompt selection |
| `dev.simulator.unavailable` | Delete Unavailable Simulators | `xcrun simctl delete unavailable` | **Partial** | None | Keep: May work if Xcode CLI installed | Try, instruct if fails |
| `dev.simulator.erase_all` | Erase All Simulators | `xcrun simctl erase all` | **Partial** | None | Keep: May work if Xcode CLI installed | Try, instruct if fails |
| `dev.cocoapods.cache` | Clear CocoaPods Cache | `rm -rf ~/Library/Caches/CocoaPods/*` | **Partial** | Bookmark | Bookmark: User selects folder | Prompt selection |
| `dev.npm.cache` | Clear npm Cache | `npm cache clean --force` | **Partial** | None | Keep: May work if npm installed | Try, instruct if fails |
| `dev.swiftpm.cache` | Clear Swift PM Cache | `rm -rf ~/Library/Caches/org.swift.swiftpm` | **Partial** | Bookmark | Bookmark: User selects folder | Prompt selection |
| `dev.brew.cleanup` | Homebrew Cleanup | `brew cleanup -s` | **Partial** | None | Keep: May work if brew installed | Try, instruct if fails |
| `dev.docker.info` | Docker Disk Usage | `docker system df` | **Partial** | None | Keep: May work if Docker installed | Try, instruct if fails |
| `dev.docker.prune` | Docker Prune Unused | `docker system prune -f` | **Partial** | None | Keep: May work if Docker installed | Try, instruct if fails |
| `dev.docker.prune_all` | Docker Prune All | `docker system prune -af --volumes` | **Partial** | None | Keep: Requires confirmation | Try, instruct if fails |

---

## Disk Capabilities

| ID | Feature | Current Implementation | MAS Compatible? | Required Permission(s) | Refactor Strategy | Degrade Behavior |
|----|---------|------------------------|-----------------|------------------------|-------------------|------------------|
| `disk.trash.size` | Trash Size | `du -sh ~/.Trash` | **Partial** | Bookmark | Bookmark: May need user permission | Try native first |
| `disk.trash.empty` | Empty Trash | `rm -rf ~/.Trash/*` | **Partial** | Bookmark | Automation: `tell app "Finder" to empty trash` | Use Finder automation |
| `disk.downloads.size` | Downloads Size | `du -sh ~/Downloads` | **Partial** | Bookmark | Bookmark: User selects Downloads | Prompt selection |

---

## System Capabilities

| ID | Feature | Current Implementation | MAS Compatible? | Required Permission(s) | Refactor Strategy | Degrade Behavior |
|----|---------|------------------------|-----------------|------------------------|-------------------|------------------|
| `sys.audio.restart` | Restart Audio Service | `killall coreaudiod` (elevated) | **No** | Admin | Remove | Show Activity Monitor |
| `sys.prefs.restart` | Restart Preferences Daemon | `killall cfprefsd` | **No** | None | Remove | Show Activity Monitor |
| `sys.maintenance.daily` | Run Daily Maintenance | `periodic daily` (elevated) | **No** | Admin | Remove | Show terminal command |
| `sys.maintenance.all` | Run Full Maintenance | `periodic daily weekly monthly` (elevated) | **No** | Admin | Remove | Show terminal command |
| `sys.spotlight.status` | Spotlight Status | `mdutil -s /` (elevated) | **No** | Admin | Remove | Show System Settings |
| `sys.spotlight.rebuild` | Rebuild Spotlight Index | `mdutil -E /` (elevated) | **No** | Admin | Remove | Show System Settings |
| `sys.launchd.list` | List Launch Jobs | `launchctl list` | **Partial** | None | Keep: May work in sandbox | Try, degrade if fails |
| `sys.launchd.user_agents` | User Launch Agents | `ls -la ~/Library/LaunchAgents/` | **Partial** | Bookmark | Bookmark: User selects folder | Prompt selection |

---

## Summary Statistics

### MAS Compatibility

| Status | Count | Percentage |
|--------|-------|------------|
| Fully MAS Compatible | 22 | 29% |
| Partially Compatible (needs changes) | 36 | 47% |
| Not MAS Compatible | 18 | 24% |
| **Total Capabilities** | **76** | 100% |

### Refactor Strategy Distribution

| Strategy | Count | Notes |
|----------|-------|-------|
| Keep (no changes) | 18 | Browser automation, simple diagnostics |
| Native API | 14 | Replace shell with Darwin/Mach APIs |
| Bookmark | 26 | Require security-scoped bookmarks |
| Remove | 12 | Admin-only features |
| Degrade | 6 | Show instructions/links |

### Permission Requirements (MAS Build)

| Permission | Required For |
|------------|--------------|
| None | 28 capabilities |
| Automation (Safari) | 6 capabilities |
| Automation (Chrome) | 5 capabilities |
| Automation (Edge) | 1 capability |
| Automation (Brave) | 1 capability |
| Automation (Arc) | 1 capability |
| Automation (Firefox) | 1 capability |
| Automation (System Events) | 1 capability |
| Security-Scoped Bookmark | 26 capabilities |

---

## Feature Tier System (Proposed)

### Tier 1: MAS Free (No Special Permissions)
- System metrics dashboard (CPU, RAM, disk, network)
- Running applications list
- Basic process info
- Memory pressure indicator
- Disk space info

### Tier 2: MAS Pro (With Automation Permission)
- Browser tab management (enumerate, close)
- Browser quit/force-quit
- Finder restart
- Trash emptying (via Finder)

### Tier 3: MAS Pro (With Bookmarks)
- User-selected folder cleanup
- Cache clearing (within selected scope)
- Log clearing (within selected scope)
- Developer tools cleanup (within selected scope)

### Tier 4: Developer ID Only
- Memory purge (sync/purge)
- System service restarts (Dock, MenuBar, Audio)
- DNS flush
- System maintenance scripts
- Spotlight management
- Force kill any process
