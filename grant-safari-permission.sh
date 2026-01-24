#!/bin/bash
# Grant Safari Automation Permission for Craig-O-Clean
# This script helps automate the permission granting process

echo "═══════════════════════════════════════════════════════════════════"
echo "  Craig-O-Clean: Safari Automation Permission Setup"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# App bundle identifier
BUNDLE_ID="com.craigoclean.app"

echo "Checking current automation permissions..."
echo ""

# Check if Craig-O-Clean has any automation permissions
if sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
   "SELECT * FROM access WHERE service='kTCCServiceAppleEvents' AND client='$BUNDLE_ID';" 2>/dev/null | grep -q "$BUNDLE_ID"; then
    echo -e "${GREEN}✓${NC} Craig-O-Clean has some automation permissions configured"

    # Check specifically for Safari
    if sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
       "SELECT allowed FROM access WHERE service='kTCCServiceAppleEvents' AND client='$BUNDLE_ID' AND indirect_object_identifier='com.apple.Safari';" 2>/dev/null | grep -q "1"; then
        echo -e "${GREEN}✓${NC} Safari automation permission: GRANTED"
        echo ""
        echo "Safari permission is already granted! If you're still having issues:"
        echo "  1. Make sure Safari is running"
        echo "  2. Try restarting Safari"
        echo "  3. Click 'Refresh' in Craig-O-Clean's Browser Tabs view"
        exit 0
    else
        echo -e "${RED}✗${NC} Safari automation permission: DENIED or NOT SET"
    fi
else
    echo -e "${YELLOW}⚠${NC}  Craig-O-Clean has no automation permissions yet"
fi

echo ""
echo "────────────────────────────────────────────────────────────────────"
echo "  To grant Safari automation permission:"
echo "────────────────────────────────────────────────────────────────────"
echo ""
echo "  1. Open ${BLUE}System Settings${NC}"
echo "  2. Go to ${BLUE}Privacy & Security${NC} → ${BLUE}Automation${NC}"
echo "  3. Find ${BLUE}Craig-O-Clean${NC} in the list"
echo "  4. Toggle ${GREEN}ON${NC} the switch for ${BLUE}Safari${NC}"
echo "  5. Restart Safari if needed"
echo ""
echo "────────────────────────────────────────────────────────────────────"
echo ""

# Offer to open System Settings
read -p "Would you like to open System Settings now? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Opening System Settings → Privacy & Security → Automation..."
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
    echo ""
    echo -e "${GREEN}✓${NC} System Settings opened"
    echo ""
    echo "After granting permission:"
    echo "  1. Make sure Safari is running with some tabs open"
    echo "  2. Open Craig-O-Clean → Browser Tabs"
    echo "  3. Click the 'Refresh' button"
    echo ""
fi

echo "────────────────────────────────────────────────────────────────────"
echo "  Alternative: Reset ALL automation permissions (if stuck)"
echo "────────────────────────────────────────────────────────────────────"
echo ""
echo "If the above doesn't work (e.g., permission was denied before):"
echo ""
echo "  ${YELLOW}tccutil reset AppleEvents${NC}"
echo ""
echo "⚠️  WARNING: This will reset automation permissions for ALL apps!"
echo "   You'll need to re-grant permissions to all apps that use automation."
echo ""

echo "═══════════════════════════════════════════════════════════════════"
