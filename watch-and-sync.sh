#!/bin/bash
# File Watcher: Auto-sync Xcode project when Swift files change
# This script watches for new/deleted Swift files and auto-syncs the Xcode project

set -e

PROJECT_NAME="Craig-O-Clean"
SOURCE_DIR="$PROJECT_NAME"
WATCH_DIR="${SOURCE_DIR}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Check if fswatch is installed
if ! command -v fswatch &> /dev/null; then
    print_error "fswatch is not installed"
    echo ""
    echo "Install it with Homebrew:"
    echo "  brew install fswatch"
    echo ""
    exit 1
fi

# Check if xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    print_error "xcodegen is not installed"
    echo ""
    echo "Install it with:"
    echo "  make setup"
    echo "or"
    echo "  brew install xcodegen"
    echo ""
    exit 1
fi

# Track file count
get_swift_file_count() {
    find "$SOURCE_DIR" -name "*.swift" -type f ! -path "*/build/*" ! -path "*/DerivedData/*" | wc -l | tr -d ' '
}

LAST_COUNT=$(get_swift_file_count)

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║     File Watcher - Auto Xcode Sync                    ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
print_info "Watching for Swift file changes in: $WATCH_DIR"
print_info "Current Swift file count: $LAST_COUNT"
echo ""
print_success "Watcher started! Press Ctrl+C to stop."
echo ""

# Debounce variables
LAST_SYNC_TIME=0
DEBOUNCE_SECONDS=2

# Watch for file system events
fswatch -r \
    --event Created \
    --event Removed \
    --event Renamed \
    --exclude ".*\.xcodeproj" \
    --exclude ".*/build/.*" \
    --exclude ".*/DerivedData/.*" \
    --exclude ".*\.git/.*" \
    --exclude ".*/Preview Content/.*" \
    --include ".*\.swift$" \
    "$WATCH_DIR" | while read -r event
do
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_SYNC_TIME))

    # Debounce: only sync if enough time has passed
    if [ $TIME_DIFF -lt $DEBOUNCE_SECONDS ]; then
        continue
    fi

    CURRENT_COUNT=$(get_swift_file_count)

    # Only sync if file count changed
    if [ "$CURRENT_COUNT" != "$LAST_COUNT" ]; then
        echo ""
        print_info "Swift file count changed: $LAST_COUNT → $CURRENT_COUNT"
        print_info "Syncing Xcode project..."

        if xcodegen generate 2>&1 | grep -q "error"; then
            print_error "Failed to sync project"
        else
            print_success "Project synced successfully!"
        fi

        LAST_COUNT=$CURRENT_COUNT
        LAST_SYNC_TIME=$CURRENT_TIME
        echo ""
    fi
done
