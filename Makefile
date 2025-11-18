.PHONY: help sync sync-ruby sync-xcodegen sync-python install-deps clean-backups build run

# Default target
help:
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║           Craig-O-Clean - Makefile Help               ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "  📦 Project Sync:"
	@echo "    make sync              - Sync Xcode project (Ruby - recommended)"
	@echo "    make sync-ruby         - Sync using Ruby script"
	@echo "    make sync-xcodegen     - Sync using xcodegen"
	@echo "    make sync-python       - Sync using Python script"
	@echo ""
	@echo "  🔧 Installation:"
	@echo "    make install-deps      - Install all dependencies"
	@echo "    make install-ruby      - Install Ruby dependencies"
	@echo "    make install-xcodegen  - Install xcodegen"
	@echo "    make install-python    - Install Python dependencies"
	@echo ""
	@echo "  🧹 Maintenance:"
	@echo "    make clean-backups     - Remove old project backups"
	@echo "    make clean-build       - Clean Xcode build artifacts"
	@echo "    make clean-all         - Clean everything"
	@echo ""
	@echo "  🚀 Build & Run:"
	@echo "    make build             - Build the project"
	@echo "    make run               - Build and run the app"
	@echo "    make open              - Open project in Xcode"
	@echo ""
	@echo "  🧪 Testing:"
	@echo "    make test              - Run tests"
	@echo ""
	@echo "  📋 Git:"
	@echo "    make commit            - Sync project and commit changes"
	@echo ""

# Sync targets (using xcodegen to avoid duplicates)
sync: sync-xcodegen

sync-ruby:
	@echo "🔄 Syncing with Ruby script..."
	@chmod +x sync-xcode-project.rb
	@./sync-xcode-project.rb

sync-xcodegen:
	@echo "🔄 Syncing with xcodegen..."
	@chmod +x sync-xcode-project.sh
	@./sync-xcode-project.sh

sync-python:
	@echo "🔄 Syncing with Python script..."
	@chmod +x sync-xcode-project.py
	@python3 sync-xcode-project.py

# Installation targets
install-deps: install-ruby install-xcodegen install-python
	@echo "✅ All dependencies installed!"

install-ruby:
	@echo "📦 Installing xcodeproj gem..."
	@gem install xcodeproj || sudo gem install xcodeproj
	@echo "✅ Ruby dependencies installed"

install-xcodegen:
	@echo "📦 Installing xcodegen..."
	@if command -v brew >/dev/null 2>&1; then \
		brew install xcodegen; \
	else \
		echo "❌ Homebrew not found. Install from https://brew.sh"; \
		exit 1; \
	fi
	@echo "✅ xcodegen installed"

install-python:
	@echo "📦 Installing pbxproj..."
	@pip3 install pbxproj
	@echo "✅ Python dependencies installed"

# Cleanup targets
clean-backups:
	@echo "🧹 Cleaning up old backups..."
	@find . -maxdepth 1 -name "*.xcodeproj.backup-*" -type d -print0 | \
		xargs -0 ls -dt 2>/dev/null | \
		tail -n +6 | \
		xargs rm -rf 2>/dev/null || true
	@echo "✅ Old backups cleaned"

clean-build:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf ~/Library/Developer/Xcode/DerivedData/Craig-O-Clean-* 2>/dev/null || true
	@rm -rf build/ 2>/dev/null || true
	@echo "✅ Build artifacts cleaned"

clean-all: clean-backups clean-build
	@echo "✅ All cleaned!"

# Build targets
build:
	@echo "🔨 Building Craig-O-Clean..."
	@xcodebuild -project Craig-O-Clean.xcodeproj \
		-scheme Craig-O-Clean \
		-configuration Debug \
		build

run: build
	@echo "🚀 Running Craig-O-Clean..."
	@open build/Debug/Craig-O-Clean.app

open:
	@echo "📂 Opening in Xcode..."
	@open Craig-O-Clean.xcodeproj

# Testing
test:
	@echo "🧪 Running tests..."
	@xcodebuild test -project Craig-O-Clean.xcodeproj \
		-scheme Craig-O-Clean \
		-destination 'platform=macOS'

# Git workflow
commit: sync
	@echo "📝 Committing changes..."
	@git add .
	@git status
	@echo ""
	@echo "Ready to commit. Run:"
	@echo "  git commit -m 'Your message'"
	@echo "  git push"

# Development workflow
dev: sync open

# Quick sync and test
check: sync test

# Show current status
status:
	@echo "📊 Project Status"
	@echo "════════════════════════════════════════════════════════"
	@echo ""
	@echo "Swift files in source:"
	@find Craig-O-Clean -name "*.swift" -type f ! -path "*/Preview Content/*" | wc -l | xargs echo "  "
	@echo ""
	@echo "Recent backups:"
	@find . -maxdepth 1 -name "*.xcodeproj.backup-*" -type d 2>/dev/null | wc -l | xargs echo "  "
	@echo ""
	@git status --short
	@echo ""
