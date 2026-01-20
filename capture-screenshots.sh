#!/bin/bash

# Screenshot Capture Helper for Craig-O-Clean
# App Store Requirements: 2560x1600 (13-inch) and 3456x2234 (16-inch)

set -e

echo "======================================"
echo "Craig-O-Clean Screenshot Capture Tool"
echo "======================================"
echo ""

# Create screenshots directory
SCREENSHOTS_DIR="$HOME/Desktop/Craig-O-Clean-Screenshots"
mkdir -p "$SCREENSHOTS_DIR"

echo "Screenshots will be saved to: $SCREENSHOTS_DIR"
echo ""

# Function to capture screenshot with countdown
capture_screenshot() {
    local name=$1
    local number=$2
    local description=$3

    echo "----------------------------------------"
    echo "Screenshot $number: $name"
    echo "Description: $description"
    echo "----------------------------------------"
    echo ""
    echo "INSTRUCTIONS:"
    echo "1. Position the Craig-O-Clean window to show: $description"
    echo "2. Press SPACE when ready to capture in 3 seconds"
    echo "3. Or press Q to skip this screenshot"
    echo ""

    read -n 1 -s key

    if [[ $key == "q" ]] || [[ $key == "Q" ]]; then
        echo "Skipped."
        echo ""
        return
    fi

    echo "Capturing in..."
    for i in 3 2 1; do
        echo "$i..."
        sleep 1
    done

    # Capture the frontmost window
    screencapture -o -w "$SCREENSHOTS_DIR/${number}_${name}.png"

    echo "✓ Captured: ${number}_${name}.png"
    echo ""
    sleep 1
}

echo "========================================="
echo "SETUP INSTRUCTIONS"
echo "========================================="
echo ""
echo "1. Make sure Craig-O-Clean is open and running"
echo "2. Set your display to 2560x1600 resolution (System Settings > Displays)"
echo "3. Position the app window to fill most of the screen"
echo "4. We'll capture 5 screenshots showing different features"
echo ""
echo "Press ENTER to start..."
read

# Screenshot 1: Dashboard
capture_screenshot \
    "Dashboard" \
    "01" \
    "Main dashboard with CPU, Memory, and Disk metrics. Show healthy system status with green indicators."

# Screenshot 2: Memory Cleanup
capture_screenshot \
    "Memory-Cleanup" \
    "02" \
    "Memory tab showing cleanup candidates and memory optimization. Click 'Analyze Memory' first to show candidates."

# Screenshot 3: Process Manager
capture_screenshot \
    "Process-Manager" \
    "03" \
    "Processes tab showing running applications with memory usage. Show sorted by memory usage."

# Screenshot 4: Browser Tabs
capture_screenshot \
    "Browser-Tabs" \
    "04" \
    "Browser tab showing Safari/Chrome tabs. Open several tabs in Safari first to show this feature."

# Screenshot 5: Menu Bar View
capture_screenshot \
    "Menu-Bar" \
    "05" \
    "Menu bar dropdown showing the mini-dashboard. Click the menu bar icon to open this view."

echo ""
echo "========================================="
echo "CAPTURE COMPLETE!"
echo "========================================="
echo ""
echo "Screenshots saved to: $SCREENSHOTS_DIR"
echo ""
echo "Next steps:"
echo "1. Review screenshots in Finder"
echo "2. Retake any that don't look good (just re-run this script)"
echo "3. Verify resolution is 2560x1600 (Right-click > Get Info)"
echo "4. Upload to App Store Connect"
echo ""
echo "For 16-inch display (3456x2234) - Optional but recommended:"
echo "1. Change display resolution to 3456x2234"
echo "2. Re-run this script"
echo "3. Screenshots will overwrite the existing ones with higher resolution"
echo ""
echo "========================================="
echo ""
