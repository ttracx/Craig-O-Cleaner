#!/bin/bash

# MARK: - Automated E2E Testing Script for Craig-O-Clean
# This script builds the app, runs it in simulator, executes UI tests,
# collects logs, and generates comprehensive reports

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_NAME="Craig-O-Clean"
SCHEME="Craig-O-Clean"
WORKSPACE_DIR="$PROJECT_ROOT"
REPORTS_DIR="$PROJECT_ROOT/test-reports"
LOGS_DIR="$PROJECT_ROOT/test-reports/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEST_SESSION_ID="test_${TIMESTAMP}"

# Create directories
mkdir -p "$REPORTS_DIR"
mkdir -p "$LOGS_DIR"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v xcodebuild &> /dev/null; then
        log_error "xcodebuild not found. Please install Xcode Command Line Tools."
        exit 1
    fi
    
    if ! command -v xcrun &> /dev/null; then
        log_error "xcrun not found. Please install Xcode Command Line Tools."
        exit 1
    fi
    
    if ! command -v simctl &> /dev/null; then
        log_error "simctl not found. Please install Xcode Command Line Tools."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Find available simulator
find_simulator() {
    log_info "Finding available macOS simulator..."
    
    # For macOS apps, we use the host system, but we can check for iOS simulators if needed
    # For now, we'll use the host system for macOS apps
    SIMULATOR_DEVICE="macOS"
    
    log_success "Using $SIMULATOR_DEVICE for testing"
    echo "$SIMULATOR_DEVICE"
}

# Clean build
clean_build() {
    log_info "Cleaning previous builds..."
    
    cd "$PROJECT_ROOT"
    xcodebuild clean \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Debug \
        > "$LOGS_DIR/clean_${TIMESTAMP}.log" 2>&1 || {
        log_warning "Clean had warnings, continuing..."
    }
    
    log_success "Clean completed"
}

# Build the app
build_app() {
    log_info "Building application..."
    
    cd "$PROJECT_ROOT"
    
    xcodebuild build \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -derivedDataPath "$REPORTS_DIR/derived_data" \
        > "$LOGS_DIR/build_${TIMESTAMP}.log" 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "Build completed successfully"
    else
        log_error "Build failed. Check $LOGS_DIR/build_${TIMESTAMP}.log"
        exit 1
    fi
}

# Build for testing
build_for_testing() {
    log_info "Building for testing..."
    
    cd "$PROJECT_ROOT"
    
    xcodebuild build-for-testing \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -derivedDataPath "$REPORTS_DIR/derived_data" \
        > "$LOGS_DIR/build_test_${TIMESTAMP}.log" 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "Build for testing completed"
    else
        log_error "Build for testing failed. Check $LOGS_DIR/build_test_${TIMESTAMP}.log"
        exit 1
    fi
}

# Run UI tests
run_ui_tests() {
    log_info "Running UI tests..."
    
    cd "$PROJECT_ROOT"
    
    TEST_RESULT_PATH="$REPORTS_DIR/test_results_${TIMESTAMP}"
    
    xcodebuild test \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination 'platform=macOS' \
        -resultBundlePath "$TEST_RESULT_PATH.xcresult" \
        -derivedDataPath "$REPORTS_DIR/derived_data" \
        > "$LOGS_DIR/test_${TIMESTAMP}.log" 2>&1
    
    TEST_EXIT_CODE=$?
    
    if [ $TEST_EXIT_CODE -eq 0 ]; then
        log_success "All tests passed"
    else
        log_warning "Some tests failed (exit code: $TEST_EXIT_CODE)"
    fi
    
    # Extract test results
    if [ -d "$TEST_RESULT_PATH.xcresult" ]; then
        log_info "Extracting test results..."
        
        # Use xcresulttool to get JSON output
        xcrun xcresulttool get \
            --path "$TEST_RESULT_PATH.xcresult" \
            --format json > "$REPORTS_DIR/test_results_${TIMESTAMP}.json" 2>/dev/null || {
            log_warning "Could not extract JSON results"
        }
    fi
    
    return $TEST_EXIT_CODE
}

# Collect app logs
collect_app_logs() {
    log_info "Collecting application logs..."
    
    # The app should export logs to the documents directory
    # We'll look for exported log files
    APP_LOGS_DIR="$HOME/Library/Containers/com.craigoclean.app/Data/Documents/CraigOCleanLogs"
    
    if [ -d "$APP_LOGS_DIR" ]; then
        log_info "Found app logs directory: $APP_LOGS_DIR"
        
        # Copy latest logs
        LATEST_LOG=$(ls -t "$APP_LOGS_DIR"/*.json 2>/dev/null | head -1)
        if [ -n "$LATEST_LOG" ]; then
            cp "$LATEST_LOG" "$LOGS_DIR/app_logs_${TIMESTAMP}.json"
            log_success "Copied app logs to $LOGS_DIR/app_logs_${TIMESTAMP}.json"
        fi
        
        LATEST_TEXT=$(ls -t "$APP_LOGS_DIR"/*.txt 2>/dev/null | head -1)
        if [ -n "$LATEST_TEXT" ]; then
            cp "$LATEST_TEXT" "$LOGS_DIR/app_logs_${TIMESTAMP}.txt"
            log_success "Copied app logs (text) to $LOGS_DIR/app_logs_${TIMESTAMP}.txt"
        fi
    else
        log_warning "App logs directory not found. App may not have exported logs yet."
    fi
    
    # Also collect system logs related to the app
    log_info "Collecting system logs..."
    log show --predicate 'subsystem == "com.craigoclean.app"' \
        --last 5m \
        --style syslog > "$LOGS_DIR/system_logs_${TIMESTAMP}.log" 2>/dev/null || {
        log_warning "Could not collect system logs (may require permissions)"
    }
}

# Generate test report
generate_report() {
    log_info "Generating comprehensive test report..."
    
    REPORT_FILE="$REPORTS_DIR/test_report_${TIMESTAMP}.md"
    
    cat > "$REPORT_FILE" << EOF
# Craig-O-Clean E2E Test Report

**Test Session:** $TEST_SESSION_ID  
**Timestamp:** $(date)  
**Test Duration:** $(($(date +%s) - START_TIME)) seconds

## Test Summary

EOF

    # Parse test results if available
    if [ -f "$REPORTS_DIR/test_results_${TIMESTAMP}.json" ]; then
        log_info "Parsing test results..."
        
        # Extract test statistics (basic parsing)
        TOTAL_TESTS=$(grep -o '"testStatusCount"' "$REPORTS_DIR/test_results_${TIMESTAMP}.json" | wc -l || echo "0")
        
        cat >> "$REPORT_FILE" << EOF
- **Total Tests:** $TOTAL_TESTS
- **Test Results:** Available in \`test_results_${TIMESTAMP}.xcresult\`

EOF
    fi
    
    # Add build information
    cat >> "$REPORT_FILE" << EOF
## Build Information

- **Project:** $PROJECT_NAME
- **Scheme:** $SCHEME
- **Configuration:** Debug
- **Build Log:** \`logs/build_${TIMESTAMP}.log\`

## Test Execution

- **Test Log:** \`logs/test_${TIMESTAMP}.log\`
- **Test Results Bundle:** \`test_results_${TIMESTAMP}.xcresult\`

## Application Logs

EOF

    if [ -f "$LOGS_DIR/app_logs_${TIMESTAMP}.json" ]; then
        cat >> "$REPORT_FILE" << EOF
- **App Logs (JSON):** \`logs/app_logs_${TIMESTAMP}.json\`
EOF
    fi
    
    if [ -f "$LOGS_DIR/app_logs_${TIMESTAMP}.txt" ]; then
        cat >> "$REPORT_FILE" << EOF
- **App Logs (Text):** \`logs/app_logs_${TIMESTAMP}.txt\`
EOF
    fi
    
    if [ -f "$LOGS_DIR/system_logs_${TIMESTAMP}.log" ]; then
        cat >> "$REPORT_FILE" << EOF
- **System Logs:** \`logs/system_logs_${TIMESTAMP}.log\`
EOF
    fi
    
    # Add error analysis
    cat >> "$REPORT_FILE" << EOF

## Error Analysis

EOF

    # Check for errors in test log
    if [ -f "$LOGS_DIR/test_${TIMESTAMP}.log" ]; then
        ERROR_COUNT=$(grep -i "error\|failed\|failure" "$LOGS_DIR/test_${TIMESTAMP}.log" | wc -l | tr -d ' ')
        if [ "$ERROR_COUNT" -gt 0 ]; then
            cat >> "$REPORT_FILE" << EOF
- **Errors Found:** $ERROR_COUNT
- **Error Details:** See \`logs/test_${TIMESTAMP}.log\`

EOF
            # Extract error snippets
            grep -i "error\|failed\|failure" "$LOGS_DIR/test_${TIMESTAMP}.log" | head -20 >> "$REPORT_FILE"
        else
            cat >> "$REPORT_FILE" << EOF
- **No errors found in test execution**

EOF
        fi
    fi
    
    # Add performance metrics if available
    if [ -f "$LOGS_DIR/app_logs_${TIMESTAMP}.json" ]; then
        cat >> "$REPORT_FILE" << EOF
## Performance Metrics

Performance data available in app logs JSON file.

EOF
    fi
    
    # Add next steps
    cat >> "$REPORT_FILE" << EOF
## Next Steps

1. Review the test results in \`test_results_${TIMESTAMP}.xcresult\`
2. Check application logs for runtime issues
3. Review system logs for system-level problems
4. Use the orchestrator prompt generator to create fix instructions

## Files Generated

- Test Report: \`test_report_${TIMESTAMP}.md\`
- Test Results: \`test_results_${TIMESTAMP}.xcresult\`
- Test Results (JSON): \`test_results_${TIMESTAMP}.json\`
- Build Log: \`logs/build_${TIMESTAMP}.log\`
- Test Log: \`logs/test_${TIMESTAMP}.log\`
- App Logs: \`logs/app_logs_${TIMESTAMP}.*\`
- System Logs: \`logs/system_logs_${TIMESTAMP}.log\`

EOF

    log_success "Test report generated: $REPORT_FILE"
    echo "$REPORT_FILE"
}

# Generate orchestrator prompt
generate_orchestrator_prompt() {
    log_info "Generating orchestrator prompt for issue resolution..."
    
    PROMPT_FILE="$REPORTS_DIR/orchestrator_prompt_${TIMESTAMP}.md"
    REPORT_FILE="$REPORTS_DIR/test_report_${TIMESTAMP}.md"
    
    cat > "$PROMPT_FILE" << EOF
# Agent Orchestrator Task: Fix Issues from E2E Testing

## Context

This task is generated from automated E2E testing of the Craig-O-Clean macOS application.
The testing has identified issues that need to be addressed by the appropriate specialized agents.

## Test Session Information

- **Session ID:** $TEST_SESSION_ID
- **Timestamp:** $(date)
- **Test Report:** \`test_report_${TIMESTAMP}.md\`

## Issues Identified

EOF

    # Extract issues from test log
    if [ -f "$LOGS_DIR/test_${TIMESTAMP}.log" ]; then
        grep -i "error\|failed\|failure\|assertion" "$LOGS_DIR/test_${TIMESTAMP}.log" | head -50 >> "$PROMPT_FILE"
    fi
    
    # Extract issues from app logs if available
    if [ -f "$LOGS_DIR/app_logs_${TIMESTAMP}.json" ]; then
        cat >> "$PROMPT_FILE" << EOF

## Application Log Errors

See \`logs/app_logs_${TIMESTAMP}.json\` for detailed application errors and stack traces.

EOF
    fi
    
    cat >> "$PROMPT_FILE" << EOF

## Required Agent Actions

Please use the agent orchestrator (@.cursor/agents/agent-orchestrator.md) to coordinate the following agents:

1. **@.cursor/agents/code-reviewer.md** - Review code for issues identified in tests
2. **@.cursor/agents/swiftui-expert.md** - Fix UI/UX issues and SwiftUI-specific problems
3. **@.cursor/agents/test-generator.md** - Improve test coverage and fix failing tests
4. **@.cursor/agents/performance-optimizer.md** - Address performance issues found in metrics
5. **@.cursor/agents/doc-generator.md** - Update documentation based on findings
6. **@.cursor/agents/api-designer.md** - Review and fix API/service layer issues
7. **@.cursor/agents/security-auditor.md** - Review security implications of any changes

## Orchestration Instructions

\`\`\`
@agent-orchestrator

Task: Fix issues identified in E2E testing session $TEST_SESSION_ID

Context:
- Test report: test_report_${TIMESTAMP}.md
- Test results: test_results_${TIMESTAMP}.xcresult
- Application logs: logs/app_logs_${TIMESTAMP}.json
- System logs: logs/system_logs_${TIMESTAMP}.log

Requirements:
1. Analyze all test failures and errors
2. Review application logs for runtime issues
3. Coordinate appropriate agents to fix identified issues
4. Ensure fixes are properly tested
5. Update documentation as needed
6. Perform security review of changes

Expected Output:
- Fixed code with explanations
- Updated tests
- Documentation updates
- Security audit results
\`\`\`

## Files Reference

All test artifacts are in: \`$REPORTS_DIR\`

- Test Report: \`test_report_${TIMESTAMP}.md\`
- Test Results Bundle: \`test_results_${TIMESTAMP}.xcresult\`
- Test Results JSON: \`test_results_${TIMESTAMP}.json\`
- Build Log: \`logs/build_${TIMESTAMP}.log\`
- Test Execution Log: \`logs/test_${TIMESTAMP}.log\`
- Application Logs: \`logs/app_logs_${TIMESTAMP}.*\`
- System Logs: \`logs/system_logs_${TIMESTAMP}.log\`

## Next Steps

1. Review the orchestrator prompt above
2. Execute the orchestration command in Cursor
3. Review agent outputs and apply fixes
4. Re-run tests to verify fixes
5. Iterate until all issues are resolved

EOF

    log_success "Orchestrator prompt generated: $PROMPT_FILE"
    echo "$PROMPT_FILE"
}

# Main execution
main() {
    log_info "=========================================="
    log_info "Craig-O-Clean Automated E2E Testing"
    log_info "=========================================="
    log_info "Session ID: $TEST_SESSION_ID"
    log_info "Timestamp: $(date)"
    log_info ""
    
    START_TIME=$(date +%s)
    
    # Execute test pipeline
    check_prerequisites
    find_simulator > /dev/null
    clean_build
    build_app
    build_for_testing
    run_ui_tests
    TEST_EXIT_CODE=$?
    collect_app_logs
    REPORT_FILE=$(generate_report)
    PROMPT_FILE=$(generate_orchestrator_prompt)
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    log_info ""
    log_info "=========================================="
    log_info "Test Execution Complete"
    log_info "=========================================="
    log_info "Duration: ${DURATION}s"
    log_info "Report: $REPORT_FILE"
    log_info "Orchestrator Prompt: $PROMPT_FILE"
    
    if [ $TEST_EXIT_CODE -eq 0 ]; then
        log_success "All tests passed!"
        exit 0
    else
        log_warning "Some tests failed. Review the report and use the orchestrator prompt to fix issues."
        exit $TEST_EXIT_CODE
    fi
}

# Run main
main "$@"
