#!/usr/bin/env python3
"""
Update Xcode project to include new Swift files in Services, Views, and Tests directories.
"""

import os
import uuid
import re

def generate_uuid():
    """Generate a 24-character hex UUID like Xcode uses."""
    return uuid.uuid4().hex[:24].upper()

# Define new files to add
new_files = [
    # Services
    ("Services/BrowserAutomationService.swift", "BrowserAutomationService.swift"),
    ("Services/MemoryOptimizerService.swift", "MemoryOptimizerService.swift"),
    ("Services/PermissionsService.swift", "PermissionsService.swift"),
    ("Services/SystemMetricsService.swift", "SystemMetricsService.swift"),
    # Views
    ("Views/BrowserTabsView.swift", "BrowserTabsView.swift"),
    ("Views/DashboardView.swift", "DashboardView.swift"),
    ("Views/EnhancedMenuBarView.swift", "EnhancedMenuBarView.swift"),
    ("Views/MainAppView.swift", "MainAppView.swift"),
    ("Views/MemoryCleanupView.swift", "MemoryCleanupView.swift"),
    ("Views/PermissionsView.swift", "PermissionsView.swift"),
]

project_path = "/workspace/Craig-O-Clean.xcodeproj/project.pbxproj"

with open(project_path, 'r') as f:
    content = f.read()

# Generate UUIDs for new files
file_refs = {}
build_files = {}

for path, name in new_files:
    file_refs[name] = generate_uuid()
    build_files[name] = generate_uuid()

# Add file references
file_ref_section = "/* End PBXFileReference section */"
new_file_refs = ""
for path, name in new_files:
    ref_id = file_refs[name]
    new_file_refs += f'\t\t{ref_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = "<group>"; }};\n'

content = content.replace(file_ref_section, new_file_refs + file_ref_section)

# Add build files
build_file_section = "/* End PBXBuildFile section */"
new_build_files = ""
for path, name in new_files:
    build_id = build_files[name]
    ref_id = file_refs[name]
    new_build_files += f'\t\t{build_id} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref_id} /* {name} */; }};\n'

content = content.replace(build_file_section, new_build_files + build_file_section)

# Add to Sources build phase
sources_pattern = r'(72E50CC81E7DFE8C4F4A01AD /\* Sources \*/ = \{[^}]+files = \()([^)]+)(\);)'

def add_sources(match):
    prefix = match.group(1)
    existing = match.group(2)
    suffix = match.group(3)
    
    new_sources = existing
    for path, name in new_files:
        build_id = build_files[name]
        new_sources += f'\n\t\t\t\t{build_id} /* {name} in Sources */,'
    
    return prefix + new_sources + suffix

content = re.sub(sources_pattern, add_sources, content)

# Add Services and Views groups to the Craig-O-Clean group
# Find the Craig-O-Clean group
group_pattern = r'(AAA8B2312C2FDE28DD3FAF8F /\* Craig-O-Clean \*/ = \{\s+isa = PBXGroup;\s+children = \()([^)]+)(\);)'

# Generate group UUIDs
services_group_id = generate_uuid()
views_group_id = generate_uuid()

def add_groups(match):
    prefix = match.group(1)
    existing = match.group(2)
    suffix = match.group(3)
    
    # Add Services and Views group references at the beginning
    new_children = f'\n\t\t\t\t{services_group_id} /* Services */,\n\t\t\t\t{views_group_id} /* Views */,' + existing
    
    return prefix + new_children + suffix

content = re.sub(group_pattern, add_groups, content)

# Add the actual Services and Views group definitions
group_end_section = "/* End PBXGroup section */"

services_children = ""
for path, name in new_files:
    if path.startswith("Services/"):
        services_children += f'\n\t\t\t\t{file_refs[name]} /* {name} */,'

views_children = ""
for path, name in new_files:
    if path.startswith("Views/"):
        views_children += f'\n\t\t\t\t{file_refs[name]} /* {name} */,'

new_groups = f'''
\t\t{services_group_id} /* Services */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ({services_children}
\t\t\t);
\t\t\tpath = Services;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{views_group_id} /* Views */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ({views_children}
\t\t\t);
\t\t\tpath = Views;
\t\t\tsourceTree = "<group>";
\t\t}};
'''

content = content.replace(group_end_section, new_groups + group_end_section)

# Update deployment target to 14.0
content = content.replace('MACOSX_DEPLOYMENT_TARGET = 13.0;', 'MACOSX_DEPLOYMENT_TARGET = 14.0;')

# Disable sandbox (needed for process monitoring)
content = content.replace('ENABLE_APP_SANDBOX = YES;', 'ENABLE_APP_SANDBOX = NO;')

# Update product name
content = content.replace('PRODUCT_NAME = "Craig-O-Clean";', 'PRODUCT_NAME = "ClearMind Control Center";')

# Fix the display name
content = re.sub(
    r'INFOPLIST_KEY_CFBundleDisplayName = "[^"]+";',
    'INFOPLIST_KEY_CFBundleDisplayName = "ClearMind Control Center";',
    content
)

with open(project_path, 'w') as f:
    f.write(content)

print("Xcode project updated successfully!")
print(f"Added {len(new_files)} new files to the project.")
