#!/bin/bash
# CI/CD Verification Script
# Use this in GitHub Actions, GitLab CI, or other CI systems
# to verify Xcode project is properly synced

set -e

# Colors (work in most CI environments)
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔍 CI/CD Xcode Project Sync Verification${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install xcodeproj gem if not available
if ! gem list -i xcodeproj > /dev/null 2>&1; then
    echo -e "${YELLOW}📦 Installing xcodeproj gem...${NC}"
    gem install xcodeproj --no-document
fi

# Run verification
echo -e "${BLUE}Verifying project sync...${NC}"
"$SCRIPT_DIR/verify_xcode_project.sh"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ CI CHECK PASSED: Xcode project is properly synced${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ CI CHECK FAILED: Xcode project is out of sync${NC}"
    echo ""
    echo -e "${YELLOW}To fix this locally:${NC}"
    echo "  ruby Scripts/sync_xcode_auto.rb --exclude-tests"
    echo "  git add Xcode/CraigOTerminator.xcodeproj/project.pbxproj"
    echo "  git commit -m 'Sync Xcode project with Swift files'"
    echo ""
    exit 1
fi
