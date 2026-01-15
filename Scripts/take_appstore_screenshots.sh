#!/bin/bash

# =============================================================================
# Craig-O-Clean App Store Screenshot Automation Script
# =============================================================================
# This script automates taking screenshots for Apple App Store submission.
#
# Required macOS screenshot sizes for Mac App Store:
# - 1280 x 800 (MacBook)
# - 1440 x 900 (MacBook Air 13")
# - 2560 x 1600 (MacBook Pro 13" Retina)
# - 2880 x 1800 (MacBook Pro 15" Retina)
#
# Usage: ./take_appstore_screenshots.sh [output_directory]
# =============================================================================

set -e

# Configuration
APP_NAME="Craig-O-Clean"
APP_BUNDLE_ID="com.craigoclean.app"
OUTPUT_DIR="${1:-./Screenshots}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SCREENSHOT_DIR="${OUTPUT_DIR}/${TIMESTAMP}"

# Screenshot dimensions (width x height)
declare -A DIMENSIONS=(
    ["macbook"]="1280x800"
    ["macbook_air"]="1440x900"
    ["macbook_pro_13"]="2560x1600"
    ["macbook_pro_15"]="2880x1800"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if app is running
check_app_running() {
    if ! pgrep -x "$APP_NAME" > /dev/null 2>&1; then
        log_warning "App is not running. Attempting to launch..."
        open -a "$APP_NAME" || {
            log_error "Failed to launch $APP_NAME"
            exit 1
        }
        sleep 3
    fi
    log_info "App is running"
}

# Create output directories
setup_directories() {
    log_info "Setting up output directories..."

    for device in "${!DIMENSIONS[@]}"; do
        mkdir -p "${SCREENSHOT_DIR}/${device}"
    done

    log_success "Created directories at ${SCREENSHOT_DIR}"
}

# Take a screenshot with screencapture
take_screenshot() {
    local name="$1"
    local device="$2"
    local window_id="$3"

    local output_path="${SCREENSHOT_DIR}/${device}/${name}.png"

    if [ -n "$window_id" ]; then
        screencapture -l"$window_id" "$output_path"
    else
        screencapture -w "$output_path"
    fi

    log_success "Captured: $output_path"
}

# Get window ID for the app
get_app_window_id() {
    osascript -e "tell application \"System Events\" to tell process \"$APP_NAME\" to get id of first window" 2>/dev/null || echo ""
}

# Simulate UI interactions using AppleScript
navigate_to_tab() {
    local tab_name="$1"

    osascript <<EOF
tell application "$APP_NAME"
    activate
end tell

tell application "System Events"
    tell process "$APP_NAME"
        delay 0.5
        -- Click on the tab based on name
        -- This would need to be customized based on actual UI elements
    end tell
end tell
EOF
}

# Take screenshot of menu bar popover
capture_menubar() {
    log_info "Capturing menu bar screenshot..."

    osascript <<EOF
tell application "System Events"
    tell process "$APP_NAME"
        -- Click menu bar icon to show popover
        click menu bar item 1 of menu bar 2
        delay 1
    end tell
end tell
EOF

    sleep 1

    for device in "${!DIMENSIONS[@]}"; do
        screencapture -R0,0,400,600 "${SCREENSHOT_DIR}/${device}/01_menubar_popover.png"
    done

    # Close popover
    osascript <<EOF
tell application "System Events"
    key code 53 -- Escape
end tell
EOF

    log_success "Menu bar screenshot captured"
}

# Capture main window screenshots
capture_main_window() {
    log_info "Capturing main window screenshots..."

    # Open main window
    osascript <<EOF
tell application "$APP_NAME"
    activate
end tell
EOF

    sleep 2

    local window_id=$(get_app_window_id)

    if [ -z "$window_id" ]; then
        log_warning "Could not get window ID, using interactive capture"
    fi

    # Capture different tabs/views
    local views=("dashboard" "processes" "memory_cleanup" "browser_tabs" "settings")
    local view_num=1

    for view in "${views[@]}"; do
        log_info "Capturing ${view} view..."

        for device in "${!DIMENSIONS[@]}"; do
            local output="${SCREENSHOT_DIR}/${device}/0${view_num}_${view}.png"

            if [ -n "$window_id" ]; then
                screencapture -l"$window_id" "$output"
            else
                screencapture -w "$output"
            fi
        done

        # Navigate to next tab (using keyboard shortcut)
        osascript <<EOF
tell application "System Events"
    tell process "$APP_NAME"
        keystroke (ASCII character 9) using {command down} -- Cmd+Tab within app
        delay 0.5
    end tell
end tell
EOF

        ((view_num++))
        sleep 1
    done

    log_success "Main window screenshots captured"
}

# Capture paywall/subscription screen
capture_paywall() {
    log_info "Capturing paywall screenshot..."

    # This would trigger showing the paywall
    # Implementation depends on how the paywall can be triggered

    for device in "${!DIMENSIONS[@]}"; do
        # Placeholder - would capture paywall when visible
        log_info "Paywall capture for ${device} - manual trigger needed"
    done
}

# Resize screenshots for different device sizes
resize_screenshots() {
    log_info "Resizing screenshots for different devices..."

    # Check if ImageMagick is available
    if ! command -v convert &> /dev/null; then
        log_warning "ImageMagick not found. Install with: brew install imagemagick"
        log_warning "Skipping resize step"
        return
    fi

    # Get the base screenshots (from macbook_pro_15 as highest res)
    local base_dir="${SCREENSHOT_DIR}/macbook_pro_15"

    for device in "${!DIMENSIONS[@]}"; do
        if [ "$device" == "macbook_pro_15" ]; then
            continue
        fi

        local dim="${DIMENSIONS[$device]}"
        local target_dir="${SCREENSHOT_DIR}/${device}"

        for screenshot in "$base_dir"/*.png; do
            if [ -f "$screenshot" ]; then
                local filename=$(basename "$screenshot")
                convert "$screenshot" -resize "$dim" "${target_dir}/${filename}"
                log_info "Resized ${filename} for ${device}"
            fi
        done
    done

    log_success "Screenshots resized"
}

# Add device frames (optional)
add_device_frames() {
    log_info "Device frames can be added using:"
    log_info "  - https://mockuphone.com"
    log_info "  - https://screenshots.pro"
    log_info "  - Figma with device mockup plugins"
}

# Generate metadata file
generate_metadata() {
    local metadata_file="${SCREENSHOT_DIR}/metadata.json"

    cat > "$metadata_file" <<EOF
{
    "app_name": "$APP_NAME",
    "bundle_id": "$APP_BUNDLE_ID",
    "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "platform": "macOS",
    "screenshots": {
        "menubar_popover": {
            "description": "Quick access menu bar dashboard",
            "filename": "01_menubar_popover.png"
        },
        "dashboard": {
            "description": "Real-time system monitoring dashboard",
            "filename": "02_dashboard.png"
        },
        "processes": {
            "description": "Process manager with memory usage",
            "filename": "03_processes.png"
        },
        "memory_cleanup": {
            "description": "Smart memory optimization",
            "filename": "04_memory_cleanup.png"
        },
        "browser_tabs": {
            "description": "Browser tab management",
            "filename": "05_browser_tabs.png"
        },
        "settings": {
            "description": "Settings and subscription options",
            "filename": "06_settings.png"
        }
    },
    "dimensions": {
        "macbook": "1280x800",
        "macbook_air": "1440x900",
        "macbook_pro_13": "2560x1600",
        "macbook_pro_15": "2880x1800"
    }
}
EOF

    log_success "Generated metadata at $metadata_file"
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "  Craig-O-Clean Screenshot Automation"
    echo "=========================================="
    echo ""

    check_app_running
    setup_directories

    log_info "Starting screenshot capture..."
    log_info "Output directory: $SCREENSHOT_DIR"
    echo ""

    # Capture screenshots
    capture_menubar
    capture_main_window

    # Post-processing
    resize_screenshots
    generate_metadata

    echo ""
    log_success "Screenshot capture complete!"
    log_info "Screenshots saved to: $SCREENSHOT_DIR"
    echo ""

    # Open output directory
    open "$SCREENSHOT_DIR"
}

# Run main function
main "$@"
