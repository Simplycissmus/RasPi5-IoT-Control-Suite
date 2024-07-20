#!/bin/bash
# Version: 1.3.0

# ============================================================================
# Script Name: github_setup.sh
# Description: Module for GitHub setup with enhanced error handling and security
# Author: Patric Aeberhard (with improvements from AI)
# Version: 1.3.0
# Date: 2024-07-21
# ============================================================================

# Ensure all variables are properly initialized
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
LOG_DIR="${LOG_DIR:-${SCRIPT_DIR}/../log}"
UTILS_DIR="${UTILS_DIR:-${SCRIPT_DIR}/../utils}"
PROJECT_DIR="${PROJECT_DIR:-/home/patric/IoT_Control_System}"

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

# Log file setup
export LOG_FILE="${LOG_FILE:-${LOG_DIR}/iot_setup.log}"

# Source utility scripts if not already sourced
if [[ -z "${LOG_INFO:-}" ]]; then
    source "${UTILS_DIR}/error_handling.sh"
    source "${UTILS_DIR}/logging_utils.sh"
fi

# Load environment variables
if [[ -f "${SCRIPT_DIR}/../credentials.env" ]]; then
    source "${SCRIPT_DIR}/../credentials.env"
    log_info "Credentials loaded successfully"
else
    log_error "credentials.env not found. Please create the file."
    return 1
fi

# Function to check and install dependencies
check_and_install_dependencies() {
    local dependencies=("jq" "git" "curl")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_info "$dep is not installed. Installing $dep..."
            if sudo apt-get update && sudo apt-get install -y "$dep"; then
                log_info "$dep has been successfully installed."
            else
                log_error "Failed to install $dep. Please install it manually and run the script again."
                return 1
            fi
        else
            log_info "$dep is already installed."
        fi
    done
    return 0
}

# Function to validate GitHub token
validate_github_token() {
    log_info "Validating GitHub token..."
    local check_response
    check_response=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
                           "https://api.github.com/user")
    log_info "GitHub API response: $check_response"
    if [ "$(echo "$check_response" | jq -r .message)" == "Bad credentials" ]; then
        log_error "Invalid GitHub token. Please check your credentials."
        return 1
    fi
    log_info "GitHub token is valid."
    return 0
}

# Function to check network connection
check_network() {
    log_info "Checking network connection..."
    if ! ping -c 1 github.com &> /dev/null; then
        log_error "Unable to reach GitHub. Please check your network connection."
        return 1
    fi
    log_info "Network connection is good."
    return 0
}

# Function to configure Git
configure_git() {
    log_info "Configuring Git..."
    git config --global user.name "${GIT_USERNAME}"
    git config --global user.email "${GIT_EMAIL}"
    log_info "Git globally configured."
}

# Function to get list of repositories
get_repository_list() {
    log_info "Fetching repository list..."
    local repos
    repos=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
                  "https://api.github.com/user/repos?sort=updated&per_page=10")
    if [[ $(echo "$repos" | jq -r 'if type=="array" then "true" else "false" end') == "true" ]]; then
        echo "$repos" | jq -r '.[].full_name'
    else
        log_error "Failed to fetch repositories. API response:"
        log_error "$repos"
        return 1
    fi
}

# Function to get list of branches for a repository
get_branch_list() {
    local repo=$1
    log_info "Fetching branch list for $repo..."
    local branches
    branches=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
                     "https://api.github.com/repos/${repo}/branches")
    if [[ $(echo "$branches" | jq -r 'if type=="array" then "true" else "false" end') == "true" ]]; then
        echo "$branches" | jq -r '.[].name'
    else
        log_error "Failed to fetch branches for $repo. API response:"
        log_error "$branches"
        return 1
    fi
}

# Function to clone an existing repository
clone_project() {
    log_info "Cloning project from GitHub..."
    
    local repos
    repos=$(get_repository_list)
    if [ $? -ne 0 ] || [ -z "$repos" ]; then
        log_error "Failed to fetch repository list. Please check your GitHub token and network connection."
        return 1
    fi

    local repo_array=()
    local i=1
    while read -r repo; do
        repo_array+=("$i" "$repo")
        ((i++))
    done <<< "$repos"

    if [ ${#repo_array[@]} -eq 0 ]; then
        log_error "No repositories found for your account."
        return 1
    fi

    local repo_choice
    repo_choice=$(dialog --clear --no-lines --title "Select Repository" \
                               --menu "Choose a repository to clone:" 15 50 10 \
                               "${repo_array[@]}" \
                        3>&1 1>&2 2>&3)

    if [ -z "$repo_choice" ]; then
        log_error "No repository selected."
        return 1
    fi

    local selected_repo=${repo_array[$(( repo_choice * 2 - 1 ))]}
    
    local branches
    branches=$(get_branch_list "$selected_repo")
    if [ $? -ne 0 ] || [ -z "$branches" ]; then
        log_error "Failed to fetch branch list for $selected_repo. Please check your permissions."
        return 1
    fi

    local branch_array=()
    i=1
    while read -r branch; do
        branch_array+=("$i" "$branch")
        ((i++))
    done <<< "$branches"

    if [ ${#branch_array[@]} -eq 0 ]; then
        log_error "No branches found for the selected repository."
        return 1
    fi

    local branch_choice
    branch_choice=$(dialog --clear --no-lines --title "Select Branch" \
                                 --menu "Choose a branch to clone:" 15 50 10 \
                                 "${branch_array[@]}" \
                          3>&1 1>&2 2>&3)

    if [ -z "$branch_choice" ]; then
        log_error "No branch selected."
        return 1
    fi

    local selected_branch=${branch_array[$(( branch_choice * 2 - 1 ))]}

    local repo_url="https://${GITHUB_TOKEN}@github.com/${selected_repo}.git"
    local repo_name
    repo_name=$(basename "${selected_repo}")
    local repo_dir="${PROJECT_DIR}/${repo_name}"
    
    if [ -d "$repo_dir" ]; then
        log_info "Removing existing directory: $repo_dir"
        rm -rf "$repo_dir"
    fi
    
    log_info "Cloning repository to: $repo_dir"      
    if git clone -b "$selected_branch" "$repo_url" "$repo_dir"; then
        log_info "Repository successfully cloned."
        dialog --msgbox "Repository '${selected_repo}' (branch: ${selected_branch}) successfully cloned to ${repo_dir}." 8 60
        PROJECT_DIR="$repo_dir"
        return 0
    else
        log_error "Failed to clone repository."
        dialog --msgbox "Failed to clone repository '${selected_repo}'." 8 50
        return 1
    fi
}

# Function to create a new repository
create_new_repo() {
    log_info "Creating a new repository on GitHub..."
    local project_name
    project_name=$(dialog --clear --no-lines --title "New Repository" \
                                --inputbox "Enter the name of the new project:" 8 50 \
                         3>&1 1>&2 2>&3)

    if [ -z "$project_name" ]; then
        log_error "No project name provided."
        return 1
    fi

    local project_dir="${PROJECT_DIR}/${project_name}"
    
    if [ -d "$project_dir" ]; then
        log_info "Removing existing directory: $project_dir"
        rm -rf "$project_dir"
    fi
    
    log_info "Creating new project directory: $project_dir"
    mkdir -p "$project_dir"
    cd "$project_dir" || return 1
    git init

    local create_repo_response
    create_repo_response=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
                                 -H "Accept: application/vnd.github.v3+json" \
                                 -d "{\"name\":\"${project_name}\"}" \
                                 "https://api.github.com/user/repos")
    
    local repo_url
    repo_url=$(echo "$create_repo_response" | jq -r .clone_url)
    local error_message
    error_message=$(echo "$create_repo_response" | jq -r .message)
    
    if [ -z "$repo_url" ] || [ "$repo_url" == "null" ]; then
        log_error "Failed to create repository on GitHub. Error message: $error_message"
        return 1
    fi

    log_info "Repository created successfully. Clone URL: $repo_url"

    git remote add origin "https://${GITHUB_TOKEN}@github.com/${GIT_USERNAME}/${project_name}.git"

    echo "# $project_name" > README.md
    git add README.md
    git commit -m "Initial commit"

    if git push -u origin master; then
        log_info "New project directory created and repository initialized."
        dialog --msgbox "New repository '${project_name}' created and initialized at ${project_dir}." 8 60
        PROJECT_DIR="$project_dir"
        return 0
    else
        log_error "Failed to push initial commit to GitHub."
        return 1
    fi
}

# Main function
github_setup() {
    log_info "Starting GitHub setup..."
    log_info "Current working directory: $(pwd)"
    log_info "Content of GITHUB_TOKEN: ${GITHUB_TOKEN}"
    log_info "Content of GIT_USERNAME: ${GIT_USERNAME}"
    log_info "Content of GIT_EMAIL: ${GIT_EMAIL}"

    if ! check_and_install_dependencies; then
        log_error "Failed to check or install dependencies"
        return 1
    fi

    if ! validate_github_token; then
        log_error "Failed to validate GitHub token"
        return 1
    fi

    if ! check_network; then
        log_error "Network check failed"
        return 1
    fi

    log_info "Configuring Git..."
    configure_git
    log_info "Git configured successfully"

    while true; do
        local choice
        choice=$(dialog --clear --no-lines --title "GitHub Setup" \
                              --menu "Choose an action:" 15 50 4 \
                              1 "Clone existing repository" \
                              2 "Create new repository" \
                              3 "Return to main menu" \
                              3>&1 1>&2 2>&3)

        case $choice in
            1) 
                if clone_project; then
                    log_info "GitHub setup completed successfully."
                    return 0
                fi
                ;;
            2)
                if create_new_repo; then
                    log_info "GitHub setup completed successfully."
                    return 0
                fi
                ;;
            3|"") 
                log_info "Returning to main menu without completing GitHub setup."
                return 0
                ;;
            *) 
                log_error "Invalid choice. Please try again."
                ;;
        esac
    done
}

# The main function is not called here, as this script will be sourced by the main setup script