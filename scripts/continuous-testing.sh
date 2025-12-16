#!/bin/bash

# MARK: - Continuous Testing Script
# Runs automated tests in a loop, analyzes results, and generates orchestrator prompts
# Can be configured to run on file changes or on a schedule

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORTS_DIR="$PROJECT_ROOT/test-reports"

# Configuration
WATCH_MODE=${WATCH_MODE:-false}
INTERVAL=${INTERVAL:-300}  # 5 minutes default
MAX_ITERATIONS=${MAX_ITERATIONS:-0}  # 0 = infinite

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

run_test_cycle() {
    local iteration=$1
    
    log_info "=========================================="
    log_info "Test Cycle #$iteration"
    log_info "=========================================="
    
    # Run automated E2E test
    "$SCRIPT_DIR/automated-e2e-test.sh"
    TEST_EXIT_CODE=$?
    
    # Analyze results
    log_info "Analyzing test results..."
    python3 "$SCRIPT_DIR/analyze_test_results.py" "$REPORTS_DIR"
    
    if [ $TEST_EXIT_CODE -eq 0 ]; then
        log_success "All tests passed in cycle #$iteration"
        return 0
    else
        log_warning "Some tests failed in cycle #$iteration"
        return $TEST_EXIT_CODE
    fi
}

watch_mode() {
    log_info "Starting watch mode - monitoring for file changes..."
    
    # Use fswatch if available, otherwise fall back to polling
    if command -v fswatch &> /dev/null; then
        log_info "Using fswatch for file monitoring"
        fswatch -o "$PROJECT_ROOT/Craig-O-Clean" | while read; do
            log_info "File change detected, running tests..."
            run_test_cycle "watch_$(date +%s)"
        done
    else
        log_warning "fswatch not found, using polling mode"
        interval_mode
    fi
}

interval_mode() {
    log_info "Starting interval mode - running tests every ${INTERVAL}s"
    
    local iteration=0
    
    while true; do
        iteration=$((iteration + 1))
        
        if [ $MAX_ITERATIONS -gt 0 ] && [ $iteration -gt $MAX_ITERATIONS ]; then
            log_info "Reached maximum iterations ($MAX_ITERATIONS), stopping"
            break
        fi
        
        run_test_cycle $iteration
        
        if [ $WATCH_MODE = false ]; then
            log_info "Waiting ${INTERVAL}s before next test cycle..."
            sleep $INTERVAL
        fi
    done
}

main() {
    log_info "Craig-O-Clean Continuous Testing"
    log_info "Project: $PROJECT_ROOT"
    log_info "Reports: $REPORTS_DIR"
    log_info ""
    
    if [ "$WATCH_MODE" = "true" ]; then
        watch_mode
    else
        interval_mode
    fi
}

# Handle signals
trap 'log_info "Stopping continuous testing..."; exit 0' SIGINT SIGTERM

main "$@"
