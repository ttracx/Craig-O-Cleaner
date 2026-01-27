#!/bin/bash
# Watch Mode for Xcode Auto-Sync
# Continuously monitors for new Swift files and auto-syncs to Xcode project

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="$PROJECT_ROOT/Xcode/CraigOTerminator"

echo -e "${BLUE}👀 Xcode Auto-Sync Watch Mode${NC}"
echo -e "${CYAN}Watching: $SOURCE_DIR${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Check if fswatch is installed
if ! command -v fswatch &> /dev/null; then
    echo -e "${YELLOW}⚠️  fswatch not found, installing...${NC}"
    if command -v brew &> /dev/null; then
        brew install fswatch
    else
        echo -e "${RED}❌ Homebrew not found. Install fswatch manually:${NC}"
        echo "   brew install fswatch"
        exit 1
    fi
fi

# Track last sync time to prevent duplicates
LAST_SYNC=0
DEBOUNCE_SECONDS=2

sync_project() {
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_SYNC))

    if [ $TIME_DIFF -lt $DEBOUNCE_SECONDS ]; then
        return
    fi

    LAST_SYNC=$CURRENT_TIME

    echo ""
    echo -e "${CYAN}🔄 Change detected, syncing...${NC}"

    # Run sync script
    ruby "$SCRIPT_DIR/sync_xcode_auto.rb" --exclude-tests

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Sync complete at $(date '+%H:%M:%S')${NC}"
    else
        echo -e "${RED}❌ Sync failed${NC}"
    fi
}

# Initial sync
sync_project

# Watch for changes
fswatch -0 -r --event Created --event Removed --event Renamed \
    --exclude "\.git/" \
    --exclude "\.build/" \
    --exclude "/build/" \
    --exclude "DerivedData/" \
    --include "\.swift$" \
    "$SOURCE_DIR" | while read -d "" event; do

    # Only sync for Swift files
    if [[ "$event" == *.swift ]]; then
        echo -e "${YELLOW}📁 $(basename "$event")${NC}"
        sync_project
    fi
done
