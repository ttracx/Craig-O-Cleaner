#!/bin/bash
# Xcode Project Verification Script
# Checks which Swift files are missing from the Xcode project

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
XCODE_DIR="$PROJECT_ROOT/Xcode"
PROJECT_FILE="$XCODE_DIR/CraigOTerminator.xcodeproj/project.pbxproj"

echo -e "${BLUE}🔍 Verifying Xcode project...${NC}"

if [ ! -f "$PROJECT_FILE" ]; then
    echo -e "${RED}Error: project.pbxproj not found at $PROJECT_FILE${NC}"
    exit 1
fi

# Find all Swift files
echo -e "\n${BLUE}Finding all Swift files...${NC}"
SWIFT_FILES=$(find "$XCODE_DIR/CraigOTerminator" -name "*.swift" -type f | grep -v "/.build/" | grep -v "/build/" | grep -v "/DerivedData/")

TOTAL_FILES=$(echo "$SWIFT_FILES" | wc -l | tr -d ' ')
echo -e "Found ${GREEN}$TOTAL_FILES${NC} Swift files"

# Check which files are in the project
echo -e "\n${BLUE}Checking project.pbxproj...${NC}"
MISSING_FILES=()

while IFS= read -r file; do
    filename=$(basename "$file")
    if ! grep -q "$filename" "$PROJECT_FILE"; then
        MISSING_FILES+=("$file")
    fi
done <<< "$SWIFT_FILES"

# Report results
if [ ${#MISSING_FILES[@]} -eq 0 ]; then
    echo -e "\n${GREEN}✅ All Swift files are in the Xcode project!${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠️  Found ${#MISSING_FILES[@]} missing files:${NC}"
    for file in "${MISSING_FILES[@]}"; do
        rel_path=$(echo "$file" | sed "s|$XCODE_DIR/CraigOTerminator/||")
        echo -e "  ${RED}✗${NC} $rel_path"
    done

    echo -e "\n${BLUE}💡 Run the sync script to add these files:${NC}"
    echo -e "   ${YELLOW}python3 scripts/sync_xcode_project.py${NC}"
    exit 1
fi
