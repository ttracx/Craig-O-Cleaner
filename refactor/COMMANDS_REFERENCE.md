# Craig-O-Clean — Command Reference & Capability Catalog

**Purpose:** This document contains all terminal commands organized by capability group for implementation in the Craig-O-Clean capability catalog.

---

## Command Catalog Structure

Each command maps to a capability entry with:
- `id`: Unique identifier (e.g., `diag.memory.pressure`)
- `privilege`: `user` | `elevated` | `automation`
- `risk`: `safe` | `moderate` | `destructive`
- `timeout`: Execution timeout in seconds

---

## 1. DIAGNOSTICS GROUP

### 1.1 Memory Diagnostics

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `diag.mem.pressure` | Memory Pressure | `memory_pressure` | user | safe | 10 |
| `diag.mem.vmstat` | VM Statistics | `vm_stat` | user | safe | 5 |
| `diag.mem.top` | Memory Summary | `top -l 1 -s 0 \| grep PhysMem` | user | safe | 10 |
| `diag.mem.total` | Total Memory | `sysctl hw.memsize` | user | safe | 5 |
| `diag.mem.top_processes` | Top Memory Processes | `ps -eo pid,rss,comm \| sort -k2 -rn \| head -15` | user | safe | 10 |

```json
{
  "id": "diag.mem.pressure",
  "title": "Memory Pressure",
  "description": "Shows current memory pressure level and availability",
  "group": "diagnostics",
  "commandTemplate": "memory_pressure",
  "arguments": [],
  "workingDirectory": null,
  "timeout": 10,
  "privilegeLevel": "user",
  "riskClass": "safe",
  "outputParser": "memoryPressure",
  "parserPattern": null,
  "preflightChecks": [],
  "requiredPaths": [],
  "requiredApps": [],
  "icon": "gauge",
  "rollbackNotes": null,
  "estimatedDuration": 1
}
```

### 1.2 Disk Diagnostics

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `diag.disk.free` | Disk Free Space | `df -h /` | user | safe | 5 |
| `diag.disk.usage_home` | Home Directory Usage | `du -sh ~/* 2>/dev/null \| sort -hr \| head -15` | user | safe | 60 |
| `diag.disk.usage_library` | Library Usage | `du -sh ~/Library/* 2>/dev/null \| sort -hr \| head -15` | user | safe | 60 |
| `diag.disk.large_files` | Large Files (>100MB) | `find ~ -type f -size +100M -print0 2>/dev/null \| xargs -0 ls -lh 2>/dev/null \| head -20` | user | safe | 120 |
| `diag.disk.info` | Disk Information | `diskutil list` | user | safe | 10 |

### 1.3 CPU/Process Diagnostics

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `diag.cpu.top` | Top CPU Processes | `ps aux --sort=-%cpu \| head -15` | user | safe | 10 |
| `diag.cpu.info` | CPU Information | `sysctl -n machdep.cpu.brand_string` | user | safe | 5 |
| `diag.cpu.cores` | CPU Core Count | `sysctl hw.ncpu hw.physicalcpu hw.logicalcpu` | user | safe | 5 |
| `diag.process.list` | Process List | `ps aux \| head -30` | user | safe | 10 |
| `diag.process.snapshot` | System Snapshot | `top -l 1 -s 0 \| head -20` | user | safe | 15 |

### 1.4 System Information

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `diag.sys.version` | macOS Version | `sw_vers` | user | safe | 5 |
| `diag.sys.arch` | Architecture | `arch` | user | safe | 5 |
| `diag.sys.uptime` | System Uptime | `uptime` | user | safe | 5 |
| `diag.sys.hardware` | Hardware Overview | `system_profiler SPHardwareDataType` | user | safe | 30 |
| `diag.sys.storage` | Storage Details | `system_profiler SPStorageDataType` | user | safe | 30 |

### 1.5 Network Diagnostics

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `diag.net.interfaces` | Network Interfaces | `networksetup -listallhardwareports` | user | safe | 10 |
| `diag.net.wifi` | Wi-Fi Info | `networksetup -getinfo Wi-Fi 2>/dev/null` | user | safe | 5 |
| `diag.net.connections` | Active Connections | `netstat -an \| grep ESTABLISHED \| head -20` | user | safe | 10 |
| `diag.net.listening` | Listening Ports | `netstat -an \| grep LISTEN \| head -20` | user | safe | 10 |

---

## 2. QUICK CLEAN GROUP

### 2.1 Safe Cleanup Operations

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `quick.dns.flush` | Flush DNS Cache | `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder` | elevated | safe | 15 |
| `quick.temp.user` | Clear Temp Files | `rm -rf ~/Library/Caches/TemporaryItems/* 2>/dev/null` | user | safe | 30 |
| `quick.ql.reset` | Reset Quick Look | `qlmanage -r cache` | user | safe | 10 |

### 2.2 System Restarts

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `quick.restart.finder` | Restart Finder | `killall Finder` | user | moderate | 10 |
| `quick.restart.dock` | Restart Dock | `killall Dock` | user | moderate | 10 |
| `quick.restart.menubar` | Restart Menu Bar | `killall SystemUIServer` | user | moderate | 10 |
| `quick.restart.controlcenter` | Restart Control Center | `killall ControlCenter` | user | moderate | 10 |
| `quick.restart.notificationcenter` | Restart Notifications | `killall NotificationCenter` | user | moderate | 10 |

```json
{
  "id": "quick.restart.finder",
  "title": "Restart Finder",
  "description": "Restarts the Finder application to fix display glitches",
  "group": "quickClean",
  "commandTemplate": "killall Finder",
  "arguments": [],
  "workingDirectory": null,
  "timeout": 10,
  "privilegeLevel": "user",
  "riskClass": "moderate",
  "outputParser": "text",
  "parserPattern": null,
  "preflightChecks": [
    {
      "type": "appRunning",
      "target": "Finder",
      "failureMessage": "Finder is not running"
    }
  ],
  "requiredPaths": [],
  "requiredApps": ["Finder"],
  "icon": "arrow.clockwise",
  "rollbackNotes": "Finder will automatically restart",
  "estimatedDuration": 2
}
```

### 2.3 Memory Operations

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `quick.mem.purge` | Purge Inactive Memory | `sudo purge` | elevated | safe | 30 |
| `quick.mem.sync_purge` | Sync & Purge | `sync && sudo purge` | elevated | safe | 45 |

---

## 3. DEEP CLEAN GROUP

### 3.1 User Cache Cleanup

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `deep.cache.user` | Clear User Caches | `rm -rf ~/Library/Caches/*` | user | moderate | 120 |
| `deep.cache.apple` | Clear Apple App Caches | `rm -rf ~/Library/Caches/com.apple.*` | user | moderate | 60 |
| `deep.cache.old` | Clear Old Caches (7+ days) | `find ~/Library/Caches -type f -mtime +7 -delete 2>/dev/null` | user | safe | 120 |

**⚠️ SAFER ALTERNATIVE for user caches:**
```bash
# Instead of blanket rm -rf, use age-based deletion
find ~/Library/Caches -type f -atime +7 -delete 2>/dev/null
```

### 3.2 Log Cleanup

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `deep.logs.user` | Clear User Logs | `rm -rf ~/Library/Logs/*` | user | moderate | 60 |
| `deep.logs.old` | Clear Old Logs (7+ days) | `find ~/Library/Logs -type f -mtime +7 -delete 2>/dev/null` | user | safe | 60 |
| `deep.logs.crashreports` | Clear Crash Reports | `rm -rf ~/Library/Application\ Support/CrashReporter/*` | user | safe | 30 |

### 3.3 Application Leftovers

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `deep.app.savedstate` | Clear Saved App State | `rm -rf ~/Library/Saved\ Application\ State/*` | user | moderate | 30 |
| `deep.app.containers_temp` | Clear Container Temp | `find ~/Library/Containers -path "*/Data/tmp/*" -type f -delete 2>/dev/null` | user | safe | 60 |

### 3.4 System-Level Cleanup (Elevated)

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `deep.system.temp` | Clear System Temp | `sudo rm -rf /private/var/tmp/*` | elevated | moderate | 60 |
| `deep.system.folders` | Clear Folder Caches | `sudo rm -rf /private/var/folders/*` | elevated | moderate | 60 |
| `deep.system.asl` | Clear ASL Logs | `sudo rm -rf /private/var/log/asl/*.asl` | elevated | safe | 30 |

---

## 4. BROWSER MANAGEMENT GROUP

### 4.1 Safari Operations

| ID | Title | Command (AppleScript) | Privilege | Risk | Timeout |
|----|-------|-----------------------|-----------|------|---------|
| `browser.safari.tabs.count` | Safari Tab Count | See AppleScript below | automation | safe | 10 |
| `browser.safari.tabs.list` | List Safari Tabs | See AppleScript below | automation | safe | 15 |
| `browser.safari.tabs.close_all` | Close All Safari Tabs | See AppleScript below | automation | moderate | 15 |
| `browser.safari.tabs.close_pattern` | Close Safari Tabs by Pattern | See AppleScript below | automation | moderate | 30 |
| `browser.safari.quit` | Quit Safari | `osascript -e 'tell application "Safari" to quit'` | automation | moderate | 10 |
| `browser.safari.force_quit` | Force Quit Safari | `killall -9 Safari` | user | moderate | 5 |

**Safari Tab Count:**
```applescript
tell application "Safari"
    set tabCount to 0
    repeat with w in windows
        set tabCount to tabCount + (count of tabs of w)
    end repeat
    return tabCount
end tell
```

**Safari List All Tabs:**
```applescript
tell application "Safari"
    set urlList to {}
    repeat with w in windows
        repeat with t in tabs of w
            set end of urlList to URL of t
        end repeat
    end repeat
    return urlList
end tell
```

**Safari Close Tabs by Pattern:**
```applescript
tell application "Safari"
    set targetPattern to "{{PATTERN}}"
    repeat with w in windows
        set tabList to tabs of w
        repeat with t in tabList
            try
                if URL of t contains targetPattern then
                    close t
                end if
            end try
        end repeat
    end repeat
end tell
```

**Safari Close All Tabs:**
```applescript
tell application "Safari"
    repeat with w in windows
        try
            tell w to close (tabs)
        end try
    end repeat
end tell
```

### 4.2 Chrome/Chromium Operations

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `browser.chrome.tabs.count` | Chrome Tab Count | See AppleScript below | automation | safe | 10 |
| `browser.chrome.tabs.list` | List Chrome Tabs | See AppleScript below | automation | safe | 15 |
| `browser.chrome.tabs.close_all` | Close All Chrome Tabs | See AppleScript below | automation | moderate | 15 |
| `browser.chrome.tabs.close_pattern` | Close Chrome Tabs by Pattern | See AppleScript below | automation | moderate | 30 |
| `browser.chrome.quit` | Quit Chrome | `osascript -e 'tell application "Google Chrome" to quit'` | automation | moderate | 10 |
| `browser.chrome.force_quit` | Force Quit Chrome | `killall -9 "Google Chrome"` | user | moderate | 5 |
| `browser.chrome.helpers.kill` | Kill Chrome Helpers | `pkill -9 -f "Google Chrome Helper"` | user | moderate | 10 |

**Chrome Tab Count:**
```applescript
tell application "Google Chrome"
    set tabCount to 0
    repeat with w in windows
        set tabCount to tabCount + (count of tabs of w)
    end repeat
    return tabCount
end tell
```

**Chrome Close Tabs by Pattern:**
```applescript
tell application "Google Chrome"
    set targetPattern to "{{PATTERN}}"
    repeat with w in windows
        set tabList to tabs of w
        repeat with t in tabList
            try
                if URL of t contains targetPattern then
                    close t
                end if
            end try
        end repeat
    end repeat
end tell
```

### 4.3 Edge Operations

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `browser.edge.quit` | Quit Edge | `osascript -e 'tell application "Microsoft Edge" to quit'` | automation | moderate | 10 |
| `browser.edge.force_quit` | Force Quit Edge | `killall -9 "Microsoft Edge"` | user | moderate | 5 |
| `browser.edge.tabs.close_all` | Close All Edge Tabs | See Chrome pattern with app name "Microsoft Edge" | automation | moderate | 15 |

### 4.4 Brave Operations

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `browser.brave.quit` | Quit Brave | `osascript -e 'tell application "Brave Browser" to quit'` | automation | moderate | 10 |
| `browser.brave.force_quit` | Force Quit Brave | `killall -9 "Brave Browser"` | user | moderate | 5 |
| `browser.brave.tabs.close_all` | Close All Brave Tabs | See Chrome pattern with app name "Brave Browser" | automation | moderate | 15 |

### 4.5 Firefox Operations

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `browser.firefox.quit` | Quit Firefox | `osascript -e 'tell application "Firefox" to quit'` | automation | moderate | 10 |
| `browser.firefox.force_quit` | Force Quit Firefox | `killall -9 Firefox` | user | moderate | 5 |

**⚠️ Note:** Firefox has limited AppleScript support. Tab operations require UI scripting.

### 4.6 Browser Cache Cleanup

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `browser.safari.cache` | Clear Safari Cache | `rm -rf ~/Library/Caches/com.apple.Safari/*` | user | moderate | 30 |
| `browser.safari.localstorage` | Clear Safari Local Storage | `rm -rf ~/Library/Safari/LocalStorage/*` | user | moderate | 30 |
| `browser.chrome.cache` | Clear Chrome Cache | `rm -rf ~/Library/Caches/Google/Chrome/* ~/Library/Application\ Support/Google/Chrome/Default/Cache/*` | user | moderate | 60 |
| `browser.edge.cache` | Clear Edge Cache | `rm -rf ~/Library/Caches/Microsoft\ Edge/* ~/Library/Application\ Support/Microsoft\ Edge/Default/Cache/*` | user | moderate | 60 |
| `browser.brave.cache` | Clear Brave Cache | `rm -rf ~/Library/Caches/BraveSoftware/* ~/Library/Application\ Support/BraveSoftware/Brave-Browser/Default/Cache/*` | user | moderate | 60 |
| `browser.firefox.cache` | Clear Firefox Cache | `rm -rf ~/Library/Caches/Firefox/* ~/Library/Application\ Support/Firefox/Profiles/*/cache2/*` | user | moderate | 60 |

### 4.7 Heavy Tab Detection

**Find Browser Processes by Memory:**
```bash
# Chrome helpers by memory (top 15)
ps aux | grep -E "Google Chrome Helper|Chrome Helper" | sort -k4 -rn | head -15

# Safari web content by memory
ps aux | grep "Safari Web Content" | sort -k4 -rn | head -15

# All browser helpers
ps aux | grep -E "Helper|Web Content" | grep -E "Safari|Chrome|Edge|Brave|Firefox" | sort -k4 -rn | head -20
```

---

## 5. DEVELOPER TOOLS GROUP

### 5.1 Xcode Cleanup

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `dev.xcode.deriveddata` | Clear Derived Data | `rm -rf ~/Library/Developer/Xcode/DerivedData/*` | user | moderate | 120 |
| `dev.xcode.archives` | Clear Archives | `rm -rf ~/Library/Developer/Xcode/Archives/*` | user | destructive | 60 |
| `dev.xcode.devicelog` | Clear Device Logs | `rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/*` | user | moderate | 60 |
| `dev.xcode.watchos` | Clear watchOS Support | `rm -rf ~/Library/Developer/Xcode/watchOS\ DeviceSupport/*` | user | moderate | 60 |

### 5.2 Simulator Cleanup

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `dev.simulator.caches` | Clear Simulator Caches | `rm -rf ~/Library/Developer/CoreSimulator/Caches/*` | user | safe | 30 |
| `dev.simulator.unavailable` | Delete Unavailable Simulators | `xcrun simctl delete unavailable` | user | moderate | 60 |
| `dev.simulator.erase_all` | Erase All Simulators | `xcrun simctl erase all` | user | destructive | 120 |

### 5.3 Package Manager Cleanup

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `dev.cocoapods.cache` | Clear CocoaPods Cache | `rm -rf ~/Library/Caches/CocoaPods/*` | user | safe | 30 |
| `dev.cocoapods.repos` | Clear CocoaPods Repos | `rm -rf ~/.cocoapods/repos/*` | user | moderate | 60 |
| `dev.npm.cache` | Clear npm Cache | `npm cache clean --force` | user | safe | 30 |
| `dev.yarn.cache` | Clear Yarn Cache | `yarn cache clean` | user | safe | 30 |
| `dev.pip.cache` | Clear pip Cache | `pip cache purge` | user | safe | 30 |
| `dev.gradle.cache` | Clear Gradle Cache | `rm -rf ~/.gradle/caches/*` | user | moderate | 60 |
| `dev.swiftpm.cache` | Clear Swift PM Cache | `rm -rf ~/Library/Caches/org.swift.swiftpm` | user | safe | 30 |

### 5.4 Homebrew Cleanup

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `dev.brew.cleanup` | Homebrew Cleanup | `brew cleanup -s` | user | safe | 120 |
| `dev.brew.autoremove` | Homebrew Autoremove | `brew autoremove` | user | safe | 60 |
| `dev.brew.cache` | Clear Homebrew Cache | `rm -rf ~/Library/Caches/Homebrew/*` | user | safe | 30 |

### 5.5 Docker Cleanup

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `dev.docker.info` | Docker Disk Usage | `docker system df` | user | safe | 15 |
| `dev.docker.prune` | Docker Prune Unused | `docker system prune -f` | user | moderate | 120 |
| `dev.docker.prune_all` | Docker Prune All | `docker system prune -af --volumes` | user | destructive | 180 |

---

## 6. MEMORY MANAGEMENT GROUP

### 6.1 Memory Analysis

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `mem.pressure` | Memory Pressure | `memory_pressure` | user | safe | 10 |
| `mem.top_processes` | Top Memory Processes | `ps -eo pid,%mem,rss,command \| sort -k2 -rn \| head -15` | user | safe | 10 |
| `mem.vm_stats` | VM Statistics | `vm_stat` | user | safe | 5 |

### 6.2 Memory Relief

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `mem.purge` | Purge Memory | `sudo purge` | elevated | safe | 30 |
| `mem.sync_purge` | Sync & Purge | `sync && sudo purge` | elevated | safe | 45 |

### 6.3 Process Termination

| ID | Title | Command Template | Privilege | Risk | Timeout |
|----|-------|-----------------|-----------|------|---------|
| `mem.kill_pid` | Kill Process by PID | `kill {{PID}}` | user | moderate | 5 |
| `mem.kill_pid_force` | Force Kill by PID | `kill -9 {{PID}}` | user | moderate | 5 |
| `mem.kill_name` | Kill by Name | `pkill -x "{{NAME}}"` | user | moderate | 5 |
| `mem.kill_name_force` | Force Kill by Name | `pkill -9 -x "{{NAME}}"` | user | moderate | 5 |

---

## 7. SYSTEM UTILITIES GROUP

### 7.1 System Services

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `sys.audio.restart` | Restart Audio | `sudo killall coreaudiod` | elevated | moderate | 15 |
| `sys.prefs.restart` | Restart Preferences | `killall cfprefsd` | user | moderate | 10 |

### 7.2 System Maintenance

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `sys.maintenance.daily` | Daily Maintenance | `sudo periodic daily` | elevated | safe | 300 |
| `sys.maintenance.weekly` | Weekly Maintenance | `sudo periodic weekly` | elevated | safe | 600 |
| `sys.maintenance.monthly` | Monthly Maintenance | `sudo periodic monthly` | elevated | safe | 900 |
| `sys.maintenance.all` | Full Maintenance | `sudo periodic daily weekly monthly` | elevated | safe | 1800 |

### 7.3 Spotlight Management

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `sys.spotlight.status` | Spotlight Status | `sudo mdutil -s /` | elevated | safe | 10 |
| `sys.spotlight.rebuild` | Rebuild Spotlight Index | `sudo mdutil -E /` | elevated | moderate | 30 |

### 7.4 Trash Management

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `sys.trash.empty` | Empty User Trash | `rm -rf ~/.Trash/*` | user | moderate | 60 |
| `sys.trash.empty_all` | Empty All Trashes | `sudo rm -rf /Volumes/*/.Trashes/* ~/.Trash/*` | elevated | moderate | 120 |
| `sys.trash.size` | Trash Size | `du -sh ~/.Trash 2>/dev/null` | user | safe | 15 |

---

## 8. PROCESS MANAGEMENT GROUP

### 8.1 Process Listing

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `proc.list.gui` | GUI Applications | `osascript -e 'tell application "System Events" to get name of (processes where background only is false)'` | automation | safe | 10 |
| `proc.list.all` | All Processes | `ps aux \| head -30` | user | safe | 10 |
| `proc.list.cpu` | By CPU Usage | `ps aux --sort=-%cpu \| head -15` | user | safe | 10 |
| `proc.list.mem` | By Memory Usage | `ps aux --sort=-%mem \| head -15` | user | safe | 10 |

### 8.2 Process Search

| ID | Title | Command Template | Privilege | Risk | Timeout |
|----|-------|-----------------|-----------|------|---------|
| `proc.find.name` | Find by Name | `pgrep -fl "{{NAME}}"` | user | safe | 10 |
| `proc.find.port` | Find by Port | `lsof -i :{{PORT}}` | user | safe | 10 |
| `proc.find.app` | Find by App Files | `lsof -c {{APP}}` | user | safe | 15 |

### 8.3 Launch Agents

| ID | Title | Command | Privilege | Risk | Timeout |
|----|-------|---------|-----------|------|---------|
| `proc.launchd.list` | List Launch Jobs | `launchctl list \| head -30` | user | safe | 10 |
| `proc.launchd.user_agents` | User Launch Agents | `ls -la ~/Library/LaunchAgents/` | user | safe | 5 |
| `proc.launchd.system_agents` | System Launch Agents | `ls -la /Library/LaunchAgents/` | user | safe | 5 |

---

## 9. COMPLETE CAPABILITY CATALOG (JSON)

Below is the full JSON catalog file to be bundled with the app:

```json
{
  "version": "1.0.0",
  "lastUpdated": "2026-01-27",
  "capabilities": [
    {
      "id": "diag.mem.pressure",
      "title": "Memory Pressure",
      "description": "Shows current memory pressure level and availability",
      "group": "diagnostics",
      "commandTemplate": "memory_pressure",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 10,
      "privilegeLevel": "user",
      "riskClass": "safe",
      "outputParser": "memoryPressure",
      "parserPattern": null,
      "preflightChecks": [],
      "requiredPaths": [],
      "requiredApps": [],
      "icon": "gauge.with.needle",
      "rollbackNotes": null,
      "estimatedDuration": 1
    },
    {
      "id": "diag.disk.free",
      "title": "Disk Free Space",
      "description": "Shows available disk space on the root volume",
      "group": "diagnostics",
      "commandTemplate": "df -h /",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 5,
      "privilegeLevel": "user",
      "riskClass": "safe",
      "outputParser": "diskUsage",
      "parserPattern": null,
      "preflightChecks": [],
      "requiredPaths": [],
      "requiredApps": [],
      "icon": "internaldrive",
      "rollbackNotes": null,
      "estimatedDuration": 1
    },
    {
      "id": "diag.cpu.top",
      "title": "Top CPU Processes",
      "description": "Lists processes consuming the most CPU",
      "group": "diagnostics",
      "commandTemplate": "ps aux --sort=-%cpu | head -15",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 10,
      "privilegeLevel": "user",
      "riskClass": "safe",
      "outputParser": "processTable",
      "parserPattern": null,
      "preflightChecks": [],
      "requiredPaths": [],
      "requiredApps": [],
      "icon": "cpu",
      "rollbackNotes": null,
      "estimatedDuration": 1
    },
    {
      "id": "quick.dns.flush",
      "title": "Flush DNS Cache",
      "description": "Clears the DNS resolver cache to fix name resolution issues",
      "group": "quickClean",
      "commandTemplate": "dscacheutil -flushcache && killall -HUP mDNSResponder",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 15,
      "privilegeLevel": "elevated",
      "riskClass": "safe",
      "outputParser": "text",
      "parserPattern": null,
      "preflightChecks": [],
      "requiredPaths": [],
      "requiredApps": [],
      "icon": "network",
      "rollbackNotes": "DNS cache rebuilds automatically",
      "estimatedDuration": 2
    },
    {
      "id": "quick.restart.finder",
      "title": "Restart Finder",
      "description": "Restarts Finder to fix display or navigation issues",
      "group": "quickClean",
      "commandTemplate": "killall Finder",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 10,
      "privilegeLevel": "user",
      "riskClass": "moderate",
      "outputParser": "text",
      "parserPattern": null,
      "preflightChecks": [
        {
          "type": "appRunning",
          "target": "Finder",
          "failureMessage": "Finder is not running"
        }
      ],
      "requiredPaths": [],
      "requiredApps": ["Finder"],
      "icon": "folder",
      "rollbackNotes": "Finder restarts automatically",
      "estimatedDuration": 2
    },
    {
      "id": "quick.restart.dock",
      "title": "Restart Dock",
      "description": "Restarts the Dock to fix icon or animation issues",
      "group": "quickClean",
      "commandTemplate": "killall Dock",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 10,
      "privilegeLevel": "user",
      "riskClass": "moderate",
      "outputParser": "text",
      "parserPattern": null,
      "preflightChecks": [],
      "requiredPaths": [],
      "requiredApps": [],
      "icon": "dock.rectangle",
      "rollbackNotes": "Dock restarts automatically",
      "estimatedDuration": 2
    },
    {
      "id": "quick.mem.purge",
      "title": "Purge Inactive Memory",
      "description": "Releases inactive memory back to the system",
      "group": "memory",
      "commandTemplate": "purge",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 30,
      "privilegeLevel": "elevated",
      "riskClass": "safe",
      "outputParser": "text",
      "parserPattern": null,
      "preflightChecks": [],
      "requiredPaths": [],
      "requiredApps": [],
      "icon": "memorychip",
      "rollbackNotes": "Memory state is temporary",
      "estimatedDuration": 5
    },
    {
      "id": "deep.cache.user",
      "title": "Clear User Caches",
      "description": "Removes all user-level application caches",
      "group": "deepClean",
      "commandTemplate": "rm -rf ~/Library/Caches/*",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 120,
      "privilegeLevel": "user",
      "riskClass": "moderate",
      "outputParser": "text",
      "parserPattern": null,
      "preflightChecks": [
        {
          "type": "pathExists",
          "target": "~/Library/Caches",
          "failureMessage": "Caches folder not found"
        }
      ],
      "requiredPaths": ["~/Library/Caches"],
      "requiredApps": [],
      "icon": "trash",
      "rollbackNotes": "Apps will rebuild caches as needed",
      "estimatedDuration": 15
    },
    {
      "id": "dev.xcode.deriveddata",
      "title": "Clear Xcode Derived Data",
      "description": "Removes Xcode build caches and derived data",
      "group": "devTools",
      "commandTemplate": "rm -rf ~/Library/Developer/Xcode/DerivedData/*",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 120,
      "privilegeLevel": "user",
      "riskClass": "moderate",
      "outputParser": "text",
      "parserPattern": null,
      "preflightChecks": [
        {
          "type": "pathExists",
          "target": "~/Library/Developer/Xcode/DerivedData",
          "failureMessage": "Derived Data folder not found"
        }
      ],
      "requiredPaths": ["~/Library/Developer/Xcode/DerivedData"],
      "requiredApps": [],
      "icon": "hammer",
      "rollbackNotes": "Xcode will rebuild on next build",
      "estimatedDuration": 20
    },
    {
      "id": "dev.simulator.unavailable",
      "title": "Delete Unavailable Simulators",
      "description": "Removes iOS simulators for unavailable runtimes",
      "group": "devTools",
      "commandTemplate": "xcrun simctl delete unavailable",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 60,
      "privilegeLevel": "user",
      "riskClass": "moderate",
      "outputParser": "text",
      "parserPattern": null,
      "preflightChecks": [],
      "requiredPaths": [],
      "requiredApps": [],
      "icon": "iphone",
      "rollbackNotes": "Simulators can be recreated from Xcode",
      "estimatedDuration": 10
    },
    {
      "id": "browser.safari.tabs.count",
      "title": "Safari Tab Count",
      "description": "Shows the number of open tabs in Safari",
      "group": "browsers",
      "commandTemplate": "osascript -e 'tell application \"Safari\" to set tc to 0\nrepeat with w in windows\nset tc to tc + (count of tabs of w)\nend repeat\nreturn tc'",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 10,
      "privilegeLevel": "automation",
      "riskClass": "safe",
      "outputParser": "text",
      "parserPattern": "^\\d+$",
      "preflightChecks": [
        {
          "type": "automationPermission",
          "target": "Safari",
          "failureMessage": "Automation permission required for Safari"
        },
        {
          "type": "appRunning",
          "target": "Safari",
          "failureMessage": "Safari is not running"
        }
      ],
      "requiredPaths": [],
      "requiredApps": ["Safari"],
      "icon": "safari",
      "rollbackNotes": null,
      "estimatedDuration": 1
    },
    {
      "id": "browser.safari.quit",
      "title": "Quit Safari",
      "description": "Gracefully quits Safari",
      "group": "browsers",
      "commandTemplate": "osascript -e 'tell application \"Safari\" to quit'",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 10,
      "privilegeLevel": "automation",
      "riskClass": "moderate",
      "outputParser": "text",
      "parserPattern": null,
      "preflightChecks": [
        {
          "type": "automationPermission",
          "target": "Safari",
          "failureMessage": "Automation permission required for Safari"
        }
      ],
      "requiredPaths": [],
      "requiredApps": ["Safari"],
      "icon": "safari",
      "rollbackNotes": "Safari can be relaunched manually",
      "estimatedDuration": 2
    },
    {
      "id": "browser.chrome.tabs.count",
      "title": "Chrome Tab Count",
      "description": "Shows the number of open tabs in Chrome",
      "group": "browsers",
      "commandTemplate": "osascript -e 'tell application \"Google Chrome\" to set tc to 0\nrepeat with w in windows\nset tc to tc + (count of tabs of w)\nend repeat\nreturn tc'",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 10,
      "privilegeLevel": "automation",
      "riskClass": "safe",
      "outputParser": "text",
      "parserPattern": "^\\d+$",
      "preflightChecks": [
        {
          "type": "automationPermission",
          "target": "Google Chrome",
          "failureMessage": "Automation permission required for Chrome"
        },
        {
          "type": "appRunning",
          "target": "Google Chrome",
          "failureMessage": "Chrome is not running"
        }
      ],
      "requiredPaths": [],
      "requiredApps": ["Google Chrome"],
      "icon": "globe",
      "rollbackNotes": null,
      "estimatedDuration": 1
    },
    {
      "id": "browser.chrome.quit",
      "title": "Quit Chrome",
      "description": "Gracefully quits Google Chrome",
      "group": "browsers",
      "commandTemplate": "osascript -e 'tell application \"Google Chrome\" to quit'",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 10,
      "privilegeLevel": "automation",
      "riskClass": "moderate",
      "outputParser": "text",
      "parserPattern": null,
      "preflightChecks": [
        {
          "type": "automationPermission",
          "target": "Google Chrome",
          "failureMessage": "Automation permission required for Chrome"
        }
      ],
      "requiredPaths": [],
      "requiredApps": ["Google Chrome"],
      "icon": "globe",
      "rollbackNotes": "Chrome can be relaunched manually",
      "estimatedDuration": 2
    },
    {
      "id": "browser.safari.cache",
      "title": "Clear Safari Cache",
      "description": "Removes Safari browser cache files",
      "group": "browsers",
      "commandTemplate": "rm -rf ~/Library/Caches/com.apple.Safari/*",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 30,
      "privilegeLevel": "user",
      "riskClass": "moderate",
      "outputParser": "text",
      "parserPattern": null,
      "preflightChecks": [
        {
          "type": "appNotRunning",
          "target": "Safari",
          "failureMessage": "Please quit Safari before clearing cache"
        }
      ],
      "requiredPaths": ["~/Library/Caches/com.apple.Safari"],
      "requiredApps": [],
      "icon": "safari",
      "rollbackNotes": "Cache rebuilds automatically",
      "estimatedDuration": 5
    },
    {
      "id": "browser.chrome.cache",
      "title": "Clear Chrome Cache",
      "description": "Removes Chrome browser cache files",
      "group": "browsers",
      "commandTemplate": "rm -rf ~/Library/Caches/Google/Chrome/* ~/Library/Application\\ Support/Google/Chrome/Default/Cache/*",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 60,
      "privilegeLevel": "user",
      "riskClass": "moderate",
      "outputParser": "text",
      "parserPattern": null,
      "preflightChecks": [
        {
          "type": "appNotRunning",
          "target": "Google Chrome",
          "failureMessage": "Please quit Chrome before clearing cache"
        }
      ],
      "requiredPaths": ["~/Library/Caches/Google/Chrome"],
      "requiredApps": [],
      "icon": "globe",
      "rollbackNotes": "Cache rebuilds automatically",
      "estimatedDuration": 10
    },
    {
      "id": "sys.trash.empty",
      "title": "Empty Trash",
      "description": "Permanently removes all items in Trash",
      "group": "disk",
      "commandTemplate": "rm -rf ~/.Trash/*",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 60,
      "privilegeLevel": "user",
      "riskClass": "destructive",
      "outputParser": "text",
      "parserPattern": null,
      "preflightChecks": [],
      "requiredPaths": ["~/.Trash"],
      "requiredApps": [],
      "icon": "trash.fill",
      "rollbackNotes": "Deleted files cannot be recovered",
      "estimatedDuration": 10
    },
    {
      "id": "sys.maintenance.daily",
      "title": "Run Daily Maintenance",
      "description": "Executes macOS daily maintenance scripts",
      "group": "system",
      "commandTemplate": "periodic daily",
      "arguments": [],
      "workingDirectory": null,
      "timeout": 300,
      "privilegeLevel": "elevated",
      "riskClass": "safe",
      "outputParser": "text",
      "parserPattern": null,
      "preflightChecks": [],
      "requiredPaths": [],
      "requiredApps": [],
      "icon": "gearshape.2",
      "rollbackNotes": null,
      "estimatedDuration": 60
    }
  ]
}
```

---

## 10. QUICK REFERENCE CARD

### Safe Commands (No Confirmation)
```bash
memory_pressure                          # Check memory
df -h /                                  # Check disk
ps aux --sort=-%cpu | head -15           # Top CPU
sw_vers                                  # macOS version
```

### Moderate Commands (Single Confirm)
```bash
killall Finder                           # Restart Finder
killall Dock                             # Restart Dock
rm -rf ~/Library/Caches/TemporaryItems/* # Clear temp
```

### Elevated Commands (Auth Required)
```bash
sudo purge                               # Purge memory
sudo dscacheutil -flushcache             # Flush DNS
sudo periodic daily                      # Maintenance
```

### Destructive Commands (Confirm + Preview)
```bash
rm -rf ~/Library/Caches/*                # All caches
rm -rf ~/.Trash/*                        # Empty trash
docker system prune -af --volumes        # Docker cleanup
xcrun simctl erase all                   # Erase simulators
```

---

*Document Version: 2.0*  
*Last Updated: January 2026*
