#!/bin/bash
# Version: 1.0.1

# ============================================================================
# Script Name: export_code.sh
# Description: Module to export code for AI
# Author: Patric Aeberhard
# Version: 1.0.1
# Date: 2024-07-15
# ============================================================================

# Error handling and logging functions
source "${UTILS_DIR}/error_handling.sh"
source "${UTILS_DIR}/logging_utils.sh"

# Set log file
export LOG_FILE="${LOG_DIR}/iot_setup.log"

log_info "Starting code export for AI..."

# Confirm and execute code export
confirm_export() {
    dialog --clear --backtitle "Code Export for AI" \
        --title "Code Export for AI" \
        --yesno "Do you want to export the code for AI?" 7 50

    response=$?
    if [ $response -eq 0 ]; then
        log_info "Exporting code..."
        tar -czvf "${HOME}/code_export.tar.gz" "${PROJECT_DIR}"
        log_info "Code export completed. The file is located at ${HOME}/code_export.tar.gz"
        dialog --msgbox "Code export completed. The file is located at ${HOME}/code_export.tar.gz" 7 50
    else
        log_info "Code export aborted."
    fi
}

confirm_export

rm -f tempfile
log_info "Code export for AI completed."
