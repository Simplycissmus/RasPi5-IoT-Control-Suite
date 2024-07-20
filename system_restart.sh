#!/bin/bash
# Version: 1.1.0

# ============================================================================
# Script Name: system_restart.sh
# Description: Module for system and service restart
# Author: Patric Aeberhard
# Version: 1.1.0
# Date: 2024-07-17
# ============================================================================

# Error handling and logging functions
source "${UTILS_DIR}/error_handling.sh"
source "${UTILS_DIR}/logging_utils.sh"

# Set log file
export LOG_FILE="${LOG_DIR}/iot_setup.log"

log_info "Starting system restart module..."

# List of services that can be restarted
services=("nginx" "mosquitto" "iot-backend" "openvpn" "prometheus" "grafana-server")

# Function to restart a specific service
restart_service() {
    local service=$1
    log_info "Restarting $service..."
    if sudo systemctl restart $service; then
        log_info "$service restarted successfully."
        dialog --msgbox "$service restarted successfully." 8 40
    else
        log_error "Failed to restart $service."
        dialog --msgbox "Failed to restart $service." 8 40
    fi
}

# Function to restart all services
restart_all_services() {
    for service in "${services[@]}"; do
        restart_service $service
    done
}

# Function to display menu for service selection
select_services() {
    local options=()
    for service in "${services[@]}"; do
        options+=($service "$service" off)
    done
    options+=("ALL" "Restart all services" off)
    
    selected_services=$(dialog --separate-output --checklist "Select services to restart:" 20 40 15 "${options[@]}" 2>&1 >/dev/tty)
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    if [[ $selected_services == *"ALL"* ]]; then
        restart_all_services
    else
        for service in $selected_services; do
            restart_service $service
        done
    fi
}

# Main menu for system restart
system_restart_menu() {
    while true; do
        choice=$(dialog --clear --backtitle "System Restart" \
            --title "System Restart" \
            --menu "Choose an option:" 15 50 3 \
            1 "Restart specific services" \
            2 "Restart entire system" \
            3 "Return to main menu" 2>&1 >/dev/tty)

        case $choice in
            1) select_services ;;
            2) 
                if dialog --yesno "Are you sure you want to restart the entire system?" 8 40; then
                    log_info "Restarting entire system..."
                    sudo reboot
                fi
                ;;
            3) return ;;
        esac
    done
}

# Execute the main menu
system_restart_menu

log_info "System restart module completed."