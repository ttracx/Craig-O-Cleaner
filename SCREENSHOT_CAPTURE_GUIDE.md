# Screenshot Capture Guide for Craig-O-Clean

This guide provides step-by-step instructions to capture all required UI states for documentation, marketing, and app store submissions.

## Quick Start

The app is already built and running. Screenshots will be saved to: `Screenshots/app-screenshots-20260118/`

## Required Screenshots

### 1. Menu Bar Icon Location
**Purpose**: Show where the Craig-O-Clean icon appears in the macOS menu bar

**Steps**:
1. Ensure Craig-O-Clean is running
2. Look for the brain icon (🧠) in the top-right menu bar area
3. Press `Cmd+Shift+4`, then press `Space` to enter window capture mode
4. Hover over the menu bar until it highlights
5. Click to capture
6. Save as: `01-menu-bar-icon.png`

**Alternative**: Use full screen capture
```bash
screencapture -x Screenshots/app-screenshots-20260118/01-menu-bar-icon.png
```

---

### 2. Main Popover Window (Light Mode)
**Purpose**: Show the mini-dashboard popover in light appearance

**Steps**:
1. **Switch to Light Mode**:
   - Open System Settings → Appearance
   - Select "Light" appearance
   - Wait 2 seconds for UI to update

2. **Open the Popover**:
   - Click the Craig-O-Clean brain icon in the menu bar
   - The popover should appear below the icon

3. **Capture**:
   - Press `Cmd+Shift+4`, then `Space` for window capture
   - Click on the popover window
   - Save as: `02-popover-light-mode.png`

**Quick Command**:
```bash
# After clicking menu bar icon to open popover
screencapture -W Screenshots/app-screenshots-20260118/02-popover-light-mode.png
```

---

### 3. Main Popover Window (Dark Mode)
**Purpose**: Show the mini-dashboard popover in dark appearance

**Steps**:
1. **Switch to Dark Mode**:
   - Open System Settings → Appearance
   - Select "Dark" appearance
   - Wait 2 seconds for UI to update

2. **Open the Popover**:
   - Click the Craig-O-Clean brain icon in the menu bar
   - The popover should appear below the icon

3. **Capture**:
   - Press `Cmd+Shift+4`, then `Space` for window capture
   - Click on the popover window
   - Save as: `03-popover-dark-mode.png`

---

### 4. Search Active State
**Purpose**: Show the search field with active input and results

**Steps**:
1. **Open Main Window**:
   - Click "Open Full App" button in the popover
   - OR right-click menu bar icon → "Open Control Center"

2. **Navigate to Process Manager**:
   - Click the "Processes" tab in the sidebar

3. **Activate Search**:
   - Click in the search field at the top
   - Type a search term (e.g., "Safari", "Chrome", or "System")
   - Wait for results to filter

4. **Capture**:
   - Press `Cmd+Shift+4`, then `Space`
   - Click on the main window
   - Save as: `04-search-active.png`

**What to Show**:
- ✅ Search field with text
- ✅ Filtered process list showing search results
- ✅ Search field should be visually "focused" (highlighted)

---

### 5. Alert Dialogs

#### 5a. Quit Confirmation Dialog
**Purpose**: Show the graceful termination confirmation

**Steps**:
1. **Open Process Manager**
2. **Select a User App**:
   - Find and click on a user application (e.g., Safari, Notes, TextEdit)
   - Avoid system processes for this screenshot

3. **Trigger Confirmation**:
   - Click the "Terminate" button
   - A confirmation dialog should appear

4. **Capture**:
   - Press `Cmd+Shift+4`, then `Space`
   - Click on the alert dialog
   - Save as: `05-alert-quit-confirmation.png`

**Dialog Should Show**:
- ✅ App name and icon
- ✅ "Are you sure you want to quit [App Name]?" message
- ✅ "Cancel" and "Quit" buttons
- ✅ Warning icon

**Note**: Click "Cancel" after capturing - don't actually quit the app!

---

#### 5b. Force Quit Warning Dialog
**Purpose**: Show the critical process warning for force quit

**Steps**:
1. **Open Process Manager**
2. **Select a Critical Process**:
   - Look for a system process (e.g., WindowServer, loginwindow, Finder)
   - OR select ANY process and click "Force Quit"

3. **Trigger Warning**:
   - Click the "Force Quit" button
   - A warning dialog should appear for system processes

4. **Capture**:
   - Press `Cmd+Shift+4`, then `Space`
   - Click on the alert dialog
   - Save as: `06-alert-force-quit-warning.png`

**Dialog Should Show**:
- ✅ Strong warning message
- ✅ Process name highlighted
- ✅ "This might cause system instability" or similar warning
- ✅ "Cancel" and "Force Quit" buttons

**IMPORTANT**: Click "Cancel" - do NOT force quit system processes!

---

### 6. Process List with Various Apps
**Purpose**: Show the full process manager with multiple apps running

**Preparation**:
1. **Launch Various Apps** (if not already running):
   - Safari or Chrome (browser)
   - Notes or TextEdit (productivity)
   - Music or Spotify (media)
   - Mail (email)
   - Messages (chat)
   - A few other apps you use

2. **Open Craig-O-Clean Main Window**

3. **Navigate to Process Manager Tab**

4. **Configure the View**:
   - Set filter to "All Processes" or "User Apps Only"
   - Sort by "Memory" to show most memory-intensive apps at top
   - Ensure columns are visible: Name, CPU %, Memory, Threads

**Steps to Capture**:
1. **Scroll to Show Variety**:
   - Position the list to show a good mix of apps
   - Include both well-known apps and some background processes

2. **Capture**:
   - Press `Cmd+Shift+4`, then `Space`
   - Click on the main window
   - Save as: `07-process-list.png`

**What to Show**:
- ✅ At least 10-15 processes visible
- ✅ Mix of apps (browsers, system apps, user apps)
- ✅ Memory usage values clearly visible
- ✅ CPU percentages showing
- ✅ Process icons visible
- ✅ Sort and filter controls visible at top

---

## Bonus Screenshots (Recommended)

### Main Dashboard View
**Purpose**: Show system metrics and health monitoring

**Steps**:
1. Click "Dashboard" tab in the main window
2. Wait for metrics to load and update
3. Capture: `08-dashboard-view.png`

**Should Show**:
- ✅ CPU usage gauge
- ✅ Memory usage with breakdown
- ✅ Disk space visualization
- ✅ Network activity
- ✅ Refresh controls

---

### Memory Cleanup View
**Purpose**: Show the memory optimization feature

**Steps**:
1. Click "Memory Cleanup" tab
2. Wait for analysis to complete
3. Shows categorized apps using memory
4. Capture: `09-memory-cleanup.png`

---

### Browser Tabs View
**Purpose**: Show browser tab management

**Steps**:
1. Open Safari/Chrome with multiple tabs
2. Click "Browser Tabs" tab in Craig-O-Clean
3. Wait for tabs to load
4. Capture: `10-browser-tabs.png`

---

## Quick Capture Commands

Use these terminal commands for rapid screenshot capture:

```bash
# Create screenshot directory
mkdir -p Screenshots/app-screenshots-20260118

# Full screen capture (includes menu bar)
screencapture -x Screenshots/app-screenshots-20260118/fullscreen.png

# Interactive window capture (click on window)
screencapture -W Screenshots/app-screenshots-20260118/window.png

# Timed capture (5 second delay)
screencapture -T 5 -x Screenshots/app-screenshots-20260118/timed.png

# Capture specific window by clicking
screencapture -w -o Screenshots/app-screenshots-20260118/clicked-window.png
```

---

## Keyboard Shortcuts Reference

| Action | Shortcut |
|--------|----------|
| Capture full screen | `Cmd+Shift+3` |
| Capture selection | `Cmd+Shift+4` |
| Capture window | `Cmd+Shift+4`, then `Space` |
| Capture to clipboard | Add `Ctrl` to any above |
| Cancel capture | `Esc` |

---

## Screenshot Quality Guidelines

### Resolution
- **Minimum**: 1280x720
- **Recommended**: Native resolution (Retina)
- **Format**: PNG (lossless)

### Composition
- ✅ Center the subject
- ✅ Include relevant context
- ✅ Avoid clutter in background
- ✅ Ensure text is readable
- ✅ Show realistic data (not lorem ipsum)

### Appearance
- 🎨 Capture in both Light and Dark modes
- 🎨 Use system default fonts and sizes
- 🎨 Ensure proper contrast
- 🎨 No debug overlays or development tools

---

## Automated Capture Scripts

We've created several scripts to help automate the capture process:

### Python Script (Interactive)
```bash
python3 Scripts/capture_screenshots.py
```
- Guides you through each screenshot
- Handles appearance mode switching
- Validates each capture

### Shell Script (Manual)
```bash
bash Scripts/capture-screenshots.sh
```
- Step-by-step prompts
- Simple and reliable
- Good for quick captures

### Auto Script (Fully Automated)
```bash
python3 Scripts/auto_capture.py
```
- No interaction needed
- Timed delays
- Best for batch captures

---

## Troubleshooting

### Menu Bar Icon Not Visible
**Problem**: Can't find the Craig-O-Clean icon in menu bar

**Solutions**:
1. Check if app is running: `ps aux | grep Craig-O-Clean`
2. Restart the app: Kill and relaunch
3. Look in the top-right area of menu bar (near clock)
4. Check for hidden menu bar items (click >> icon)

### Popover Won't Open
**Problem**: Clicking icon doesn't show popover

**Solutions**:
1. Try clicking again (might be a timing issue)
2. Restart the app
3. Check Console.app for errors
4. Verify permissions in System Settings

### Alert Dialogs Not Appearing
**Problem**: Terminate/Force Quit buttons don't show dialogs

**Solutions**:
1. Make sure you've selected a process first
2. Check if dialogs are behind other windows
3. Look in Mission Control (F3) for hidden windows
4. Restart the app if needed

### Screenshots Are Blank/Black
**Problem**: Captured images are empty or corrupted

**Solutions**:
1. Grant Screen Recording permission:
   - System Settings → Privacy & Security → Screen Recording
   - Enable Terminal or your capture tool
2. Try different capture method (window vs fullscreen)
3. Update macOS if on older version

---

## Verification Checklist

After capturing all screenshots, verify:

- [ ] All 6+ required screenshots captured
- [ ] Light and Dark mode variants included
- [ ] UI elements are clearly visible
- [ ] Text is readable at 100% zoom
- [ ] No sensitive information visible
- [ ] Realistic sample data shown
- [ ] File names are descriptive
- [ ] Files are PNG format
- [ ] File sizes are reasonable (<5MB each)

---

## Next Steps

After capturing screenshots:

1. **Review Quality**: Open each image and verify clarity
2. **Edit if Needed**: Crop, annotate, or highlight key features
3. **Organize**: Move to final documentation location
4. **Update Docs**: Add screenshots to README, website, etc.
5. **App Store**: Prepare for App Store submission format

---

## Contact

If you encounter issues with screenshot capture, check:
- Xcode build logs: `~/Library/Developer/Xcode/DerivedData/`
- App logs: Console.app → Filter for "Craig-O-Clean"
- Project issues: GitHub repository

---

**Last Updated**: January 18, 2026
**App Version**: Development Build
**macOS Version**: macOS 15.3 (Sequoia)
