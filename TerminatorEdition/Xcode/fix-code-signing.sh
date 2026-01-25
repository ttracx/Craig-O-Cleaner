#!/bin/bash

# Craig-O Terminator - Code Signing Fix Script
# This script properly code signs the debug build for TCC compatibility

set -e  # Exit on error

echo "🔐 Craig-O Terminator Code Signing Fix"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Find the debug build dynamically
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
DEBUG_BUILD=$(find "$DERIVED_DATA" -path "*/CraigOTerminator*/Build/Products/Debug/CraigOTerminator.app" -type d | head -1)

if [ -z "$DEBUG_BUILD" ] || [ ! -d "$DEBUG_BUILD" ]; then
    echo -e "${RED}❌ Debug build not found in DerivedData${NC}"
    echo ""
    echo "Searched: $DERIVED_DATA/CraigOTerminator*/Build/Products/Debug/"
    echo ""
    echo "Please build the project first in Xcode (⌘B)"
    exit 1
fi

echo -e "${GREEN}✅ Found debug build${NC}"
echo "   Location: $DEBUG_BUILD"
echo ""

# Check available signing identities
echo "📋 Available signing identities:"
security find-identity -v -p codesigning | grep "Apple Development"
echo ""

# Get the signing identity (use hash to avoid ambiguity)
SIGNING_IDENTITY="B0AD8C8399EC9952C93347E34123171E25B458A6"

echo "🔑 Using signing identity: $SIGNING_IDENTITY"
echo ""

# Kill the app if running
echo "🛑 Stopping app if running..."
killall CraigOTerminator 2>/dev/null || true
sleep 1
echo ""

# Remove extended attributes (they can interfere with signing)
echo "🧹 Removing extended attributes..."
xattr -c "$DEBUG_BUILD" 2>/dev/null || true
find "$DEBUG_BUILD" -type f -exec xattr -c {} \; 2>/dev/null || true
echo -e "${GREEN}✅ Extended attributes removed${NC}"
echo ""

# Re-sign the app with proper entitlements
echo "✍️  Re-signing application..."
ENTITLEMENTS="/Volumes/VibeStore/Craig-O-Cleaner/TerminatorEdition/Xcode/CraigOTerminator/CraigOTerminator.entitlements"

if [ ! -f "$ENTITLEMENTS" ]; then
    echo -e "${RED}❌ Entitlements file not found at: $ENTITLEMENTS${NC}"
    exit 1
fi

# Sign with entitlements and hardened runtime
codesign --force \
    --deep \
    --sign "$SIGNING_IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    --timestamp \
    "$DEBUG_BUILD"

echo -e "${GREEN}✅ App re-signed successfully${NC}"
echo ""

# Verify the signature
echo "🔍 Verifying signature..."
codesign --verify --verbose=4 "$DEBUG_BUILD"
echo ""
codesign --display --entitlements - "$DEBUG_BUILD"
echo ""

echo -e "${GREEN}✅ Signature verification complete${NC}"
echo ""

# Check TCC database registration
echo "🔎 Checking TCC database registration..."
echo "Note: The app may need to be launched once to register with TCC"
echo ""

# Reset TCC for this app (optional but recommended)
read -p "Reset TCC permissions for fresh start? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔄 Resetting TCC permissions..."
    tccutil reset All com.vibecaas.CraigOTerminator 2>/dev/null || true
    tccutil reset Accessibility 2>/dev/null || true
    tccutil reset SystemPolicyAllFiles 2>/dev/null || true
    tccutil reset AppleEvents 2>/dev/null || true
    echo -e "${GREEN}✅ TCC permissions reset${NC}"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Code signing fix complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 Next steps:"
echo "1. Launch the app: open '$DEBUG_BUILD'"
echo "2. Grant permissions when prompted"
echo "3. Test browser automation and other features"
echo ""
echo "⚠️  Note: For distribution, create an Archive build:"
echo "   Xcode → Product → Archive → Export"
echo ""
