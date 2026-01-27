#!/bin/bash
# Xcode Project Verification Script for Craig-O-Clean
# Checks which Swift files are missing from the Xcode project

set -e

# Parse arguments
QUIET=false
EXCLUDE_TESTS=false
for arg in "$@"; do
    case $arg in
        --quiet|-q)
            QUIET=true
            shift
            ;;
        --exclude-tests)
            EXCLUDE_TESTS=true
            shift
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="$PROJECT_ROOT/Craig-O-Clean"
PROJECT_FILE="$PROJECT_ROOT/Craig-O-Clean.xcodeproj/project.pbxproj"

if [ "$QUIET" = false ]; then
    echo -e "${BLUE}🔍 Verifying Craig-O-Clean Xcode project...${NC}"
fi

if [ ! -f "$PROJECT_FILE" ]; then
    echo -e "${RED}Error: project.pbxproj not found at $PROJECT_FILE${NC}"
    exit 1
fi

# Find all Swift files
if [ "$QUIET" = false ]; then
    echo -e "\n${BLUE}Finding all Swift files...${NC}"
fi

if [ "$EXCLUDE_TESTS" = true ]; then
    SWIFT_FILES=$(find "$SOURCE_DIR" -name "*.swift" -type f | grep -v "/.build/" | grep -v "/build/" | grep -v "/DerivedData/" | grep -v "/Tests/")
else
    SWIFT_FILES=$(find "$SOURCE_DIR" -name "*.swift" -type f | grep -v "/.build/" | grep -v "/build/" | grep -v "/DerivedData/")
fi

TOTAL_FILES=$(echo "$SWIFT_FILES" | wc -l | tr -d ' ')

if [ "$QUIET" = false ]; then
    echo -e "Found ${GREEN}$TOTAL_FILES${NC} Swift files"
    echo -e "\n${BLUE}Checking project.pbxproj...${NC}"
fi

# Check which files are in the project
MISSING_FILES=()

while IFS= read -r file; do
    filename=$(basename "$file")
    if ! grep -q "$filename" "$PROJECT_FILE"; then
        MISSING_FILES+=("$file")
    fi
done <<< "$SWIFT_FILES"

# Report results
if [ ${#MISSING_FILES[@]} -eq 0 ]; then
    if [ "$QUIET" = false ]; then
        echo -e "\n${GREEN}✅ All Swift files are in the Xcode project!${NC}"
    fi
    exit 0
else
    if [ "$QUIET" = false ]; then
        echo -e "\n${YELLOW}⚠️  Found ${#MISSING_FILES[@]} missing files:${NC}"
        for file in "${MISSING_FILES[@]}"; do
            rel_path=$(echo "$file" | sed "s|$SOURCE_DIR/||")
            echo -e "  ${RED}✗${NC} $rel_path"
        done

        echo -e "\n${BLUE}💡 Run the sync script to add these files:${NC}"
        echo -e "   ${YELLOW}ruby Scripts/sync_craig_o_clean.rb --exclude-tests${NC}"
    else
        # In quiet mode, just output count
        echo "Found ${#MISSING_FILES[@]} missing Swift files"
    fi
    exit 1
fi
