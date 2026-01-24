# Craig-O-Clean Terminator Edition - Xcode Project

## Overview

This is the native macOS SwiftUI application for Craig-O-Clean Terminator Edition. It provides an autonomous, AI-powered system management solution for macOS Silicon devices.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Apple Silicon (M1/M2/M3/M4) or Intel Mac

## Project Structure

```
CraigOTerminator.xcodeproj/
CraigOTerminator/
├── App/
│   └── CraigOTerminatorApp.swift      # Main app entry point
├── Views/
│   ├── ContentView.swift              # Main container with navigation
│   ├── DashboardView.swift            # System metrics dashboard
│   ├── CleanupView.swift              # Cleanup category selection
│   ├── BrowsersView.swift             # Browser management
│   ├── ProcessesView.swift            # Process monitoring and control
│   ├── DiagnosticsView.swift          # System diagnostics
│   ├── AgentsView.swift               # AI agent teams
│   ├── SettingsView.swift             # App settings
│   ├── AboutView.swift                # About page
│   └── MenuBarView.swift              # Menu bar extra view
├── ViewModels/
│   └── AppState.swift                 # Central state management
├── Core/
│   └── CommandExecutor.swift          # Shell command execution
├── Assets.xcassets/
│   ├── AppIcon.appiconset/            # App icons
│   └── AppLogo.imageset/              # Logo image
├── Info.plist                         # App configuration
└── CraigOTerminator.entitlements      # App entitlements
```

## Features

### Dashboard
- Real-time CPU, memory, and disk usage monitoring
- Health score visualization
- Quick action buttons for common operations

### Cleanup
- User caches
- Browser caches (Safari, Chrome, Firefox, Edge, Brave, Arc)
- System temporary files
- Developer caches (Xcode, npm, etc.)
- Log files
- Trash
- DNS cache

### Browser Management
- View running browsers and tab counts
- Close heavy tabs
- Clear browser caches
- Force quit browsers

### Process Management
- List all running processes
- Sort by CPU, memory, name, or PID
- Filter system processes
- Terminate or force kill processes

### Diagnostics
- Comprehensive system information
- CPU, memory, disk, network, and battery analysis
- Health score calculation
- Recommendations

### AI Agents
- Multi-agent team orchestration
- Quick cleanup missions
- Deep cleanup missions
- Emergency response
- Diagnostic missions

### Menu Bar
- Quick access to system stats
- One-click cleanup actions
- Memory purge
- DNS flush

## Building

1. Open `CraigOTerminator.xcodeproj` in Xcode
2. Select the `CraigOTerminator` scheme
3. Choose your target device (My Mac)
4. Press `Cmd + R` to build and run

## Adding the Logo

1. Export the Craig-O Terminator logo in the following sizes:
   - 16x16, 32x32, 64x64 (16@2x), 128x128, 256x256, 512x512, 1024x1024 (512@2x) for AppIcon
   - Multiple resolutions for AppLogo
2. Place the images in the appropriate asset catalog folders
3. Update the Contents.json files with the correct filenames

## Entitlements

The app requires the following permissions:
- Apple Events (for AppleScript automation)
- Network access (for AI integration)
- File system access (for cleanup operations)

## Configuration

### Ollama AI Integration

1. Install Ollama: `brew install ollama`
2. Pull a model: `ollama pull llama3.2`
3. Start Ollama: `ollama serve`
4. Enable AI in Settings > AI

### Autonomous Mode

1. Go to Settings > Automation
2. Enable Autonomous Mode
3. Configure thresholds for memory and disk
4. Set the check interval

## License

Copyright © 2024 Craig Tracey. All rights reserved.
