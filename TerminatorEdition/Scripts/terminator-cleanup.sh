#!/bin/bash
# ============================================================================
# Craig-O-Clean Terminator Edition - Quick Cleanup Script
# Autonomous system cleanup for macOS Silicon
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Craig-O-Clean Terminator Edition - Quick Cleanup         ║"
echo "║              Autonomous macOS Silicon Manager                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Functions
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

get_size() {
    du -sh "$1" 2>/dev/null | cut -f1 || echo "0"
}

# Check if running with sudo for privileged operations
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        log_warning "Some operations require sudo. You may be prompted for your password."
    fi
}

# Memory cleanup
cleanup_memory() {
    log_info "Purging inactive memory..."
    sync
    if sudo -n true 2>/dev/null; then
        sudo purge
    else
        sudo purge
    fi
    log_success "Memory purged"
}

# User caches
cleanup_user_caches() {
    log_info "Clearing user caches..."
    local size_before=$(get_size ~/Library/Caches)
    rm -rf ~/Library/Caches/* 2>/dev/null
    local size_after=$(get_size ~/Library/Caches)
    log_success "User caches cleared (was: $size_before)"
}

# Temporary files
cleanup_temp_files() {
    log_info "Clearing temporary files..."

    # User temp
    rm -rf ~/Library/Caches/TemporaryItems/* 2>/dev/null

    # System temp (requires sudo)
    if sudo -n true 2>/dev/null; then
        sudo rm -rf /private/var/tmp/* 2>/dev/null
        sudo rm -rf /private/var/folders/*/*/*/C/* 2>/dev/null
        sudo rm -rf /private/var/folders/*/*/*/T/* 2>/dev/null
    fi

    log_success "Temporary files cleared"
}

# Browser caches
cleanup_browser_caches() {
    log_info "Clearing browser caches..."

    # Safari
    rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null
    rm -rf ~/Library/Safari/LocalStorage/* 2>/dev/null

    # Chrome
    rm -rf ~/Library/Caches/Google/Chrome/* 2>/dev/null
    rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Cache/* 2>/dev/null
    rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Code\ Cache/* 2>/dev/null

    # Firefox
    rm -rf ~/Library/Caches/Firefox/* 2>/dev/null
    rm -rf ~/Library/Application\ Support/Firefox/Profiles/*/cache2/* 2>/dev/null

    # Edge
    rm -rf ~/Library/Caches/Microsoft\ Edge/* 2>/dev/null

    # Brave
    rm -rf ~/Library/Caches/BraveSoftware/* 2>/dev/null

    # Arc
    rm -rf ~/Library/Caches/company.thebrowser.Browser/* 2>/dev/null

    log_success "Browser caches cleared"
}

# DNS cache
flush_dns() {
    log_info "Flushing DNS cache..."
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder 2>/dev/null || true
    log_success "DNS cache flushed"
}

# Log files
cleanup_logs() {
    log_info "Clearing old log files..."

    # User logs older than 7 days
    find ~/Library/Logs -type f -mtime +7 -delete 2>/dev/null

    # System logs (requires sudo)
    if sudo -n true 2>/dev/null; then
        sudo find /var/log -name "*.log" -type f -mtime +7 -delete 2>/dev/null
        sudo rm -rf /private/var/log/asl/*.asl 2>/dev/null
    fi

    log_success "Old log files cleared"
}

# Crash reports
cleanup_crash_reports() {
    log_info "Clearing crash reports..."
    rm -rf ~/Library/Application\ Support/CrashReporter/* 2>/dev/null
    rm -rf ~/Library/Logs/DiagnosticReports/* 2>/dev/null
    log_success "Crash reports cleared"
}

# Empty trash
empty_trash() {
    log_info "Emptying trash..."
    local size_before=$(get_size ~/.Trash)
    rm -rf ~/.Trash/* 2>/dev/null
    log_success "Trash emptied (was: $size_before)"
}

# Show disk status
show_disk_status() {
    echo ""
    log_info "Current disk status:"
    df -h / | tail -1 | awk '{print "  Root Volume: " $3 " used of " $2 " (" $5 " full)"}'
}

# Main execution
main() {
    local start_time=$(date +%s)

    echo ""
    log_info "Starting cleanup at $(date)"
    echo ""

    # Show disk before
    show_disk_status
    echo ""

    # Run cleanup tasks
    cleanup_memory
    cleanup_user_caches
    cleanup_temp_files
    cleanup_browser_caches
    flush_dns
    cleanup_logs
    cleanup_crash_reports

    # Optional: empty trash
    if [ "$1" == "--empty-trash" ] || [ "$1" == "-t" ]; then
        empty_trash
    fi

    echo ""
    # Show disk after
    show_disk_status

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    log_success "Cleanup completed in ${duration} seconds!"
}

# Parse arguments
case "$1" in
    -h|--help)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -t, --empty-trash    Also empty the trash"
        echo "  -h, --help           Show this help message"
        echo ""
        exit 0
        ;;
    *)
        check_sudo
        main "$@"
        ;;
esac
