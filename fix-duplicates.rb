#!/usr/bin/env ruby
# Fix duplicate file references in Xcode project

require 'xcodeproj'

PROJECT_FILE = 'Craig-O-Clean.xcodeproj'

puts "🔧 Fixing duplicate file references in #{PROJECT_FILE}"
puts ""

project = Xcodeproj::Project.open(PROJECT_FILE)
target = project.targets.first

# Track files by path
file_refs_by_path = {}
duplicates_found = []

# Find all file references
project.main_group.recursive_children.each do |item|
  next unless item.is_a?(Xcodeproj::Project::Object::PBXFileReference)

  path = item.path
  next unless path

  if file_refs_by_path[path]
    # Duplicate found
    duplicates_found << path
    puts "🔍 Found duplicate: #{path}"

    # Remove from build phases
    target.build_phases.each do |phase|
      phase.files.each do |build_file|
        if build_file.file_ref == item
          phase.remove_build_file(build_file)
          puts "   ✂️  Removed from build phase"
        end
      end
    end

    # Remove file reference
    item.remove_from_project
    puts "   🗑️  Removed reference"
  else
    file_refs_by_path[path] = item
  end
end

if duplicates_found.empty?
  puts "✅ No duplicates found!"
else
  puts ""
  puts "=" * 60
  puts "📊 Summary"
  puts "=" * 60
  puts "Removed #{duplicates_found.uniq.count} duplicate file references:"
  duplicates_found.uniq.each do |path|
    puts "  - #{path}"
  end
  puts "=" * 60
  puts ""

  puts "💾 Saving project..."
  project.save
  puts "✅ Project saved!"
  puts ""
  puts "🎉 Done! Try building again."
end
