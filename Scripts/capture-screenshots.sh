#!/bin/bash

# Screenshot Capture Script for Craig-O-Clean
# This script helps capture all required UI states

SCREENSHOT_DIR="Screenshots/app-screenshots-$(date +%Y%m%d)"
mkdir -p "$SCREENSHOT_DIR"

echo "Craig-O-Clean Screenshot Capture Guide"
echo "======================================="
echo ""
echo "Screenshots will be saved to: $SCREENSHOT_DIR"
echo ""

# Function to wait for user input
wait_for_capture() {
    local filename=$1
    local description=$2
    echo "Step: $description"
    echo "Press ENTER when ready to capture, then you'll have 3 seconds..."
    read -r
    echo "Capturing in 3 seconds..."
    sleep 3
    screencapture -x "$SCREENSHOT_DIR/$filename"
    echo "✓ Saved: $filename"
    echo ""
}

# Function for interactive window capture
capture_window() {
    local filename=$1
    local description=$2
    echo "Step: $description"
    echo "Press ENTER, then click the window you want to capture..."
    read -r
    screencapture -W "$SCREENSHOT_DIR/$filename"
    echo "✓ Saved: $filename"
    echo ""
}

echo "Starting screenshot capture process..."
echo ""

# 1. Menu Bar Icon
echo "1/8 - Menu Bar Icon Location"
echo "Please ensure the Craig-O-Clean menu bar icon is visible in the menu bar."
wait_for_capture "01-menu-bar-icon.png" "Menu bar with Craig-O-Clean icon"

# 2. Main Popover (Light Mode)
echo "2/8 - Main Popover Window (Light Mode)"
echo "Instructions:"
echo "  1. Make sure macOS is in Light Mode (System Settings > Appearance > Light)"
echo "  2. Click the Craig-O-Clean menu bar icon to open the popover"
echo "  3. Make sure the popover is fully visible"
wait_for_capture "02-popover-light-mode.png" "Main popover in light mode"

# 3. Main Popover (Dark Mode)
echo "3/8 - Main Popover Window (Dark Mode)"
echo "Instructions:"
echo "  1. Switch macOS to Dark Mode (System Settings > Appearance > Dark)"
echo "  2. Click the Craig-O-Clean menu bar icon again if it closed"
echo "  3. Make sure the popover is fully visible"
wait_for_capture "03-popover-dark-mode.png" "Main popover in dark mode"

# 4. Search Active State
echo "4/8 - Search Active State"
echo "Instructions:"
echo "  1. In the Craig-O-Clean popover or main window, activate the search field"
echo "  2. Type something in the search field to show the active state"
wait_for_capture "04-search-active.png" "Search field in active state"

# 5. Alert Dialog - Quit Confirmation
echo "5/8 - Alert Dialog (Quit Confirmation)"
echo "Instructions:"
echo "  1. In the Process Manager, select a running app"
echo "  2. Click 'Terminate' to trigger the confirmation dialog"
echo "  3. Position the dialog so it's clearly visible"
wait_for_capture "05-alert-quit-confirmation.png" "Quit confirmation alert dialog"

# 6. Alert Dialog - Force Quit Warning
echo "6/8 - Alert Dialog (Force Quit Warning)"
echo "Instructions:"
echo "  1. In the Process Manager, select a system process"
echo "  2. Click 'Force Quit' to trigger the warning dialog"
echo "  3. Position the dialog so it's clearly visible"
wait_for_capture "06-alert-force-quit-warning.png" "Force quit warning dialog"

# 7. Process List with Various Apps
echo "7/8 - Process List with Various Apps"
echo "Instructions:"
echo "  1. Open the main Craig-O-Clean window (click 'Open Full App' in popover)"
echo "  2. Navigate to the Process Manager tab"
echo "  3. Ensure several apps are running and visible in the list"
echo "  4. Scroll to show a good variety of apps"
wait_for_capture "07-process-list.png" "Process list showing various apps"

# 8. Full Main Window
echo "8/8 - Bonus: Full Main Window"
echo "Instructions:"
echo "  1. Open the main Craig-O-Clean window"
echo "  2. Show the Dashboard view with metrics"
wait_for_capture "08-main-window-dashboard.png" "Main window dashboard view"

echo ""
echo "========================================="
echo "Screenshot capture complete!"
echo "All screenshots saved to: $SCREENSHOT_DIR"
echo "========================================="
echo ""
echo "Files captured:"
ls -1 "$SCREENSHOT_DIR"
