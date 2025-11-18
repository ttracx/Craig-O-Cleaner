#!/usr/bin/env ruby
# Fix duplicate entries in build phases

require 'xcodeproj'

PROJECT_FILE = 'Craig-O-Clean.xcodeproj'

puts "🔧 Fixing duplicate build phase entries in #{PROJECT_FILE}"
puts ""

project = Xcodeproj::Project.open(PROJECT_FILE)
target = project.targets.first

puts "🎯 Target: #{target.name}"
puts ""

total_duplicates = 0

# Check each build phase
target.build_phases.each do |phase|
  next unless phase.respond_to?(:files)

  phase_name = phase.class.name.split('::').last
  puts "📋 Checking #{phase_name}..."

  # Track files in this phase
  seen_files = {}
  duplicates = []

  phase.files.each do |build_file|
    next unless build_file.file_ref

    file_path = build_file.file_ref.path
    file_id = build_file.file_ref.uuid

    if seen_files[file_id]
      duplicates << build_file
      puts "   🔍 Duplicate: #{file_path}"
    else
      seen_files[file_id] = build_file
    end
  end

  # Remove duplicates
  duplicates.each do |build_file|
    phase.remove_build_file(build_file)
    total_duplicates += 1
    puts "   🗑️  Removed duplicate entry"
  end
end

puts ""

if total_duplicates > 0
  puts "=" * 60
  puts "📊 Summary"
  puts "=" * 60
  puts "Removed #{total_duplicates} duplicate build phase entries"
  puts "=" * 60
  puts ""

  puts "💾 Saving project..."
  project.save
  puts "✅ Project saved!"
  puts ""
  puts "🎉 Done! Try building again."
else
  puts "✅ No duplicates found in build phases!"
end
