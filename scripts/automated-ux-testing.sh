#!/bin/bash

# =============================================================================
# Craig-O-Clean Automated UX & App Testing Script
# =============================================================================
# This script performs comprehensive end-to-end testing of the Craig-O-Clean
# macOS application, generates detailed reports, and creates instructional
# prompts for the agent orchestration system.
#
# Usage: ./scripts/automated-ux-testing.sh [options]
#
# Options:
#   --full          Run full test suite (default)
#   --quick         Run quick sanity tests only
#   --report-only   Generate report from existing test results
#   --clean         Clean build artifacts before testing
#   --verbose       Enable verbose logging
#   --help          Show this help message
# =============================================================================

set -e

# =============================================================================
# Configuration
# =============================================================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="Craig-O-Clean"
SCHEME_NAME="Craig-O-Clean"
XCODEPROJ_PATH="${PROJECT_DIR}/Craig-O-Clean.xcodeproj"

# Output directories
OUTPUT_DIR="${PROJECT_DIR}/test-output"
REPORTS_DIR="${OUTPUT_DIR}/reports"
LOGS_DIR="${OUTPUT_DIR}/logs"
SCREENSHOTS_DIR="${OUTPUT_DIR}/screenshots"
AGENTS_OUTPUT_DIR="${OUTPUT_DIR}/agent-prompts"

# Timestamps
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
TEST_RUN_ID="test-run-${TIMESTAMP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default options
RUN_MODE="full"
CLEAN_BUILD=false
VERBOSE=false

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[${timestamp}] [${level}] ${message}" >> "${LOGS_DIR}/${TEST_RUN_ID}.log"

    if [[ "$VERBOSE" == "true" ]]; then
        echo "[${timestamp}] [${level}] ${message}"
    fi
}

setup_directories() {
    print_step "Setting up output directories..."

    mkdir -p "${OUTPUT_DIR}"
    mkdir -p "${REPORTS_DIR}"
    mkdir -p "${LOGS_DIR}"
    mkdir -p "${SCREENSHOTS_DIR}"
    mkdir -p "${AGENTS_OUTPUT_DIR}"

    log "INFO" "Created output directories"
    print_success "Output directories created"
}

show_help() {
    cat << EOF
Craig-O-Clean Automated UX & App Testing Script

Usage: $0 [options]

Options:
  --full          Run full test suite (default)
  --quick         Run quick sanity tests only
  --report-only   Generate report from existing test results
  --clean         Clean build artifacts before testing
  --verbose       Enable verbose logging
  --help          Show this help message

Examples:
  $0                    # Run full test suite
  $0 --quick            # Run quick tests only
  $0 --clean --verbose  # Clean build and run with verbose output

EOF
}

# =============================================================================
# Parse Arguments
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            RUN_MODE="full"
            shift
            ;;
        --quick)
            RUN_MODE="quick"
            shift
            ;;
        --report-only)
            RUN_MODE="report-only"
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# =============================================================================
# Main Functions
# =============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check Xcode
    if ! command -v xcodebuild &> /dev/null; then
        print_error "xcodebuild not found. Please install Xcode Command Line Tools."
        exit 1
    fi
    print_success "Xcode Command Line Tools found"

    # Check Xcode project exists
    if [[ ! -d "${XCODEPROJ_PATH}" ]]; then
        print_error "Xcode project not found at: ${XCODEPROJ_PATH}"
        exit 1
    fi
    print_success "Xcode project found"

    # Check jq for JSON processing
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found. Installing via Homebrew..."
        if command -v brew &> /dev/null; then
            brew install jq
        else
            print_warning "Homebrew not found. JSON processing may be limited."
        fi
    fi

    # Print Xcode version
    XCODE_VERSION=$(xcodebuild -version | head -1)
    print_info "Using: ${XCODE_VERSION}"

    log "INFO" "Prerequisites check passed"
}

clean_build() {
    if [[ "$CLEAN_BUILD" == "true" ]]; then
        print_header "Cleaning Build Artifacts"

        print_step "Running xcodebuild clean..."
        xcodebuild clean \
            -project "${XCODEPROJ_PATH}" \
            -scheme "${SCHEME_NAME}" \
            -configuration Debug \
            2>&1 | tee -a "${LOGS_DIR}/${TEST_RUN_ID}-clean.log"

        print_success "Build artifacts cleaned"
        log "INFO" "Build cleaned"
    fi
}

build_app() {
    print_header "Building Application"

    print_step "Building ${PROJECT_NAME}..."

    BUILD_LOG="${LOGS_DIR}/${TEST_RUN_ID}-build.log"

    xcodebuild build \
        -project "${XCODEPROJ_PATH}" \
        -scheme "${SCHEME_NAME}" \
        -configuration Debug \
        -derivedDataPath "${OUTPUT_DIR}/DerivedData" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        2>&1 | tee "${BUILD_LOG}"

    BUILD_RESULT=${PIPESTATUS[0]}

    if [[ $BUILD_RESULT -eq 0 ]]; then
        print_success "Application built successfully"
        log "INFO" "Build succeeded"
    else
        print_error "Build failed. Check ${BUILD_LOG} for details."
        log "ERROR" "Build failed"
        generate_build_error_report "${BUILD_LOG}"
        exit 1
    fi
}

run_unit_tests() {
    print_header "Running Unit Tests"

    print_step "Executing unit tests..."

    UNIT_TEST_LOG="${LOGS_DIR}/${TEST_RUN_ID}-unit-tests.log"
    UNIT_TEST_RESULT_PATH="${OUTPUT_DIR}/unit-test-results"

    mkdir -p "${UNIT_TEST_RESULT_PATH}"

    xcodebuild test \
        -project "${XCODEPROJ_PATH}" \
        -scheme "${SCHEME_NAME}" \
        -configuration Debug \
        -derivedDataPath "${OUTPUT_DIR}/DerivedData" \
        -resultBundlePath "${UNIT_TEST_RESULT_PATH}/unit-tests.xcresult" \
        -only-testing:"CraigOCleanTests" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        2>&1 | tee "${UNIT_TEST_LOG}"

    UNIT_TEST_RESULT=${PIPESTATUS[0]}

    if [[ $UNIT_TEST_RESULT -eq 0 ]]; then
        print_success "Unit tests passed"
        log "INFO" "Unit tests passed"
    else
        print_warning "Some unit tests failed"
        log "WARNING" "Unit tests had failures"
    fi

    return $UNIT_TEST_RESULT
}

run_ui_tests() {
    print_header "Running UI/E2E Tests"

    print_step "Executing automated E2E tests..."

    UI_TEST_LOG="${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log"
    UI_TEST_RESULT_PATH="${OUTPUT_DIR}/ui-test-results"

    mkdir -p "${UI_TEST_RESULT_PATH}"

    # Run UI tests with screenshot capture
    xcodebuild test \
        -project "${XCODEPROJ_PATH}" \
        -scheme "${SCHEME_NAME}" \
        -configuration Debug \
        -derivedDataPath "${OUTPUT_DIR}/DerivedData" \
        -resultBundlePath "${UI_TEST_RESULT_PATH}/ui-tests.xcresult" \
        -only-testing:"CraigOCleanUITests" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CAPTURE_SCREENSHOTS=true \
        VERBOSE_LOGGING=true \
        2>&1 | tee "${UI_TEST_LOG}"

    UI_TEST_RESULT=${PIPESTATUS[0]}

    if [[ $UI_TEST_RESULT -eq 0 ]]; then
        print_success "UI tests passed"
        log "INFO" "UI tests passed"
    else
        print_warning "Some UI tests failed"
        log "WARNING" "UI tests had failures"
    fi

    return $UI_TEST_RESULT
}

extract_test_results() {
    print_header "Extracting Test Results"

    print_step "Processing test results..."

    # Extract results from xcresult bundles
    local result_bundle="${OUTPUT_DIR}/ui-test-results/ui-tests.xcresult"

    if [[ -d "${result_bundle}" ]]; then
        # Export test summary
        xcrun xcresulttool get --format json --path "${result_bundle}" > "${REPORTS_DIR}/test-results-raw.json" 2>/dev/null || true

        # Extract screenshots
        print_step "Extracting screenshots..."
        xcrun xcresulttool get --path "${result_bundle}" --format json --type activityLog > "${REPORTS_DIR}/activity-log.json" 2>/dev/null || true

        print_success "Test results extracted"
    else
        print_warning "No test result bundle found"
    fi

    log "INFO" "Test results extracted"
}

collect_app_logs() {
    print_header "Collecting Application Logs"

    print_step "Gathering debug logs from app..."

    # Find app support directory logs
    APP_SUPPORT_LOGS="${HOME}/Library/Application Support/CraigOClean/Logs"

    if [[ -d "${APP_SUPPORT_LOGS}" ]]; then
        cp -r "${APP_SUPPORT_LOGS}"/* "${LOGS_DIR}/" 2>/dev/null || true
        print_success "App logs collected"
    else
        print_info "No app logs found (app may not have run yet)"
    fi

    # Collect system logs related to the app
    print_step "Collecting system logs..."
    log show --predicate 'subsystem == "com.craigoclean"' --last 1h > "${LOGS_DIR}/system-logs.txt" 2>/dev/null || true

    log "INFO" "Application logs collected"
}

generate_test_report() {
    print_header "Generating Test Report"

    print_step "Creating comprehensive test report..."

    REPORT_FILE="${REPORTS_DIR}/test-report-${TIMESTAMP}.md"
    HTML_REPORT="${REPORTS_DIR}/test-report-${TIMESTAMP}.html"
    JSON_REPORT="${REPORTS_DIR}/test-report-${TIMESTAMP}.json"

    # Parse test logs to extract results
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local test_details=""

    # Count tests from UI test log
    if [[ -f "${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log" ]]; then
        total_tests=$(grep -c "Test Case" "${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log" 2>/dev/null || echo "0")
        passed_tests=$(grep -c "passed" "${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log" 2>/dev/null || echo "0")
        failed_tests=$(grep -c "failed" "${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log" 2>/dev/null || echo "0")
    fi

    # Generate Markdown report
    cat > "${REPORT_FILE}" << EOF
# Craig-O-Clean Automated Test Report

## Test Run Summary

- **Test Run ID:** ${TEST_RUN_ID}
- **Timestamp:** $(date)
- **Run Mode:** ${RUN_MODE}
- **Total Tests:** ${total_tests}
- **Passed:** ${passed_tests}
- **Failed:** ${failed_tests}
- **Pass Rate:** $(echo "scale=2; ${passed_tests} * 100 / (${total_tests} + 1)" | bc 2>/dev/null || echo "N/A")%

## Environment

- **macOS Version:** $(sw_vers -productVersion)
- **Xcode Version:** $(xcodebuild -version | head -1)
- **Project:** ${PROJECT_NAME}
- **Scheme:** ${SCHEME_NAME}

## Test Categories

### Unit Tests
$(grep -E "(Test Case|passed|failed)" "${LOGS_DIR}/${TEST_RUN_ID}-unit-tests.log" 2>/dev/null | head -50 || echo "No unit test results available")

### UI/E2E Tests
$(grep -E "(Test Case|passed|failed)" "${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log" 2>/dev/null | head -50 || echo "No UI test results available")

## Issues Found

### Critical Issues
$(grep -E "(CRITICAL|ERROR|FAILED)" "${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log" 2>/dev/null | head -20 || echo "No critical issues found")

### Warnings
$(grep -E "(WARNING|warn)" "${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log" 2>/dev/null | head -20 || echo "No warnings found")

## Performance Metrics

- **Build Time:** $(grep -E "Build Succeeded" "${LOGS_DIR}/${TEST_RUN_ID}-build.log" 2>/dev/null | head -1 || echo "N/A")
- **Test Execution Time:** ${SECONDS}s

## Log Files

- Build Log: \`${LOGS_DIR}/${TEST_RUN_ID}-build.log\`
- Unit Test Log: \`${LOGS_DIR}/${TEST_RUN_ID}-unit-tests.log\`
- UI Test Log: \`${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log\`

## Screenshots

Screenshots are available in: \`${SCREENSHOTS_DIR}/\`

---
*Report generated by Craig-O-Clean Automated Testing System*
EOF

    print_success "Test report generated: ${REPORT_FILE}"

    # Generate JSON report for programmatic consumption
    cat > "${JSON_REPORT}" << EOF
{
    "testRunId": "${TEST_RUN_ID}",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "runMode": "${RUN_MODE}",
    "environment": {
        "macOSVersion": "$(sw_vers -productVersion)",
        "xcodeVersion": "$(xcodebuild -version | head -1)",
        "project": "${PROJECT_NAME}",
        "scheme": "${SCHEME_NAME}"
    },
    "summary": {
        "totalTests": ${total_tests},
        "passed": ${passed_tests},
        "failed": ${failed_tests},
        "executionTimeSeconds": ${SECONDS}
    },
    "reportFiles": {
        "markdown": "${REPORT_FILE}",
        "json": "${JSON_REPORT}",
        "buildLog": "${LOGS_DIR}/${TEST_RUN_ID}-build.log",
        "unitTestLog": "${LOGS_DIR}/${TEST_RUN_ID}-unit-tests.log",
        "uiTestLog": "${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log"
    }
}
EOF

    print_success "JSON report generated: ${JSON_REPORT}"
    log "INFO" "Test reports generated"
}

generate_build_error_report() {
    local build_log=$1

    print_step "Generating build error report..."

    ERROR_REPORT="${REPORTS_DIR}/build-errors-${TIMESTAMP}.md"

    cat > "${ERROR_REPORT}" << EOF
# Craig-O-Clean Build Error Report

## Build Failed

**Timestamp:** $(date)

## Errors

\`\`\`
$(grep -E "(error:|Error:|ERROR)" "${build_log}" 2>/dev/null || echo "No specific errors extracted")
\`\`\`

## Full Build Log

See: ${build_log}

---
*This report requires agent review for fixes*
EOF

    print_error "Build error report: ${ERROR_REPORT}"
}

generate_agent_prompt() {
    print_header "Generating Agent Orchestration Prompt"

    print_step "Creating instructional prompt for agent system..."

    AGENT_PROMPT_FILE="${AGENTS_OUTPUT_DIR}/agent-orchestration-prompt-${TIMESTAMP}.md"

    # Collect error information
    local errors=""
    local warnings=""
    local failed_tests=""

    if [[ -f "${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log" ]]; then
        errors=$(grep -E "(error:|Error:|ERROR|FAILED)" "${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log" 2>/dev/null | head -30 || echo "")
        warnings=$(grep -E "(warning:|Warning:|WARNING)" "${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log" 2>/dev/null | head -30 || echo "")
        failed_tests=$(grep -E "Test Case.*failed" "${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log" 2>/dev/null || echo "")
    fi

    # Also check build log
    if [[ -f "${LOGS_DIR}/${TEST_RUN_ID}-build.log" ]]; then
        local build_errors=$(grep -E "(error:|Error:)" "${LOGS_DIR}/${TEST_RUN_ID}-build.log" 2>/dev/null | head -20 || echo "")
        if [[ -n "$build_errors" ]]; then
            errors="${errors}

### Build Errors
${build_errors}"
        fi
    fi

    cat > "${AGENT_PROMPT_FILE}" << 'PROMPT_START'
# Craig-O-Clean Automated Test Results - Agent Orchestration Request

## Context

This prompt is generated by the automated UX testing system for Craig-O-Clean.
The testing pipeline has completed and requires agent intervention to address
identified issues.

## Test Run Information

PROMPT_START

    cat >> "${AGENT_PROMPT_FILE}" << EOF
- **Test Run ID:** ${TEST_RUN_ID}
- **Timestamp:** $(date)
- **Run Mode:** ${RUN_MODE}
- **Duration:** ${SECONDS}s

## Issues Requiring Attention

### Errors Detected
\`\`\`
${errors:-No errors detected}
\`\`\`

### Warnings Detected
\`\`\`
${warnings:-No warnings detected}
\`\`\`

### Failed Tests
\`\`\`
${failed_tests:-No failed tests}
\`\`\`

## Agent Orchestration Instructions

Using the @.cursor/agents/agent-orchestrator.md, please route this task to
the appropriate specialized agents:

### Recommended Agent Workflow

1. **@.cursor/agents/code-reviewer.md**
   - Review all code changes related to failed tests
   - Identify code quality issues
   - Check for SOLID principle violations

2. **@.cursor/agents/swiftui-expert.md**
   - Analyze SwiftUI view issues
   - Fix UI rendering problems
   - Optimize view performance
   - Address accessibility issues

3. **@.cursor/agents/test-generator.md**
   - Analyze failing test cases
   - Generate additional test coverage
   - Create edge case tests

4. **@.cursor/agents/performance-optimizer.md**
   - Analyze performance bottlenecks
   - Optimize slow operations
   - Review memory usage patterns

5. **@.cursor/agents/security-auditor.md**
   - Check for security vulnerabilities
   - Review permission handling
   - Validate data protection

6. **@.cursor/agents/doc-generator.md**
   - Update documentation for fixes
   - Document new test cases
   - Update API documentation

7. **@.cursor/agents/api-designer.md**
   - Review API contract issues
   - Validate endpoint responses
   - Check error handling

## Execution Plan

### Phase 1: Analysis
- Agent: code-reviewer
- Task: Analyze all errors and warnings from test output
- Input: Test logs and error reports

### Phase 2: SwiftUI Fixes
- Agent: swiftui-expert
- Task: Fix UI-related issues identified in E2E tests
- Dependencies: Phase 1 output

### Phase 3: Test Fixes
- Agent: test-generator
- Task: Fix or update failing tests
- Dependencies: Phase 2 output

### Phase 4: Performance Review
- Agent: performance-optimizer
- Task: Optimize any performance issues
- Dependencies: Phase 3 output

### Phase 5: Security Check
- Agent: security-auditor
- Task: Security audit of changes
- Dependencies: Phase 4 output

### Phase 6: Documentation
- Agent: doc-generator
- Task: Update documentation
- Dependencies: Phase 5 output

## Reference Files

- Test Report: \`${REPORTS_DIR}/test-report-${TIMESTAMP}.md\`
- JSON Report: \`${REPORTS_DIR}/test-report-${TIMESTAMP}.json\`
- Build Log: \`${LOGS_DIR}/${TEST_RUN_ID}-build.log\`
- UI Test Log: \`${LOGS_DIR}/${TEST_RUN_ID}-ui-tests.log\`

## Project Structure

- Main App: \`Craig-O-Clean/\`
- Core Services: \`Craig-O-Clean/Core/\`
- UI Views: \`Craig-O-Clean/UI/\`
- Tests: \`Tests/\`
- Agent Definitions: \`.cursor/agents/\`

## Success Criteria

1. All previously failing tests pass
2. No new errors or warnings introduced
3. Code review approval
4. Documentation updated
5. Performance metrics maintained or improved

---
*Generated by Craig-O-Clean Automated Testing System*
*Use with @.cursor/agents/agent-orchestrator.md for coordinated fixes*
EOF

    print_success "Agent prompt generated: ${AGENT_PROMPT_FILE}"
    log "INFO" "Agent orchestration prompt generated"

    # Also create a simplified version for quick reference
    QUICK_PROMPT="${AGENTS_OUTPUT_DIR}/quick-fix-prompt-${TIMESTAMP}.md"

    cat > "${QUICK_PROMPT}" << EOF
# Quick Fix Request

## Command for Agent Orchestrator

ORCHESTRATE the following task using appropriate agents:

Review and fix the Craig-O-Clean test failures from test run ${TEST_RUN_ID}.

### Priority Issues:
${failed_tests:-No failed tests - verification run}

### Error Summary:
$(echo "${errors}" | head -10)

### Recommended Agents:
1. swiftui-expert - For UI fixes
2. code-reviewer - For code quality
3. test-generator - For test fixes
4. performance-optimizer - For performance issues

### Test Report Location:
${REPORTS_DIR}/test-report-${TIMESTAMP}.md

EOF

    print_success "Quick prompt generated: ${QUICK_PROMPT}"
}

run_quick_tests() {
    print_header "Running Quick Sanity Tests"

    print_step "Building for quick test..."
    build_app

    print_step "Running critical path tests only..."

    UI_TEST_LOG="${LOGS_DIR}/${TEST_RUN_ID}-quick-tests.log"

    # Run only critical tests
    xcodebuild test \
        -project "${XCODEPROJ_PATH}" \
        -scheme "${SCHEME_NAME}" \
        -configuration Debug \
        -derivedDataPath "${OUTPUT_DIR}/DerivedData" \
        -only-testing:"CraigOCleanUITests/AutomatedE2ETests/test_A01_AppLaunch" \
        -only-testing:"CraigOCleanUITests/AutomatedE2ETests/test_B02_AllNavigationItemsPresent" \
        -only-testing:"CraigOCleanUITests/AutomatedE2ETests/test_J01_FullUserJourney" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        2>&1 | tee "${UI_TEST_LOG}"

    return ${PIPESTATUS[0]}
}

print_summary() {
    print_header "Test Run Summary"

    echo ""
    echo -e "${CYAN}Test Run ID:${NC} ${TEST_RUN_ID}"
    echo -e "${CYAN}Duration:${NC} ${SECONDS}s"
    echo -e "${CYAN}Reports:${NC} ${REPORTS_DIR}"
    echo -e "${CYAN}Logs:${NC} ${LOGS_DIR}"
    echo -e "${CYAN}Agent Prompts:${NC} ${AGENTS_OUTPUT_DIR}"
    echo ""

    if [[ -f "${REPORTS_DIR}/test-report-${TIMESTAMP}.md" ]]; then
        print_success "Test report: ${REPORTS_DIR}/test-report-${TIMESTAMP}.md"
    fi

    if [[ -f "${AGENTS_OUTPUT_DIR}/agent-orchestration-prompt-${TIMESTAMP}.md" ]]; then
        print_success "Agent prompt: ${AGENTS_OUTPUT_DIR}/agent-orchestration-prompt-${TIMESTAMP}.md"
    fi

    echo ""
    print_info "To use with Cursor agents, copy the agent prompt content and use:"
    echo -e "  ${YELLOW}@.cursor/agents/agent-orchestrator.md${NC}"
    echo ""
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    print_header "Craig-O-Clean Automated UX Testing"

    echo "Test Run ID: ${TEST_RUN_ID}"
    echo "Mode: ${RUN_MODE}"
    echo ""

    SECONDS=0

    # Setup
    setup_directories
    check_prerequisites
    clean_build

    # Run tests based on mode
    case "${RUN_MODE}" in
        full)
            build_app
            run_unit_tests || true
            run_ui_tests || true
            ;;
        quick)
            run_quick_tests || true
            ;;
        report-only)
            print_info "Generating report from existing results..."
            ;;
    esac

    # Post-test processing
    extract_test_results
    collect_app_logs
    generate_test_report
    generate_agent_prompt

    # Summary
    print_summary

    log "INFO" "Test run completed in ${SECONDS}s"

    print_success "Automated testing completed!"
}

# Run main function
main "$@"
