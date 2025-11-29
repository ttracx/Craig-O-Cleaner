#!/bin/bash
# Setup script for automatic Xcode project syncing
# Installs git hooks and configures file watcher

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║     Auto-Sync Setup - Craig-O-Clean                   ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Check if in git repository
if [ ! -d ".git" ]; then
    print_error "Not in a git repository"
    exit 1
fi

# Make sync scripts executable
print_info "Making scripts executable..."
chmod +x sync-xcode-project.sh 2>/dev/null || true
chmod +x watch-and-sync.sh 2>/dev/null || true
chmod +x .git-hooks/post-merge 2>/dev/null || true
chmod +x .git-hooks/post-checkout 2>/dev/null || true
print_success "Scripts are now executable"
echo ""

# Setup git hooks
print_info "Setting up git hooks..."

# Configure git to use custom hooks directory
git config core.hooksPath .git-hooks

print_success "Git hooks configured!"
print_info "Hooks location: .git-hooks/"
print_info "Active hooks:"
echo "  • post-merge (runs after git pull)"
echo "  • post-checkout (runs after branch checkout)"
echo ""

# Check dependencies
print_info "Checking dependencies..."

MISSING_DEPS=false

if command -v xcodegen &> /dev/null; then
    print_success "xcodegen: installed"
else
    print_warning "xcodegen: not installed"
    MISSING_DEPS=true
fi

if command -v fswatch &> /dev/null; then
    print_success "fswatch: installed (optional, for file watcher)"
else
    print_warning "fswatch: not installed (optional, for file watcher)"
    echo "           Install with: brew install fswatch"
fi

echo ""

# Install missing dependencies if needed
if [ "$MISSING_DEPS" = true ]; then
    echo ""
    print_warning "Some required dependencies are missing"
    echo ""
    read -p "Would you like to install them now? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installing dependencies..."
        make setup
        echo ""
    else
        print_info "You can install dependencies later with: make setup"
        echo ""
    fi
fi

# Summary
echo "╔════════════════════════════════════════════════════════╗"
echo "║                  Setup Complete!                       ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Auto-sync is now configured! You have three options:"
echo ""
echo "1. Git Hooks (Automatic - ENABLED)"
echo "   ✅ Syncs automatically after:"
echo "      • git pull"
echo "      • git merge"
echo "      • git checkout (switching branches)"
echo ""
echo "2. Manual Sync (When needed)"
echo "   Run one of these commands:"
echo "      make sync"
echo "      ./sync-xcode-project.sh"
echo ""
echo "3. File Watcher (Real-time - Optional)"
echo "   Start the watcher to sync when files change:"
echo "      ./watch-and-sync.sh"
echo "   Keep it running in a separate terminal"
echo ""
echo "Recommendation:"
echo "   Use git hooks for most work (already enabled!)"
echo "   Use file watcher when actively adding many files"
echo "   Use manual sync for quick one-off syncs"
echo ""
print_success "Happy coding!"
echo ""
