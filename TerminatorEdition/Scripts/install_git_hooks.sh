#!/bin/bash
# Install Git Hooks for Xcode Project Auto-Sync
# This script installs pre-commit and pre-push hooks to keep Xcode project in sync

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Installing Git Hooks for Xcode Auto-Sync${NC}"
echo ""

# Get project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERMINATOR_ROOT="$(dirname "$SCRIPT_DIR")"

# Find git root (could be parent of TerminatorEdition)
if [ -d "$TERMINATOR_ROOT/.git" ]; then
    GIT_ROOT="$TERMINATOR_ROOT"
elif [ -d "$(dirname "$TERMINATOR_ROOT")/.git" ]; then
    GIT_ROOT="$(dirname "$TERMINATOR_ROOT")"
else
    echo -e "${RED}❌ Error: Git repository not found${NC}"
    echo -e "Checked: $TERMINATOR_ROOT/.git"
    echo -e "Checked: $(dirname "$TERMINATOR_ROOT")/.git"
    exit 1
fi

GIT_HOOKS_DIR="$GIT_ROOT/.git/hooks"
echo -e "${BLUE}Git repository: $GIT_ROOT${NC}"

# Create hooks directory if it doesn't exist
mkdir -p "$GIT_HOOKS_DIR"

# Install pre-commit hook
echo -e "${BLUE}📝 Installing pre-commit hook...${NC}"
cat > "$GIT_HOOKS_DIR/pre-commit" << 'HOOK_EOF'
#!/bin/bash
# Pre-commit hook: Verify Xcode project is in sync

# Find TerminatorEdition/Scripts directory
if [ -d "$(git rev-parse --show-toplevel)/TerminatorEdition/Scripts" ]; then
    SCRIPT_DIR="$(git rev-parse --show-toplevel)/TerminatorEdition/Scripts"
elif [ -d "$(dirname "${BASH_SOURCE[0]}")/../../Scripts" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../Scripts" && pwd)"
else
    echo "❌ Cannot find TerminatorEdition/Scripts directory"
    exit 1
fi

echo "🔍 Verifying Xcode project sync..."

# Run verification script
"$SCRIPT_DIR/verify_xcode_project.sh" --quiet

if [ $? -ne 0 ]; then
    echo ""
    echo "⚠️  Xcode project is out of sync with Swift files!"
    echo ""
    echo "Options:"
    echo "  1. Run: ruby Scripts/sync_xcode_auto.rb --exclude-tests"
    echo "  2. Or add missing files manually in Xcode"
    echo "  3. Or commit with --no-verify (not recommended)"
    echo ""
    exit 1
fi

echo "✅ Xcode project is in sync"
exit 0
HOOK_EOF

chmod +x "$GIT_HOOKS_DIR/pre-commit"
echo -e "${GREEN}  ✓ Pre-commit hook installed${NC}"

# Install pre-push hook
echo -e "${BLUE}📝 Installing pre-push hook...${NC}"
cat > "$GIT_HOOKS_DIR/pre-push" << 'HOOK_EOF'
#!/bin/bash
# Pre-push hook: Final verification before push

# Find TerminatorEdition/Scripts directory
if [ -d "$(git rev-parse --show-toplevel)/TerminatorEdition/Scripts" ]; then
    SCRIPT_DIR="$(git rev-parse --show-toplevel)/TerminatorEdition/Scripts"
elif [ -d "$(dirname "${BASH_SOURCE[0]}")/../../Scripts" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../Scripts" && pwd)"
else
    echo "❌ Cannot find TerminatorEdition/Scripts directory"
    exit 1
fi

echo "🔍 Final Xcode project verification before push..."

# Run verification script
"$SCRIPT_DIR/verify_xcode_project.sh" --quiet

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Cannot push: Xcode project is out of sync!"
    echo ""
    echo "Run: ruby Scripts/sync_xcode_auto.rb --exclude-tests"
    echo ""
    exit 1
fi

echo "✅ Xcode project verification passed"
exit 0
HOOK_EOF

chmod +x "$GIT_HOOKS_DIR/pre-push"
echo -e "${GREEN}  ✓ Pre-push hook installed${NC}"

# Install post-merge hook (auto-sync after pulls)
echo -e "${BLUE}📝 Installing post-merge hook...${NC}"
cat > "$GIT_HOOKS_DIR/post-merge" << 'HOOK_EOF'
#!/bin/bash
# Post-merge hook: Auto-sync after pull/merge

# Find TerminatorEdition/Scripts directory
if [ -d "$(git rev-parse --show-toplevel)/TerminatorEdition/Scripts" ]; then
    SCRIPT_DIR="$(git rev-parse --show-toplevel)/TerminatorEdition/Scripts"
elif [ -d "$(dirname "${BASH_SOURCE[0]}")/../../Scripts" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../Scripts" && pwd)"
else
    echo "❌ Cannot find TerminatorEdition/Scripts directory"
    exit 1
fi

echo "🔄 Checking for Xcode project changes after merge..."

# Check if project file was modified
if git diff-tree -r --name-only --no-commit-id ORIG_HEAD HEAD | grep -q "\.xcodeproj"; then
    echo "📝 Xcode project was modified, verifying sync..."
    "$SCRIPT_DIR/verify_xcode_project.sh" --quiet

    if [ $? -ne 0 ]; then
        echo ""
        echo "⚠️  New Swift files detected after merge"
        echo "💡 Run: ruby Scripts/sync_xcode_auto.rb --exclude-tests"
        echo ""
    fi
fi

exit 0
HOOK_EOF

chmod +x "$GIT_HOOKS_DIR/post-merge"
echo -e "${GREEN}  ✓ Post-merge hook installed${NC}"

echo ""
echo -e "${GREEN}✅ Git hooks installed successfully!${NC}"
echo ""
echo -e "${BLUE}Installed hooks:${NC}"
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
echo -e "${BLUE}To test:${NC}"
echo "   cd $GIT_ROOT"
echo "   touch TerminatorEdition/Xcode/CraigOTerminator/Test.swift"
echo "   git add ."
echo "   git commit -m 'Test' # Should fail"
echo "   rm TerminatorEdition/Xcode/CraigOTerminator/Test.swift"
echo ""
