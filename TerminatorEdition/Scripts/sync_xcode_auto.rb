#!/usr/bin/env ruby
# Automated Xcode Project Sync - Non-Interactive Version
# Automatically syncs Swift files to Xcode project without prompts

require 'xcodeproj'
require 'pathname'
require 'set'
require 'optparse'

# Colors
RED = "\e[31m"
GREEN = "\e[32m"
YELLOW = "\e[33m"
BLUE = "\e[34m"
CYAN = "\e[36m"
RESET = "\e[0m"

# Options - Global constant
OPTIONS = {
  dry_run: false,
  verbose: false,
  exclude_tests: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: sync_xcode_auto.rb [options]"

  opts.on("-d", "--dry-run", "Show what would be added without making changes") do
    OPTIONS[:dry_run] = true
  end

  opts.on("-v", "--verbose", "Show detailed output") do
    OPTIONS[:verbose] = true
  end

  opts.on("-t", "--exclude-tests", "Exclude test files") do
    OPTIONS[:exclude_tests] = true
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit 0
  end
end.parse!

def log(message, color = RESET, prefix = "")
  puts "#{color}#{prefix}#{message}#{RESET}"
end

def find_swift_files(project_dir, exclude_tests: false)
  swift_files = Set.new

  Dir.glob("#{project_dir}/**/*.swift").each do |file|
    # Skip build directories
    next if file.include?('/.build/') || file.include?('/build/') ||
            file.include?('/DerivedData/') || file.include?('/.git/')

    # Skip test files if requested
    if exclude_tests && file.include?('/Tests/')
      next
    end

    rel_path = Pathname.new(file).relative_path_from(Pathname.new(project_dir))
    swift_files.add(rel_path.to_s)
  end

  swift_files
end

def find_files_in_project(project)
  files_in_project = Set.new

  project.files.each do |file|
    files_in_project.add(file.path) if file.path && file.path.end_with?('.swift')
  end

  files_in_project
end

def determine_group_path(file_path)
  parts = Pathname.new(file_path).each_filename.to_a
  parts[0...-1] # All parts except the filename
end

def find_or_create_group(project, source_dir, group_parts, dry_run: false)
  # Start from main group
  group = project.main_group

  # Find the CraigOTerminator group
  craig_group = group.groups.find { |g| g.name == 'CraigOTerminator' || g.path == 'CraigOTerminator' }

  unless craig_group
    log("Error: Could not find CraigOTerminator group", RED, "❌ ")
    exit 1
  end

  group = craig_group

  # Navigate/create the group hierarchy
  group_parts.each do |part|
    next if part.empty?

    # Try to find existing group
    existing_group = group.groups.find { |g| g.name == part || g.path == part }

    if existing_group
      group = existing_group
    else
      # Create new group with proper path
      unless dry_run
        group = group.new_group(part, part)
        log("Created group: #{part}", CYAN, "  📁 ") if OPTIONS[:verbose]
      else
        log("Would create group: #{part}", YELLOW, "  📁 ")
      end
    end
  end

  group
end

def main
  # Get paths
  script_dir = File.dirname(__FILE__)
  project_root = File.dirname(script_dir)
  xcode_dir = File.join(project_root, 'Xcode')
  project_path = File.join(xcode_dir, 'CraigOTerminator.xcodeproj')
  source_dir = File.join(xcode_dir, 'CraigOTerminator')

  unless File.exist?(project_path)
    log("Error: Xcode project not found at #{project_path}", RED, "❌ ")
    exit 1
  end

  log("🔄 Automated Xcode Project Sync", BLUE)
  log("Mode: #{OPTIONS[:dry_run] ? 'DRY RUN' : 'LIVE'}", CYAN)
  puts ""

  log("Scanning for Swift files...", BLUE, "🔍 ")

  # Load project
  project = Xcodeproj::Project.open(project_path)
  target = project.targets.find { |t| t.name == 'CraigOTerminator' }

  unless target
    log("Error: Could not find CraigOTerminator target", RED, "❌ ")
    exit 1
  end

  # Find all Swift files
  all_swift_files = find_swift_files(source_dir, exclude_tests: OPTIONS[:exclude_tests])
  log("Found #{all_swift_files.size} Swift files in project directory", GREEN)

  # Find files already in project
  files_in_project = find_files_in_project(project)
  log("Found #{files_in_project.size} Swift files in Xcode project", GREEN)
  puts ""

  # Find missing files
  missing_files = all_swift_files.reject do |file|
    filename = File.basename(file)
    # Check if file or just filename exists in project
    files_in_project.include?(file) || files_in_project.any? { |p| File.basename(p) == filename }
  end

  if missing_files.empty?
    log("✅ All Swift files are already in the Xcode project!", GREEN)
    return 0
  end

  log("Found #{missing_files.size} missing files:", YELLOW, "📋 ")
  missing_files.sort.each do |file|
    log("#{file}", YELLOW, "  - ")
  end
  puts ""

  if OPTIONS[:dry_run]
    log("DRY RUN: Would add these files (use without --dry-run to apply)", CYAN, "💡 ")
    return 0
  end

  # Add missing files
  log("Adding files to Xcode project...", BLUE, "📝 ")
  added_count = 0
  failed_count = 0

  missing_files.sort.each do |file_path|
    begin
      # Determine group path
      group_parts = determine_group_path(file_path)
      group = find_or_create_group(project, source_dir, group_parts)

      # Get just the filename
      filename = File.basename(file_path)

      # Add file reference with just the filename
      file_ref = group.new_file(filename)

      # Add to target
      target.add_file_references([file_ref])

      log("Added #{file_path}", GREEN, "  ✓ ")
      added_count += 1
    rescue StandardError => e
      log("Failed to add #{file_path}: #{e.message}", RED, "  ✗ ")
      log("#{e.backtrace.first}", RED, "     ") if OPTIONS[:verbose]
      failed_count += 1
    end
  end

  # Save project
  puts ""
  log("Saving project...", BLUE, "💾 ")
  project.save

  puts ""
  log("Successfully added #{added_count} files", GREEN, "✅ ")
  if failed_count > 0
    log("Failed to add #{failed_count} files", RED, "❌ ")
    return 1
  end

  log("Project updated successfully!", GREEN, "🎉 ")
  0
end

exit main
