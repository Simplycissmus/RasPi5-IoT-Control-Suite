#!/bin/bash
# Version: 1.2.4

# ============================================================================
# Script Name: vpn_setup.sh
# Description: Module for VPN setup (OpenVPN)
# Author: Patric Aeberhard (with updates by AI Assistant)
# Version: 1.2.4
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

vpn_setup() {
    log_info "Starting VPN setup..."

    install_openvpn
    configure_openvpn
    setup_firewall_rules
    generate_client_config

    if [ $? -eq 0 ]; then
        log_info "VPN setup completed successfully."
        return 0
    else
        log_error "VPN setup failed."
        return 1
    fi
}

install_openvpn() {
    if command -v openvpn &> /dev/null; then
        log_info "OpenVPN is already installed."
    else
        log_info "Installing OpenVPN..."
        run_safely apt-get update
        run_safely apt-get install -y openvpn easy-rsa
    fi
}

configure_openvpn() {
    log_info "Configuring OpenVPN..."

    # Use the new EasyRSA method for key generation
    run_safely mkdir -p /etc/openvpn/easy-rsa
    run_safely cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
    
    cd /etc/openvpn/easy-rsa
    run_safely ./easyrsa init-pki
    
    # Automatically create CA without user interaction
    echo -e "\n\n\n\n\n\n\n\n" | run_safely ./easyrsa build-ca nopass
    
    run_safely ./easyrsa gen-dh
    echo -e "\n\n\n\n\n\n\n\n" | run_safely ./easyrsa build-server-full server nopass
    echo -e "\n\n\n\n\n\n\n\n" | run_safely ./easyrsa build-client-full client1 nopass

    # Create server configuration
    cat > /etc/openvpn/server.conf <<EOF
port ${VPN_PORT}
proto udp
dev tun
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh /etc/openvpn/easy-rsa/pki/dh.pem
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
EOF

    log_info "OpenVPN configured."
}

setup_firewall_rules() {
    log_info "Setting firewall rules..."

    # Check if iptables is installed
    if ! command -v iptables &> /dev/null; then
        run_safely apt-get install -y iptables
    fi

    # Allow VPN traffic
    run_safely iptables -A INPUT -i tun+ -j ACCEPT
    run_safely iptables -A FORWARD -i tun+ -j ACCEPT
    run_safely iptables -A FORWARD -i tun+ -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    run_safely iptables -A FORWARD -i eth0 -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT

    # Allow VPN port
    run_safely iptables -A INPUT -i eth0 -p udp --dport ${VPN_PORT} -j ACCEPT

    # Save rules
    run_safely iptables-save > /etc/iptables.rules

    log_info "Firewall rules set."
}

generate_client_config() {
    log_info "Generating client configuration..."

    # Create directory for client configurations
    run_safely mkdir -p /etc/openvpn/client

    # Create base client configuration
    cat > /etc/openvpn/client/client.ovpn <<EOF
client
dev tun
proto udp
remote ${DDNS_HOSTNAME} ${VPN_PORT}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
verb 3
<ca>
$(cat /etc/openvpn/easy-rsa/pki/ca.crt)
</ca>
<cert>
$(cat /etc/openvpn/easy-rsa/pki/issued/client1.crt)
</cert>
<key>
$(cat /etc/openvpn/easy-rsa/pki/private/client1.key)
</key>
EOF

    log_info "Client configuration generated."
}

# Execute the vpn_setup function
vpn_setup
