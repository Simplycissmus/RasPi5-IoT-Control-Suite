#!/bin/bash

# ============================================================================
# Script Name: setup_iot_system.sh
# Description: Interactive main setup script for the entire IoT Control System
# Author: Patric Aeberhard (with comprehensive improvements)
# Version: 4.8.0
# Date: 2024-07-21
# ============================================================================
# Usage Instructions:
# 1. Ensure you have sudo privileges on your Raspberry Pi system.
# 2. Place this script in your desired project directory.
# 3. Make the script executable:
#    chmod +x setup_iot_system.sh
# 4. Run the script with sudo:
#    sudo ./setup_iot_system.sh
# 5. Follow the on-screen prompts to set up your IoT Control System.
#
# Note: This script requires an active internet connection to download
# necessary packages and dependencies.
#
# For Windows users:
# If you're having issues connecting to your Raspberry Pi, you may need to
# remove the old SSH key. Use this command in PowerShell (replace IP if needed):
#    ssh-keygen -R 10.0.0.44
#
# For more detailed information, please refer to the README.md file.
# ============================================================================

set -e  # Exit immediately if a command exits with a non-zero status.
set -u  # Treat unset variables as an error when substituting.

SCRIPT_VERSION="4.8.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="${SCRIPT_DIR}/utils"
MODULES_DIR="${SCRIPT_DIR}/modules"
LOG_DIR="${SCRIPT_DIR}/log"
PROJECT_DIR="/home/patric/IoT_Control_System"
PROGRESS_FILE="${SCRIPT_DIR}/setup_progress.txt"
LOCK_FILE="/tmp/setup_iot_system.lock"

# Ensure only one instance of the script is running
exec 200>"${LOCK_FILE}"
flock -n 200 || { echo "Another instance of the script is already running."; exit 1; }

# Trap for cleanup
trap cleanup EXIT

cleanup() {
    rm -f "${LOCK_FILE}"
    echo "Script execution completed. Cleaning up..."
}

cleanup_and_exit() {
    log_info "Performing cleanup before exiting"
    save_progress
    rm -f "${LOCK_FILE}"
    log_info "Exiting script"
    exit 0
}

setup_permissions() {
    local user=$(logname)
    sudo chown -R "$user:$user" "$SCRIPT_DIR"
    sudo chmod -R 755 "$SCRIPT_DIR"
}

# Call this function right after defining variables
setup_permissions

# Check and install dependencies
check_and_install_dependencies() {
    local dependencies=("dialog" "curl" "wget" "jq")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "Installing $dep..."
            if ! sudo apt-get update && sudo apt-get install -y "$dep"; then
                echo "Failed to install $dep. Please install it manually and run the script again."
                exit 1
            fi
        fi
    done
}

check_and_install_dependencies

# Source utility scripts
source "${UTILS_DIR}/error_handling.sh"
source "${UTILS_DIR}/logging_utils.sh"

# Load environment variables
if [[ -f "${SCRIPT_DIR}/credentials.env" ]]; then
    source "${SCRIPT_DIR}/credentials.env"
else
    log_error "credentials.env not found. Please create the file."
    exit 1
fi

# Error handling and logging
set_error_trap
mkdir -p "${LOG_DIR}"
export LOG_FILE="${LOG_DIR}/iot_setup.log"
log_info "Starting IoT System Setup v${SCRIPT_VERSION}"

# Check scripts function
check_scripts() {
    local dir=$1
    for script in "${dir}"/*.sh; do
        if [[ ! -f "$script" ]]; then
            log_error "Script not found: $script"
            dialog --msgbox "Error: Script not found: $script" 8 50
            return 1
        elif [[ ! -x "$script" ]]; then
            log_error "Script not executable: $script"
            chmod +x "$script"
            log_info "Made $script executable."
        fi
    done
    return 0
}

# Check utility and module scripts
check_scripts "${UTILS_DIR}" && check_scripts "${MODULES_DIR}" || { log_error "Error checking scripts"; exit 1; }

# Menu options, status, and dependencies
declare -A MENU_OPTIONS DEPENDENCIES
SETUP_ORDER=(
    "Network Setup" "GitHub Setup" "Database Setup" "MQTT Setup"
    "Backend Setup" "Frontend Setup" "Webserver Setup" "VPN Setup"
    "ESP32 Setup" "Monitoring Setup" "Backup Setup"
    "Check System" "Restart System" "Export Code" "Exit"
)

# Initialize menu options
for option in "${SETUP_ORDER[@]}"; do
    MENU_OPTIONS["$option"]="Not Executed"
done

# Initialize dependencies
DEPENDENCIES["GitHub Setup"]="Network Setup"
DEPENDENCIES["Database Setup"]="GitHub Setup"
DEPENDENCIES["MQTT Setup"]="Database Setup"
DEPENDENCIES["Backend Setup"]="MQTT Setup"
DEPENDENCIES["Frontend Setup"]="Backend Setup"
DEPENDENCIES["Webserver Setup"]="Frontend Setup"
DEPENDENCIES["VPN Setup"]="Webserver Setup"
DEPENDENCIES["ESP32 Setup"]="MQTT Setup"
DEPENDENCIES["Monitoring Setup"]="Backend Setup"
DEPENDENCIES["Backup Setup"]="Database Setup Backend Setup"

save_progress() {
    log_info "Saving progress..."
    (
        flock -x 201
        > "$PROGRESS_FILE"  # Clear the file before writing
        for key in "${!MENU_OPTIONS[@]}"; do
            echo "${key}:${MENU_OPTIONS[$key]}" >> "$PROGRESS_FILE"
        done
    ) 201>"${PROGRESS_FILE}.lock"
    log_info "Progress saved to $PROGRESS_FILE"
    log_info "Contents of progress file:"
    cat "$PROGRESS_FILE" | while read line; do log_info "$line"; done
}

load_progress() {
    log_info "Loading progress..."
    if [[ -f "$PROGRESS_FILE" ]]; then
        (
            flock -s 201
            while IFS=: read -r key value; do
                MENU_OPTIONS["$key"]="$value"
                log_info "Loaded: $key = $value"
            done < "$PROGRESS_FILE"
        ) 201>"${PROGRESS_FILE}.lock"
        log_info "Progress loaded from $PROGRESS_FILE"
    else
        log_info "No progress file found. Starting fresh."
    fi
}

# Load saved progress
load_progress

# Helper functions
get_status_symbol() {
    case $1 in
        "Successful") echo "[✓]" ;;
        "Failed") echo "[✗]" ;;
        *) echo "[ ]" ;;
    esac
}

update_progress() {
    local completed=0
    for status in "${MENU_OPTIONS[@]}"; do
        [[ "$status" == "Successful" ]] && ((completed++))
    done
    echo $((completed * 100 / ${#MENU_OPTIONS[@]}))
}

check_dependencies() {
    local module=$1
    if [[ -n "${DEPENDENCIES[$module]:-}" ]]; then
        IFS=' ' read -ra deps <<< "${DEPENDENCIES[$module]}"
        for dep in "${deps[@]}"; do
            if [[ "${MENU_OPTIONS[$dep]:-}" != "Successful" ]]; then
                dialog --clear --colors --no-lines --title "Dependency Warning" \
                       --msgbox "\Z1Warning: Dependency '$dep' has not been executed yet.\Zn\nIt is recommended to run it before proceeding with $module." 10 60
                return 1
            fi
        done
    fi
    return 0
}

update_dependencies() {
    local completed_module=$1
    log_info "Updating dependencies for completed module: $completed_module"
    for key in "${!DEPENDENCIES[@]}"; do
        IFS=' ' read -ra deps <<< "${DEPENDENCIES[$key]}"
        local all_deps_met=true
        for dep in "${deps[@]}"; do
            if [[ "${MENU_OPTIONS[$dep]:-}" != "Successful" ]]; then
                all_deps_met=false
                break
            fi
        done
        if $all_deps_met; then
            MENU_OPTIONS["$key"]="Ready"
            log_info "Module $key is now ready to execute"
        fi
    done
    save_progress
}

check_network_connection() {
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_error "Network connection lost. Attempting to restore connection..."
        sudo systemctl restart networking
        sleep 5
        if ! ping -c 1 8.8.8.8 &> /dev/null; then
            log_error "Failed to restore network connection."
            return 1
        fi
    fi
    return 0
}

check_ssh_service() {
    if ! systemctl is-active --quiet ssh; then
        log_error "SSH service is not running. Attempting to restart..."
        sudo systemctl restart ssh
        if ! systemctl is-active --quiet ssh; then
            log_error "Failed to restart SSH service."
            return 1
        fi
    fi
    return 0
}

check_system_resources() {
    local mem_free=$(free | awk '/^Mem:/ {print $4}')
    local disk_free=$(df / | awk 'NR==2 {print $4}')
    
    if [ "${mem_free}" -lt 100000 ]; then
        log_warning "Low memory detected (${mem_free}K free). Some operations may fail."
        return 1
    fi
    if [ "${disk_free}" -lt 1000000 ]; then
        log_warning "Low disk space detected (${disk_free}K free). Some operations may fail."
        return 1
    fi
    return 0
}

run_module_with_timeout() {
    local module=$1
    local timeout=300  # 5 minutes timeout

    (
        run_module "$module" &
        module_pid=$!
        (sleep $timeout && kill $module_pid 2>/dev/null) &
        wait $module_pid
    )

    if [[ $? -eq 143 ]]; then  # 143 is the exit code for SIGTERM
        log_error "Module $module timed out after $timeout seconds"
        dialog --msgbox "Module $module timed out. Please check the logs." 8 50
        return 1
    fi

    return 0
}

run_module() {
    local module=$1
    log_info "Starting module execution: $module"
    
    if ! check_network_connection || ! check_ssh_service || ! check_system_resources; then
        log_error "Pre-execution checks failed for module $module"
        return 1
    fi
    
    if check_dependencies "$module"; then
        local module_script="${MODULES_DIR}/$(echo "${module,,}" | tr ' ' '_').sh"
        if [[ -f "$module_script" ]]; then
            # Source the module script in a subshell to avoid affecting the main script
            (
                source "$module_script"
                local function_name="$(echo "${module,,}" | tr ' ' '_')"
                if declare -f "$function_name" > /dev/null; then
                    if $function_name; then
                        exit 0  # Success
                    else
                        exit 1  # Failure
                    fi
                else
                    log_error "Function $function_name not found in $module_script"
                    exit 2  # Function not found
                fi
            )
            local result=$?
            case $result in
                0)
                    MENU_OPTIONS["$module"]="Successful"
                    log_info "Module $module executed successfully"
                    dialog --msgbox "Module $module executed successfully" 8 50
                    clear_screen
                    save_progress
                    update_dependencies "$module"
                    update_progress
                    log_info "Returning to main menu after successful execution of $module"
                    ;;
                1)
                    MENU_OPTIONS["$module"]="Failed"
                    log_error "Error executing module $module"
                    save_progress
                    show_error_dialog "$module"
                    log_info "Returning to main menu after failed execution of $module"
                    ;;
                2)
                    log_error "Function $function_name not found in $module_script"
                    show_error_dialog "$module" "Function not found"
                    log_info "Returning to main menu after function not found error in $module"
                    ;;
            esac
        else
            log_error "Module script $module_script not found"
            show_error_dialog "$module" "Script not found"
        fi
    else
        log_error "Dependencies not met for module $module"
    fi
    
    return 0  # Explicit return
}

run_module_silent() {
    local module=$1
    log_info "Starting silent execution of module: $module"
    
    local module_script="${MODULES_DIR}/$(echo "${module,,}" | tr ' ' '_').sh"
    if [[ -f "$module_script" ]]; then
        source "$module_script"
        local function_name="$(echo "${module,,}" | tr ' ' '_')"
        if declare -f "$function_name" > /dev/null; then
            if $function_name; then
                MENU_OPTIONS["$module"]="Successful"
                log_info "Module $module executed successfully"
                save_progress
                update_dependencies "$module"
                update_progress
                return 0
            else
                MENU_OPTIONS["$module"]="Failed"
                log_error "Error executing module $module"
                save_progress
               return 1
        fi
    else
        log_error "Function $function_name not found in $module_script"
        return 1
    fi
    else
        log_error "Module script $module_script not found"
        return 1
    fi
}

clear_screen() {
    clear
    log_info "Screen cleared"
}


check_environment_variables() {
    local required_vars=("WIFI_SSID" "WIFI_PASSPHRASE" "AP_SSID" "AP_PASSPHRASE" "MQTT_USER" "MQTT_PASSWORD")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            log_error "Required environment variable $var is not set"
            return 1
        fi
    done
    return 0
}

handle_error() {
    local error_message="$1"
    log_error "Unexpected error: $error_message"
    dialog --msgbox "An unexpected error occurred. Please check the logs." 8 50
    cleanup_and_exit
}

show_error_dialog() {
    local module=$1
    local error_message=${2:-"Unknown error"}
    dialog --clear --colors --no-lines --title "Error" \
           --msgbox "\Z1Error in $module:\Zn\n$error_message" 10 60
    if dialog --clear --colors --no-lines --title "Retry" \
              --yesno "Do you want to try again?" 6 40; then
        run_module "$module"
    else
        log_error "Execution of $module failed and not retried."
    fi
}

get_module_version() {
    local version=""
    local module_file="${MODULES_DIR}/$(echo "${1,,}" | tr ' ' '_').sh"
    [[ -f "$module_file" ]] && version=$(grep "^# Version:" "$module_file" | awk '{print $3}')
    [[ -n "$version" ]] && echo "(v$version)" || echo ""
}

complete_installation() {
    log_info "Starting complete installation process..."
    
    local modules=(
        "Network Setup" "GitHub Setup" "Database Setup" "MQTT Setup"
        "Backend Setup" "Frontend Setup" "Webserver Setup" "VPN Setup"
        "ESP32 Setup" "Monitoring Setup" "Backup Setup"
    )
    
    local total_modules=${#modules[@]}
    local current_module=0
    
    for module in "${modules[@]}"; do
        ((current_module++))
        local progress=$((current_module * 100 / total_modules))
        
        dialog --title "Complete Installation" --gauge "Installing $module..." 10 70 $progress
        
        if [[ "$module" == "GitHub Setup" ]]; then
            dialog --msgbox "The next step is GitHub Setup. You will need to choose between cloning an existing repository or creating a new one." 10 60
            run_module "$module"
        else
            if ! run_module_silent "$module"; then
                dialog --msgbox "Error occurred during $module. Installation will continue, but please check the logs." 10 60
            fi
        fi
        
        sleep 2
    done
    
    dialog --title "Installation Complete" --msgbox "The complete installation process has finished. Please review the logs for any warnings or errors." 10 60
    log_info "Complete installation process finished."
}

clear_logs() {
    if dialog --yesno "Are you sure you want to clear all logs?" 8 40; then
        sudo truncate -s 0 "${LOG_FILE}"
        # Re-initialize the log file
        log_info "Log file cleared and re-initialized."
        dialog --msgbox "Logs have been cleared." 8 40
    fi
}

reset_progress() {
    if dialog --yesno "Are you sure you want to reset all progress? This action cannot be undone." 8 60; then
        rm -f "${PROGRESS_FILE}"
        for key in "${!MENU_OPTIONS[@]}"; do
            MENU_OPTIONS["$key"]="Not Executed"
        done
        save_progress
        log_info "Progress reset."
        dialog --msgbox "Progress has been reset." 8 40
    fi
}

show_menu() {
    log_info "Current MENU_OPTIONS:"
    for key in "${!MENU_OPTIONS[@]}"; do
        log_info "$key: ${MENU_OPTIONS[$key]}"
    done

    local menu_items=()
    local progress=$(update_progress)
    
    for key in "${SETUP_ORDER[@]}"; do
        local status="${MENU_OPTIONS[$key]}"
        local version=$(get_module_version "$key")
        local deps="${DEPENDENCIES[$key]:-}"
        local menu_entry="$(get_status_symbol "$status") $key $version"
        [[ -n "$deps" ]] && menu_entry+=" [Depends on: $deps]"
        menu_items+=("$key" "$menu_entry")
    done

    menu_items+=("Complete Install" "Run complete installation process")
    menu_items+=("Clear Logs" "Clear all log files")
    menu_items+=("Reset Progress" "Reset all progress")

    local choice
    choice=$(dialog --clear --colors --no-lines \
                    --backtitle "IoT Control System Setup v${SCRIPT_VERSION}" \
                    --title "Main Menu" \
                    --menu "Select an option: (Progress: ${progress}%)" 24 78 19 \
                    "${menu_items[@]}" \
             3>&1 1>&2 2>&3)

    case $choice in
        "Exit") 
            save_progress
            log_info "Exiting setup script."
            exit 0 
            ;;
        "Check System") 
            source "${MODULES_DIR}/system_check.sh"
            system_check 
            ;;
        "Restart System")
            source "${MODULES_DIR}/system_restart.sh"
            system_restart 
            ;;
        "Export Code")
            source "${SCRIPT_DIR}/export_code.sh"
            export_code 
            ;;
        "Complete Install") 
            complete_installation 
            ;;
        "Clear Logs")
            clear_logs
            ;;
        "Reset Progress")
            reset_progress
            ;;
        *)  
            if [[ -n "$choice" ]]; then
                run_module "$choice"
            fi
            ;;
    esac
}

main() {
    log_info "Entering main function"
    if ! check_environment_variables; then
        log_error "Environment check failed. Exiting."
        exit 1
    fi
    while true; do
        log_info "Showing main menu"
        if ! show_menu; then
            log_error "show_menu failed. Restarting main loop."
            continue
        fi
        log_info "Returned from show_menu, continuing loop"
    done
}

# Set global error handling
set -o errtrace
trap 'handle_error "$BASH_COMMAND" >&2' ERR

# Execute the main function
log_info "Starting main function"
main
log_info "Exiting script"  # This line should never be reached under normal circumstances