# Craig-O-Clean Screenshot Automation Scripts

This directory contains scripts for automating App Store screenshot capture for Craig-O-Clean.

## App Store Screenshot Requirements

### Mac App Store Dimensions
| Device | Resolution |
|--------|------------|
| MacBook | 1280 x 800 |
| MacBook Air 13" | 1440 x 900 |
| MacBook Pro 13" Retina | 2560 x 1600 |
| MacBook Pro 15" Retina | 2880 x 1800 |

### Required Screenshots
1. **Menu Bar Popover** - Quick access dashboard
2. **Dashboard** - System monitoring overview
3. **Process Manager** - Running applications list
4. **Memory Cleanup** - Memory optimization view
5. **Browser Tabs** - Tab management interface
6. **Settings** - App configuration and subscription

## Scripts

### 1. take_appstore_screenshots.sh (Bash)
Automated shell script for capturing screenshots.

```bash
# Make executable
chmod +x take_appstore_screenshots.sh

# Run with default output directory
./take_appstore_screenshots.sh

# Run with custom output directory
./take_appstore_screenshots.sh /path/to/output
```

### 2. screenshot_helper.py (Python)
Python script with more advanced features including resizing and optimization.

```bash
# Install dependencies
pip install Pillow

# Interactive capture session
python screenshot_helper.py interactive

# Resize existing screenshots
python screenshot_helper.py resize -s ./Screenshots/20250115_120000

# Optimize for upload
python screenshot_helper.py optimize -s ./Screenshots/20250115_120000
```

### 3. capture_all_views.applescript (AppleScript)
Guided AppleScript for step-by-step capture with dialogs.

```bash
# Run the AppleScript
osascript capture_all_views.applescript
```

## Setup Instructions

### Prerequisites
1. Craig-O-Clean must be installed and running
2. Grant Accessibility permissions to Terminal (System Settings > Privacy & Security > Accessibility)
3. For Python script: Install Pillow (`pip install Pillow`)
4. For resizing: Install ImageMagick (`brew install imagemagick`)

### Capture Workflow

1. **Prepare the App**
   - Launch Craig-O-Clean
   - Sign in with test account
   - Set up sample data (processes running, browser tabs open)

2. **Run Screenshot Script**
   ```bash
   ./take_appstore_screenshots.sh
   ```

3. **Review & Edit**
   - Check screenshots in output directory
   - Remove any sensitive information
   - Add device frames if desired

4. **Upload to App Store Connect**
   - Go to App Store Connect > Your App > App Information
   - Upload screenshots for each device size

## Screenshot Tips

### Best Practices
- Use clean, representative data (no personal info)
- Ensure high contrast and readability
- Show key features prominently
- Use consistent styling across screenshots

### Adding Device Frames
You can add Mac device frames using:
- [MockUPhone](https://mockuphone.com) (Free)
- [Screenshots.pro](https://screenshots.pro)
- Figma with device mockup plugins

### Adding Text Overlays
The Python script can add text overlays:
```python
from screenshot_helper import ScreenshotProcessor
processor = ScreenshotProcessor(session_dir)
processor.add_text_overlay(
    image_path,
    "Real-time Monitoring",
    "Track CPU, Memory, and more"
)
```

## Output Structure

```
Screenshots/
├── 20250115_120000/           # Timestamp folder
│   ├── mac_1280x800/          # MacBook
│   │   ├── 01_menubar.png
│   │   ├── 02_dashboard.png
│   │   └── ...
│   ├── mac_1440x900/          # MacBook Air
│   ├── mac_2560x1600/         # MacBook Pro 13"
│   ├── mac_2880x1800/         # MacBook Pro 15"
│   └── metadata.json          # Screenshot metadata
```

## Troubleshooting

### "Operation not permitted"
Grant Terminal/Script Editor accessibility permissions:
1. Open System Settings
2. Go to Privacy & Security > Accessibility
3. Add and enable Terminal

### Screenshots are black/empty
- Ensure Craig-O-Clean window is visible
- Try using interactive capture (-w flag)
- Check screen recording permissions

### Window not found
- Make sure Craig-O-Clean is running
- Activate the app before capture
- Use `osascript -e 'tell application "Craig-O-Clean" to activate'`

## App Store Connect Guidelines

### Screenshot Requirements
- PNG or JPEG format
- RGB color space (not P3)
- No alpha channel for smaller file sizes
- Maximum file size: 500KB per image

### Content Guidelines
- No placeholder content
- Accurate representation of app
- Device frames are optional
- Text overlays should be readable

## Related Files

- `../Craig-O-Clean/Info.plist` - App configuration
- `../Craig-O-Clean/Core/TrialManager.swift` - Trial logic
- `../Craig-O-Clean/UI/PaywallView.swift` - Subscription UI
