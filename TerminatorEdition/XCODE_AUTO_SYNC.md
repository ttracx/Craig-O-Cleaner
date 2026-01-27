# Xcode Auto-Sync System 🔄

Comprehensive automated synchronization system to keep your Xcode project in sync with Swift source files.

## 📋 Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Automation Options](#automation-options)
- [Scripts Reference](#scripts-reference)
- [Integration Guides](#integration-guides)
- [Troubleshooting](#troubleshooting)

---

## Overview

This system ensures your Xcode project (`CraigOTerminator.xcodeproj`) always includes all Swift files from your source directory, preventing build errors and missing file issues.

### ✨ Features

- **Automatic Detection**: Scans for new, moved, or renamed Swift files
- **Smart Grouping**: Mirrors directory structure in Xcode groups
- **Test Exclusion**: Optionally excludes test files (when no test target exists)
- **Git Integration**: Pre-commit, pre-push, and post-merge hooks
- **CI/CD Ready**: Scripts for automated verification in pipelines
- **Watch Mode**: Continuous monitoring and auto-sync
- **Non-Interactive**: Works in automated environments

---

## Quick Start

### 1. Verify Current State

```bash
cd TerminatorEdition
./Scripts/verify_xcode_project.sh
```

### 2. Sync Missing Files

```bash
ruby Scripts/sync_xcode_auto.rb --exclude-tests
```

### 3. Install Git Hooks (Recommended)

```bash
./Scripts/install_git_hooks.sh
```

Done! Your project will now auto-verify on every commit.

---

## Automation Options

Choose the automation level that fits your workflow:

### Option 1: Manual (Default)

Run sync script when needed:

```bash
ruby Scripts/sync_xcode_auto.rb --exclude-tests
```

**Best for**: Small teams, infrequent changes

### Option 2: Git Hooks (Recommended)

Auto-verify on commits and pushes:

```bash
./Scripts/install_git_hooks.sh
```

**Best for**: Most development workflows

**Hooks installed**:
- `pre-commit`: Blocks commits if project is out of sync
- `pre-push`: Final verification before pushing
- `post-merge`: Alerts you after pulling changes

### Option 3: Xcode Build Phase

Add verification to every build:

1. Open `CraigOTerminator.xcodeproj` in Xcode
2. Select **CraigOTerminator** target
3. **Build Phases** → **+** → **New Run Script Phase**
4. Drag it **before** "Compile Sources"
5. Add this script:
   ```bash
   "${PROJECT_DIR}/../Scripts/xcode_build_phase.sh"
   ```

**Best for**: Ensuring builds always use latest files

### Option 4: Watch Mode

Continuous monitoring with auto-sync:

```bash
./Scripts/watch_and_sync.sh
```

**Best for**: Active development sessions

Requires `fswatch`:
```bash
brew install fswatch
```

### Option 5: CI/CD Integration

Add to your CI pipeline:

```bash
./Scripts/ci_verify_sync.sh
```

**Best for**: Team projects with automated testing

---

## Scripts Reference

### Core Scripts

#### `verify_xcode_project.sh`

Checks if all Swift files are in the Xcode project.

```bash
./Scripts/verify_xcode_project.sh [--quiet]
```

**Options**:
- `--quiet`, `-q`: Minimal output (for automation)

**Exit Codes**:
- `0`: All files in sync
- `1`: Missing files found

**Example**:
```bash
# Detailed output
./Scripts/verify_xcode_project.sh

# Quiet mode for scripts
./Scripts/verify_xcode_project.sh --quiet
if [ $? -eq 0 ]; then
    echo "Project is synced"
fi
```

---

#### `sync_xcode_auto.rb`

Automatically adds missing Swift files to Xcode project.

```bash
ruby Scripts/sync_xcode_auto.rb [options]
```

**Options**:
- `-d, --dry-run`: Show what would be added without making changes
- `-v, --verbose`: Show detailed output
- `-t, --exclude-tests`: Skip test files (recommended until test target exists)
- `-h, --help`: Show help message

**Examples**:
```bash
# Standard sync (excluding tests)
ruby Scripts/sync_xcode_auto.rb --exclude-tests

# Preview changes without applying
ruby Scripts/sync_xcode_auto.rb --dry-run

# Verbose output for debugging
ruby Scripts/sync_xcode_auto.rb --verbose --exclude-tests
```

**What it does**:
1. Scans source directory for Swift files
2. Compares with Xcode project references
3. Creates missing group hierarchy
4. Adds file references to project
5. Links files to build target
6. Saves `project.pbxproj`

---

### Automation Scripts

#### `install_git_hooks.sh`

Installs Git hooks for automatic verification.

```bash
./Scripts/install_git_hooks.sh
```

**Installs**:
- `pre-commit`: Verifies sync before commits
- `pre-push`: Final check before pushing
- `post-merge`: Alerts after pulls/merges

**To uninstall**:
```bash
rm .git/hooks/pre-commit
rm .git/hooks/pre-push
rm .git/hooks/post-merge
```

**To bypass temporarily**:
```bash
git commit --no-verify
```

---

#### `watch_and_sync.sh`

Monitors source directory and auto-syncs on changes.

```bash
./Scripts/watch_and_sync.sh
```

**Requirements**:
- `fswatch` (install via `brew install fswatch`)

**Features**:
- Monitors for file creation, deletion, renaming
- Debounces rapid changes (2 second delay)
- Shows real-time sync status
- Excludes build directories

**Usage**:
```bash
# Start watching (Ctrl+C to stop)
./Scripts/watch_and_sync.sh
```

---

#### `xcode_build_phase.sh`

Xcode build phase script for build-time verification.

```bash
"${PROJECT_DIR}/../Scripts/xcode_build_phase.sh"
```

**To add to Xcode**:
1. Target → Build Phases → + → New Run Script Phase
2. Paste the script path above
3. Move before "Compile Sources"

**Behavior**:
- Runs before every build
- Fails build if project is out of sync
- Shows clear error message with fix instructions

---

#### `ci_verify_sync.sh`

CI/CD verification script for automated pipelines.

```bash
./Scripts/ci_verify_sync.sh
```

**Features**:
- Auto-installs `xcodeproj` gem if needed
- Clear pass/fail reporting
- Helpful error messages
- Works in non-interactive environments

**Example GitHub Actions**:
```yaml
- name: Verify Xcode Sync
  run: ./TerminatorEdition/Scripts/ci_verify_sync.sh
```

---

## Integration Guides

### GitHub Actions

Create `.github/workflows/xcode-sync.yml`:

```yaml
name: Xcode Project Sync Check

on: [push, pull_request]

jobs:
  verify-sync:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v3

      - name: Install xcodeproj gem
        run: gem install xcodeproj

      - name: Verify Xcode project sync
        run: ./TerminatorEdition/Scripts/ci_verify_sync.sh
```

### GitLab CI

Add to `.gitlab-ci.yml`:

```yaml
verify-xcode-sync:
  stage: test
  image: macos
  script:
    - gem install xcodeproj
    - ./TerminatorEdition/Scripts/ci_verify_sync.sh
```

### Jenkins

```groovy
stage('Verify Xcode Sync') {
    steps {
        sh 'gem install xcodeproj'
        sh './TerminatorEdition/Scripts/ci_verify_sync.sh'
    }
}
```

---

## Troubleshooting

### Common Issues

#### "xcodeproj gem not found"

**Solution**:
```bash
sudo gem install xcodeproj
```

Or without sudo (user install):
```bash
gem install xcodeproj --user-install
```

#### "Permission denied"

**Solution**:
```bash
chmod +x Scripts/*.sh Scripts/*.rb
```

#### Verification passes but Xcode shows missing files

**Cause**: Xcode cache issue

**Solution**:
1. Close Xcode completely
2. Run sync script
3. Clean build folder: Xcode → Product → Clean Build Folder
4. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/CraigOTerminator-*
   ```
5. Reopen project

#### Git hooks not running

**Check installation**:
```bash
ls -la .git/hooks/
```

Should show:
- `pre-commit` (executable)
- `pre-push` (executable)
- `post-merge` (executable)

**Reinstall**:
```bash
./Scripts/install_git_hooks.sh
```

#### Test files cause errors

**Solution**: Use `--exclude-tests` flag until test target is created:
```bash
ruby Scripts/sync_xcode_auto.rb --exclude-tests
```

**To create test target**:
1. Xcode → File → New → Target
2. Choose "Unit Testing Bundle"
3. Name it "CraigOTerminatorTests"
4. Update sync script to add test files to test target

#### Watch mode: "fswatch not found"

**Solution**:
```bash
brew install fswatch
```

Or with MacPorts:
```bash
sudo port install fswatch
```

---

## Advanced Usage

### Custom Exclusions

Edit `sync_xcode_auto.rb` to exclude specific patterns:

```ruby
def find_swift_files(project_dir, exclude_tests: false)
  swift_files = Set.new

  Dir.glob("#{project_dir}/**/*.swift").each do |file|
    # Add custom exclusions here
    next if file.include?('/Deprecated/')
    next if file.include?('/Generated/')

    # ... rest of method
  end
end
```

### Running Sync on Schedule

Use cron or launchd to run periodic syncs:

**Cron example** (every hour during work hours):
```bash
crontab -e
```

Add:
```
0 9-17 * * 1-5 cd /path/to/Craig-O-Cleaner/TerminatorEdition && ruby Scripts/sync_xcode_auto.rb --exclude-tests
```

### Verbose Logging

For debugging, enable verbose mode:

```bash
ruby Scripts/sync_xcode_auto.rb --verbose --exclude-tests 2>&1 | tee sync.log
```

---

## Best Practices

### ✅ Do

- Run verification before commits
- Install git hooks for automatic checking
- Use `--exclude-tests` until test target exists
- Review sync changes before committing
- Keep scripts updated with project changes

### ❌ Don't

- Manually edit `project.pbxproj` (unless necessary)
- Commit out-of-sync projects
- Bypass hooks without good reason
- Add generated/build files to project
- Skip verification in CI/CD

---

## Maintenance

### Updating Scripts

To update scripts to latest version:

```bash
cd TerminatorEdition/Scripts
git pull origin main
chmod +x *.sh *.rb
```

### Monitoring

Check sync status regularly:

```bash
# Quick check
./Scripts/verify_xcode_project.sh --quiet && echo "✅ Synced" || echo "❌ Out of sync"

# Detailed status
./Scripts/verify_xcode_project.sh
```

---

## FAQ

**Q: Do I need to run sync after every file addition?**

A: Not if you have git hooks installed. They'll check automatically on commit.

**Q: What if I want to add files manually in Xcode?**

A: That's fine! The scripts only add *missing* files. Manually added files are preserved.

**Q: Can I use this with multiple Xcode projects?**

A: Yes, but you'll need to modify the scripts to specify which project file to update.

**Q: Does this work with Swift Package Manager?**

A: These scripts are for `.xcodeproj` files. SPM uses `Package.swift` which auto-includes files.

**Q: What about Objective-C files?**

A: Currently Swift-only. Modify `find_swift_files()` to include `.m` and `.h` files if needed.

---

## Support

### Getting Help

1. Check this documentation
2. Run scripts with `--verbose` for detailed output
3. Check script comments for implementation details
4. Review git history for recent changes

### Reporting Issues

When reporting sync issues, include:

1. Output of `./Scripts/verify_xcode_project.sh`
2. Output of `ruby Scripts/sync_xcode_auto.rb --verbose --dry-run`
3. Xcode version
4. macOS version
5. Ruby version (`ruby --version`)

---

## Version History

- **v2.0** - Automated sync system with git hooks, CI/CD, and watch mode
- **v1.0** - Initial manual sync scripts

---

## License

Copyright © 2026 NeuralQuantum.ai / VibeCaaS
Part of Craig-O-Cleaner Terminator Edition

---

**Last Updated**: January 27, 2026
**Maintained By**: VibeCaaS Platform Team
