# Xcode Project Auto-Sync

This project uses **XcodeGen** to automatically keep the Xcode project file in sync with source files. This means you never have to manually add files to Xcode!

## Quick Start

### First Time Setup

Run the setup script to configure automatic syncing:

```bash
./setup-auto-sync.sh
```

This will:
- Install git hooks for automatic syncing
- Make all scripts executable
- Check and optionally install dependencies

That's it! Your project will now auto-sync with git operations.

---

## How It Works

### 1. Git Hooks (Automatic - Recommended) ✅

**Already enabled after running setup!**

The project will automatically sync when you:
- Pull changes: `git pull`
- Merge branches: `git merge`
- Switch branches: `git checkout`

The hooks check if any `.swift` files or `project.yml` changed, and only sync if needed.

**Location:** `.git-hooks/post-merge` and `.git-hooks/post-checkout`

**Disable git hooks:**
```bash
git config --unset core.hooksPath
```

**Re-enable git hooks:**
```bash
git config core.hooksPath .git-hooks
```

---

### 2. Manual Sync (When Needed)

If you add/remove files outside of git operations, sync manually:

```bash
# Using Make
make sync

# Or use the script directly
./sync-xcode-project.sh
```

**When to use:**
- You created new Swift files in Finder or terminal
- You deleted files outside of git
- You want to force a project refresh

---

### 3. File Watcher (Real-time - Optional)

For active development where you're frequently adding files, use the file watcher:

```bash
./watch-and-sync.sh
```

This script:
- Monitors the `Craig-O-Clean/` directory for new/deleted Swift files
- Automatically syncs the Xcode project in real-time
- Uses debouncing to avoid excessive syncs
- Runs in the foreground (keep terminal open)

**When to use:**
- You're actively creating many new files
- You're refactoring and moving files around
- You want immediate feedback in Xcode

**Stop the watcher:** Press `Ctrl+C`

**Requirements:** Needs `fswatch` installed
```bash
brew install fswatch
```

---

## Understanding XcodeGen

### What is XcodeGen?

XcodeGen generates your Xcode project from a YAML specification file (`project.yml`). This means:

- The `.xcodeproj` file is **generated**, not manually edited
- All source files are automatically discovered
- No more merge conflicts in project files
- Consistent project structure for the team

### Project Configuration

The project structure is defined in `project.yml`:

```yaml
name: Craig-O-Clean
targets:
  Craig-O-Clean:
    sources:
      - path: Craig-O-Clean
        excludes:
          - "Tests/**"
          - "Preview Content/**"
```

When you run `xcodegen generate`, it:
1. Scans the `Craig-O-Clean/` directory
2. Finds all Swift files (excluding Tests and Preview Content)
3. Regenerates the Xcode project with all files included
4. Preserves your build settings and configurations

### Adding Files

Just create the file anywhere in `Craig-O-Clean/` and sync:

```bash
# Create a new Swift file
touch Craig-O-Clean/MyNewFeature.swift

# Sync (if git hooks aren't enabled)
make sync

# Or just commit - hooks will auto-sync!
git add Craig-O-Clean/MyNewFeature.swift
git commit -m "Add new feature"
```

The file will automatically appear in Xcode next time you open it!

---

## Troubleshooting

### Files not appearing in Xcode?

1. Check if the file is in an excluded path:
   - `Tests/**` (test files have their own target)
   - `Preview Content/**` (preview assets)
   - `build/**` (build artifacts)

2. Force a sync:
   ```bash
   ./sync-xcode-project.sh
   ```

3. Close and reopen Xcode

### "xcodegen: command not found"

Install XcodeGen:
```bash
# Using Homebrew
brew install xcodegen

# Or using the Makefile
make setup
```

### Git hooks not working?

Check if hooks are configured:
```bash
git config core.hooksPath
```

Should output: `.git-hooks`

If not, run:
```bash
./setup-auto-sync.sh
```

### File watcher not detecting changes?

1. Check if `fswatch` is installed:
   ```bash
   brew install fswatch
   ```

2. Make sure you're running it from the project root

3. Check the script is executable:
   ```bash
   chmod +x watch-and-sync.sh
   ```

### Project regenerated with errors?

1. Check `project.yml` syntax
2. Look at the error message from xcodegen
3. Restore from backup:
   ```bash
   ls -la | grep ".xcodeproj.backup"
   cp -R Craig-O-Clean.xcodeproj.backup-XXXXXX Craig-O-Clean.xcodeproj
   ```

---

## Advanced Usage

### Modifying Project Structure

Edit `project.yml` to change:
- Build settings
- Source paths
- Dependencies
- Schemes
- Code signing

After editing, sync:
```bash
make sync
```

### Custom File Exclusions

Add exclusions to `project.yml`:

```yaml
targets:
  Craig-O-Clean:
    sources:
      - path: Craig-O-Clean
        excludes:
          - "Tests/**"
          - "Preview Content/**"
          - "Legacy/**"           # Add custom exclusions
          - "*.backup.swift"      # Exclude patterns
```

### Multiple Targets

The project has three targets defined:
1. **Craig-O-Clean** - Main app
2. **Craig-O-CleanTests** - Unit tests
3. **Craig-O-CleanUITests** - UI tests

Files are automatically assigned based on path:
- `Craig-O-Clean/*.swift` → Craig-O-Clean
- `Craig-O-Clean/Tests/Craig-O-CleanTests/*.swift` → Craig-O-CleanTests
- `Craig-O-Clean/Tests/Craig-O-CleanUITests/*.swift` → Craig-O-CleanUITests

---

## Commands Reference

| Command | Description |
|---------|-------------|
| `./setup-auto-sync.sh` | Initial setup (run once) |
| `make sync` | Manually sync project |
| `./sync-xcode-project.sh` | Manually sync (alternative) |
| `./watch-and-sync.sh` | Start file watcher |
| `make setup` | Install all dev dependencies |

---

## Files Overview

```
Craig-O-Cleaner/
├── project.yml                    # XcodeGen configuration
├── setup-auto-sync.sh            # Setup script
├── sync-xcode-project.sh         # Manual sync script
├── watch-and-sync.sh             # File watcher script
├── .git-hooks/
│   ├── post-merge                # Auto-sync after pull/merge
│   └── post-checkout             # Auto-sync after checkout
├── Craig-O-Clean.xcodeproj/      # Generated (don't edit manually)
└── Craig-O-Clean/                # Source files
    ├── *.swift                   # Automatically included
    ├── Core/                     # Automatically included
    ├── UI/                       # Automatically included
    └── Tests/                    # Separate test targets
```

---

## Best Practices

1. **Never manually edit `.xcodeproj`** - All changes will be overwritten
2. **Edit `project.yml` instead** - This is the source of truth
3. **Let git hooks handle syncing** - They work automatically
4. **Use file watcher for heavy refactoring** - Real-time feedback
5. **Commit `project.yml`** - Share configuration with team
6. **Don't commit `.xcodeproj` to git** - It's generated (optional)

---

## Why Auto-Sync?

Traditional Xcode workflow:
1. Create file in Finder ❌
2. Open Xcode ❌
3. Right-click project ❌
4. Select "Add Files to Project" ❌
5. Navigate to file ❌
6. Click Add ❌
7. Fix merge conflicts in .xcodeproj ❌😭

With Auto-Sync:
1. Create file anywhere ✅
2. Sync happens automatically ✅😎

---

## Resources

- [XcodeGen Documentation](https://github.com/yonaskolb/XcodeGen)
- [fswatch Documentation](https://github.com/emcrisostomo/fswatch)
- [Git Hooks Documentation](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)

---

**Questions or Issues?**

Check the troubleshooting section above or open an issue!
