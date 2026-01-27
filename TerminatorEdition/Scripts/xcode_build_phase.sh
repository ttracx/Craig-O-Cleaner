#!/bin/bash
# Xcode Build Phase Script
# Add this to your Xcode project Build Phases to verify sync before every build

# This script is designed to run as an Xcode Run Script Build Phase
# It will fail the build if the project is out of sync

# Get the directory of this script
if [ -n "$PROJECT_DIR" ]; then
    # Running from Xcode
    SCRIPT_DIR="$PROJECT_DIR/../Scripts"
else
    # Running standalone
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

echo "🔍 Verifying Xcode project sync before build..."

# Run verification
"$SCRIPT_DIR/verify_xcode_project.sh" --quiet

if [ $? -ne 0 ]; then
    echo "error: Xcode project is out of sync with Swift files!"
    echo "error: Run: ruby Scripts/sync_xcode_auto.rb --exclude-tests"
    exit 1
fi

echo "✅ Project sync verified"
exit 0
