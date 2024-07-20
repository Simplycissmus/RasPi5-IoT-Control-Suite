#!/bin/bash
# Version: 1.2.3

# ============================================================================
# Script Name: webserver_setup.sh
# Description: Module for Webserver setup (Nginx)
# Author: Patric Aeberhard (with updates by AI Assistant)
# Version: 1.2.3
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

webserver_setup() {
    log_info "Starting Webserver setup..."

    # Check if Nginx is already installed
    if command -v nginx &> /dev/null; then
        log_info "Nginx is already installed."
    else
        install_nginx
    fi

    configure_nginx
    setup_ssl
    configure_firewall

    log_info "Webserver setup completed."
    return 0
}

# Install Nginx
install_nginx() {
    log_info "Installing Nginx..."

    run_safely apt-get update
    run_safely apt-get install -y nginx

    log_info "Nginx installed."
}

# Configure Nginx
configure_nginx() {
    log_info "Configuring Nginx..."

    # Create Nginx configuration
    cat > /etc/nginx/sites-available/iot-control <<EOF
server {
    listen ${WEB_PORT} default_server;
    listen [::]:${WEB_PORT} default_server;
    server_name ${DDNS_HOSTNAME};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen ${HTTPS_PORT} ssl http2 default_server;
    listen [::]:${HTTPS_PORT} ssl http2 default_server;
    server_name ${DDNS_HOSTNAME};

    ssl_certificate /etc/letsencrypt/live/${DDNS_HOSTNAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DDNS_HOSTNAME}/privkey.pem;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /socket.io {
        proxy_pass http://localhost:5000/socket.io;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

    # Enable the configuration
    run_safely ln -sf /etc/nginx/sites-available/iot-control /etc/nginx/sites-enabled/
    run_safely rm -f /etc/nginx/sites-enabled/default

    # Test the Nginx configuration
    if ! nginx -t; then
        log_error "Nginx configuration test failed. Please check your configuration."
        return 1
    fi

    # Restart Nginx
    run_safely systemctl restart nginx

    log_info "Nginx configured."
}

# Setup SSL
setup_ssl() {
    log_info "Setting up SSL..."

    # Install Certbot
    run_safely apt-get install -y certbot python3-certbot-nginx

    # Stop Nginx before obtaining the certificate
    run_safely systemctl stop nginx

    # Obtain and install SSL certificate
    if ! certbot certonly --standalone -d ${DDNS_HOSTNAME} --non-interactive --agree-tos --email ${EMAIL_ADDRESS}; then
        log_error "Failed to obtain SSL certificate. Please check your domain and try again."
        return 1
    fi

    # Start Nginx after obtaining the certificate
    run_safely systemctl start nginx

    log_info "SSL set up."
}

# Configure firewall
configure_firewall() {
    log_info "Configuring firewall for Webserver..."

    # Check if ufw is installed
    if ! command -v ufw &> /dev/null; then
        log_info "ufw is not installed. Installing..."
        run_safely apt-get update
        run_safely apt-get install -y ufw
    fi

    # Allow HTTP and HTTPS traffic
    run_safely ufw allow ${WEB_PORT}/tcp
    run_safely ufw allow ${HTTPS_PORT}/tcp

    # Enable firewall if not already active
    if ! ufw status | grep -q "Status: active"; then
        run_safely ufw --force enable
    fi

    log_info "Firewall configured for Webserver."
}

# Execute the webserver_setup function
webserver_setup
