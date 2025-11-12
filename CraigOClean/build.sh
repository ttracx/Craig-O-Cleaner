#!/bin/bash

# Craig-O-Clean Build Script
# This script builds the app from the command line

echo "================================================"
echo "Craig-O-Clean - Build Script"
echo "================================================"
echo ""

# Check if we're in the right directory
if [ ! -f "CraigOClean.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: CraigOClean.xcodeproj not found!"
    echo "Please run this script from the CraigOClean directory."
    exit 1
fi

echo "🔨 Building Craig-O-Clean..."
echo ""

# Build the project
xcodebuild -project CraigOClean.xcodeproj \
           -scheme CraigOClean \
           -configuration Release \
           -derivedDataPath ./build \
           build

# Check if build was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "📦 Built application location:"
    echo "   ./build/Build/Products/Release/CraigOClean.app"
    echo ""
    echo "To run the app:"
    echo "   open ./build/Build/Products/Release/CraigOClean.app"
    echo ""
    echo "To copy to Applications folder:"
    echo "   cp -r ./build/Build/Products/Release/CraigOClean.app /Applications/"
    echo ""
else
    echo ""
    echo "❌ Build failed!"
    echo "Please check the error messages above."
    echo ""
    echo "Common issues:"
    echo "  - Make sure Xcode Command Line Tools are installed"
    echo "  - Run: xcode-select --install"
    echo "  - Or open the project in Xcode and build from there"
    exit 1
fi
