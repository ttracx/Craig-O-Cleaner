# Automated Testing and Debugging System

This directory contains comprehensive automated testing and debugging infrastructure for Craig-O-Clean.

## Overview

The testing system provides:
- **Automated E2E Testing** - Runs the app in simulator and executes UI tests
- **Comprehensive Logging** - Real-time logging with export capabilities
- **Issue Analysis** - Automated analysis of test results and logs
- **Orchestrator Integration** - Generates prompts for multi-agent issue resolution
- **Continuous Testing** - Watch mode and interval-based testing

## Components

### 1. AppLogger (`Core/AppLogger.swift`)

Comprehensive logging system integrated into the app:

**Features:**
- Multiple log levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- Performance metrics tracking
- UI event tracking
- Export to JSON, Text, or CSV formats
- Real-time log collection
- Error stack traces
- Session-based logging

**Usage:**
```swift
// Basic logging
AppLogger.shared.info("Operation completed", category: "ProcessManager")
AppLogger.shared.error("Failed to load data", category: "DataService", error: error)

// Performance tracking
let tracker = AppLogger.shared.startPerformanceTracking(operation: "LoadProcesses")
// ... do work ...
tracker.end()

// UI event tracking
AppLogger.shared.trackUIEvent(
    eventType: "button_tap",
    viewName: "DashboardView",
    action: "refresh_button"
)

// Export logs
let logURL = try AppLogger.shared.exportLogs(format: .json)
```

### 2. Automated E2E Test Script (`automated-e2e-test.sh`)

Runs comprehensive end-to-end testing:

**Features:**
- Builds the application
- Launches in simulator
- Executes UI tests
- Collects application logs
- Collects system logs
- Generates test reports
- Creates orchestrator prompts

**Usage:**
```bash
./scripts/automated-e2e-test.sh
```

**Output:**
- Test reports in `test-reports/`
- Logs in `test-reports/logs/`
- Orchestrator prompt in `test-reports/orchestrator_prompt_*.md`

### 3. Test Result Analyzer (`analyze_test_results.py`)

Analyzes test results and generates detailed issue reports:

**Features:**
- Parses test results (xcresult)
- Analyzes application logs
- Categorizes issues by severity
- Identifies performance issues
- Generates orchestrator prompts

**Usage:**
```bash
python3 scripts/analyze_test_results.py test-reports/
```

**Output:**
- Issue report JSON: `test-reports/issue_report_*.json`
- Orchestrator prompt: `test-reports/orchestrator_prompt_*.md`

### 4. Continuous Testing (`continuous-testing.sh`)

Runs tests continuously in watch or interval mode:

**Features:**
- Watch mode (runs on file changes)
- Interval mode (runs on schedule)
- Automatic result analysis
- Orchestrator prompt generation

**Usage:**
```bash
# Watch mode (runs on file changes)
WATCH_MODE=true ./scripts/continuous-testing.sh

# Interval mode (runs every 5 minutes)
INTERVAL=300 ./scripts/continuous-testing.sh

# Limited iterations
MAX_ITERATIONS=10 ./scripts/continuous-testing.sh
```

## Workflow

### Standard Testing Workflow

1. **Run Tests:**
   ```bash
   ./scripts/automated-e2e-test.sh
   ```

2. **Analyze Results:**
   ```bash
   python3 scripts/analyze_test_results.py test-reports/
   ```

3. **Review Orchestrator Prompt:**
   - Open `test-reports/orchestrator_prompt_*.md`
   - Copy the orchestration command
   - Run in Cursor with agent orchestrator

4. **Apply Fixes:**
   - Review agent outputs
   - Apply code fixes
   - Update tests if needed

5. **Re-run Tests:**
   ```bash
   ./scripts/automated-e2e-test.sh
   ```

### Continuous Testing Workflow

1. **Start Continuous Testing:**
   ```bash
   WATCH_MODE=true ./scripts/continuous-testing.sh
   ```

2. **Make Code Changes:**
   - Tests run automatically on file changes
   - Results are analyzed automatically
   - Orchestrator prompts are generated

3. **Review and Fix:**
   - Check latest orchestrator prompt
   - Apply fixes
   - Tests re-run automatically

## Orchestrator Integration

The system generates prompts that use the agent orchestrator to coordinate multiple specialized agents:

### Agents Used

1. **@.cursor/agents/code-reviewer.md** - Code review and fixes
2. **@.cursor/agents/swiftui-expert.md** - UI/UX fixes
3. **@.cursor/agents/test-generator.md** - Test improvements
4. **@.cursor/agents/performance-optimizer.md** - Performance optimization
5. **@.cursor/agents/doc-generator.md** - Documentation updates
6. **@.cursor/agents/api-designer.md** - API/service fixes
7. **@.cursor/agents/security-auditor.md** - Security review

### Using Orchestrator Prompts

1. Open the generated orchestrator prompt file
2. Copy the orchestration command
3. Paste into Cursor chat
4. The orchestrator will coordinate agents to fix issues
5. Review and apply the fixes
6. Re-run tests to verify

## Log Export

The app automatically exports logs to:
- `~/Library/Containers/com.craigoclean.app/Data/Documents/CraigOCleanLogs/`

The testing script automatically collects these logs.

### Manual Export

You can also export logs programmatically:
```swift
let logURL = try AppLogger.shared.exportLogs(format: .json)
// Share or upload logURL
```

## Report Structure

### Test Report (`test_report_*.md`)

- Test summary
- Build information
- Test execution details
- Application logs
- Error analysis
- Performance metrics
- Next steps

### Issue Report (`issue_report_*.json`)

- Issue categorization
- Severity levels
- Error details
- Performance issues
- UI issues
- Recommendations

### Orchestrator Prompt (`orchestrator_prompt_*.md`)

- Context and summary
- Critical issues
- High priority issues
- Performance issues
- Agent coordination instructions
- Orchestration command

## Configuration

### Environment Variables

- `WATCH_MODE` - Enable watch mode (true/false)
- `INTERVAL` - Interval between test runs in seconds (default: 300)
- `MAX_ITERATIONS` - Maximum test cycles (0 = infinite)

### Logging Configuration

Logging is configured in `AppLogger.swift`:
- `maxLogEntries` - Maximum in-memory log entries (default: 10000)
- `maxPerformanceMetrics` - Maximum performance metrics (default: 5000)
- `maxUIEvents` - Maximum UI events (default: 5000)

## Best Practices

1. **Run Tests Before Committing:**
   ```bash
   ./scripts/automated-e2e-test.sh
   ```

2. **Use Continuous Testing During Development:**
   ```bash
   WATCH_MODE=true ./scripts/continuous-testing.sh
   ```

3. **Review Orchestrator Prompts:**
   - Always review generated prompts before applying fixes
   - Verify agent recommendations make sense

4. **Export Logs for Debugging:**
   - Export logs when encountering issues
   - Include logs in bug reports

5. **Monitor Performance:**
   - Review performance metrics regularly
   - Address slow operations proactively

## Troubleshooting

### Tests Not Running

- Check Xcode Command Line Tools are installed
- Verify project builds successfully
- Check simulator is available

### Logs Not Collected

- Verify app has run and exported logs
- Check app sandbox permissions
- Verify log export directory exists

### Analysis Fails

- Ensure Python 3 is installed
- Check JSON files are valid
- Verify file permissions

## Integration with CI/CD

The testing scripts can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run E2E Tests
  run: ./scripts/automated-e2e-test.sh

- name: Analyze Results
  run: python3 scripts/analyze_test_results.py test-reports/

- name: Upload Reports
  uses: actions/upload-artifact@v3
  with:
    path: test-reports/
```

## Future Enhancements

- [ ] Screenshot capture on test failures
- [ ] Video recording of test execution
- [ ] Integration with crash reporting
- [ ] Real-time log streaming
- [ ] Web dashboard for test results
- [ ] Automated fix application (with review)
