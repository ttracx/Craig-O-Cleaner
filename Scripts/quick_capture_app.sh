#!/bin/bash

# Quick App-Focused Screenshot Capture
# This script uses AppleScript to bring Craig-O-Clean to foreground and capture

SCREENSHOT_DIR="Screenshots/app-screenshots-$(date +%Y%m%d)"
mkdir -p "$SCREENSHOT_DIR"

echo "🎯 Craig-O-Clean Quick Capture Tool"
echo "===================================="
echo ""

# Function to activate and capture
capture_app_window() {
    local filename=$1
    local window_title=$2

    echo "Capturing: $filename"

    # Activate Craig-O-Clean
    osascript <<EOF
tell application "System Events"
    set frontmost of process "Craig-O-Clean" to true
end tell
EOF

    sleep 1

    # Capture the frontmost window
    screencapture -l$(osascript -e 'tell application "Craig-O-Clean" to id of window 1') "$SCREENSHOT_DIR/$filename" 2>/dev/null || \
    screencapture -W "$SCREENSHOT_DIR/$filename"

    echo "✓ Saved: $filename"
}

# 1. Try to capture menu bar with icon visible
echo ""
echo "[1/3] Capturing menu bar area..."
screencapture -R 0,0,1920,50 "$SCREENSHOT_DIR/01-menu-bar-area.png" 2>/dev/null || \
screencapture -x "$SCREENSHOT_DIR/01-menu-bar-area.png"
echo "✓ Saved: 01-menu-bar-area.png"
sleep 1

# 2. Click menu bar icon and capture popover
echo ""
echo "[2/3] Opening popover..."
osascript <<'EOF'
tell application "System Events"
    tell process "Craig-O-Clean"
        try
            -- Try multiple methods to click menu bar icon
            set menuBarItems to menu bar items of menu bar 1
            click last item of menuBarItems
        on error
            -- Alternative: look for specific menu bar extra
            click (first menu bar item of menu bar 1 whose description contains "brain")
        end try
    end tell
end tell
EOF

sleep 2
echo "Capturing popover (click on it when screencapture activates)..."
screencapture -W "$SCREENSHOT_DIR/02-popover-interactive.png"
echo "✓ Saved: 02-popover-interactive.png"

# 3. Try to open main window
echo ""
echo "[3/3] Attempting to open main window..."
osascript <<'EOF'
tell application "System Events"
    tell process "Craig-O-Clean"
        keystroke "o" using {command down}
    end tell
end tell
EOF

sleep 2
capture_app_window "03-main-window-auto.png" "Craig-O-Clean"

echo ""
echo "===================================="
echo "✅ Quick capture complete!"
echo "===================================="
echo ""
echo "Screenshots saved to: $SCREENSHOT_DIR"
echo ""
echo "Next steps:"
echo "1. Review the captured images"
echo "2. For remaining screenshots, use the comprehensive guide:"
echo "   cat SCREENSHOT_CAPTURE_GUIDE.md"
echo "3. For interactive capture:"
echo "   bash Scripts/capture-screenshots.sh"
