#!/bin/bash
# Version: 1.2.4

# ============================================================================
# Script Name: backend_setup.sh
# Description: Module for Backend setup (Flask, Gunicorn)
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

backend_setup() {
    log_info "Starting Backend setup..."

    # Setup Python environment
    setup_python_environment() {
        log_info "Setting up Python environment..."

        run_safely apt-get update
        run_safely apt-get install -y python3-venv python3-pip

        # Create virtual environment
        run_safely python3 -m venv "${VENV_DIR}"

        # Activate virtual environment
        source "${VENV_DIR}/bin/activate"

        log_info "Python environment set up."
    }

    # Install dependencies
    install_dependencies() {
        log_info "Installing Python dependencies..."

        run_safely "${VENV_DIR}/bin/pip" install flask gunicorn flask-socketio eventlet paho-mqtt

        # Create requirements.txt
        "${VENV_DIR}/bin/pip" freeze > "${PROJECT_DIR}/requirements.txt"

        log_info "Python dependencies installed."
    }

    # Create Flask app
    create_flask_app() {
        log_info "Creating Flask app..."

        # Create app.py
        cat > "${PROJECT_DIR}/app.py" <<EOF
from flask import Flask, render_template
from flask_socketio import SocketIO
import paho.mqtt.client as mqtt

app = Flask(__name__)
socketio = SocketIO(app)

# MQTT client setup
mqtt_client = mqtt.Client()
mqtt_client.username_pw_set("${MQTT_USER}", "${MQTT_PASSWORD}")
mqtt_client.connect("localhost", 1883, 60)

@app.route('/')
def index():
    return render_template('index.html')

@socketio.on('connect')
def handle_connect():
    print('Client connected')

@socketio.on('disconnect')
def handle_disconnect():
    print('Client disconnected')

if __name__ == '__main__':
    socketio.run(app, debug=True)
EOF

        # Create templates/index.html
        mkdir -p "${PROJECT_DIR}/templates"
        cat > "${PROJECT_DIR}/templates/index.html" <<EOF
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>IoT Control System</title>
</head>
<body>
    <h1>Willkommen zum IoT Control System</h1>
    <p>Diese Seite wird bald mit Funktionen gefüllt.</p>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/socket.io/4.0.1/socket.io.js"></script>
    <script>
        var socket = io();
    </script>
</body>
</html>
EOF

        log_info "Flask app created."
    }

    # Setup Gunicorn
    setup_gunicorn() {
        log_info "Setting up Gunicorn..."

        # Create Gunicorn configuration file
        cat > "${PROJECT_DIR}/gunicorn_config.py" <<EOF
bind = "127.0.0.1:5000"
workers = 3
worker_class = "eventlet"
EOF

        log_info "Gunicorn set up."
    }

    # Create systemd service
    create_systemd_service() {
        log_info "Creating systemd service for backend..."

        # Create service file
        cat > /etc/systemd/system/iot-backend.service <<EOF
[Unit]
Description=IoT Control System Backend
After=network.target

[Service]
User=${SUDO_USER}
Group=${SUDO_USER}
WorkingDirectory=${PROJECT_DIR}
Environment="PATH=${VENV_DIR}/bin"
ExecStart=${VENV_DIR}/bin/gunicorn --worker-class eventlet -c gunicorn_config.py app:app

[Install]
WantedBy=multi-user.target
EOF

        # Enable and start the service
        run_safely systemctl daemon-reload
        run_safely systemctl enable iot-backend
        run_safely systemctl start iot-backend

        log_info "systemd service for backend created and started."
    }

    # Execute the backend setup
    setup_python_environment
    install_dependencies
    create_flask_app
    setup_gunicorn
    create_systemd_service

    log_info "Backend setup completed successfully."
    return 0
}

# Execute the backend_setup function
backend_setup
