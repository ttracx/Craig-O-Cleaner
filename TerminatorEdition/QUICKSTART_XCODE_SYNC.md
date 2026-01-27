# Xcode Auto-Sync Quick Start Guide 🚀

Get your Xcode project automatically synced in under 2 minutes.

## TL;DR

```bash
cd TerminatorEdition

# 1. Sync missing files
ruby Scripts/sync_xcode_auto.rb --exclude-tests

# 2. Install git hooks
./Scripts/install_git_hooks.sh

# Done! ✅
```

---

## What This Does

**Problem**: Adding Swift files outside Xcode (via terminal, IDE, git pull) doesn't update the Xcode project, causing build failures.

**Solution**: Automated scripts that:
- ✅ Detect missing Swift files
- ✅ Add them to Xcode project
- ✅ Verify sync before commits
- ✅ Keep project structure clean

---

## Installation (One-Time)

### Step 1: Verify Current State

```bash
cd /Volumes/VibeStore/Craig-O-Cleaner/TerminatorEdition
./Scripts/verify_xcode_project.sh
```

**Expected output**:
- ✅ "All Swift files are in sync" → You're good!
- ⚠️ "Found X missing files" → Continue to Step 2

### Step 2: Sync Missing Files

```bash
ruby Scripts/sync_xcode_auto.rb --exclude-tests
```

**What happens**:
1. Scans for Swift files
2. Adds missing ones to Xcode
3. Creates proper group structure
4. Saves project file

**Time**: ~5 seconds

### Step 3: Install Automation (Recommended)

```bash
./Scripts/install_git_hooks.sh
```

**What gets installed**:
- `pre-commit` hook: Blocks commits if out of sync
- `pre-push` hook: Final check before pushing
- `post-merge` hook: Alerts after git pulls

**Time**: ~2 seconds

---

## Daily Workflow

### With Git Hooks (Recommended Setup)

Just work normally! Hooks automatically check on commit:

```bash
# 1. Add new Swift file
touch Xcode/CraigOTerminator/Features/NewFeature.swift

# 2. Commit (hook auto-runs sync check)
git add .
git commit -m "Add new feature"

# If out of sync, hook shows:
# ⚠️  Xcode project is out of sync!
# Run: ruby Scripts/sync_xcode_auto.rb --exclude-tests

# 3. Run suggested command
ruby Scripts/sync_xcode_auto.rb --exclude-tests

# 4. Commit again (now succeeds)
git add Xcode/CraigOTerminator.xcodeproj/project.pbxproj
git commit -m "Add new feature"
```

### Without Git Hooks (Manual Workflow)

```bash
# After adding Swift files, before committing:
ruby Scripts/sync_xcode_auto.rb --exclude-tests

# Then commit:
git add .
git commit -m "Your changes"
```

---

## Common Commands

### Check Sync Status
```bash
./Scripts/verify_xcode_project.sh
```

### Sync Files
```bash
ruby Scripts/sync_xcode_auto.rb --exclude-tests
```

### Preview Changes (Don't Apply)
```bash
ruby Scripts/sync_xcode_auto.rb --dry-run
```

### Watch Mode (Auto-Sync on File Changes)
```bash
./Scripts/watch_and_sync.sh
# Press Ctrl+C to stop
```

---

## Troubleshooting

### "xcodeproj gem not found"

```bash
sudo gem install xcodeproj
```

### "Permission denied"

```bash
chmod +x Scripts/*.sh Scripts/*.rb
```

### Hook Not Running

```bash
# Verify installation
ls -la .git/hooks/pre-commit

# Reinstall if missing
./Scripts/install_git_hooks.sh
```

### Bypass Hook Temporarily

```bash
git commit --no-verify
```

---

## Optional: Advanced Setup

### Xcode Build Phase

Auto-verify on every build:

1. Open Xcode
2. CraigOTerminator target → Build Phases
3. + → New Run Script Phase
4. Add: `"${PROJECT_DIR}/../Scripts/xcode_build_phase.sh"`
5. Move before "Compile Sources"

### CI/CD Integration

Add to GitHub Actions:

```yaml
- name: Verify Xcode Sync
  run: ./TerminatorEdition/Scripts/ci_verify_sync.sh
```

---

## Need More Info?

See full documentation: [`XCODE_AUTO_SYNC.md`](./XCODE_AUTO_SYNC.md)

---

**You're all set! 🎉**

The system will now keep your Xcode project in sync automatically.
