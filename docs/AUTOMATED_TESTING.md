# Craig-O-Clean Automated UX Testing System

## Overview

This document describes the comprehensive automated UX and app testing system for Craig-O-Clean. The system provides end-to-end testing, debug logging, report generation, and integration with the Cursor agent orchestration system for automated issue resolution.

## System Components

### 1. Debug Logger (`Craig-O-Clean/Core/DebugLogger.swift`)

A comprehensive logging system for the SwiftUI app that provides:

- **Multi-level logging**: Verbose, Debug, Info, Warning, Error, Critical
- **Category-based filtering**: App, UI, Navigation, Memory, Process, etc.
- **Performance measurement**: Automatic timing of operations
- **Test session management**: Recording and exporting test results
- **Export capabilities**: JSON export for automated consumption

#### Usage in Code

```swift
// Basic logging
DebugLogger.shared.info("User clicked button", category: .ui)
DebugLogger.shared.error("Failed to load data", category: .network)

// Performance measurement
let measure = PerformanceMeasure("Data Loading")
// ... perform operation
measure.complete()

// Navigation logging
DebugLogger.shared.logNavigation(from: "Dashboard", to: "Settings")

// Export logs
let logPath = DebugLogger.shared.exportForAutomatedTesting()
```

### 2. Automated E2E Tests (`Tests/CraigOCleanUITests/AutomatedE2ETests.swift`)

Comprehensive XCUITest suite covering:

- **App Launch Tests**: Verify successful launch and window creation
- **Navigation Tests**: Test all sidebar navigation paths
- **Dashboard Tests**: Verify metric cards and real-time updates
- **Process Manager Tests**: Test search, filtering, and process list
- **Memory Cleanup Tests**: Test cleanup functionality
- **Settings Tests**: Test settings sections and toggles
- **Accessibility Tests**: Verify accessibility labels and hittability
- **Performance Tests**: Launch performance and navigation timing
- **Integration Tests**: Full user journey end-to-end

### 3. Testing Shell Script (`scripts/automated-ux-testing.sh`)

Main orchestration script that:

- Checks prerequisites (Xcode, tools)
- Builds the application
- Runs unit and UI tests
- Collects logs and screenshots
- Generates reports
- Creates agent orchestration prompts

#### Usage

```bash
# Full test suite
./scripts/automated-ux-testing.sh --full

# Quick sanity tests
./scripts/automated-ux-testing.sh --quick

# Clean build and full tests
./scripts/automated-ux-testing.sh --clean --verbose

# Generate report only
./scripts/automated-ux-testing.sh --report-only
```

### 4. Report Generator (`scripts/generate-test-report.py`)

Python script for advanced report generation:

- Parses test logs and results
- Identifies and categorizes issues
- Maps issues to recommended agents
- Generates JSON, Markdown, and summary reports
- Creates agent orchestration prompts

### 5. Agent Orchestration Templates

Located in `.cursor/prompts/automated-test-fix-orchestration.md`:

- Coordinates multiple specialized agents
- Routes issues to appropriate experts
- Defines workflow phases
- Provides success criteria

## Quick Start

### Using Make Commands

```bash
# Run full automated testing
make test-automated

# Run quick tests
make test-quick

# Generate report from existing results
make test-report

# Show agent fix instructions
make agent-fix
```

### Manual Execution

```bash
# 1. Run automated tests
./scripts/automated-ux-testing.sh --full --verbose

# 2. Review reports
cat test-output/reports/test-report-*.md

# 3. Review agent prompt
cat test-output/agent-prompts/agent-orchestration-prompt-*.md

# 4. Use with Cursor agents
# Copy the agent prompt content and use with:
# @.cursor/agents/agent-orchestrator.md
```

## Output Structure

After running tests, the following structure is created:

```
test-output/
├── reports/
│   ├── test-report-TIMESTAMP.md      # Full Markdown report
│   ├── test-report-TIMESTAMP.json    # JSON report
│   └── summary-TIMESTAMP.txt         # Brief summary
├── logs/
│   ├── test-run-TIMESTAMP.log        # Main test log
│   ├── test-run-TIMESTAMP-build.log  # Build log
│   ├── test-run-TIMESTAMP-unit-tests.log
│   └── test-run-TIMESTAMP-ui-tests.log
├── screenshots/
│   └── [captured screenshots]
├── agent-prompts/
│   ├── agent-orchestration-prompt-TIMESTAMP.md
│   └── quick-fix-prompt-TIMESTAMP.md
└── DerivedData/
    └── [Xcode build data]
```

## Agent Orchestration Workflow

### Phase 1: Analysis
- **Agent**: `code-reviewer`
- **Task**: Analyze failures, categorize issues

### Phase 2: SwiftUI Fixes
- **Agent**: `swiftui-expert`
- **Task**: Fix UI issues, navigation, accessibility

### Phase 3: Test Fixes
- **Agent**: `test-generator`
- **Task**: Fix failing tests, add coverage

### Phase 4: Performance
- **Agent**: `performance-optimizer`
- **Task**: Optimize slow operations

### Phase 5: Security
- **Agent**: `security-auditor`
- **Task**: Audit security implications

### Phase 6: Documentation
- **Agent**: `doc-generator`
- **Task**: Update documentation

## Adding Debug Logging to Views

To enable logging in SwiftUI views:

```swift
struct MyView: View {
    var body: some View {
        SomeContent()
            .logAppearance(viewName: "MyView")
            .logDisappearance(viewName: "MyView")
            .onTapGesture {
                Task { @MainActor in
                    DebugLogger.shared.logUIAction(
                        "tap",
                        view: "MyView",
                        element: "button"
                    )
                }
            }
    }
}
```

## Adding New E2E Tests

To add new tests to the automated suite:

```swift
// In AutomatedE2ETests.swift

func test_X01_NewFeature() throws {
    logTestEvent("Testing new feature")

    // Navigate to the feature
    XCTAssertTrue(navigateToSection("Feature"), "Should navigate to Feature")

    // Perform actions
    let button = app.buttons["FeatureButton"]
    XCTAssertTrue(button.waitForExistence(timeout: 5))
    button.tap()

    // Capture screenshot
    captureScreenshot(name: "new_feature_result")

    // Verify results
    let result = app.staticTexts["ExpectedResult"]
    XCTAssertTrue(result.exists, "Expected result should appear")

    logTestEvent("New feature test completed")
}
```

## Continuous Integration

### GitHub Actions Integration

```yaml
name: Automated UX Testing

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app

      - name: Run Automated Tests
        run: make test-automated

      - name: Upload Test Results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: test-output/
```

## Troubleshooting

### Common Issues

**Build Fails**
```bash
# Clean and rebuild
./scripts/automated-ux-testing.sh --clean --full
```

**Tests Timeout**
- Increase timeout values in test configuration
- Check if app is actually launching

**No Test Results**
- Verify Xcode project has test targets configured
- Check scheme settings include test targets

**Agent Prompts Not Generated**
- Ensure tests actually ran (check logs)
- Verify Python is available for report generation

### Debug Mode

Run with verbose output:
```bash
./scripts/automated-ux-testing.sh --full --verbose 2>&1 | tee debug.log
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CAPTURE_SCREENSHOTS` | Enable screenshot capture | `true` |
| `VERBOSE_LOGGING` | Enable verbose test logging | `false` |
| `UITEST_MODE` | Indicates UI test mode | `true` |
| `LOG_LEVEL` | Debug logger level | `debug` |

### Customizing Test Behavior

Edit the test configuration in `AutomatedE2ETests.swift`:

```swift
private var shouldCaptureScreenshots: Bool {
    ProcessInfo.processInfo.environment["CAPTURE_SCREENSHOTS"] == "true"
}
```

## Related Documentation

- [CLAUDE.md](/.claude/CLAUDE.md) - Development environment setup
- [Agent Orchestrator](/.cursor/agents/agent-orchestrator.md) - Agent coordination
- [SwiftUI Expert](/.cursor/agents/swiftui-expert.md) - SwiftUI guidance
- [Test Generator](/.cursor/agents/test-generator.md) - Test generation

---

*Part of the Craig-O-Clean automated development workflow powered by VibeCaaS.com*
