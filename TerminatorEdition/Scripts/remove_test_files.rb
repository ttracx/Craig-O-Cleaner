#!/usr/bin/env ruby
# Remove test files from main target (they need a separate test target)

require 'xcodeproj'

project_path = '/Volumes/VibeStore/Craig-O-Cleaner/TerminatorEdition/Xcode/CraigOTerminator.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'CraigOTerminator' }

# Find and remove test files from the target
test_files = target.source_build_phase.files.select do |build_file|
  file_ref = build_file.file_ref
  file_ref && file_ref.path && file_ref.path.include?('Tests/')
end

test_files.each do |build_file|
  puts "Removing #{build_file.file_ref.path} from target"
  target.source_build_phase.files.delete(build_file)
end

# Also remove the file references from the project if they're test files
project.files.select { |f| f.path && f.path.include?('Tests/') }.each do |file_ref|
  puts "Removing file reference: #{file_ref.path}"
  file_ref.remove_from_project
end

project.save
puts "Removed #{test_files.size} test files from project"
