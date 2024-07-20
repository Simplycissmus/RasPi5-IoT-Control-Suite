#!/bin/bash

# File: export_project_files_content.sh
# Author: Patric Aeberhard (with enhancements by the Assistant)
# Version: 6.0
# Description: Exports the content of project files and system configuration files into separate Markdown files with metadata and usage instructions.
# Instructions: 
# 1. Save this script to the same directory where setup_iot_system.sh is located.
# 2. Make the script executable: chmod +x export_project_files_content.sh
# 3. Run the script with sudo: sudo ./export_project_files_content.sh
# 4. The output files will be saved in ./docs/md/

# Set directories relative to the script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
OUTPUT_DIR_MD="$SCRIPT_DIR/docs/md"

# Create directories and delete old files
prepare_directories() {
    echo "Preparing directories..."
    sudo rm -rf "$OUTPUT_DIR_MD"
    mkdir -p "$OUTPUT_DIR_MD"
    mkdir -p "$OUTPUT_DIR_MD/individual_files"
    sudo chown "$(whoami)":"$(whoami)" "$OUTPUT_DIR_MD"
    sudo chown "$(whoami)":"$(whoami)" "$OUTPUT_DIR_MD/individual_files"
}

# Function to export the directory structure
export_directory_structure() {
    echo "Creating directory structure..."
    output_file="$OUTPUT_DIR_MD/directory_structure.md"
    echo "## Directory Structure" > "$output_file"
    echo '```' >> "$output_file"
    tree "$PROJECT_DIR" -I 'venv|__pycache__|*.pyc|*.dist-info|*.egg-info|.git|*.log|*.tmp|*.swp|node_modules|docs/md' >> "$output_file"
    echo '```' >> "$output_file"
}

# Function to add metadata to a file
add_metadata_to_file() {
    local file_path="$1"
    local output_file="$2"
    echo "## Metadata" >> "$output_file"
    echo "- Export Date: $(date +"%Y-%m-%d %H:%M:%S")" >> "$output_file"
    echo "- Original File Path: $file_path" >> "$output_file"
    echo "- General Project Overview: See general_project_overview.md" >> "$output_file"
    echo "" >> "$output_file"
}

# Function to export system configuration files
export_system_config_files() {
    echo "Exporting system configuration files..."

    system_files=(
        "/etc/nginx/sites-available/default"
        "/etc/nginx/nginx.conf"
        "/etc/systemd/system/webinterface.service"
        "/etc/mosquitto/mosquitto.conf"
        "/etc/openvpn/server.conf"
        "/etc/dnsmasq.conf"
        "/etc/ddclient.conf"
    )

    for file in "${system_files[@]}"; do
        output_file="$OUTPUT_DIR_MD/individual_files/$(basename "$file").md"
        if [[ -f "$file" ]]; then
            echo -e "\n### $file\n" >> "$output_file"
            add_metadata_to_file "$file" "$output_file"
            echo '```' >> "$output_file"
            sudo cat "$file" >> "$output_file"
            echo '```' >> "$output_file"
        else
            echo -e "\n### WARNING: $file does not exist and will be skipped.\n" >> "$output_file"
        fi
    done
}

# Function to export the content of project files
export_project_files() {
    echo "Exporting project files..."

    declare -A file_counter

    find "$PROJECT_DIR" -type f \
        -not -path '*/__pycache__/*' \
        -not -path '*.pyc' \
        -not -path '*/venv/*' \
        -not -path '*.dist-info/*' \
        -not -path '*.egg-info/*' \
        -not -path '*/.git/*' \
        -not -path '*.log' \
        -not -path '*.tmp' \
        -not -path '*.swp' \
        -not -path '*/node_modules/*' \
        -not -path "$OUTPUT_DIR_MD/*" \
        -not -name ".gitignore" \
        -print0 | while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            base_name=$(basename "$file")
            ext="${base_name##*.}"
            name="${base_name%.*}"
            
            if [[ -v file_counter["$base_name"] ]]; then
                count=${file_counter["$base_name"]}
                new_base_name="${name}_$count.$ext"
                file_counter["$base_name"]=$((count + 1))
            else
                new_base_name="$base_name"
                file_counter["$base_name"]=1
            fi

            output_file="$OUTPUT_DIR_MD/individual_files/$new_base_name.md"
            echo -e "\n## $new_base_name\n" > "$output_file"
            add_metadata_to_file "$file" "$output_file"
            echo '```' >> "$output_file"
            # Add syntax highlighting
            case "$file" in
                *.sh) echo 'bash' >> "$output_file" ;;
                *.py) echo 'python' >> "$output_file" ;;
                *.conf) echo 'ini' >> "$output_file" ;;
                *.html) echo 'html' >> "$output_file" ;;
                *.css) echo 'css' >> "$output_file" ;;
                *) echo '' >> "$output_file" ;; # No highlighting for unknown types
            esac
            cat "$file" >> "$output_file"
            echo '```' >> "$output_file"
        else
            echo "WARNING: $file is not a file and will be skipped."
        fi
    done
}

# Function to create a list of all exported files
create_export_list() {
    echo "Creating export list..."
    output_file="$OUTPUT_DIR_MD/export_list.md"
    echo "## Export List" > "$output_file"
    echo "This file lists all exported files." >> "$output_file"
    echo "" >> "$output_file"
    
    for file in "$OUTPUT_DIR_MD/individual_files"/*.md; do
        echo "- $(basename "$file")" >> "$output_file"
    done
}

# Main execution
prepare_directories
export_directory_structure
export_system_config_files
export_project_files
create_export_list

echo "Export complete. The files have been created in the $OUTPUT_DIR_MD directory."
