#!/bin/bash
# Install Git Hooks for Multi-Project Xcode Auto-Sync
# Verifies BOTH Craig-O-Clean and TerminatorEdition projects

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Installing Unified Git Hooks for All Xcode Projects${NC}"
echo ""

# Get project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GIT_HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

# Check if we're in a git repo
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo -e "${RED}❌ Error: Not in a git repository${NC}"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$GIT_HOOKS_DIR"

echo -e "${BLUE}Git repository: $PROJECT_ROOT${NC}"
echo ""

# Install pre-commit hook
echo -e "${BLUE}📝 Installing pre-commit hook...${NC}"
cat > "$GIT_HOOKS_DIR/pre-commit" << 'HOOK_EOF'
#!/bin/bash
# Pre-commit hook: Verify ALL Xcode projects are in sync

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT_DIR="$GIT_ROOT/Scripts"

echo "🔍 Verifying Xcode projects sync..."

# Track failures
FAILED=0

# Check Craig-O-Clean project
echo ""
echo "Checking Craig-O-Clean..."
if [ -f "$SCRIPT_DIR/verify_craig_o_clean.sh" ]; then
    "$SCRIPT_DIR/verify_craig_o_clean.sh" --quiet
    if [ $? -ne 0 ]; then
        echo "❌ Craig-O-Clean project is out of sync"
        echo "   Fix: ruby Scripts/sync_craig_o_clean.rb --exclude-tests"
        FAILED=1
    else
        echo "✅ Craig-O-Clean is in sync"
    fi
fi

# Check TerminatorEdition project
echo ""
echo "Checking TerminatorEdition..."
if [ -f "$GIT_ROOT/TerminatorEdition/Scripts/verify_xcode_project.sh" ]; then
    "$GIT_ROOT/TerminatorEdition/Scripts/verify_xcode_project.sh" --quiet
    if [ $? -ne 0 ]; then
        echo "❌ TerminatorEdition project is out of sync"
        echo "   Fix: cd TerminatorEdition && ruby Scripts/sync_xcode_auto.rb --exclude-tests"
        FAILED=1
    else
        echo "✅ TerminatorEdition is in sync"
    fi
fi

if [ $FAILED -eq 1 ]; then
    echo ""
    echo "⚠️  One or more Xcode projects are out of sync!"
    echo ""
    echo "Options:"
    echo "  1. Run the suggested sync commands above"
    echo "  2. Or commit with --no-verify (not recommended)"
    echo ""
    exit 1
fi

echo ""
echo "✅ All Xcode projects are in sync"
exit 0
HOOK_EOF

chmod +x "$GIT_HOOKS_DIR/pre-commit"
echo -e "${GREEN}  ✓ Pre-commit hook installed${NC}"

# Install pre-push hook
echo -e "${BLUE}📝 Installing pre-push hook...${NC}"
cat > "$GIT_HOOKS_DIR/pre-push" << 'HOOK_EOF'
#!/bin/bash
# Pre-push hook: Final verification of ALL projects before push

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT_DIR="$GIT_ROOT/Scripts"

echo "🔍 Final Xcode project verification before push..."

# Track failures
FAILED=0

# Check Craig-O-Clean
if [ -f "$SCRIPT_DIR/verify_craig_o_clean.sh" ]; then
    "$SCRIPT_DIR/verify_craig_o_clean.sh" --quiet
    [ $? -ne 0 ] && FAILED=1
fi

# Check TerminatorEdition
if [ -f "$GIT_ROOT/TerminatorEdition/Scripts/verify_xcode_project.sh" ]; then
    "$GIT_ROOT/TerminatorEdition/Scripts/verify_xcode_project.sh" --quiet
    [ $? -ne 0 ] && FAILED=1
fi

if [ $FAILED -eq 1 ]; then
    echo ""
    echo "❌ Cannot push: Xcode projects are out of sync!"
    echo "Run verification scripts to see details."
    echo ""
    exit 1
fi

echo "✅ All Xcode projects verified"
exit 0
HOOK_EOF

chmod +x "$GIT_HOOKS_DIR/pre-push"
echo -e "${GREEN}  ✓ Pre-push hook installed${NC}"

# Install post-merge hook
echo -e "${BLUE}📝 Installing post-merge hook...${NC}"
cat > "$GIT_HOOKS_DIR/post-merge" << 'HOOK_EOF'
#!/bin/bash
# Post-merge hook: Check ALL projects after pull/merge

GIT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT_DIR="$GIT_ROOT/Scripts"

echo "🔄 Checking Xcode projects after merge..."

# Check if any Xcode project files were modified
if git diff-tree -r --name-only --no-commit-id ORIG_HEAD HEAD | grep -q "\.xcodeproj"; then
    echo "📝 Xcode project files were modified, verifying sync..."

    # Check Craig-O-Clean
    if [ -f "$SCRIPT_DIR/verify_craig_o_clean.sh" ]; then
        "$SCRIPT_DIR/verify_craig_o_clean.sh" --quiet
        if [ $? -ne 0 ]; then
            echo ""
            echo "⚠️  Craig-O-Clean has new Swift files"
            echo "💡 Run: ruby Scripts/sync_craig_o_clean.rb --exclude-tests"
        fi
    fi

    # Check TerminatorEdition
    if [ -f "$GIT_ROOT/TerminatorEdition/Scripts/verify_xcode_project.sh" ]; then
        "$GIT_ROOT/TerminatorEdition/Scripts/verify_xcode_project.sh" --quiet
        if [ $? -ne 0 ]; then
            echo ""
            echo "⚠️  TerminatorEdition has new Swift files"
            echo "💡 Run: cd TerminatorEdition && ruby Scripts/sync_xcode_auto.rb --exclude-tests"
        fi
    fi
fi

exit 0
HOOK_EOF

chmod +x "$GIT_HOOKS_DIR/post-merge"
echo -e "${GREEN}  ✓ Post-merge hook installed${NC}"

echo ""
echo -e "${GREEN}✅ Unified git hooks installed successfully!${NC}"
echo ""
echo -e "${BLUE}Installed hooks verify:${NC}"
echo "  • Craig-O-Clean.xcodeproj"
echo "  • TerminatorEdition/Xcode/CraigOTerminator.xcodeproj"
echo ""
echo -e "${BLUE}Hooks installed:${NC}"
echo "  • pre-commit  - Verifies sync before commits"
echo "  • pre-push    - Final verification before push"
echo "  • post-merge  - Checks for new files after pulls"
echo ""
echo -e "${YELLOW}💡 To bypass hooks temporarily:${NC}"
echo "   git commit --no-verify"
echo ""
echo -e "${BLUE}To uninstall:${NC}"
echo "   rm $GIT_HOOKS_DIR/pre-commit"
echo "   rm $GIT_HOOKS_DIR/pre-push"
echo "   rm $GIT_HOOKS_DIR/post-merge"
echo ""
