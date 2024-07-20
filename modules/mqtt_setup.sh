#!/bin/bash
# Version: 1.2.2

# ============================================================================
# Script Name: mqtt_setup.sh
# Description: Module for MQTT Broker Setup (Mosquitto)
# Author: Patric Aeberhard
# Version: 1.2.2
# Date: 2024-07-16
# ============================================================================

# Set up script directory and log directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/../log"
UTILS_DIR="${SCRIPT_DIR}/../utils"

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

# Log file setup
export LOG_FILE="${LOG_DIR}/iot_setup.log"

# Error handling and logging functions
source "${UTILS_DIR}/error_handling.sh"
source "${UTILS_DIR}/logging_utils.sh"

mqtt_setup() {
    log_info "Starting MQTT Setup..."

    # MQTT Setup main function
    setup_mqtt() {
        log_info "Starting MQTT Broker Setup..."

        install_mosquitto
        configure_mosquitto
        setup_authentication
        configure_firewall
        start_mosquitto

        log_info "MQTT Broker Setup completed."
        return 0
    }

    # Install Mosquitto
    install_mosquitto() {
        log_info "Installing Mosquitto..."
        
        run_safely apt-get update
        run_safely apt-get install -y mosquitto mosquitto-clients
        
        log_info "Mosquitto installed."
    }

    # Configure Mosquitto
    configure_mosquitto() {
        log_info "Configuring Mosquitto..."
        
        # Create Mosquitto configuration file
        cat > /etc/mosquitto/mosquitto.conf <<EOF
# Base Configuration
pid_file /var/run/mosquitto/mosquitto.pid

# Persistence
persistence true
persistence_location /var/lib/mosquitto/

# Logging
log_dest file /var/log/mosquitto/mosquitto.log
log_type all

# Network Settings
listener 1883
protocol mqtt

# Authentication
allow_anonymous false
password_file /etc/mosquitto/passwd

# WebSocket Support (optional)
listener 9001
protocol websockets
EOF
        
        log_info "Mosquitto configured."
    }

    # Setup Authentication
    setup_authentication() {
        log_info "Setting up MQTT Authentication..."
        
        # Create password file
        run_safely touch /etc/mosquitto/passwd
        
        # Add user
        run_safely mosquitto_passwd -b /etc/mosquitto/passwd "${MQTT_USER}" "${MQTT_PASSWORD}"
        
        log_info "MQTT Authentication set up."
    }

    # Configure Firewall
    configure_firewall() {
        log_info "Configuring Firewall for MQTT..."
        
        # Allow MQTT traffic
        run_safely ufw allow 1883/tcp
        run_safely ufw allow 9001/tcp  # For WebSocket, if needed
        
        log_info "Firewall configured for MQTT."
    }

    # Start Mosquitto
    start_mosquitto() {
        log_info "Starting Mosquitto service..."
        
        run_safely systemctl enable mosquitto
        if ! run_safely systemctl start mosquitto; then
            log_error "Failed to start Mosquitto service."
            return 1
        fi
        
        log_info "Mosquitto service started."
        return 0
    }

    # Execute MQTT setup
    if setup_mqtt; then
        log_info "MQTT Setup completed successfully."
        return 0
    else
        log_error "MQTT Setup failed."
        return 1
    fi
}

# Execute the mqtt_setup function
mqtt_setup
