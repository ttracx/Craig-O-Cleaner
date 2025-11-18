#!/usr/bin/env ruby
# Xcode Project Sync Script
# Automatically adds new files and removes deleted files from Xcode project

require 'xcodeproj'
require 'pathname'
require 'set'

# Configuration
PROJECT_NAME = 'Craig-O-Clean'
PROJECT_FILE = "#{PROJECT_NAME}.xcodeproj"
SOURCE_DIR = PROJECT_NAME
EXCLUDE_PATTERNS = [
  /\.backup$/,
  /\.DS_Store$/,
  /^\.git/,
  /Preview Content/,
  /\.xcassets$/,
  /\.entitlements$/,
  /\.plist$/
]

# File type mappings
FILE_TYPES = {
  '.swift' => :source,
  '.h' => :header,
  '.m' => :source,
  '.mm' => :source,
  '.cpp' => :source,
  '.c' => :source,
  '.metal' => :source,
  '.mlmodel' => :resource,
  '.xib' => :resource,
  '.storyboard' => :resource
}

class XcodeProjectSync
  def initialize(project_path, source_dir)
    @project_path = project_path
    @source_dir = source_dir
    @project = Xcodeproj::Project.open(project_path)
    @main_group = @project.main_group
    @target = @project.targets.first

    puts "📦 Syncing Xcode project: #{@project_path}"
    puts "📁 Source directory: #{@source_dir}"
    puts "🎯 Target: #{@target.name}"
    puts ""
  end

  def sync
    @added_files = []
    @removed_files = []
    @skipped_files = []

    # Get current files in project
    project_files = get_project_files

    # Get actual files in directory
    disk_files = get_disk_files

    # Find files to add
    files_to_add = disk_files - project_files

    # Find files to remove
    files_to_remove = project_files - disk_files

    # Add new files
    files_to_add.each { |file| add_file(file) }

    # Remove deleted files
    files_to_remove.each { |file| remove_file(file) }

    # Save project if changes were made
    if @added_files.any? || @removed_files.any?
      @project.save
      print_summary
    else
      puts "✅ Project is already in sync!"
    end
  end

  private

  def get_project_files
    files = Set.new
    @main_group.recursive_children.each do |item|
      if item.is_a?(Xcodeproj::Project::Object::PBXFileReference)
        relative_path = get_relative_path(item)
        files.add(relative_path) if relative_path
      end
    end
    files
  end

  def get_disk_files
    files = Set.new
    source_path = Pathname.new(@source_dir)

    Dir.glob("#{@source_dir}/**/*").each do |file|
      next if File.directory?(file)
      next if should_exclude?(file)

      relative_path = Pathname.new(file).relative_path_from(Pathname.new('.'))
      files.add(relative_path.to_s)
    end

    files
  end

  def should_exclude?(file)
    EXCLUDE_PATTERNS.any? { |pattern| file.match?(pattern) }
  end

  def get_relative_path(file_ref)
    return nil unless file_ref.real_path

    begin
      real_path = Pathname.new(file_ref.real_path)
      project_dir = Pathname.new(File.dirname(@project_path))
      relative_path = real_path.relative_path_from(project_dir)
      relative_path.to_s
    rescue
      nil
    end
  end

  def add_file(file_path)
    return if should_exclude?(file_path)

    file_type = get_file_type(file_path)
    return unless file_type

    begin
      # Find or create group structure
      group = find_or_create_group(File.dirname(file_path))

      # Add file reference
      file_ref = group.new_reference(file_path)

      # Add to appropriate build phase
      case file_type
      when :source
        @target.source_build_phase.add_file_reference(file_ref)
      when :resource
        @target.resources_build_phase.add_file_reference(file_ref)
      when :header
        # Headers don't need to be added to build phase for Swift projects
      end

      @added_files << file_path
      puts "✅ Added: #{file_path}"
    rescue => e
      @skipped_files << file_path
      puts "⚠️  Skipped: #{file_path} (#{e.message})"
    end
  end

  def remove_file(file_path)
    @main_group.recursive_children.each do |item|
      if item.is_a?(Xcodeproj::Project::Object::PBXFileReference)
        relative_path = get_relative_path(item)
        if relative_path == file_path
          # Remove from build phases
          @target.build_phases.each do |phase|
            phase.files.each do |build_file|
              if build_file.file_ref == item
                phase.remove_build_file(build_file)
              end
            end
          end

          # Remove file reference
          item.remove_from_project
          @removed_files << file_path
          puts "🗑️  Removed: #{file_path}"
          break
        end
      end
    end
  end

  def find_or_create_group(path)
    return @main_group if path == '.' || path.empty?

    parts = path.split('/')
    current_group = @main_group

    parts.each do |part|
      next if part == '.'

      found_group = current_group.children.find do |child|
        child.is_a?(Xcodeproj::Project::Object::PBXGroup) && child.name == part
      end

      if found_group
        current_group = found_group
      else
        current_group = current_group.new_group(part, part)
      end
    end

    current_group
  end

  def get_file_type(file_path)
    ext = File.extname(file_path)
    FILE_TYPES[ext]
  end

  def print_summary
    puts ""
    puts "=" * 60
    puts "📊 Sync Summary"
    puts "=" * 60
    puts "✅ Added files:   #{@added_files.count}"
    puts "🗑️  Removed files: #{@removed_files.count}"
    puts "⚠️  Skipped files: #{@skipped_files.count}"
    puts "=" * 60
    puts ""

    if @added_files.any?
      puts "Added files:"
      @added_files.each { |f| puts "  + #{f}" }
      puts ""
    end

    if @removed_files.any?
      puts "Removed files:"
      @removed_files.each { |f| puts "  - #{f}" }
      puts ""
    end

    puts "✅ Project saved successfully!"
  end
end

# Main execution
begin
  unless File.exist?(PROJECT_FILE)
    puts "❌ Error: Project file not found: #{PROJECT_FILE}"
    exit 1
  end

  unless Dir.exist?(SOURCE_DIR)
    puts "❌ Error: Source directory not found: #{SOURCE_DIR}"
    exit 1
  end

  syncer = XcodeProjectSync.new(PROJECT_FILE, SOURCE_DIR)
  syncer.sync

  puts ""
  puts "🎉 Done!"

rescue Gem::LoadError
  puts "❌ Error: xcodeproj gem not installed"
  puts ""
  puts "Install it with:"
  puts "  gem install xcodeproj"
  puts ""
  exit 1
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.join("\n")
  exit 1
end
