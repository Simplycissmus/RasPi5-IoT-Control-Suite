#!/bin/bash
# Version: 1.2.8

# ============================================================================
# Script Name: network_setup.sh
# Description: Module for Network setup
# Author: Patric Aeberhard (with updates by AI Assistant)
# Version: 1.2.8
# Date: 2024-07-20
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

function network_setup() {
    log_info "Starting Network setup..."

    # Network setup main function
    setup_network() {
        log_info "Starting Network setup..."

        if ! install_dependencies; then
            return 1
        fi
        if ! configure_access_point; then
            return 1
        fi
        if ! configure_ip_forwarding; then
            return 1
        fi
        if ! configure_dhcp; then
            return 1
        fi

        log_info "Network setup completed successfully."
        return 0
    }

    # Install required packages
    install_dependencies() {
        log_info "Installing required packages..."
        if ! run_safely apt-get update; then
            log_error "Failed to update package lists"
            return 1
        fi
        if ! run_safely apt-get install -y dnsmasq hostapd iptables; then
            log_error "Failed to install required packages"
            return 1
        fi
        log_info "Packages installed."
        return 0
    }

    # Configure Access Point
    configure_access_point() {
        log_info "Setting up Access Point..."

        # Hostapd configuration
        cat <<EOF | sudo tee /etc/hostapd/hostapd.conf
interface=wlan1
ssid=${AP_SSID}
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${AP_PASSPHRASE}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

        if ! run_safely sudo systemctl unmask hostapd; then
            log_error "Failed to unmask hostapd"
            return 1
        fi
        if ! run_safely sudo systemctl enable hostapd; then
            log_error "Failed to enable hostapd"
            return 1
        fi
        if ! run_safely sudo systemctl start hostapd; then
            log_error "Failed to start hostapd"
            return 1
        fi

        log_info "Access Point set up."
        return 0
    }

    # Configure IP forwarding
    configure_ip_forwarding() {
        log_info "Configuring IP forwarding..."

        if ! run_safely sudo sysctl -w net.ipv4.ip_forward=1; then
            log_error "Failed to enable IP forwarding"
            return 1
        fi
        if ! run_safely sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; then
            log_error "Failed to set up NAT"
            return 1
        fi
        if ! run_safely sudo iptables -A FORWARD -i eth0 -o wlan1 -m state --state RELATED,ESTABLISHED -j ACCEPT; then
            log_error "Failed to set up forward rule"
            return 1
        fi
        if ! run_safely sudo iptables -A FORWARD -i wlan1 -o eth0 -j ACCEPT; then
            log_error "Failed to set up forward rule"
            return 1
        fi

        # Ensure iptables rules directory exists
        sudo mkdir -p /etc/iptables
        if ! run_safely sudo iptables-save | sudo tee /etc/iptables/rules.v4; then
            log_error "Failed to save iptables rules"
            return 1
        fi

        log_info "IP forwarding configured."
        return 0
    }

    # Configure DHCP
    configure_dhcp() {
        log_info "Configuring DHCP..."

        cat <<EOF | sudo tee /etc/dnsmasq.conf
interface=wlan1
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
EOF

        if ! run_safely sudo systemctl enable dnsmasq; then
            log_error "Failed to enable dnsmasq"
            return 1
        fi
        if ! run_safely sudo systemctl start dnsmasq; then
            log_error "Failed to start dnsmasq"
            return 1
        fi

        log_info "DHCP configured."
        return 0
    }

    # Execute the network setup
    if setup_network; then
        log_info "Network setup completed successfully."
        return 0
    else
        log_error "Network setup failed."
        return 1
    fi
}

# This script will be sourced, so don't call the function here
