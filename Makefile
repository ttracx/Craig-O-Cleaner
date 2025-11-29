# ClearMind Control Center Makefile
# Build, test, and package commands

.PHONY: all build release test clean archive dmg help setup sync

# Default target
all: build

# Configuration
SCHEME = Craig-O-Clean
PROJECT = Craig-O-Clean.xcodeproj
BUILD_DIR = build
APP_NAME = ClearMind Control Center

# Help target
help:
	@echo "ClearMind Control Center - Build Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build     - Build debug configuration"
	@echo "  release   - Build release configuration"
	@echo "  test      - Run all tests"
	@echo "  test-unit - Run unit tests only"
	@echo "  test-ui   - Run UI tests only"
	@echo "  clean     - Clean build artifacts"
	@echo "  archive   - Create release archive"
	@echo "  dmg       - Create DMG installer"
	@echo "  setup     - Install development dependencies"
	@echo "  sync      - Sync source files with Xcode project"
	@echo "  lint      - Run SwiftLint (if installed)"
	@echo "  format    - Format code with swift-format (if installed)"
	@echo ""

# Build debug configuration
build:
	@echo "Building debug configuration..."
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR)/DerivedData \
		| xcpretty || xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -configuration Debug

# Build release configuration
release:
	@echo "Building release configuration..."
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR)/DerivedData \
		| xcpretty || xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -configuration Release

# Run all tests
test: test-unit test-ui

# Run unit tests
test-unit:
	@echo "Running unit tests..."
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		-only-testing:ClearMindTests \
		| xcpretty || xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS'

# Run UI tests
test-ui:
	@echo "Running UI tests..."
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		-only-testing:ClearMindUITests \
		| xcpretty || xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS'

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME)
	rm -rf $(BUILD_DIR)
	rm -rf ~/Library/Developer/Xcode/DerivedData/$(SCHEME)-*

# Create archive for distribution
archive: clean
	@echo "Creating archive..."
	mkdir -p $(BUILD_DIR)
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-archivePath $(BUILD_DIR)/$(SCHEME).xcarchive \
		-configuration Release

# Create DMG installer
dmg: archive
	@echo "Creating DMG installer..."
	@if [ -d "$(BUILD_DIR)/$(SCHEME).xcarchive/Products/Applications/$(APP_NAME).app" ]; then \
		hdiutil create -volname "$(APP_NAME)" \
			-srcfolder "$(BUILD_DIR)/$(SCHEME).xcarchive/Products/Applications/$(APP_NAME).app" \
			-ov -format UDZO \
			$(BUILD_DIR)/ClearMind.dmg; \
		echo "DMG created at $(BUILD_DIR)/ClearMind.dmg"; \
	else \
		echo "Error: App bundle not found in archive"; \
		exit 1; \
	fi

# Install development dependencies
setup:
	@echo "Installing development dependencies..."
	@if command -v brew >/dev/null 2>&1; then \
		echo "Installing xcpretty..."; \
		gem install xcpretty 2>/dev/null || sudo gem install xcpretty; \
		echo "Installing swiftlint..."; \
		brew install swiftlint 2>/dev/null || true; \
		echo "Installing swift-format..."; \
		brew install swift-format 2>/dev/null || true; \
		echo "Installing xcodegen..."; \
		brew install xcodegen 2>/dev/null || true; \
	else \
		echo "Homebrew not found. Please install Homebrew first."; \
		echo "Visit: https://brew.sh"; \
	fi
	@echo "Setup complete!"

# Sync source files with Xcode project
sync:
	@echo "Syncing source files with Xcode project..."
	@if command -v xcodegen >/dev/null 2>&1; then \
		xcodegen generate; \
		echo "Project regenerated successfully!"; \
	else \
		echo "XcodeGen not found. Install with: brew install xcodegen"; \
		echo "Or manually add new files in Xcode."; \
	fi

# Run SwiftLint
lint:
	@echo "Running SwiftLint..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --path Craig-O-Clean; \
	else \
		echo "SwiftLint not found. Install with: brew install swiftlint"; \
	fi

# Format code
format:
	@echo "Formatting code..."
	@if command -v swift-format >/dev/null 2>&1; then \
		find Craig-O-Clean -name "*.swift" -exec swift-format -i {} \;; \
		echo "Code formatted!"; \
	else \
		echo "swift-format not found. Install with: brew install swift-format"; \
	fi

# Open project in Xcode
open:
	@open $(PROJECT)

# Show project statistics
stats:
	@echo "Project Statistics:"
	@echo "==================="
	@echo "Swift files: $$(find Craig-O-Clean -name '*.swift' | wc -l | tr -d ' ')"
	@echo "Lines of code: $$(find Craig-O-Clean -name '*.swift' -exec cat {} \; | wc -l | tr -d ' ')"
	@echo "Test files: $$(find Craig-O-Clean/Tests -name '*.swift' 2>/dev/null | wc -l | tr -d ' ')"
