#!/usr/bin/env ruby
# Script to add new source files to the Xcode project
# Usage: ruby add-files-to-xcode.rb

require 'xcodeproj'

PROJECT_PATH = 'Craig-O-Clean.xcodeproj'
TARGET_NAME = 'Craig-O-Clean'

# Files to add organized by group
NEW_FILES = {
  'Core' => [
    'Craig-O-Clean/Core/SystemMetricsService.swift',
    'Craig-O-Clean/Core/BrowserAutomationService.swift',
    'Craig-O-Clean/Core/MemoryOptimizerService.swift',
    'Craig-O-Clean/Core/PermissionsService.swift',
  ],
  'UI' => [
    'Craig-O-Clean/UI/MainAppView.swift',
    'Craig-O-Clean/UI/DashboardView.swift',
    'Craig-O-Clean/UI/ProcessManagerView.swift',
    'Craig-O-Clean/UI/MemoryCleanupView.swift',
    'Craig-O-Clean/UI/BrowserTabsView.swift',
    'Craig-O-Clean/UI/SettingsPermissionsView.swift',
    'Craig-O-Clean/UI/MenuBarContentView.swift',
  ]
}

TEST_FILES = {
  'ClearMindTests' => [
    'Craig-O-Clean/Tests/ClearMindTests/SystemMetricsServiceTests.swift',
    'Craig-O-Clean/Tests/ClearMindTests/MemoryOptimizerServiceTests.swift',
    'Craig-O-Clean/Tests/ClearMindTests/BrowserAutomationServiceTests.swift',
    'Craig-O-Clean/Tests/ClearMindTests/PermissionsServiceTests.swift',
  ],
  'ClearMindUITests' => [
    'Craig-O-Clean/Tests/ClearMindUITests/ClearMindUITests.swift',
  ]
}

begin
  project = Xcodeproj::Project.open(PROJECT_PATH)
  
  # Find the main target
  target = project.targets.find { |t| t.name == TARGET_NAME }
  unless target
    puts "Error: Target '#{TARGET_NAME}' not found"
    exit 1
  end
  
  # Find or create the main group
  main_group = project.main_group.find_subpath('Craig-O-Clean', true)
  
  # Add source files
  NEW_FILES.each do |group_name, files|
    # Find or create the group
    group = main_group.find_subpath(group_name, false) || main_group.new_group(group_name)
    
    files.each do |file_path|
      # Check if file already exists in project
      existing = group.files.find { |f| f.path && f.path.end_with?(File.basename(file_path)) }
      
      if existing
        puts "Skipping (already exists): #{file_path}"
        next
      end
      
      # Add file reference
      file_ref = group.new_file(file_path)
      
      # Add to target's compile sources
      target.source_build_phase.add_file_reference(file_ref)
      
      puts "Added: #{file_path}"
    end
  end
  
  # Save the project
  project.save
  
  puts "\nProject updated successfully!"
  puts "Please open #{PROJECT_PATH} in Xcode to verify."
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end
