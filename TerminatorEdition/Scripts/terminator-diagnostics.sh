#!/bin/bash
# ============================================================================
# Craig-O-Clean Terminator Edition - System Diagnostics Script
# Comprehensive system health analysis for macOS Silicon
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Banner
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Craig-O-Clean Terminator Edition - Diagnostics           ║"
echo "║              System Health Analysis                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# System Information
print_system_info() {
    echo -e "${MAGENTA}=== SYSTEM INFORMATION ===${NC}"
    echo ""
    echo "Hostname:     $(hostname)"
    echo "Model:        $(sysctl -n hw.model)"
    echo "macOS:        $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
    echo "Kernel:       $(uname -r)"
    echo "Architecture: $(arch)"
    echo "Uptime:       $(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"
    echo ""
}

# CPU Information
print_cpu_info() {
    echo -e "${MAGENTA}=== CPU INFORMATION ===${NC}"
    echo ""
    echo "CPU:          $(sysctl -n machdep.cpu.brand_string)"
    echo "Cores:        $(sysctl -n hw.physicalcpu) physical, $(sysctl -n hw.logicalcpu) logical"

    # Get CPU usage
    local cpu_usage=$(top -l 1 -s 0 | grep "CPU usage" | awk '{print $3}' | tr -d '%')
    echo "CPU Usage:    $cpu_usage%"
    echo ""
}

# Memory Information
print_memory_info() {
    echo -e "${MAGENTA}=== MEMORY INFORMATION ===${NC}"
    echo ""

    # Physical memory summary
    top -l 1 -s 0 | grep PhysMem | sed 's/PhysMem: //'

    # Memory pressure
    echo "Pressure:     $(memory_pressure | head -1 | awk -F': ' '{print $2}')"
    echo ""

    # Detailed VM stats
    echo "VM Statistics:"
    vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+(\w+)[^\d]+(\d+)/ and printf("  %-16s %8.1f MB\n", "$1:", $2 * $size / 1048576);' | head -6
    echo ""
}

# Disk Information
print_disk_info() {
    echo -e "${MAGENTA}=== DISK INFORMATION ===${NC}"
    echo ""

    # Main volume
    df -h / | tail -1 | awk '{print "Root Volume:  " $3 " used of " $2 " (" $5 " full)"}'

    # All volumes
    echo ""
    echo "All Volumes:"
    df -h | grep -E "^/dev" | awk '{printf "  %-20s %8s used of %8s (%s)\n", $9, $3, $2, $5}'
    echo ""
}

# Top Processes
print_top_processes() {
    echo -e "${MAGENTA}=== TOP PROCESSES ===${NC}"
    echo ""

    echo "By CPU:"
    ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "  %-20s CPU: %5s%% MEM: %5s%%\n", $11, $3, $4}'
    echo ""

    echo "By Memory:"
    ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "  %-20s CPU: %5s%% MEM: %5s%%\n", $11, $3, $4}'
    echo ""
}

# Network Information
print_network_info() {
    echo -e "${MAGENTA}=== NETWORK INFORMATION ===${NC}"
    echo ""

    # Active interface
    local active_if=$(route get default 2>/dev/null | grep interface | awk '{print $2}')
    echo "Active Interface: $active_if"

    # IP Address
    if [ -n "$active_if" ]; then
        local ip=$(ifconfig "$active_if" 2>/dev/null | grep "inet " | awk '{print $2}')
        echo "IP Address:       $ip"
    fi

    # Wi-Fi info
    local wifi_ssid=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null | grep ' SSID' | awk '{print $2}')
    if [ -n "$wifi_ssid" ]; then
        echo "Wi-Fi Network:    $wifi_ssid"
    fi

    # Internet connectivity
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo -e "Internet:         ${GREEN}Connected${NC}"
    else
        echo -e "Internet:         ${RED}Disconnected${NC}"
    fi
    echo ""
}

# Battery Information (MacBooks)
print_battery_info() {
    local battery_info=$(pmset -g batt 2>/dev/null)
    if echo "$battery_info" | grep -q "Battery"; then
        echo -e "${MAGENTA}=== BATTERY INFORMATION ===${NC}"
        echo ""

        local percent=$(echo "$battery_info" | grep -o '[0-9]*%' | head -1)
        local status=$(echo "$battery_info" | grep -o 'discharging\|charging\|charged' | head -1)

        echo "Charge:       $percent"
        echo "Status:       ${status:-AC Power}"

        # Cycle count
        local cycles=$(system_profiler SPPowerDataType 2>/dev/null | grep "Cycle Count" | awk '{print $3}')
        if [ -n "$cycles" ]; then
            echo "Cycle Count:  $cycles"
        fi

        # Condition
        local condition=$(system_profiler SPPowerDataType 2>/dev/null | grep "Condition" | awk -F: '{print $2}' | xargs)
        if [ -n "$condition" ]; then
            echo "Condition:    $condition"
        fi
        echo ""
    fi
}

# Health Score
calculate_health_score() {
    echo -e "${MAGENTA}=== HEALTH SCORE ===${NC}"
    echo ""

    local score=100

    # Memory check
    local mem_used=$(top -l 1 -s 0 | grep PhysMem | grep -o '[0-9]*G used' | grep -o '[0-9]*')
    local mem_total=$(sysctl -n hw.memsize | awk '{print $0/1073741824}')
    local mem_percent=$(echo "scale=0; $mem_used * 100 / $mem_total" | bc 2>/dev/null || echo "50")

    if [ "$mem_percent" -gt 90 ]; then
        score=$((score - 30))
        echo -e "  Memory:     ${RED}Critical ($mem_percent%)${NC}"
    elif [ "$mem_percent" -gt 80 ]; then
        score=$((score - 20))
        echo -e "  Memory:     ${YELLOW}Warning ($mem_percent%)${NC}"
    else
        echo -e "  Memory:     ${GREEN}Good ($mem_percent%)${NC}"
    fi

    # Disk check
    local disk_percent=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
    if [ "$disk_percent" -gt 95 ]; then
        score=$((score - 30))
        echo -e "  Disk:       ${RED}Critical ($disk_percent%)${NC}"
    elif [ "$disk_percent" -gt 85 ]; then
        score=$((score - 15))
        echo -e "  Disk:       ${YELLOW}Warning ($disk_percent%)${NC}"
    else
        echo -e "  Disk:       ${GREEN}Good ($disk_percent%)${NC}"
    fi

    # CPU check
    local cpu_percent=$(top -l 1 -s 0 | grep "CPU usage" | awk '{print $3}' | tr -d '%' | cut -d. -f1)
    if [ "$cpu_percent" -gt 90 ]; then
        score=$((score - 20))
        echo -e "  CPU:        ${RED}High ($cpu_percent%)${NC}"
    elif [ "$cpu_percent" -gt 70 ]; then
        score=$((score - 10))
        echo -e "  CPU:        ${YELLOW}Moderate ($cpu_percent%)${NC}"
    else
        echo -e "  CPU:        ${GREEN}Good ($cpu_percent%)${NC}"
    fi

    echo ""
    if [ "$score" -ge 80 ]; then
        echo -e "  Overall:    ${GREEN}$score/100 - Healthy${NC}"
    elif [ "$score" -ge 60 ]; then
        echo -e "  Overall:    ${YELLOW}$score/100 - Needs Attention${NC}"
    else
        echo -e "  Overall:    ${RED}$score/100 - Critical${NC}"
    fi
    echo ""
}

# Recommendations
print_recommendations() {
    echo -e "${MAGENTA}=== RECOMMENDATIONS ===${NC}"
    echo ""

    local has_recommendations=false

    # Memory
    local mem_pressure=$(memory_pressure 2>/dev/null | head -1)
    if echo "$mem_pressure" | grep -qi "critical\|warn"; then
        echo "  • Consider closing unused applications"
        echo "  • Run: terminator-cleanup.sh to free memory"
        has_recommendations=true
    fi

    # Disk
    local disk_percent=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
    if [ "$disk_percent" -gt 85 ]; then
        echo "  • Low disk space - consider clearing caches"
        echo "  • Run: terminator-cleanup.sh --empty-trash"
        has_recommendations=true
    fi

    # Processes
    local process_count=$(ps aux | wc -l)
    if [ "$process_count" -gt 300 ]; then
        echo "  • Many processes running ($process_count)"
        echo "  • Review startup items and background services"
        has_recommendations=true
    fi

    if [ "$has_recommendations" = false ]; then
        echo -e "  ${GREEN}System is running optimally. No action required.${NC}"
    fi
    echo ""
}

# Main
main() {
    echo ""
    echo "Generating system diagnostics report..."
    echo "Date: $(date)"
    echo ""

    print_system_info
    print_cpu_info
    print_memory_info
    print_disk_info
    print_top_processes
    print_network_info
    print_battery_info
    calculate_health_score
    print_recommendations

    echo -e "${CYAN}Diagnostics complete.${NC}"
}

main "$@"
