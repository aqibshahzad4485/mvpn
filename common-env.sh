#!/bin/bash

################################################################################
# Common Environment Variable Helper Library
# 
# This library provides reusable functions for loading .env files,
# prompting for missing values, and validating configuration.
#
# Usage:
#   source /path/to/common-env.sh
#   load_env_file
#   prompt_if_missing "VARIABLE_NAME" "Description" "default_value"
#   validate_required "VAR1" "VAR2" "VAR3"
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Check if running in an interactive terminal
################################################################################
is_interactive() {
    [[ -t 0 ]] && [[ -t 1 ]]
}

################################################################################
# Load .env file and export variables
# 
# Searches for .env file in:
# 1. Current directory
# 2. Script directory
# 3. Parent directory
#
# Usage: load_env_file [path_to_env_file]
################################################################################
load_env_file() {
    local env_file="${1:-.env}"
    
    # If absolute path provided, use it
    if [[ "$env_file" = /* ]]; then
        if [ -f "$env_file" ]; then
            echo -e "${BLUE}→ Loading configuration from: $env_file${NC}"
            set -a
            source "$env_file"
            set +a
            return 0
        fi
        return 1
    fi
    
    # Search for .env file in common locations
    local search_paths=(
        "./$env_file"
        "$(dirname "${BASH_SOURCE[1]}")/$env_file"
        "$(dirname "${BASH_SOURCE[1]}")/../$env_file"
    )
    
    for path in "${search_paths[@]}"; do
        if [ -f "$path" ]; then
            echo -e "${BLUE}→ Loading configuration from: $path${NC}"
            set -a
            source "$path"
            set +a
            return 0
        fi
    done
    
    return 1
}

################################################################################
# Prompt for a value if not already set
#
# Arguments:
#   $1 - Variable name
#   $2 - Description/prompt text
#   $3 - Default value (optional)
#   $4 - Is secret? (true/false, optional, default: false)
#
# Usage:
#   prompt_if_missing "GITHUB_TOKEN" "GitHub Personal Access Token"
#   prompt_if_missing "DOMAIN" "Your domain name" "vpn.example.com"
#   prompt_if_missing "API_TOKEN" "API Token" "" "true"
################################################################################
prompt_if_missing() {
    local var_name="$1"
    local description="$2"
    local default_value="${3:-}"
    local is_secret="${4:-false}"
    
    # Get current value using indirect expansion
    local current_value="${!var_name}"
    
    # If value is already set, return
    if [ -n "$current_value" ]; then
        return 0
    fi
    
    # If not interactive, use default or return error
    if ! is_interactive; then
        if [ -n "$default_value" ]; then
            export "$var_name"="$default_value"
            echo -e "${YELLOW}⚠ Using default value for $var_name: $default_value${NC}"
            return 0
        else
            echo -e "${RED}ERROR: $var_name is required but not set${NC}" >&2
            echo -e "${YELLOW}Set it in .env file or as environment variable${NC}" >&2
            return 1
        fi
    fi
    
    # Interactive prompt
    local prompt_text="$description"
    if [ -n "$default_value" ]; then
        prompt_text="$prompt_text [$default_value]"
    fi
    prompt_text="$prompt_text: "
    
    local user_input
    if [ "$is_secret" = "true" ]; then
        # Read secret without echoing
        read -s -p "$(echo -e ${YELLOW}${prompt_text}${NC})" user_input
        echo "" # New line after secret input
    else
        read -p "$(echo -e ${YELLOW}${prompt_text}${NC})" user_input
    fi
    
    # Use default if no input provided
    if [ -z "$user_input" ] && [ -n "$default_value" ]; then
        user_input="$default_value"
    fi
    
    # Export the value
    if [ -n "$user_input" ]; then
        export "$var_name"="$user_input"
        return 0
    else
        echo -e "${RED}ERROR: $var_name is required${NC}" >&2
        return 1
    fi
}

################################################################################
# Validate that required variables are set
#
# Arguments:
#   $@ - List of required variable names
#
# Usage:
#   validate_required "GITHUB_TOKEN" "CF_TOKEN" "DOMAIN"
################################################################################
validate_required() {
    local missing_vars=()
    
    for var_name in "$@"; do
        local var_value="${!var_name}"
        if [ -z "$var_value" ]; then
            missing_vars+=("$var_name")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo -e "${RED}ERROR: The following required variables are not set:${NC}" >&2
        for var in "${missing_vars[@]}"; do
            echo -e "${RED}  - $var${NC}" >&2
        done
        echo "" >&2
        echo -e "${YELLOW}Please set them in .env file or as environment variables${NC}" >&2
        return 1
    fi
    
    return 0
}

################################################################################
# Set default value for a variable if not already set
#
# Arguments:
#   $1 - Variable name
#   $2 - Default value
#
# Usage:
#   set_default "INSTALL_DIR" "/opt/git"
################################################################################
set_default() {
    local var_name="$1"
    local default_value="$2"
    
    local current_value="${!var_name}"
    if [ -z "$current_value" ]; then
        export "$var_name"="$default_value"
    fi
}

################################################################################
# Display configuration summary
#
# Arguments:
#   $@ - List of variable names to display
#
# Usage:
#   show_config "GITHUB_ORG" "INSTALL_DIR" "VPN_DOMAIN"
################################################################################
show_config() {
    echo -e "${BLUE}Configuration:${NC}"
    for var_name in "$@"; do
        local var_value="${!var_name}"
        # Mask sensitive values
        if [[ "$var_name" =~ TOKEN|PASSWORD|SECRET|KEY ]]; then
            if [ -n "$var_value" ]; then
                echo "  $var_name: ${var_value:0:8}***"
            else
                echo "  $var_name: (not set)"
            fi
        else
            echo "  $var_name: $var_value"
        fi
    done
    echo ""
}

################################################################################
# Create .env.example file with provided variables
#
# Arguments:
#   $1 - Output file path
#   $@ - Variable definitions in format "VAR_NAME|Description|default_value|required"
#
# Usage:
#   create_env_example ".env.example" \
#     "GITHUB_TOKEN|GitHub Personal Access Token||required" \
#     "DOMAIN|Your domain name|vpn.example.com|optional"
################################################################################
create_env_example() {
    local output_file="$1"
    shift
    
    cat > "$output_file" <<'HEADER'
# MVPN Configuration File
# 
# Copy this file to .env and fill in your values
# DO NOT commit .env to version control!

HEADER
    
    for var_def in "$@"; do
        IFS='|' read -r var_name description default_value required <<< "$var_def"
        
        echo "# $description" >> "$output_file"
        if [ "$required" = "required" ]; then
            echo "# REQUIRED" >> "$output_file"
        else
            echo "# Optional - Default: $default_value" >> "$output_file"
        fi
        
        if [ -n "$default_value" ]; then
            echo "$var_name=\"$default_value\"" >> "$output_file"
        else
            echo "$var_name=\"\"" >> "$output_file"
        fi
        echo "" >> "$output_file"
    done
    
    echo -e "${GREEN}✓ Created example configuration: $output_file${NC}"
}

################################################################################
# Confirm action with user
#
# Arguments:
#   $1 - Prompt message
#   $2 - Default answer (y/n, optional, default: n)
#
# Returns:
#   0 if user confirms (y/yes)
#   1 if user declines (n/no)
#
# Usage:
#   if confirm_action "Continue with installation?"; then
#     echo "Proceeding..."
#   fi
################################################################################
confirm_action() {
    local prompt="$1"
    local default="${2:-n}"
    
    if ! is_interactive; then
        # In non-interactive mode, use default
        if [ "$default" = "y" ]; then
            return 0
        else
            return 1
        fi
    fi
    
    local yn
    if [ "$default" = "y" ]; then
        read -p "$(echo -e ${YELLOW}${prompt} [Y/n]: ${NC})" yn
        yn=${yn:-y}
    else
        read -p "$(echo -e ${YELLOW}${prompt} [y/N]: ${NC})" yn
        yn=${yn:-n}
    fi
    
    case $yn in
        [Yy]* ) return 0;;
        * ) return 1;;
    esac
}
