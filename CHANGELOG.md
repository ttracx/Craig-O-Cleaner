# Changelog

All notable changes to Craig-O-Clean will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-11-12

### Initial Release

#### Added
- Menu bar application for macOS memory management
- Real-time process monitoring with memory usage display
- Process list sorted by memory consumption (top 50 processes)
- Search functionality to filter processes by name
- Force quit capability for user-owned processes
- Memory purge button executing `sync && sudo purge` commands
- Auto-refresh every 5 seconds
- Manual refresh button
- Memory usage statistics display
- Process count display
- Last update timestamp
- SwiftUI-based native macOS interface
- Support for both Apple Silicon and Intel Macs
- Dark mode support
- Process information display (PID, name, memory usage)
- Administrator privilege escalation for purge command
- Clean, modern UI with SF Symbols

#### Technical Details
- Built with SwiftUI for macOS 13.0+
- Uses NSStatusItem for menu bar integration
- Uses NSPopover for the main interface
- Process monitoring via `ps` command
- Force quit via `kill` command
- Memory purge via AppleScript with admin privileges
- Observable pattern for reactive UI updates
- Automatic process list refresh timer

#### Security
- Runs without sandbox to enable process monitoring
- Requests admin privileges only for purge command
- No network access
- No data collection or transmission
- All operations performed locally

### Known Limitations
- Fixed 5-second refresh interval
- Limited to top 50 processes
- Processes using less than 10 MB are filtered out
- Cannot show memory pressure or swap usage
- Requires admin password for each purge operation

---

## Future Releases

### Planned Features for Future Versions
- CPU usage monitoring
- Configurable refresh intervals
- User preferences panel
- Export process list to CSV
- Process history tracking
- Memory usage graphs
- Alert/notification system for high memory usage
- Custom process filters
- Favorite/pinned processes
- Startup at login option
- More detailed memory statistics
- Network usage monitoring
- Disk I/O monitoring
- Keyboard shortcuts
- Multiple window support
- Process grouping by application

### Under Consideration
- Widget support
- Command-line interface
- AppleScript support
- Shortcuts app integration
- Focus mode integration
- Multiple profiles
- Cloud sync preferences
- Plugin system

---

[1.0.0]: https://github.com/ttracx/Craig-O-Cleaner/releases/tag/v1.0.0
