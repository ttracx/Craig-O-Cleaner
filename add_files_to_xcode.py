#!/usr/bin/env python3
"""
Script to add missing Swift files to Xcode project.pbxproj
"""

import re
import uuid
import sys

def generate_uuid():
    """Generate a 24-character hex UUID (Xcode style)"""
    return uuid.uuid4().hex.upper()[:24]

def add_files_to_project(project_path, files_to_add):
    """Add Swift files to Xcode project"""

    # Read the project file
    with open(project_path, 'r') as f:
        content = f.read()

    # Generate UUIDs for each file
    file_refs = {}
    build_refs = {}

    for filename in files_to_add:
        file_refs[filename] = generate_uuid()
        build_refs[filename] = generate_uuid()

    # Find the PBXBuildFile section
    build_file_section = re.search(
        r'(/\* Begin PBXBuildFile section \*/\n)(.*?)(/\* End PBXBuildFile section \*/)',
        content,
        re.DOTALL
    )

    if not build_file_section:
        print("Error: Could not find PBXBuildFile section")
        return False

    # Find the PBXFileReference section
    file_ref_section = re.search(
        r'(/\* Begin PBXFileReference section \*/\n)(.*?)(/\* End PBXFileReference section \*/)',
        content,
        re.DOTALL
    )

    if not file_ref_section:
        print("Error: Could not find PBXFileReference section")
        return False

    # Find the Sources build phase (PBXSourcesBuildPhase)
    sources_phase = re.search(
        r'(/\* Sources \*/ = \{[^}]*?files = \()(.*?)(\);)',
        content,
        re.DOTALL
    )

    if not sources_phase:
        print("Error: Could not find Sources build phase")
        return False

    # Add PBXBuildFile entries
    build_file_entries = build_file_section.group(2)
    new_build_entries = []

    for filename in files_to_add:
        entry = f"\t\t{build_refs[filename]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[filename]} /* {filename} */; }};\n"
        new_build_entries.append(entry)

    # Add PBXFileReference entries
    file_ref_entries = file_ref_section.group(2)
    new_file_entries = []

    for filename in files_to_add:
        entry = f"\t\t{file_refs[filename]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"
        new_file_entries.append(entry)

    # Add to Sources build phase
    sources_files = sources_phase.group(2)
    new_source_refs = []

    for filename in files_to_add:
        ref = f"\t\t\t\t{build_refs[filename]} /* {filename} in Sources */,\n"
        new_source_refs.append(ref)

    # Insert the new entries
    updated_content = content.replace(
        build_file_section.group(0),
        build_file_section.group(1) + ''.join(new_build_entries) + build_file_entries + build_file_section.group(3)
    )

    updated_content = updated_content.replace(
        file_ref_section.group(0),
        file_ref_section.group(1) + ''.join(new_file_entries) + file_ref_entries + file_ref_section.group(3)
    )

    updated_content = updated_content.replace(
        sources_phase.group(0),
        sources_phase.group(1) + ''.join(new_source_refs) + sources_files + sources_phase.group(3)
    )

    # Find the Core group and add file references there
    # Look for a group that contains other Core files
    core_group_pattern = r'(/\* Core \*/ = \{[^}]*?children = \()(.*?)(\);)'
    core_group = re.search(core_group_pattern, updated_content, re.DOTALL)

    if core_group:
        group_children = core_group.group(2)
        new_group_refs = []

        for filename in files_to_add:
            ref = f"\t\t\t\t{file_refs[filename]} /* {filename} */,\n"
            new_group_refs.append(ref)

        updated_content = updated_content.replace(
            core_group.group(0),
            core_group.group(1) + ''.join(new_group_refs) + group_children + core_group.group(3)
        )
    else:
        print("Warning: Could not find Core group, files may not appear in correct folder")

    # Write the updated project file
    with open(project_path, 'w') as f:
        f.write(updated_content)

    print(f"Successfully added {len(files_to_add)} files to the project:")
    for filename in files_to_add:
        print(f"  - {filename}")

    return True

if __name__ == "__main__":
    project_path = "Craig-O-Clean.xcodeproj/project.pbxproj"

    files_to_add = [
        "PaywallView.swift"
    ]

    print("Adding missing files to Xcode project...")
    if add_files_to_project(project_path, files_to_add):
        print("\nSuccess! You may need to restart Xcode for changes to take effect.")
        sys.exit(0)
    else:
        print("\nFailed to update project file.")
        sys.exit(1)
