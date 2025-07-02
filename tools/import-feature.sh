#!/usr/bin/env bash

# Import feature branch bundles from local development
# Server-side script for importing feature branch bundles

set -euo pipefail

# Load configuration utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

# Default config file
CONFIG_FILE="${1:-$SCRIPT_DIR/server.config}"

# Load and validate configuration
if ! validate_config "$CONFIG_FILE" "repo_path"; then
    echo "Usage: $0 <bundle_directory> [config_file]"
    echo "Default config file: $SCRIPT_DIR/server.config"
    echo
    echo "Example: $0 /media/usb/feature-bundles"
    exit 1
fi

BUNDLE_DIR="${1:-}"
if [[ -z "$BUNDLE_DIR" ]]; then
    echo "Error: Bundle directory not specified" >&2
    echo "Usage: $0 <bundle_directory> [config_file]"
    exit 1
fi

if [[ ! -d "$BUNDLE_DIR" ]]; then
    echo "Error: Bundle directory '$BUNDLE_DIR' does not exist" >&2
    exit 1
fi

load_config "$CONFIG_FILE"

REPO_PATH="$CONFIG_REPO_PATH"

# Auto-detect modules if not specified in config
MODULES="$CONFIG_MODULES"
if [[ -z "$MODULES" ]]; then
    echo "No modules specified in config, auto-detecting from .gitmodules..."
    MODULES=$(get_submodules "$CONFIG_FILE" "$REPO_PATH")
    if [[ -z "$MODULES" ]]; then
        echo "Warning: No submodules detected. Proceeding with main repository only."
    else
        echo "Detected submodules: $MODULES"
    fi
fi

# Validate repository path
if [[ ! -d "$REPO_PATH" ]]; then
    echo "Error: Repository path '$REPO_PATH' does not exist" >&2
    exit 1
fi

# Get repository name
REPO_NAME=$(basename "$REPO_PATH")

echo "=== Importing feature branch bundles ==="
echo "Repository: $REPO_PATH"
echo "Bundle directory: $BUNDLE_DIR"
echo "Modules: $MODULES"
echo

# Change to repository directory
cd "$REPO_PATH"

# Check if this is a git repository
if [[ ! -d ".git" ]]; then
    echo "Error: '$REPO_PATH' is not a git repository" >&2
    exit 1
fi

# Find feature branch bundles
FEATURE_BUNDLES=()
for bundle in "$BUNDLE_DIR"/*.bundle; do
    if [[ -f "$bundle" ]]; then
        FEATURE_BUNDLES+=("$bundle")
    fi
done

if [[ ${#FEATURE_BUNDLES[@]} -eq 0 ]]; then
    echo "Error: No bundle files found in '$BUNDLE_DIR'" >&2
    exit 1
fi

echo "Found bundle files:"
for bundle in "${FEATURE_BUNDLES[@]}"; do
    echo "  - $(basename "$bundle")"
done
echo

# Import main repository feature bundle
MAIN_FEATURE_BUNDLE=""
for bundle in "${FEATURE_BUNDLES[@]}"; do
    bundle_name=$(basename "$bundle" .bundle)
    if [[ "$bundle_name" == "$REPO_NAME"* ]]; then
        MAIN_FEATURE_BUNDLE="$bundle"
        break
    fi
done

if [[ -n "$MAIN_FEATURE_BUNDLE" ]]; then
    echo "Importing main repository feature bundle: $(basename "$MAIN_FEATURE_BUNDLE")"
    
    # Extract feature branch name from bundle filename
    BUNDLE_NAME=$(basename "$MAIN_FEATURE_BUNDLE" .bundle)
    FEATURE_BRANCH="${BUNDLE_NAME#${REPO_NAME}-}"
    
    if [[ "$FEATURE_BRANCH" == "$BUNDLE_NAME" ]]; then
        echo "Error: Could not extract feature branch name from bundle filename" >&2
        exit 1
    fi
    
    echo "Feature branch: $FEATURE_BRANCH"
    
    # Fetch the feature branch from bundle
    git fetch "$MAIN_FEATURE_BUNDLE" "$FEATURE_BRANCH:$FEATURE_BRANCH"
    echo "Successfully imported main repository feature branch: $FEATURE_BRANCH"
else
    echo "Warning: No main repository feature bundle found"
fi

# Import submodule feature bundles
echo
echo "Importing submodule feature bundles..."

# Convert comma-separated modules to array
IFS=',' read -ra MODULE_ARRAY <<< "$MODULES"

for module in "${MODULE_ARRAY[@]}"; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [[ ! -d "$module" ]]; then
        echo "Warning: Submodule directory '$module' not found, skipping..."
        continue
    fi
    
    # Find corresponding feature bundle
    MODULE_FEATURE_BUNDLE=""
    for bundle in "${FEATURE_BUNDLES[@]}"; do
        bundle_name=$(basename "$bundle" .bundle)
        if [[ "$bundle_name" == "${module}-"* ]]; then
            MODULE_FEATURE_BUNDLE="$bundle"
            break
        fi
    done
    
    if [[ -n "$MODULE_FEATURE_BUNDLE" ]]; then
        echo "Importing submodule feature bundle: $module -> $(basename "$MODULE_FEATURE_BUNDLE")"
        
        # Extract feature branch name from bundle filename
        BUNDLE_NAME=$(basename "$MODULE_FEATURE_BUNDLE" .bundle)
        FEATURE_BRANCH="${BUNDLE_NAME#${module}-}"
        
        if [[ "$FEATURE_BRANCH" == "$BUNDLE_NAME" ]]; then
            echo "Error: Could not extract feature branch name from bundle filename" >&2
            continue
        fi
        
        echo "Feature branch: $FEATURE_BRANCH"
        
        # Check if submodule is initialized
        if [[ -d "$module/.git" ]]; then
            # Fetch the feature branch from bundle
            git -C "$module" fetch "$MODULE_FEATURE_BUNDLE" "$FEATURE_BRANCH:$FEATURE_BRANCH"
            echo "Successfully imported submodule feature branch: $module/$FEATURE_BRANCH"
        else
            echo "Warning: Submodule '$module' is not initialized, skipping..."
        fi
    else
        echo "Warning: No feature bundle found for submodule '$module'"
    fi
done

echo
echo "=== Import completed ==="
echo "Feature branches are now available for review and merging" 