#!/usr/bin/env python3
"""
Xcode Project Sync Script (Python)
Automatically syncs Swift files with Xcode project using pbxproj library
"""

import os
import sys
import glob
from pathlib import Path
from datetime import datetime

try:
    from pbxproj import XcodeProject
except ImportError:
    print("❌ Error: pbxproj library not installed")
    print("")
    print("Install it with:")
    print("  pip3 install pbxproj")
    print("")
    sys.exit(1)

# Configuration
PROJECT_NAME = "Craig-O-Clean"
PROJECT_FILE = f"{PROJECT_NAME}.xcodeproj/project.pbxproj"
SOURCE_DIR = PROJECT_NAME
EXCLUDE_PATTERNS = [
    "*.backup",
    ".DS_Store",
    "Preview Content/*",
    "*.plist",
    "*.entitlements"
]

class Colors:
    GREEN = '\033[0;32m'
    RED = '\033[0;31m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'

def print_colored(color, symbol, message):
    print(f"{color}{symbol} {message}{Colors.NC}")

def print_success(msg):
    print_colored(Colors.GREEN, "✅", msg)

def print_error(msg):
    print_colored(Colors.RED, "❌", msg)

def print_warning(msg):
    print_colored(Colors.YELLOW, "⚠️ ", msg)

def print_info(msg):
    print_colored(Colors.BLUE, "ℹ️ ", msg)

def should_exclude(file_path):
    """Check if file should be excluded based on patterns"""
    for pattern in EXCLUDE_PATTERNS:
        if Path(file_path).match(pattern):
            return True
    return False

def get_disk_files(source_dir):
    """Get all Swift files from disk"""
    files = set()
    pattern = f"{source_dir}/**/*.swift"

    for file_path in glob.glob(pattern, recursive=True):
        if not should_exclude(file_path):
            files.add(file_path)

    return files

def get_project_files(project):
    """Get all Swift files currently in project"""
    files = set()

    for item in project.objects.get_objects_in_section('PBXFileReference'):
        if item.get('path', '').endswith('.swift'):
            # Try to reconstruct full path
            path = item.get('path')
            if path:
                full_path = os.path.join(SOURCE_DIR, os.path.basename(path))
                if os.path.exists(full_path):
                    files.add(full_path)

    return files

def add_file_to_project(project, file_path):
    """Add a file to the Xcode project"""
    try:
        # Get the target
        targets = project.objects.get_targets()
        if not targets:
            print_error("No targets found in project")
            return False

        target = targets[0]

        # Add file
        project.add_file(file_path, parent=project.get_or_create_group(SOURCE_DIR))

        # Add to build phase
        if file_path.endswith('.swift'):
            project.add_file_to_build_phase(file_path, target)

        return True
    except Exception as e:
        print_warning(f"Could not add {file_path}: {str(e)}")
        return False

def remove_file_from_project(project, file_path):
    """Remove a file from the Xcode project"""
    try:
        project.remove_file(file_path)
        return True
    except Exception as e:
        print_warning(f"Could not remove {file_path}: {str(e)}")
        return False

def backup_project():
    """Create a backup of the project file"""
    if os.path.exists(PROJECT_FILE):
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        backup_file = f"{PROJECT_FILE}.backup-{timestamp}"

        import shutil
        shutil.copy2(PROJECT_FILE, backup_file)
        print_info(f"Backed up project to {backup_file}")

def cleanup_old_backups():
    """Keep only the last 5 backups"""
    backup_pattern = f"{PROJECT_FILE}.backup-*"
    backups = sorted(glob.glob(backup_pattern), reverse=True)

    if len(backups) > 5:
        print_info("Cleaning up old backups (keeping last 5)...")
        for old_backup in backups[5:]:
            os.remove(old_backup)
            print_info(f"Removed old backup: {old_backup}")

def main():
    print("")
    print("╔════════════════════════════════════════════════════════╗")
    print("║     Xcode Project Sync - Craig-O-Clean (Python)       ║")
    print("╚════════════════════════════════════════════════════════╝")
    print("")

    # Check if project exists
    if not os.path.exists(PROJECT_FILE):
        print_error(f"Project file not found: {PROJECT_FILE}")
        sys.exit(1)

    # Check if source directory exists
    if not os.path.exists(SOURCE_DIR):
        print_error(f"Source directory not found: {SOURCE_DIR}")
        sys.exit(1)

    print_info(f"Source directory: {SOURCE_DIR}")
    print_info(f"Project file: {PROJECT_FILE}")
    print("")

    # Backup project
    backup_project()

    # Load project
    print_info("Loading Xcode project...")
    try:
        project = XcodeProject.load(PROJECT_FILE)
    except Exception as e:
        print_error(f"Failed to load project: {str(e)}")
        sys.exit(1)

    # Get files
    disk_files = get_disk_files(SOURCE_DIR)
    project_files = get_project_files(project)

    print_info(f"Found {len(disk_files)} Swift files on disk")
    print_info(f"Found {len(project_files)} Swift files in project")
    print("")

    # Find differences
    files_to_add = disk_files - project_files
    files_to_remove = project_files - disk_files

    added_count = 0
    removed_count = 0

    # Add new files
    if files_to_add:
        print_info(f"Adding {len(files_to_add)} new files...")
        for file_path in sorted(files_to_add):
            if add_file_to_project(project, file_path):
                print_success(f"Added: {os.path.basename(file_path)}")
                added_count += 1

    # Remove deleted files
    if files_to_remove:
        print_info(f"Removing {len(files_to_remove)} deleted files...")
        for file_path in sorted(files_to_remove):
            if remove_file_from_project(project, file_path):
                print_colored(Colors.RED, "🗑️ ", f"Removed: {os.path.basename(file_path)}")
                removed_count += 1

    # Save if changes were made
    if added_count > 0 or removed_count > 0:
        print("")
        print_info("Saving project...")
        project.save()

        print("")
        print("=" * 60)
        print("📊 Sync Summary")
        print("=" * 60)
        print(f"✅ Added files:   {added_count}")
        print(f"🗑️  Removed files: {removed_count}")
        print("=" * 60)
        print("")

        print_success("Project saved successfully!")

        # Cleanup old backups
        cleanup_old_backups()
    else:
        print_success("Project is already in sync!")

    print("")
    print("🎉 Done!")
    print("")

if __name__ == "__main__":
    main()
