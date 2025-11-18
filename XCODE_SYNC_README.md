# Xcode Project Sync Scripts

Automatically synchronize your Xcode project with files in your repository. These scripts add new files and remove deleted files from the Xcode project automatically.

## 🎯 Purpose

When working with Xcode projects in version control, manually adding/removing files from the `.xcodeproj` can be tedious and error-prone. These scripts automate the process by:

- ✅ **Adding** new Swift files found in your source directory
- 🗑️ **Removing** references to deleted files
- 📦 **Organizing** files into proper groups
- 💾 **Backing up** your project before making changes
- 🧹 **Cleaning up** old backups automatically

## 📋 Three Methods Available

### Method 1: Ruby Script (Most Powerful) ⭐️

Uses the `xcodeproj` gem to directly manipulate the project file.

**Pros:**
- Most control over project structure
- Can handle complex scenarios
- Preserves existing project settings
- Fast and reliable

**Cons:**
- Requires Ruby and xcodeproj gem

### Method 2: Shell Script with xcodegen (Recommended for Teams)

Regenerates the entire project from a YAML configuration.

**Pros:**
- Simple and predictable
- Great for team consistency
- Easy to version control project structure
- No manual Xcode configuration needed

**Cons:**
- Regenerates entire project (loses some manual customizations)
- Requires xcodegen installation

### Method 3: Python Script

Uses pbxproj library to manipulate project files.

**Pros:**
- Python is commonly available
- Good for Python-based toolchains
- Cross-platform

**Cons:**
- Requires Python 3 and pbxproj library
- Less mature than Ruby solution

---

## 🚀 Quick Start

### Option A: Ruby Script (Recommended)

```bash
# Install dependencies
gem install xcodeproj

# Make executable
chmod +x sync-xcode-project.rb

# Run
./sync-xcode-project.rb
```

### Option B: Shell Script with xcodegen

```bash
# Install xcodegen
brew install xcodegen

# Make executable
chmod +x sync-xcode-project.sh

# Run
./sync-xcode-project.sh
```

### Option C: Python Script

```bash
# Install dependencies
pip3 install pbxproj

# Make executable
chmod +x sync-xcode-project.py

# Run
./sync-xcode-project.py
```

---

## 📖 Detailed Usage

### Ruby Script

```bash
# Basic usage
./sync-xcode-project.rb

# The script will:
# 1. Scan Craig-O-Clean/ directory for .swift files
# 2. Compare with files in Craig-O-Clean.xcodeproj
# 3. Add missing files to project
# 4. Remove references to deleted files
# 5. Save the project

# Output example:
# 📦 Syncing Xcode project: Craig-O-Clean.xcodeproj
# 📁 Source directory: Craig-O-Clean
# 🎯 Target: Craig-O-Clean
#
# ✅ Added: SystemCPUMonitorView.swift
# ✅ Added: ProcessDetailsView.swift
# 🗑️  Removed: OldFile.swift
#
# ✅ Project saved successfully!
```

**Configuration** (edit script to customize):
```ruby
# Change these in the script:
PROJECT_NAME = 'Craig-O-Clean'        # Your project name
SOURCE_DIR = PROJECT_NAME              # Source directory
EXCLUDE_PATTERNS = [                   # Files to ignore
  /\.backup$/,
  /\.DS_Store$/,
  /^\.git/
]
```

### Shell Script (xcodegen)

```bash
# First run generates project.yml
./sync-xcode-project.sh

# Edit project.yml to customize settings
vim project.yml

# Run again to regenerate project
./sync-xcode-project.sh
```

**project.yml** will be auto-generated with:
- Project name and bundle ID
- macOS deployment target
- Source file locations
- Build settings
- Schemes

### Python Script

```bash
# Run with Python 3
python3 sync-xcode-project.py

# Or make executable and run directly
chmod +x sync-xcode-project.py
./sync-xcode-project.py
```

---

## 🔧 Advanced Usage

### Automated Sync with Git Hooks

Add to `.git/hooks/post-checkout`:

```bash
#!/bin/bash
# Auto-sync Xcode project after checkout

echo "Syncing Xcode project..."
./sync-xcode-project.rb || true
```

Make executable:
```bash
chmod +x .git/hooks/post-checkout
```

### Pre-commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Ensure project is synced before commit

./sync-xcode-project.rb
git add *.xcodeproj/project.pbxproj
```

### CI/CD Integration

Add to your CI pipeline (GitHub Actions example):

```yaml
- name: Sync Xcode Project
  run: |
    gem install xcodeproj
    ./sync-xcode-project.rb

- name: Verify Project
  run: |
    xcodebuild -list -project Craig-O-Clean.xcodeproj
```

---

## 📝 Makefile Integration

Create a `Makefile`:

```makefile
.PHONY: sync-project sync-ruby sync-xcodegen sync-python

sync-project: sync-ruby

sync-ruby:
	@echo "Syncing with Ruby script..."
	@./sync-xcode-project.rb

sync-xcodegen:
	@echo "Syncing with xcodegen..."
	@./sync-xcode-project.sh

sync-python:
	@echo "Syncing with Python script..."
	@./sync-xcode-project.py

install-deps-ruby:
	gem install xcodeproj

install-deps-xcodegen:
	brew install xcodegen

install-deps-python:
	pip3 install pbxproj

clean-backups:
	find . -name "*.xcodeproj.backup-*" -exec rm -rf {} +
```

Usage:
```bash
make sync-project          # Use Ruby script
make sync-xcodegen         # Use xcodegen
make install-deps-ruby     # Install Ruby dependencies
make clean-backups         # Remove old backups
```

---

## 🛡️ Safety Features

All scripts include:

1. **Automatic Backups**
   - Creates timestamped backup before changes
   - Format: `Craig-O-Clean.xcodeproj.backup-20250118-143022`

2. **Backup Rotation**
   - Keeps last 5 backups
   - Automatically deletes older backups

3. **Validation**
   - Checks if project exists
   - Verifies source directory
   - Validates file types

4. **Rollback**
   ```bash
   # If something goes wrong, restore from backup:
   rm -rf Craig-O-Clean.xcodeproj
   cp -R Craig-O-Clean.xcodeproj.backup-TIMESTAMP Craig-O-Clean.xcodeproj
   ```

---

## 🎨 File Type Support

### Ruby Script
- `.swift` - Source files
- `.h` - Headers
- `.m`, `.mm` - Objective-C/C++
- `.c`, `.cpp` - C/C++
- `.metal` - Metal shaders
- `.xib`, `.storyboard` - Interface files
- `.mlmodel` - Core ML models

### All Scripts
Automatically exclude:
- `.backup` files
- `.DS_Store`
- Preview Content
- `.plist` files (handled separately)
- `.entitlements` files (handled separately)

---

## 🐛 Troubleshooting

### "xcodeproj gem not installed"

```bash
gem install xcodeproj
```

### "xcodegen not found"

```bash
brew install xcodegen
# or
mint install yonaskolb/XcodeGen
```

### "pbxproj library not installed"

```bash
pip3 install pbxproj
```

### Permission Denied

```bash
chmod +x sync-xcode-project.rb
chmod +x sync-xcode-project.sh
chmod +x sync-xcode-project.py
```

### Project Won't Open in Xcode

1. Restore from backup:
   ```bash
   cp -R Craig-O-Clean.xcodeproj.backup-LATEST Craig-O-Clean.xcodeproj
   ```

2. Try manual fix:
   ```bash
   rm -rf Craig-O-Clean.xcodeproj/xcuserdata
   rm -rf Craig-O-Clean.xcodeproj/project.xcworkspace
   ```

### Files Added But Not Showing in Xcode

1. Close Xcode
2. Run sync script
3. Clean build folder:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. Open Xcode

---

## 🔄 Workflow Recommendations

### Daily Development

```bash
# Morning: Pull latest changes
git pull
./sync-xcode-project.rb

# During work: Add files normally in Xcode
# Xcode automatically updates project file

# End of day: Commit
git add .
git commit -m "Your changes"
git push
```

### After Merging Branches

```bash
git merge feature-branch
./sync-xcode-project.rb  # Sync any new files
```

### Team Collaboration

```bash
# Use xcodegen for consistency
./sync-xcode-project.sh

# Commit project.yml instead of .xcodeproj
git add project.yml
git commit -m "Update project structure"

# Others regenerate on pull
git pull
./sync-xcode-project.sh
```

---

## 📊 Comparison Table

| Feature | Ruby Script | xcodegen | Python Script |
|---------|------------|----------|---------------|
| **Setup Complexity** | Medium | Low | Medium |
| **Preserves Settings** | ✅ Yes | ❌ No (regenerates) | ✅ Yes |
| **Team Friendly** | ✅ Yes | ✅✅ Best | ✅ Yes |
| **Speed** | Fast | Medium | Fast |
| **Customization** | High | Medium | Medium |
| **Reliability** | ✅✅ Best | ✅ Good | ✅ Good |
| **Dependencies** | Ruby gem | Homebrew | Python pip |

---

## 🎯 Recommended Choice

- **Solo Developer**: Ruby script (most reliable, preserves settings)
- **Small Team**: xcodegen (consistent project generation)
- **Large Team**: xcodegen + version controlled project.yml
- **CI/CD**: Ruby script (fast, scriptable)
- **Python Codebase**: Python script (consistent tooling)

---

## 📚 Additional Resources

- [xcodeproj gem](https://github.com/CocoaPods/Xcodeproj)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- [pbxproj Python](https://github.com/kronenthaler/mod-pbxproj)

---

## 🤝 Contributing

To add support for more file types, edit the `FILE_TYPES` hash in the Ruby script:

```ruby
FILE_TYPES = {
  '.swift' => :source,
  '.h' => :header,
  '.m' => :source,
  '.yourext' => :source  # Add your type here
}
```

---

## 📄 License

These scripts are provided as-is for the Craig-O-Clean project. Modify as needed for your projects.
