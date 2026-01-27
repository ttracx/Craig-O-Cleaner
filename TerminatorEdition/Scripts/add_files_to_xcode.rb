#!/usr/bin/env ruby
# Xcode Project File Adder
# Adds missing Swift files to the Xcode project using xcodeproj gem

require 'xcodeproj'
require 'pathname'
require 'set'

# Colors
RED = "\e[31m"
GREEN = "\e[32m"
YELLOW = "\e[33m"
BLUE = "\e[34m"
RESET = "\e[0m"

def find_swift_files(project_dir)
  swift_files = Set.new

  Dir.glob("#{project_dir}/**/*.swift").each do |file|
    # Skip build directories
    next if file.include?('/.build/') || file.include?('/build/') ||
            file.include?('/DerivedData/') || file.include?('/.git/')

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

def find_or_create_group(project, group_parts)
  group = project.main_group

  group_parts.each do |part|
    next if part.empty?

    # Try to find existing group
    existing_group = group.groups.find { |g| g.name == part || g.path == part }

    if existing_group
      group = existing_group
    else
      # Create new group
      group = group.new_group(part, part)
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
    puts "#{RED}Error: Xcode project not found at #{project_path}#{RESET}"
    exit 1
  end

  puts "#{BLUE}🔍 Scanning for Swift files...#{RESET}"

  # Load project
  project = Xcodeproj::Project.open(project_path)
  target = project.targets.find { |t| t.name == 'CraigOTerminator' }

  unless target
    puts "#{RED}Error: Could not find CraigOTerminator target#{RESET}"
    exit 1
  end

  # Find all Swift files
  all_swift_files = find_swift_files(source_dir)
  puts "Found #{all_swift_files.size} Swift files in project directory"

  # Find files already in project
  files_in_project = find_files_in_project(project)
  puts "Found #{files_in_project.size} Swift files in Xcode project"

  # Find missing files
  missing_files = all_swift_files.reject do |file|
    filename = File.basename(file)
    # Check if file or just filename exists in project
    files_in_project.include?(file) || files_in_project.any? { |p| File.basename(p) == filename }
  end

  if missing_files.empty?
    puts "\n#{GREEN}✅ All Swift files are already in the Xcode project!#{RESET}"
    return 0
  end

  puts "\n#{YELLOW}⚠️  Found #{missing_files.size} missing files:#{RESET}"
  missing_files.sort.each do |file|
    puts "  - #{file}"
  end

  # Ask for confirmation
  print "\n#{BLUE}Add these files to the Xcode project? (y/n): #{RESET}"
  response = gets.strip.downcase

  unless response == 'y'
    puts "Aborted."
    return 0
  end

  # Add missing files
  puts "\n#{BLUE}📝 Adding files to Xcode project...#{RESET}"
  added_count = 0
  failed_count = 0

  missing_files.sort.each do |file_path|
    begin
      # Determine group path
      group_parts = determine_group_path(file_path)
      group = find_or_create_group(project, group_parts)

      # Add file reference
      # Use relative path from group's location
      file_ref = group.new_file(file_path)

      # Add to target if it's not a test file in a test target
      # For now, add all files to the main target
      target.add_file_references([file_ref])

      puts "#{GREEN}  ✓#{RESET} Added #{file_path}"
      added_count += 1
    rescue StandardError => e
      puts "#{RED}  ✗#{RESET} Failed to add #{file_path}: #{e.message}"
      failed_count += 1
    end
  end

  # Save project
  puts "\n#{BLUE}💾 Saving project...#{RESET}"
  project.save

  puts "\n#{GREEN}✅ Successfully added #{added_count} files#{RESET}"
  if failed_count > 0
    puts "#{RED}❌ Failed to add #{failed_count} files#{RESET}"
    return 1
  end

  puts "\n#{BLUE}💡 Project updated successfully. Open in Xcode to verify.#{RESET}"
  0
end

exit main
