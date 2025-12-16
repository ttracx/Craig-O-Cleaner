#!/bin/bash

# MARK: - Log Export Helper Script
# Exports logs from the app for analysis

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

# Find app logs directory
APP_LOGS_DIR="$HOME/Library/Containers/com.craigoclean.app/Data/Documents/CraigOCleanLogs"

if [ ! -d "$APP_LOGS_DIR" ]; then
    log_warning "App logs directory not found: $APP_LOGS_DIR"
    log_info "The app may not have run yet or logs haven't been exported."
    exit 1
fi

# Create export directory
EXPORT_DIR="$HOME/Desktop/CraigOClean_Logs_Export_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$EXPORT_DIR"

log_info "Exporting logs to: $EXPORT_DIR"

# Copy all log files
if [ "$(ls -A $APP_LOGS_DIR)" ]; then
    cp -r "$APP_LOGS_DIR"/* "$EXPORT_DIR/"
    log_success "Copied $(ls -1 "$APP_LOGS_DIR" | wc -l | tr -d ' ') log files"
else
    log_warning "No log files found in app directory"
fi

# Also collect system logs
log_info "Collecting system logs..."
log show --predicate 'subsystem == "com.craigoclean.app"' \
    --last 1h \
    --style syslog > "$EXPORT_DIR/system_logs.txt" 2>/dev/null || {
    log_warning "Could not collect system logs (may require permissions)"
}

# Create summary
cat > "$EXPORT_DIR/EXPORT_SUMMARY.txt" << EOF
Craig-O-Clean Log Export Summary
================================

Export Time: $(date)
Export Directory: $EXPORT_DIR

Files Exported:
$(ls -lh "$EXPORT_DIR" | tail -n +2)

To analyze these logs, use:
python3 scripts/analyze_test_results.py "$EXPORT_DIR"

EOF

log_success "Log export complete!"
log_info "Exported to: $EXPORT_DIR"
log_info "Summary: $EXPORT_DIR/EXPORT_SUMMARY.txt"

# Open export directory
open "$EXPORT_DIR"
