#!/usr/bin/env ruby
require 'xcodeproj'

PROJECT_PATH = 'Craig-O-Clean.xcodeproj'
TARGET_NAME = 'Craig-O-Clean'
FILE_PATH = 'Craig-O-Clean/SystemMemoryMonitorView.swift'

begin
  project = Xcodeproj::Project.open(PROJECT_PATH)
  
  target = project.targets.find { |t| t.name == TARGET_NAME }
  unless target
    puts "Error: Target '#{TARGET_NAME}' not found"
    exit 1
  end
  
  main_group = project.main_group.find_subpath('Craig-O-Clean', true)
  
  existing = main_group.files.find { |f| f.path == 'SystemMemoryMonitorView.swift' }
  
  if existing
    puts "File already exists in project"
  else
    file_ref = main_group.new_file('SystemMemoryMonitorView.swift')
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added SystemMemoryMonitorView.swift to project"
  end
  
  project.save
  
rescue => e
  puts "Error: #{e.message}"
end
