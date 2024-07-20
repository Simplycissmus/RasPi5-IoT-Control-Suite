#!/bin/bash
# Version: 1.0.1

# ============================================================================
# Script Name: logging_utils.sh
# Description: Utility functions for logging
# Author: Patric Aeberhard
# Version: 1.0.1
# Date: 2024-07-15
# ============================================================================

# Set up log directory in script directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_DIR="${SCRIPT_DIR}/temp"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Global variables
LOG_FILE=${LOG_FILE:-"${LOG_DIR}/setup_log.txt"}

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Info level logging
log_info() {
    log "INFO" "$1"
}

# Warning level logging
log_warning() {
    log "WARNING" "$1" >&2
}

# Error level logging
log_error() {
    log "ERROR" "$1" >&2
}

# Debug level logging
log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        log "DEBUG" "$1"
    fi
}
