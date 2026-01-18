# Craig-O-Clean Makefile
# Build, test, and package commands

.PHONY: all build release test clean archive dmg help setup sync setup-auto-sync watch-sync \
       test-automated test-quick test-full test-report agent-fix

# Default target
all: build

# Configuration
SCHEME = Craig-O-Clean
PROJECT = Craig-O-Clean.xcodeproj
BUILD_DIR = build
APP_NAME = Craig-O-Clean

# Help target
help:
	@echo "Craig-O-Clean - Build Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Build & Test:"
	@echo "  build        - Build debug configuration"
	@echo "  release      - Build release configuration"
	@echo "  test         - Run all tests"
	@echo "  test-unit    - Run unit tests only"
	@echo "  test-ui      - Run UI tests only"
	@echo "  clean        - Clean build artifacts"
	@echo ""
	@echo "Automated UX Testing:"
	@echo "  test-automated - Run full automated E2E testing with reports"
	@echo "  test-quick     - Run quick sanity tests"
	@echo "  test-full      - Run full suite with clean build"
	@echo "  test-report    - Generate report from existing results"
	@echo "  agent-fix      - Show agent orchestration instructions"
	@echo ""
	@echo "Distribution:"
	@echo "  archive      - Create release archive"
	@echo "  dmg          - Create DMG installer"
	@echo ""
	@echo "Development:"
	@echo "  setup        - Install development dependencies"
	@echo "  sync         - Sync source files with Xcode project (manual)"
	@echo "  setup-auto-sync - Configure automatic Xcode syncing (git hooks)"
	@echo "  watch-sync   - Start file watcher for real-time syncing"
	@echo "  lint         - Run SwiftLint (if installed)"
	@echo "  format       - Format code with swift-format (if installed)"
	@echo "  open         - Open project in Xcode"
	@echo "  stats        - Show project statistics"
	@echo ""
	@echo "Auto-Sync Info:"
	@echo "  See XCODE_SYNC.md for complete auto-sync documentation"
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
		-only-testing:Craig-O-CleanTests \
		| xcpretty || xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS'

# Run UI tests
test-ui:
	@echo "Running UI tests..."
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		-only-testing:Craig-O-CleanUITests \
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
			$(BUILD_DIR)/Craig-O-Clean.dmg; \
		echo "DMG created at $(BUILD_DIR)/Craig-O-Clean.dmg"; \
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

# Setup automatic Xcode syncing
setup-auto-sync:
	@echo "Setting up automatic Xcode project syncing..."
	@./setup-auto-sync.sh

# Start file watcher for real-time syncing
watch-sync:
	@echo "Starting file watcher for real-time Xcode syncing..."
	@if command -v fswatch >/dev/null 2>&1; then \
		./watch-and-sync.sh; \
	else \
		echo "fswatch not found. Install with: brew install fswatch"; \
		echo "Then run: make watch-sync"; \
	fi

# =============================================================================
# Automated UX Testing
# =============================================================================

# Run full automated E2E testing suite with report generation
test-automated:
	@echo "Running automated E2E testing suite..."
	@./scripts/automated-ux-testing.sh --full --verbose

# Run quick sanity tests
test-quick:
	@echo "Running quick sanity tests..."
	@./scripts/automated-ux-testing.sh --quick

# Run full test suite with clean build
test-full:
	@echo "Running full test suite with clean build..."
	@./scripts/automated-ux-testing.sh --full --clean --verbose

# Generate test report from existing results
test-report:
	@echo "Generating test report..."
	@python3 scripts/generate-test-report.py --input test-output --output test-output/reports

# Show agent orchestration prompt for fixing test issues
agent-fix:
	@echo ""
	@echo "=========================================="
	@echo "Agent Orchestration Instructions"
	@echo "=========================================="
	@echo ""
	@echo "To fix issues identified by automated testing:"
	@echo ""
	@echo "1. First, run the automated tests:"
	@echo "   make test-automated"
	@echo ""
	@echo "2. Review the generated reports:"
	@echo "   - test-output/reports/test-report-*.md"
	@echo "   - test-output/agent-prompts/agent-orchestration-prompt-*.md"
	@echo ""
	@echo "3. Use the agent orchestrator in Cursor:"
	@echo "   @.cursor/agents/agent-orchestrator.md"
	@echo ""
	@echo "4. Copy the contents of the agent prompt file"
	@echo "   and paste it to start the fix workflow"
	@echo ""
	@echo "5. Or use the orchestration template:"
	@echo "   @.cursor/prompts/automated-test-fix-orchestration.md"
	@echo ""
	@if [ -d "test-output/agent-prompts" ]; then \
		latest=$$(ls -t test-output/agent-prompts/agent-orchestration-prompt-*.md 2>/dev/null | head -1); \
		if [ -n "$$latest" ]; then \
			echo "Latest agent prompt: $$latest"; \
		fi; \
	fi
	@echo ""
