#!/bin/bash
# Version: 1.0.1

# ============================================================================
# Script Name: system_check.sh
# Description: Module for system check
# Author: Patric Aeberhard
# Version: 1.0.1
# Date: 2024-07-15
# ============================================================================

# Error handling and logging functions
source "${UTILS_DIR}/error_handling.sh"
source "${UTILS_DIR}/logging_utils.sh"

# Set log file
export LOG_FILE="${LOG_DIR}/iot_setup.log"

log_info "Starting system check..."

# Check system resources
check_system_resources() {
    log_info "Checking system resources..."

    cpu_load=$(uptime | awk -F'[a-z]:' '{ print $2}' | awk '{print $1}')
    mem_free=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2 }')
    disk_free=$(df -h | awk '$NF=="/"{printf "%s", $5}')

    dialog --msgbox "System Resources:\n\nCPU Load: $cpu_load\nFree Memory: $mem_free%\nFree Disk Space: $disk_free" 10 50
    log_info "System resources checked."
}

# Check network connection
check_network() {
    log_info "Checking network connection..."

    ip_address=$(hostname -I)
    ping_result=$(ping -c 4 8.8.8.8 | grep 'packet loss' | awk '{print $6}')
    
    dialog --msgbox "Network Connection:\n\nIP Address: $ip_address\nPacket Loss: $ping_result" 10 50
    log_info "Network connection checked."
}

# Main menu for system check
system_check_menu() {
    dialog --clear --backtitle "System Check" \
        --title "System Check" \
        --menu "Choose an option:" 15 50 3 \
        1 "Check system resources" \
        2 "Check network connection" \
        3 "Return to main menu" 2>tempfile

    menuitem=$(<tempfile)
    case $menuitem in
        1) check_system_resources ;;
        2) check_network ;;
        3) return ;;
    esac
}

# Main loop for system check
while true; do
    system_check_menu
done

rm -f tempfile
log_info "System check completed."
