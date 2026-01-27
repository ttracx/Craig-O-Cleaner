# Xcode Project Sync Scripts

This directory contains automation scripts to keep your Xcode project synchronized with all source files.

## Scripts

### 1. `verify_xcode_project.sh`
**Purpose**: Check which Swift files are missing from the Xcode project.

**Usage**:
```bash
./scripts/verify_xcode_project.sh
```

**Output**:
- ✅ Success if all files are included
- ⚠️ Warning with list of missing files if any are found

---

### 2. `add_files_to_xcode.rb`
**Purpose**: Automatically add missing Swift files to the Xcode project.

**Requirements**:
- Ruby (pre-installed on macOS)
- xcodeproj gem

**Installation**:
```bash
sudo gem install xcodeproj
```

**Usage**:
```bash
ruby scripts/add_files_to_xcode.rb
```

**Features**:
- Scans entire project directory for Swift files
- Compares with files already in project
- Asks for confirmation before making changes
- Creates proper group hierarchy in Xcode
- Adds files to the appropriate target

---

### 3. `sync_xcode_project.py`
**Purpose**: Python-based alternative for adding files (with automatic gem installation).

**Requirements**:
- Python 3
- Will automatically offer to install xcodeproj gem if needed

**Usage**:
```bash
python3 scripts/sync_xcode_project.py
```

---

## Quick Start

### First Time Setup

1. **Install xcodeproj gem** (required for automatic file addition):
   ```bash
   sudo gem install xcodeproj
   ```

2. **Make scripts executable**:
   ```bash
   chmod +x scripts/*.sh scripts/*.rb scripts/*.py
   ```

### Regular Workflow

When you add new Swift files to your project:

1. **Check for missing files**:
   ```bash
   ./scripts/verify_xcode_project.sh
   ```

2. **Add missing files automatically**:
   ```bash
   ruby scripts/add_files_to_xcode.rb
   ```

   OR

   ```bash
   python3 scripts/sync_xcode_project.py
   ```

3. **Commit the updated project**:
   ```bash
   git add Xcode/CraigOTerminator.xcodeproj/project.pbxproj
   git commit -m "Add new files to Xcode project"
   ```

---

## Adding to Xcode Build Phase (Optional)

You can add automatic verification to your Xcode build process:

1. Open your Xcode project
2. Select the **CraigOTerminator** target
3. Go to **Build Phases**
4. Click **+** and select **New Run Script Phase**
5. Add this script:
   ```bash
   "${PROJECT_DIR}/../scripts/verify_xcode_project.sh"
   ```
6. Move the script phase to run early (before "Compile Sources")

This will warn you during build if any Swift files are missing from the project.

---

## Troubleshooting

### "xcodeproj gem not found"
Install it with:
```bash
sudo gem install xcodeproj
```

### "Permission denied"
Make scripts executable:
```bash
chmod +x scripts/*.sh scripts/*.rb scripts/*.py
```

### Scripts don't detect files
Make sure you're running from the project root directory, or the scripts will handle relative paths automatically.

### Files added to wrong group
The scripts automatically determine the group structure based on the file's directory path. If you need custom organization, manually adjust in Xcode after running the script.

---

## How It Works

### File Detection
1. Scans `Xcode/CraigOTerminator/` directory recursively
2. Finds all `.swift` files
3. Excludes build directories (`.build`, `build`, `DerivedData`)

### Project Analysis
1. Parses `project.pbxproj` file
2. Extracts all currently referenced Swift files
3. Compares filesystem vs. project references

### File Addition
1. Uses xcodeproj Ruby gem to manipulate project
2. Creates group hierarchy matching directory structure
3. Adds file references to appropriate groups
4. Links files to the main target
5. Saves updated project file

---

## Integration with Git Hooks (Optional)

You can automate verification on commit:

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

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

---

## Future Enhancements

Potential improvements to these scripts:

- [ ] Support for resource files (.json, .plist, etc.)
- [ ] Support for test targets
- [ ] Automatic target assignment based on file location
- [ ] Configuration file for custom rules
- [ ] Integration with CI/CD pipelines
- [ ] Support for Swift Package Manager integration

---

## Support

For issues or questions:
1. Check script output for specific error messages
2. Verify xcodeproj gem is installed: `gem list xcodeproj`
3. Ensure you have write permissions to the project file
4. Try running scripts with `--verbose` flag (if implemented)

---

**Last Updated**: January 2026
**Maintained By**: Craig-O-Cleaner Development Team
