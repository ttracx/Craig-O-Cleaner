#!/usr/bin/env python3
"""
Xcode Project Sync Tool
Automatically adds missing Swift files to the Xcode project.
"""

import os
import sys
import subprocess
from pathlib import Path
from typing import Set, List, Tuple

# ANSI color codes
GREEN = '\033[92m'
YELLOW = '\033[93m'
RED = '\033[91m'
BLUE = '\033[94m'
RESET = '\033[0m'

def find_swift_files(project_root: Path) -> Set[str]:
    """Find all .swift files in the project directory."""
    swift_files = set()

    # Directories to scan
    scan_dirs = [
        project_root / "Xcode" / "CraigOTerminator"
    ]

    # Directories to exclude
    exclude_dirs = {
        '.build',
        'build',
        'DerivedData',
        '.git',
        'Pods',
        'Carthage'
    }

    for scan_dir in scan_dirs:
        if not scan_dir.exists():
            continue

        for swift_file in scan_dir.rglob("*.swift"):
            # Skip excluded directories
            if any(excluded in swift_file.parts for excluded in exclude_dirs):
                continue

            # Get relative path from CraigOTerminator directory
            try:
                rel_path = swift_file.relative_to(project_root / "Xcode" / "CraigOTerminator")
                swift_files.add(str(rel_path))
            except ValueError:
                continue

    return swift_files

def find_files_in_pbxproj(pbxproj_path: Path) -> Set[str]:
    """Extract all Swift files referenced in project.pbxproj."""
    files_in_project = set()

    with open(pbxproj_path, 'r', encoding='utf-8') as f:
        content = f.read()

        # Look for PBXFileReference entries with .swift files
        for line in content.split('\n'):
            if '.swift' in line and 'path = ' in line:
                # Extract the path value
                try:
                    path_part = line.split('path = ')[1]
                    path = path_part.split(';')[0].strip().strip('"')
                    if path.endswith('.swift'):
                        files_in_project.add(path)
                except IndexError:
                    continue

    return files_in_project

def add_file_to_xcode_project(project_path: Path, file_path: str, group_path: str) -> bool:
    """
    Add a file to the Xcode project using xcodebuild and plutil.
    This uses the Ruby xcodeproj gem if available.
    """
    project_file = project_path / "project.pbxproj"

    # Try to use xcodeproj gem (requires installation)
    script = f'''
require 'xcodeproj'

project_path = "{project_path}"
file_path = "{file_path}"
group_path = "{group_path}"

project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Find or create the group
group = project.main_group
group_parts = group_path.split('/')
group_parts.each do |part|
  next if part.empty?
  existing_group = group.groups.find {{ |g| g.name == part || g.path == part }}
  if existing_group
    group = existing_group
  else
    group = group.new_group(part, part)
  end
end

# Add the file
file_ref = group.new_file(file_path)
target.add_file_references([file_ref])

project.save
puts "Added {{file_path}} to project"
'''

    try:
        result = subprocess.run(
            ['ruby', '-e', script],
            capture_output=True,
            text=True,
            timeout=10
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False

def determine_group_path(file_relative_path: str) -> str:
    """Determine the appropriate Xcode group path for a file."""
    path_parts = Path(file_relative_path).parts

    if len(path_parts) > 1:
        # Return all parts except the filename
        return '/'.join(path_parts[:-1])

    return ''

def check_ruby_gem_installed() -> bool:
    """Check if xcodeproj Ruby gem is installed."""
    try:
        result = subprocess.run(
            ['gem', 'list', 'xcodeproj'],
            capture_output=True,
            text=True,
            timeout=5
        )
        return 'xcodeproj' in result.stdout
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False

def install_xcodeproj_gem() -> bool:
    """Install the xcodeproj Ruby gem."""
    print(f"{YELLOW}Installing xcodeproj Ruby gem...{RESET}")
    try:
        result = subprocess.run(
            ['sudo', 'gem', 'install', 'xcodeproj'],
            timeout=60
        )
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        return False

def main():
    # Get project root
    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    xcode_project_path = project_root / "Xcode" / "CraigOTerminator.xcodeproj"
    pbxproj_path = xcode_project_path / "project.pbxproj"

    if not pbxproj_path.exists():
        print(f"{RED}Error: project.pbxproj not found at {pbxproj_path}{RESET}")
        sys.exit(1)

    print(f"{BLUE}🔍 Scanning for Swift files...{RESET}")

    # Find all Swift files
    all_swift_files = find_swift_files(project_root)
    print(f"Found {len(all_swift_files)} Swift files in project directory")

    # Find files already in project
    files_in_project = find_files_in_pbxproj(pbxproj_path)
    print(f"Found {len(files_in_project)} Swift files in Xcode project")

    # Find missing files
    missing_files = []
    for swift_file in sorted(all_swift_files):
        filename = Path(swift_file).name
        # Check if this exact file or just the filename is in the project
        if swift_file not in files_in_project and filename not in [Path(p).name for p in files_in_project]:
            missing_files.append(swift_file)

    if not missing_files:
        print(f"{GREEN}✅ All Swift files are already in the Xcode project!{RESET}")
        return 0

    print(f"\n{YELLOW}⚠️  Found {len(missing_files)} missing files:{RESET}")
    for file in missing_files:
        print(f"  - {file}")

    # Ask for confirmation
    response = input(f"\n{BLUE}Add these files to the Xcode project? (y/n): {RESET}").strip().lower()
    if response != 'y':
        print("Aborted.")
        return 0

    # Check if xcodeproj gem is installed
    if not check_ruby_gem_installed():
        print(f"{YELLOW}xcodeproj Ruby gem not found.{RESET}")
        install_response = input(f"{BLUE}Install it now? (requires sudo) (y/n): {RESET}").strip().lower()
        if install_response == 'y':
            if not install_xcodeproj_gem():
                print(f"{RED}Failed to install xcodeproj gem{RESET}")
                print("\nManually install with: sudo gem install xcodeproj")
                return 1
        else:
            print(f"{RED}Cannot proceed without xcodeproj gem{RESET}")
            print("Install with: sudo gem install xcodeproj")
            return 1

    # Add missing files
    print(f"\n{BLUE}📝 Adding files to Xcode project...{RESET}")
    added_count = 0
    failed_count = 0

    for file_path in missing_files:
        group_path = determine_group_path(file_path)
        full_path = project_root / "Xcode" / "CraigOTerminator" / file_path

        if add_file_to_xcode_project(xcode_project_path, str(full_path), group_path):
            print(f"{GREEN}  ✓{RESET} Added {file_path}")
            added_count += 1
        else:
            print(f"{RED}  ✗{RESET} Failed to add {file_path}")
            failed_count += 1

    print(f"\n{GREEN}✅ Successfully added {added_count} files{RESET}")
    if failed_count > 0:
        print(f"{RED}❌ Failed to add {failed_count} files{RESET}")
        return 1

    print(f"\n{BLUE}💡 Tip: Add this script to your Xcode build phases for automatic syncing{RESET}")
    return 0

if __name__ == '__main__':
    sys.exit(main())
