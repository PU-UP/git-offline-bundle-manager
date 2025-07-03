#!/usr/bin/env bash

# Configuration utilities for git-offline-bundle-manager
# This script provides functions to parse INI configuration files

# Parse INI file and export variables
# Usage: load_config <config_file>
load_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        echo "Error: Configuration file '$config_file' not found" >&2
        return 1
    fi
    
    # Read config file and export variables
    local current_section=""
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        
        # Handle INI section headers (lines starting with [)
        if [[ $key =~ ^[[:space:]]*\[ ]]; then
            current_section=$(echo "$key" | sed 's/^[[:space:]]*\[//;s/\][[:space:]]*$//')
            continue
        fi
        
        # Remove leading/trailing whitespace
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Export variable (with section prefix if not in main section)
        if [[ "$current_section" == "main" || -z "$current_section" ]]; then
            export "CONFIG_${key^^}"="$value"
        else
            export "CONFIG_${current_section^^}_${key^^}"="$value"
        fi
    done < "$config_file"
}

# Get config value by key
# Usage: get_config <config_file> <key>
get_config() {
    local config_file="$1"
    local key="$2"
    
    if [[ ! -f "$config_file" ]]; then
        echo "Error: Configuration file '$config_file' not found" >&2
        return 1
    fi
    
    # Search for key and return value
    local value=$(grep "^[[:space:]]*${key}[[:space:]]*=" "$config_file" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "$value"
}

# Validate required configuration
# Usage: validate_config <config_file> <required_keys...>
validate_config() {
    local config_file="$1"
    shift
    
    if [[ ! -f "$config_file" ]]; then
        echo "Error: Configuration file '$config_file' not found" >&2
        return 1
    fi
    
    for key in "$@"; do
        local value=$(get_config "$config_file" "$key")
        if [[ -z "$value" ]]; then
            echo "Error: Required configuration key '$key' not found in '$config_file'" >&2
            return 1
        fi
    done
    
    return 0
}

# Auto-detect submodules from .gitmodules file
# Usage: detect_submodules <repo_path>
detect_submodules() {
    local repo_path="$1"
    local gitmodules_file="$repo_path/.gitmodules"
    
    if [[ ! -f "$gitmodules_file" ]]; then
        echo "Warning: .gitmodules file not found in '$repo_path'" >&2
        return 1
    fi
    
    # Extract submodule paths from .gitmodules file
    local submodules=()
    while IFS='=' read -r key value; do
        if [[ "$key" =~ ^[[:space:]]*path[[:space:]]*$ ]]; then
            # Remove leading/trailing whitespace and quotes
            local path=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
            submodules+=("$path")
        fi
    done < "$gitmodules_file"
    
    # Join submodules with comma
    if [[ ${#submodules[@]} -gt 0 ]]; then
        printf '%s' "${submodules[*]}" | tr ' ' ','
    else
        echo ""
    fi
}

# Get submodules list (auto-detect or from config)
# Usage: get_submodules <config_file> <repo_path>
get_submodules() {
    local config_file="$1"
    local repo_path="$2"
    
    # Try to get modules from config first
    local config_modules=$(get_config "$config_file" "modules")
    
    if [[ -n "$config_modules" ]]; then
        echo "$config_modules"
    else
        # Auto-detect from .gitmodules
        detect_submodules "$repo_path"
    fi
} 