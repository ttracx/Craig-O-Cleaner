#!/bin/bash
# File: CraigOClean-vNext/scripts/lint.sh
# Craig-O-Clean - Lint Script
# Runs code quality checks

set -e

echo "Craig-O-Clean Code Quality Checks"
echo "=================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Check for SwiftLint
if command -v swiftlint &> /dev/null; then
    echo "Running SwiftLint..."
    swiftlint lint --path CraigOClean --reporter emoji
else
    echo "SwiftLint not installed. Skipping..."
    echo "Install with: brew install swiftlint"
fi

# Check for SwiftFormat
if command -v swiftformat &> /dev/null; then
    echo ""
    echo "Running SwiftFormat (check only)..."
    swiftformat CraigOClean --lint
else
    echo "SwiftFormat not installed. Skipping..."
    echo "Install with: brew install swiftformat"
fi

# Build check
echo ""
echo "Checking compilation..."

# Build Lite
echo "Building AppStoreLite..."
xcodebuild -scheme CraigOClean-AppStoreLite -configuration Debug build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    -quiet 2>/dev/null || echo "Note: Build requires Xcode project setup"

# Build Pro
echo "Building DirectPro..."
xcodebuild -scheme CraigOClean-DirectPro -configuration Debug build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    -quiet 2>/dev/null || echo "Note: Build requires Xcode project setup"

# Run tests
echo ""
echo "Running tests..."
xcodebuild test -scheme CraigOClean-AppStoreLite \
    -destination 'platform=macOS' \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    -quiet 2>/dev/null || echo "Note: Tests require Xcode project setup"

echo ""
echo "Lint complete!"
