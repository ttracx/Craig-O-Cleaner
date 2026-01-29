#!/bin/bash
# File: CraigOClean-vNext/scripts/bootstrap.sh
# Craig-O-Clean - Bootstrap Script
# Sets up the development environment

set -e

echo "Craig-O-Clean Development Setup"
echo "================================"

# Check Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode command line tools not found"
    echo "Please install Xcode from the App Store"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1)
echo "Found: $XCODE_VERSION"

# Check Swift version
SWIFT_VERSION=$(swift --version | head -1)
echo "Found: $SWIFT_VERSION"

# Check minimum macOS version
OS_VERSION=$(sw_vers -productVersion)
echo "Running on: macOS $OS_VERSION"

# Navigate to project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo ""
echo "Project Directory: $PROJECT_DIR"

# Create Xcode project if it doesn't exist
XCODEPROJ="$PROJECT_DIR/CraigOClean/CraigOClean.xcodeproj"
if [ ! -d "$XCODEPROJ" ]; then
    echo ""
    echo "Note: Xcode project not found"
    echo "Please create the project manually in Xcode:"
    echo ""
    echo "1. Open Xcode"
    echo "2. Create New Project → macOS → App"
    echo "3. Product Name: CraigOClean"
    echo "4. Team: Your Development Team"
    echo "5. Bundle Identifier: com.craigosoft.CraigOClean"
    echo "6. Interface: SwiftUI"
    echo "7. Language: Swift"
    echo "8. Save to: $PROJECT_DIR/CraigOClean/"
    echo ""
    echo "After creating:"
    echo "1. Add existing files from CraigOClean/ directory"
    echo "2. Create two schemes: CraigOClean-DirectPro, CraigOClean-AppStoreLite"
    echo "3. Configure build settings using .xcconfig files"
    echo "4. Set entitlements for each scheme"
fi

# Create Assets.xcassets structure
ASSETS_DIR="$PROJECT_DIR/CraigOClean/Resources/Assets.xcassets"
if [ ! -d "$ASSETS_DIR" ]; then
    echo "Creating Assets.xcassets..."
    mkdir -p "$ASSETS_DIR/AppIcon.appiconset"
    mkdir -p "$ASSETS_DIR/AccentColor.colorset"

    # Create Contents.json for Assets
    cat > "$ASSETS_DIR/Contents.json" << 'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

    # Create AppIcon Contents.json
    cat > "$ASSETS_DIR/AppIcon.appiconset/Contents.json" << 'EOF'
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

    # Create AccentColor Contents.json
    cat > "$ASSETS_DIR/AccentColor.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.875",
          "green" : "0.435",
          "red" : "0.220"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

    echo "Created Assets.xcassets"
fi

# Create Localizable.strings if not exists
STRINGS_FILE="$PROJECT_DIR/CraigOClean/Resources/Localizable.strings"
if [ ! -f "$STRINGS_FILE" ]; then
    cat > "$STRINGS_FILE" << 'EOF'
/* Craig-O-Clean Localizable Strings */

/* App */
"app.name" = "Craig-O-Clean";
"app.tagline" = "Keep your Mac clean and running smoothly";

/* Dashboard */
"dashboard.title" = "Dashboard";
"dashboard.welcome" = "Welcome to Craig-O-Clean";

/* Cleanup */
"cleanup.title" = "Cleanup";
"cleanup.scan" = "Scan";
"cleanup.clean" = "Clean Selected";
"cleanup.empty" = "No items to clean";

/* Diagnostics */
"diagnostics.title" = "Diagnostics";
"diagnostics.collect" = "Collect Report";
"diagnostics.export" = "Export...";

/* Settings */
"settings.title" = "Settings";
"settings.edition" = "Edition";
"settings.compare" = "Compare Editions";

/* Logs */
"logs.title" = "Logs";
"logs.clear" = "Clear Logs";
"logs.export" = "Export Logs";

/* Edition */
"edition.pro" = "Craig-O-Clean Pro";
"edition.lite" = "Craig-O-Clean Lite";
"edition.compare.title" = "Compare Craig-O-Clean Editions";
"edition.pro.info.link" = "Copy Pro Info Link";

/* Pro Feature */
"profeature.unavailable.title" = "Not Available in This Edition";
"profeature.unavailable.copy" = "Copy Pro Info Link";
EOF
    echo "Created Localizable.strings"
fi

echo ""
echo "Bootstrap complete!"
echo ""
echo "Next steps:"
echo "1. Open the project in Xcode"
echo "2. Configure code signing"
echo "3. Build and run with desired scheme"
