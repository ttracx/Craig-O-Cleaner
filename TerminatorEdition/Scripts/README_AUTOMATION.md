# Xcode Auto-Sync Scripts

Automated synchronization between Swift source files and Xcode project.

## 🚀 Quick Start

```bash
# Install git hooks (one-time setup)
./install_git_hooks.sh

# Verify current status
./verify_xcode_project.sh

# Sync missing files
ruby sync_xcode_auto.rb --exclude-tests
```

## 📋 Scripts Overview

### Core Scripts

| Script | Description | Usage |
|--------|-------------|-------|
| `sync_xcode_auto.rb` | **Main sync script** - Automatically adds missing Swift files | `ruby sync_xcode_auto.rb --exclude-tests` |
| `verify_xcode_project.sh` | **Status checker** - Shows which files are missing | `./verify_xcode_project.sh` |

### Automation Scripts

| Script | Description | When to Use |
|--------|-------------|-------------|
| `install_git_hooks.sh` | **Git hook installer** - Sets up automatic verification | Once per machine |
| `xcode_build_phase.sh` | **Xcode integration** - Add to Build Phases | Optional - for maximum safety |
| `watch_and_sync.sh` | **Watch mode** - Continuous monitoring | During active development |
| `ci_verify_sync.sh` | **CI/CD check** - For automated pipelines | GitHub Actions, GitLab CI, etc. |

## 🎯 Common Tasks

### Daily Use

**Check if project is synced**:
```bash
./verify_xcode_project.sh
```

**Sync missing files**:
```bash
ruby sync_xcode_auto.rb --exclude-tests
```

**Preview what would be synced**:
```bash
ruby sync_xcode_auto.rb --dry-run
```

### One-Time Setup

**Install git hooks** (recommended):
```bash
./install_git_hooks.sh
```

This installs:
- `pre-commit` - Blocks commits if out of sync
- `pre-push` - Final check before pushing
- `post-merge` - Alerts after pulls

### Advanced Usage

**Watch mode** (continuous sync):
```bash
./watch_and_sync.sh
```
Requires: `brew install fswatch`

**Verbose output** (for debugging):
```bash
ruby sync_xcode_auto.rb --verbose --exclude-tests
```

**CI/CD verification**:
```bash
./ci_verify_sync.sh
```

## 📝 Script Options

### sync_xcode_auto.rb

```bash
ruby sync_xcode_auto.rb [options]

Options:
  -d, --dry-run         Show what would be added without making changes
  -v, --verbose         Show detailed output
  -t, --exclude-tests   Skip test files (recommended until test target exists)
  -h, --help           Show help message
```

### verify_xcode_project.sh

```bash
./verify_xcode_project.sh [options]

Options:
  --quiet, -q          Minimal output (for automation)
```

## 🔧 Workflow Examples

### Scenario 1: Adding New File

```bash
# 1. Create new Swift file
touch ../Xcode/CraigOTerminator/Features/NewFeature.swift

# 2. Try to commit (git hook checks automatically)
git add .
git commit -m "Add new feature"

# If out of sync, hook shows error with fix:
# ⚠️  Run: ruby Scripts/sync_xcode_auto.rb --exclude-tests

# 3. Run sync
ruby sync_xcode_auto.rb --exclude-tests

# 4. Commit the updated project
git add ../Xcode/CraigOTerminator.xcodeproj/project.pbxproj
git commit -m "Add new feature"
```

### Scenario 2: After Git Pull

```bash
# 1. Pull latest code
git pull origin main

# 2. If post-merge hook alerts about new files:
ruby sync_xcode_auto.rb --exclude-tests

# Done!
```

### Scenario 3: Before Making Changes

```bash
# Verify project is clean before starting work
./verify_xcode_project.sh

# If out of sync:
ruby sync_xcode_auto.rb --exclude-tests
```

## 🐛 Troubleshooting

### "xcodeproj gem not found"

```bash
sudo gem install xcodeproj
```

Or without sudo:
```bash
gem install xcodeproj --user-install
```

### Scripts not executable

```bash
chmod +x *.sh *.rb
```

### Git hooks not running

**Check installation**:
```bash
ls -la ../../.git/hooks/pre-commit
```

**Reinstall**:
```bash
./install_git_hooks.sh
```

### Want to bypass hook once

```bash
git commit --no-verify -m "Emergency fix"
```
**Warning**: Only for emergencies!

## 📚 Documentation

For complete documentation, see:

- **Quick Start**: `../QUICKSTART_XCODE_SYNC.md` (2 min read)
- **Full Guide**: `../XCODE_AUTO_SYNC.md` (comprehensive)
- **Setup Summary**: `../SETUP_SUMMARY.md` (overview)
- **Implementation**: `../AUTOMATION_COMPLETE.md` (details)

## 🎯 What These Scripts Do

### Detection
1. Scan source directory for `.swift` files
2. Parse Xcode `project.pbxproj` for existing files
3. Compare and identify missing files

### Synchronization
1. Create group hierarchy matching directory structure
2. Add file references to Xcode project
3. Link files to build target
4. Save updated project file

### Verification
1. Check sync status before commits (git hooks)
2. Report missing files with clear messages
3. Provide fix commands
4. Block bad commits automatically

## ⚡ Quick Reference

```bash
# Essential commands
./verify_xcode_project.sh              # Check status
ruby sync_xcode_auto.rb --exclude-tests # Sync files
./install_git_hooks.sh                 # Setup automation

# Advanced commands
ruby sync_xcode_auto.rb --dry-run      # Preview changes
ruby sync_xcode_auto.rb --verbose      # Debug mode
./watch_and_sync.sh                    # Continuous sync
./ci_verify_sync.sh                    # CI/CD check

# Git commands
git commit --no-verify                 # Bypass hooks
```

## 🔗 Related Files

```
TerminatorEdition/
├── Scripts/
│   ├── sync_xcode_auto.rb          ← Main script
│   ├── verify_xcode_project.sh     ← Status checker
│   ├── install_git_hooks.sh        ← Hook installer
│   ├── xcode_build_phase.sh        ← Xcode integration
│   ├── watch_and_sync.sh           ← Watch mode
│   ├── ci_verify_sync.sh           ← CI/CD check
│   └── README_AUTOMATION.md        ← This file
├── QUICKSTART_XCODE_SYNC.md        ← Quick start guide
├── XCODE_AUTO_SYNC.md              ← Complete guide
├── SETUP_SUMMARY.md                ← Setup overview
└── AUTOMATION_COMPLETE.md          ← Implementation details
```

## 📊 Status

- ✅ All scripts created and tested
- ✅ Git hooks installed and verified
- ✅ Documentation complete
- ✅ 41 source files synced to Xcode
- ✅ 3 test files excluded (no test target)
- ✅ Automation working correctly

## 🎉 Success!

The automation system is fully operational. For detailed usage, see the documentation links above.

---

**Last Updated**: January 27, 2026
**Version**: 2.0
**Part of**: Craig-O-Cleaner Terminator Edition
