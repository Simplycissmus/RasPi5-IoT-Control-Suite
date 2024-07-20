#!/bin/bash
# Version: 1.0.1

# ============================================================================
# Script Name: error_handling.sh
# Description: Utility functions for error handling
# Author: Patric Aeberhard
# Version: 1.0.1
# Date: 2024-07-15
# ============================================================================

# Error handling function
handle_error() {
    local exit_code=$1
    local line_number=$2
    local error_message=$3
    log_error "Error on line $line_number: $error_message (Exit code: $exit_code)"
}

# Trap for error handling
set_error_trap() {
    trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
}

# Function to safely execute commands
run_safely() {
    local cmd="$@"
    log_debug "Executing: $cmd"
    if ! eval "$cmd"; then
        log_error "Command failed: $cmd"
        return 1
    fi
}

# Ensure that logging functions are available
source "${UTILS_DIR}/logging_utils.sh"
