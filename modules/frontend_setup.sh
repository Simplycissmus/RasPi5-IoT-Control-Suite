#!/bin/bash
# Version: 1.2.3

# ============================================================================
# Script Name: frontend_setup.sh
# Description: Module for Frontend setup (React)
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

frontend_setup() {
    log_info "Starting Frontend setup..."

    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed. Installing Node.js..."
        install_node
    else
        log_info "Node.js is already installed."
    fi

    # Frontend setup main function
    setup_frontend() {
        log_info "Starting Frontend setup..."

        create_react_app
        install_dependencies
        configure_proxy
        build_frontend
        integrate_with_backend

        log_info "Frontend setup completed."
        return 0
    }

    # Install Node.js and npm
    install_node() {
        log_info "Installing Node.js and npm..."

        run_safely curl -fsSL https://deb.nodesource.com/setup_14.x | sudo -E bash -
        run_safely apt-get install -y nodejs

        if ! command -v node &> /dev/null; then
            log_error "Failed to install Node.js. Please install it manually and try again."
            return 1
        fi

        log_info "Node.js and npm installed."
    }

    # Create React app
    create_react_app() {
        log_info "Creating React app..."

        cd "${PROJECT_DIR}" || return 1
        run_safely npx create-react-app frontend
        cd frontend || return 1

        log_info "React app created."
    }

    # Install additional dependencies
    install_dependencies() {
        log_info "Installing additional dependencies..."

        run_safely npm install axios socket.io-client @material-ui/core

        log_info "Additional dependencies installed."
    }

    # Configure proxy for development
    configure_proxy() {
        log_info "Configuring proxy for development..."

        # Add proxy configuration to package.json
        sed -i '/"private": true,/a\  "proxy": "http://localhost:5000",' package.json

        log_info "Proxy configured."
    }

    # Build frontend
    build_frontend() {
        log_info "Building frontend..."

        run_safely npm run build

        log_info "Frontend built."
    }

    # Integrate with backend
    integrate_with_backend() {
        log_info "Integrating frontend with backend..."

        # Move the build folder to the backend directory
        run_safely mv build "${PROJECT_DIR}/static"

        # Update Flask app to serve the frontend
        sed -i '/from flask import Flask, render_template/c\from flask import Flask, render_template, send_from_directory' "${PROJECT_DIR}/app.py"

        # Add route for serving the frontend
        cat >> "${PROJECT_DIR}/app.py" <<EOF

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve(path):
    if path != "" and os.path.exists("static/" + path):
        return send_from_directory('static', path)
    else:
        return send_from_directory('static', 'index.html')
EOF

        log_info "Frontend integrated with backend."
    }

    # Execute the frontend setup
    if setup_frontend; then
        log_info "Frontend setup completed successfully."
        return 0
    else
        log_error "Frontend setup failed."
        return 1
    fi
}

# Execute the frontend_setup function
frontend_setup
