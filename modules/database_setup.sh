#!/bin/bash
# Version: 1.2.4

# ============================================================================
# Script Name: database_setup.sh
# Description: Module for Database setup
# Author: Patric Aeberhard
# Version: 1.2.4
# Date: 2024-07-17
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

database_setup() {
    log_info "Starting Database setup..."

    # Database setup main function
    setup_database() {
        log_info "Starting Database setup..."

        install_sqlite
        create_database
        setup_permissions

        log_info "Database setup completed."
        return 0
    }

    # Install SQLite
    install_sqlite() {
        log_info "Installing SQLite..."
        if command -v sqlite3 &> /dev/null; then
            log_info "SQLite is already installed."
        else
            run_safely apt-get update
            run_safely apt-get install -y sqlite3 libsqlite3-dev
        fi
        log_info "SQLite installed."
    }

    # Create database and tables
    create_database() {
        log_info "Creating database..."
        sqlite3 "${PROJECT_DIR}/${DB_NAME}.db" <<EOF
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL,
    password TEXT NOT NULL,
    email TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    status TEXT NOT NULL
);
EOF
        log_info "Database and tables created."
    }

    # Set permissions
    setup_permissions() {
        log_info "Setting permissions for the database..."
        chmod 600 "${PROJECT_DIR}/${DB_NAME}.db"
        log_info "Permissions set."
    }

    # Execute the database setup
    if setup_database; then
        log_info "Database setup completed successfully."
        return 0
    else
        log_error "Database setup failed."
        return 1
    fi
}

# Execute the database_setup function
database_setup
