#!/bin/bash
set -e

VERSION="$1"
if [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/release.sh <version>"
  echo "Example: ./scripts/release.sh 1.0.0"
  exit 1
fi

echo "🚀 Building Craig-O Terminator v$VERSION"
echo ""

# Change to Xcode directory
cd "$(dirname "$0")/../Xcode"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/
xcodebuild clean -project CraigOTerminator.xcodeproj -scheme CraigOTerminator

# Archive
echo ""
echo "📦 Creating archive..."
xcodebuild archive \
  -project CraigOTerminator.xcodeproj \
  -scheme CraigOTerminator \
  -configuration Release \
  -archivePath "build/CraigOTerminator.xcarchive"

# Export
echo ""
echo "📤 Exporting for Developer ID distribution..."
xcodebuild -exportArchive \
  -archivePath "build/CraigOTerminator.xcarchive" \
  -exportPath "build/export" \
  -exportOptionsPlist "ExportOptions.plist"

# Create DMG
echo ""
echo "💿 Creating DMG..."
hdiutil create -volname "Craig-O Terminator v$VERSION" \
  -srcfolder "build/export/CraigOTerminator.app" \
  -ov -format UDZO \
  "build/CraigOTerminator-v$VERSION.dmg"

# Verify code signing
echo ""
echo "🔐 Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "build/export/CraigOTerminator.app"

echo ""
echo "✅ Build complete!"
echo ""
echo "📁 Output: build/CraigOTerminator-v$VERSION.dmg"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️⃣  Submit for notarization:"
echo "   xcrun notarytool submit build/CraigOTerminator-v$VERSION.dmg \\"
echo "     --keychain-profile notary-profile --wait"
echo ""
echo "   OR (first time):"
echo "   xcrun notarytool submit build/CraigOTerminator-v$VERSION.dmg \\"
echo "     --apple-id \"your-apple-id@email.com\" \\"
echo "     --team-id \"FVYG82RN3T\" \\"
echo "     --password \"your-app-specific-password\" \\"
echo "     --wait"
echo ""
echo "2️⃣  Staple notarization ticket:"
echo "   xcrun stapler staple build/CraigOTerminator-v$VERSION.dmg"
echo ""
echo "3️⃣  Verify stapling:"
echo "   xcrun stapler validate build/CraigOTerminator-v$VERSION.dmg"
echo ""
echo "4️⃣  Test on clean Mac (or VM)"
echo ""
echo "5️⃣  Upload to distribution channels:"
echo "   - Website: vibecaas.com/downloads/"
echo "   - GitHub: gh release create v$VERSION build/CraigOTerminator-v$VERSION.dmg"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
