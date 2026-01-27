# Xcode Project Auto-Sync Setup

## Overview

An automated system has been set up to keep your Xcode project synchronized with all Swift source files. This prevents build errors caused by files not being added to the project.

## What Was Done

### 1. Scripts Created

Three automation scripts have been created in the `scripts/` directory:

#### `verify_xcode_project.sh` (Verification)
- Scans for all Swift files in the project
- Checks which files are missing from the Xcode project
- Returns exit code 0 if all files are included, 1 if any are missing
- **Usage**: `./scripts/verify_xcode_project.sh`

#### `add_files_to_xcode.rb` (Automatic Addition)
- Automatically adds missing Swift files to the Xcode project
- Creates proper group hierarchy matching directory structure
- Asks for confirmation before making changes
- Uses the xcodeproj Ruby gem
- **Usage**: `ruby scripts/add_files_to_xcode.rb`

#### `sync_xcode_project.py` (Python Alternative)
- Python-based alternative with automatic gem installation
- Same functionality as the Ruby script
- **Usage**: `python3 scripts/sync_xcode_project.py`

### 2. Initial Sync Completed

The following 8 files were automatically added to the Xcode project:

1. ✅ `Core/Execution/ExecutionExample.swift`
2. ✅ `Core/Execution/OutputParsers.swift`
3. ✅ `Core/Execution/ProcessRunner.swift`
4. ✅ `Core/Execution/UserExecutor.swift`
5. ✅ `Core/Logging/RunRecord.swift`
6. ✅ `Core/Logging/SQLiteLogStore.swift`
7. ✅ `Tests/CapabilityTests/CatalogLoadingTests.swift`
8. ✅ `Tests/ExecutionTests/ExecutionTests.swift`

### 3. Project Structure Created

New groups were created in the Xcode project:
- `Core/Execution/` - Process execution framework
- `Core/Logging/` - Logging and persistence
- `Tests/ExecutionTests/` - Execution tests
- `Tests/CapabilityTests/` - Already existed, file added

---

## How to Use

### When You Add New Swift Files

**Option 1: Manual Sync (Recommended)**
```bash
# 1. Check for missing files
./scripts/verify_xcode_project.sh

# 2. Add missing files
ruby scripts/add_files_to_xcode.rb

# 3. Commit changes
git add Xcode/CraigOTerminator.xcodeproj/project.pbxproj
git commit -m "Add new files to Xcode project"
```

**Option 2: Using Python**
```bash
python3 scripts/sync_xcode_project.py
```

### Before Building

```bash
# Quick check before building
./scripts/verify_xcode_project.sh && xcodebuild
```

### In CI/CD Pipeline

Add to your CI script:
```bash
# Fail CI if project is out of sync
./scripts/verify_xcode_project.sh || {
  echo "ERROR: Xcode project is out of sync!"
  echo "Run: ruby scripts/add_files_to_xcode.rb"
  exit 1
}
```

---

## Advanced Setup (Optional)

### 1. Git Pre-Commit Hook

Automatically verify on every commit:

Create `.git/hooks/pre-commit`:
```bash
#!/bin/bash
./scripts/verify_xcode_project.sh
if [ $? -ne 0 ]; then
    echo ""
    echo "⚠️  Xcode project is out of sync!"
    echo "Run: ruby scripts/add_files_to_xcode.rb"
    echo ""
    read -p "Commit anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
```

Make executable:
```bash
chmod +x .git/hooks/pre-commit
```

### 2. Xcode Build Phase

Add automatic verification during build:

1. Open Xcode project
2. Select **CraigOTerminator** target
3. Go to **Build Phases** tab
4. Click **+** → **New Run Script Phase**
5. Name it: "Verify Project Files"
6. Add script:
   ```bash
   "${PROJECT_DIR}/../scripts/verify_xcode_project.sh"
   ```
7. Move it before "Compile Sources" phase
8. **Important**: Uncheck "Based on dependency analysis" for it to run every time

This will show a warning during build if files are missing.

### 3. VS Code Task

Add to `.vscode/tasks.json`:
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Sync Xcode Project",
      "type": "shell",
      "command": "ruby scripts/add_files_to_xcode.rb",
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    },
    {
      "label": "Verify Xcode Project",
      "type": "shell",
      "command": "./scripts/verify_xcode_project.sh",
      "problemMatcher": []
    }
  ]
}
```

---

## How It Works

### Detection Process

1. **File Discovery**
   - Recursively scans `Xcode/CraigOTerminator/` directory
   - Finds all `.swift` files
   - Excludes build directories (`.build/`, `build/`, `DerivedData/`)

2. **Project Analysis**
   - Parses `project.pbxproj` file
   - Extracts all currently referenced Swift files
   - Compares filesystem vs. project references

3. **Smart Matching**
   - Checks both full paths and filenames
   - Handles files moved between directories
   - Prevents duplicate additions

### Addition Process

1. **Group Creation**
   - Analyzes file's directory path
   - Creates nested groups matching directory structure
   - Reuses existing groups when possible

2. **File Reference**
   - Adds file reference to appropriate group
   - Links file to main target
   - Preserves existing project settings

3. **Project Save**
   - Updates `project.pbxproj` file
   - Maintains Xcode compatibility
   - Preserves all other project settings

---

## Troubleshooting

### "xcodeproj gem not found"

Install the gem:
```bash
sudo gem install xcodeproj
```

### "Permission denied"

Make scripts executable:
```bash
chmod +x scripts/*.sh scripts/*.rb scripts/*.py
```

### Files Added to Wrong Group

The scripts automatically place files in groups matching their directory structure. If you need custom organization:

1. Let the script add the files
2. Manually reorganize in Xcode
3. The files will remain linked to the target

### Duplicate File Warnings

If Xcode shows duplicate file warnings:

1. Open Xcode
2. Select the duplicate file
3. Check the file's group location
4. Remove one reference (keep the one in the correct group)

### Script Hangs or Fails

1. Ensure no other process has the project file open
2. Close Xcode before running the script
3. Check that you have write permissions to the project file
4. Try the Python version if Ruby version fails: `python3 scripts/sync_xcode_project.py`

---

## Maintenance

### Keep Scripts Updated

The scripts are designed to be maintenance-free, but you may want to update them if:

- You change the project structure significantly
- You want to add support for additional file types
- You want to customize group organization rules

### Regular Verification

Good practice:
```bash
# Before each build
./scripts/verify_xcode_project.sh

# After pulling changes
git pull && ./scripts/verify_xcode_project.sh

# Before creating a release
./scripts/verify_xcode_project.sh && ruby scripts/add_files_to_xcode.rb
```

---

## Benefits

### ✅ Prevents Build Errors
No more "file not found" errors due to missing project references

### ✅ Saves Time
Automatic addition instead of manual drag-and-drop

### ✅ Consistency
Ensures all team members have the same project structure

### ✅ CI/CD Ready
Can be integrated into automated build pipelines

### ✅ Safe
Always asks for confirmation before making changes

---

## What's Next

### Recommended Workflow

1. **When starting work**:
   ```bash
   ./scripts/verify_xcode_project.sh
   ```

2. **After adding new files**:
   ```bash
   ruby scripts/add_files_to_xcode.rb
   ```

3. **Before committing**:
   ```bash
   ./scripts/verify_xcode_project.sh
   git add Xcode/CraigOTerminator.xcodeproj/project.pbxproj
   git commit -m "Add new files to Xcode project"
   ```

4. **Before building**:
   ```bash
   ./scripts/verify_xcode_project.sh && xcodebuild
   ```

### Consider Adding

- [ ] Pre-commit git hook for automatic verification
- [ ] Xcode build phase for build-time warnings
- [ ] CI/CD integration to catch issues early
- [ ] VS Code tasks for quick access

---

## Files Modified

The following files were created or modified:

### Created
- ✅ `scripts/verify_xcode_project.sh` - Verification script
- ✅ `scripts/add_files_to_xcode.rb` - Automatic addition script
- ✅ `scripts/sync_xcode_project.py` - Python alternative
- ✅ `scripts/README.md` - Detailed documentation
- ✅ `XCODE_AUTO_SYNC_SETUP.md` - This file

### Modified
- ✅ `Xcode/CraigOTerminator.xcodeproj/project.pbxproj` - Added 8 new file references

---

## Questions?

### How often should I run the sync?

Run verification (`verify_xcode_project.sh`) frequently, especially:
- Before building
- After pulling changes
- Before creating pull requests

Run addition (`add_files_to_xcode.rb`) only when verification reports missing files.

### Will this work with Xcode open?

Yes, but it's recommended to:
1. Save all changes in Xcode
2. Close the project
3. Run the script
4. Reopen in Xcode

Xcode will detect the changes and reload the project.

### What if I rename or move files?

The scripts detect new files, but don't handle renames/moves. For those:
1. Use Xcode's built-in rename/move features, OR
2. Rename/move in Finder, then run the script to add the "new" file and remove the old reference in Xcode

### Can I customize which files are added?

Currently, all `.swift` files are added to the main target. To customize:
1. Edit the Ruby script's filtering logic
2. Manually adjust target membership in Xcode after running the script

---

**Last Updated**: January 27, 2026
**Status**: ✅ Operational - All files synced
**Next Steps**: Consider adding git hooks or Xcode build phase for automation
