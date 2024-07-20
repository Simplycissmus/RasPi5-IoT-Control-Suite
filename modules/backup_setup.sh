#!/bin/bash
# Version: 1.2.1

# ============================================================================
# Script Name: backup_setup.sh
# Description: Module for Backup setup
# Author: Patric Aeberhard
# Version: 1.2.1
# Date: 2024-07-15
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

backup_setup() {
    log_info "Starting Backup setup..."

    # Backup setup main function
    setup_backup() {
        log_info "Starting Backup setup..."

        create_backup_script
        setup_backup_cron
        create_restore_script

        log_info "Backup setup completed."
        STATUS["Backup Setup"]="Successful"
    }

    # Create Backup script
    create_backup_script() {
        log_info "Creating Backup script..."

        mkdir -p "${PROJECT_DIR}/scripts"
        
        cat > "${PROJECT_DIR}/scripts/backup.sh" <<EOF
#!/bin/bash

# Backup script for IoT Control System

# Configuration
BACKUP_DIR="/home/patric/backups"
TIMESTAMP=\$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="\${BACKUP_DIR}/iot_control_backup_\${TIMESTAMP}.tar.gz"

# Create backup directory if it does not exist
mkdir -p \${BACKUP_DIR}

# Perform backup
tar -czf \${BACKUP_FILE} \\
    -C ${PROJECT_DIR} \\
    --exclude="venv" \\
    --exclude="__pycache__" \\
    --exclude="*.pyc" \\
    --exclude="node_modules" \\
    .

# Backup database
sqlite3 ${PROJECT_DIR}/${DB_NAME}.db ".backup '\${BACKUP_DIR}/database_\${TIMESTAMP}.sqlite'"

# Backup important configuration files
cp /etc/nginx/sites-available/iot-control "\${BACKUP_DIR}/nginx_config_\${TIMESTAMP}"
cp /etc/systemd/system/iot-backend.service "\${BACKUP_DIR}/systemd_config_\${TIMESTAMP}"

# Delete old backups (keep the last 7)
find \${BACKUP_DIR} -name "iot_control_backup_*.tar.gz" -type f -mtime +7 -delete
find \${BACKUP_DIR} -name "database_*.sqlite" -type f -mtime +7 -delete
find \${BACKUP_DIR} -name "nginx_config_*" -type f -mtime +7 -delete
find \${BACKUP_DIR} -name "systemd_config_*" -type f -mtime +7 -delete

echo "Backup completed: \${BACKUP_FILE}"
EOF

        chmod +x "${PROJECT_DIR}/scripts/backup.sh"

        log_info "Backup script created."
    }

    # Setup Backup Cron job
    setup_backup_cron() {
        log_info "Setting up Backup Cron job..."

        # Add daily Cron job
        (crontab -l 2>/dev/null; echo "0 2 * * * ${PROJECT_DIR}/scripts/backup.sh") | crontab -

        log_info "Backup Cron job set up."
    }

    # Create Restore script
    create_restore_script() {
        log_info "Creating Restore script..."

        cat > "${PROJECT_DIR}/scripts/restore.sh" <<EOF
#!/bin/bash

# Restore script for IoT Control System

# Check if a backup file name was passed as an argument
if [ \$# -eq 0 ]; then
    echo "Please provide the path to the backup file."
    exit 1
fi

BACKUP_FILE=\$1

# Check if the backup file exists
if [ ! -f "\${BACKUP_FILE}" ]; then
    echo "The specified backup file does not exist."
    exit 1
fi

# Extract the backup
tar -xzf \${BACKUP_FILE} -C ${PROJECT_DIR}

# Restore the database
BACKUP_DIR=\$(dirname \${BACKUP_FILE})
DB_BACKUP=\$(ls -t \${BACKUP_DIR}/database_*.sqlite | head -n1)
if [ -f "\${DB_BACKUP}" ]; then
    sqlite3 ${PROJECT_DIR}/${DB_NAME}.db ".restore '\${DB_BACKUP}'"
    echo "Database restored."
else
    echo "No database backup found."
fi

# Restore configuration files
NGINX_BACKUP=\$(ls -t \${BACKUP_DIR}/nginx_config_* | head -n1)
SYSTEMD_BACKUP=\$(ls -t \${BACKUP_DIR}/systemd_config_* | head -n1)

if [ -f "\${NGINX_BACKUP}" ]; then
    sudo cp "\${NGINX_BACKUP}" /etc/nginx/sites-available/iot-control
    sudo systemctl reload nginx
    echo "Nginx configuration restored."
fi

if [ -f "\${SYSTEMD_BACKUP}" ]; then
    sudo cp "\${SYSTEMD_BACKUP}" /etc/systemd/system/iot-backend.service
    sudo systemctl daemon-reload
    sudo systemctl restart iot-backend
    echo "Systemd configuration restored."
fi

echo "Restore completed."
EOF

        chmod +x "${PROJECT_DIR}/scripts/restore.sh"

        log_info "Restore script created."
    }

    setup_backup
}

# Execute the backup_setup function
backup_setup
