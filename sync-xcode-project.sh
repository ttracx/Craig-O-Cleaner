#!/bin/bash
# Simple Xcode Project Sync Script
# Uses xcodegen to regenerate project from file structure

set -e

PROJECT_NAME="Craig-O-Clean"
SOURCE_DIR="$PROJECT_NAME"
PROJECT_YML="project.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Check if xcodegen is installed
check_xcodegen() {
    if ! command -v xcodegen &> /dev/null; then
        print_error "xcodegen is not installed"
        echo ""
        echo "Install it with Homebrew:"
        echo "  brew install xcodegen"
        echo ""
        echo "Or with Mint:"
        echo "  mint install yonaskolb/XcodeGen"
        echo ""
        exit 1
    fi
}

# Generate project.yml if it doesn't exist
generate_project_yml() {
    if [ -f "$PROJECT_YML" ]; then
        print_info "Using existing $PROJECT_YML"
        return
    fi

    print_info "Generating $PROJECT_YML..."

    cat > "$PROJECT_YML" << 'EOF'
name: Craig-O-Clean

options:
  bundleIdPrefix: com.neuralquantum
  deploymentTarget:
    macOS: "13.0"

settings:
  SWIFT_VERSION: 5.9
  MACOSX_DEPLOYMENT_TARGET: 13.0

targets:
  Craig-O-Clean:
    type: application
    platform: macOS

    sources:
      - Craig-O-Clean

    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.neuralquantum.Craig-O-Clean
      INFOPLIST_FILE: Craig-O-Clean/Info.plist
      CODE_SIGN_ENTITLEMENTS: Craig-O-Clean/Craig-O-Clean.entitlements
      ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
      COMBINE_HIDPI_IMAGES: YES
      ENABLE_PREVIEWS: YES
      DEVELOPMENT_ASSET_PATHS: "\"Craig-O-Clean/Preview Content\""
      SWIFT_EMIT_LOC_STRINGS: YES
      CURRENT_PROJECT_VERSION: 1
      GENERATE_INFOPLIST_FILE: NO
      MARKETING_VERSION: 1.0

    scheme:
      testTargets:
        - Craig-O-CleanTests

    dependencies: []

schemes:
  Craig-O-Clean:
    build:
      targets:
        Craig-O-Clean: all
    run:
      config: Debug
    archive:
      config: Release
EOF

    print_success "Generated $PROJECT_YML"
}

# Backup existing project
backup_project() {
    if [ -d "${PROJECT_NAME}.xcodeproj" ]; then
        BACKUP_NAME="${PROJECT_NAME}.xcodeproj.backup-$(date +%Y%m%d-%H%M%S)"
        print_info "Backing up existing project to $BACKUP_NAME"
        cp -R "${PROJECT_NAME}.xcodeproj" "$BACKUP_NAME"
    fi
}

# Clean up old backups (keep last 5)
cleanup_backups() {
    BACKUP_COUNT=$(find . -maxdepth 1 -name "${PROJECT_NAME}.xcodeproj.backup-*" -type d | wc -l | tr -d ' ')

    if [ "$BACKUP_COUNT" -gt 5 ]; then
        print_info "Cleaning up old backups (keeping last 5)..."
        find . -maxdepth 1 -name "${PROJECT_NAME}.xcodeproj.backup-*" -type d -print0 | \
            xargs -0 ls -dt | \
            tail -n +6 | \
            xargs rm -rf
    fi
}

# Generate project using xcodegen
generate_project() {
    print_info "Generating Xcode project..."

    if xcodegen generate; then
        print_success "Project generated successfully!"
        return 0
    else
        print_error "Failed to generate project"
        return 1
    fi
}

# List Swift files
list_swift_files() {
    print_info "Swift files in $SOURCE_DIR:"
    find "$SOURCE_DIR" -name "*.swift" -type f ! -path "*/Preview Content/*" | sort | while read -r file; do
        echo "  📄 $(basename "$file")"
    done
    echo ""
}

# Main execution
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║     Xcode Project Sync - Craig-O-Clean                ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""

    # Check requirements
    check_xcodegen

    # Show current files
    list_swift_files

    # Generate project.yml if needed
    generate_project_yml

    # Backup existing project
    backup_project

    # Generate project
    if generate_project; then
        cleanup_backups
        echo ""
        print_success "Project sync complete!"
        echo ""
        print_info "You can now open the project:"
        echo "  open ${PROJECT_NAME}.xcodeproj"
        echo ""
    else
        print_error "Project sync failed"
        exit 1
    fi
}

# Run main function
main
