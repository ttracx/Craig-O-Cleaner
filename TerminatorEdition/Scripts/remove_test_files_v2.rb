#!/usr/bin/env ruby
# Remove test files from main target more thoroughly

require 'xcodeproj'

project_path = '/Volumes/VibeStore/Craig-O-Cleaner/TerminatorEdition/Xcode/CraigOTerminator.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'CraigOTerminator' }

removed_count = 0

# Get all files in the project
all_files = []
project.main_group.recursive_children.each do |item|
  all_files << item if item.is_a?(Xcodeproj::Project::Object::PBXFileReference)
end

# Find test files
test_file_refs = all_files.select do |file_ref|
  file_ref.path && (file_ref.path.include?('Test') || file_ref.parent.name == 'CapabilityTests' || file_ref.parent.name == 'ExecutionTests')
end

puts "Found #{test_file_refs.size} test file references"

# Remove from build phases
test_file_refs.each do |file_ref|
  puts "Processing: #{file_ref.path}"

  # Remove from source build phase
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref == file_ref
      puts "  - Removing from build phase: #{file_ref.path}"
      build_file.remove_from_project
      removed_count += 1
    end
  end

  # Remove the file reference itself
  puts "  - Removing file reference: #{file_ref.path}"
  file_ref.remove_from_project
end

# Remove empty test groups
['CapabilityTests', 'ExecutionTests', 'Tests'].each do |group_name|
  group = project.main_group.recursive_children.find { |g| g.is_a?(Xcodeproj::Project::Object::PBXGroup) && g.name == group_name }
  if group && group.children.empty?
    puts "Removing empty group: #{group_name}"
    group.remove_from_project
  end
end

project.save
puts "\nSuccessfully removed #{removed_count} test files from build phases"
puts "Test files can be re-added once a proper test target is created"
