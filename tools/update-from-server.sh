#!/usr/bin/env bash

# Update local repository from server bundles
# Local-side script for fetching server updates

set -euo pipefail

# Load configuration utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

# Default config file
CONFIG_FILE="${1:-$SCRIPT_DIR/local.config}"

# Load and validate configuration
if ! validate_config "$CONFIG_FILE" "repo_path" "bundle_source"; then
    echo "Usage: $0 [config_file]"
    echo "Default config file: $SCRIPT_DIR/local.config"
    echo
    echo "Make sure updated bundle files are available in the bundle_source directory:"
    echo "  - slam-core.bundle"
    echo "  - (submodule bundles will be auto-detected)"
    exit 1
fi

load_config "$CONFIG_FILE"

REPO_PATH="$CONFIG_REPO_PATH"
BUNDLE_SOURCE="$CONFIG_BUNDLE_SOURCE"

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

# Validate paths
if [[ ! -d "$REPO_PATH" ]]; then
    echo "Error: Repository path '$REPO_PATH' does not exist" >&2
    exit 1
fi

if [[ ! -d "$BUNDLE_SOURCE" ]]; then
    echo "Error: Bundle source directory '$BUNDLE_SOURCE' does not exist" >&2
    exit 1
fi

# Get repository name
REPO_NAME=$(basename "$REPO_PATH")

echo "=== Updating repository from server bundles ==="
echo "Repository: $REPO_PATH"
echo "Bundle source: $BUNDLE_SOURCE"
echo "Modules: $MODULES"
echo

# Change to repository directory
cd "$REPO_PATH"

# Check if this is a git repository
if [[ ! -d ".git" ]]; then
    echo "Error: '$REPO_PATH' is not a git repository" >&2
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ -z "$CURRENT_BRANCH" ]]; then
    echo "Error: Not on any branch (detached HEAD)" >&2
    exit 1
fi

echo "Current branch: $CURRENT_BRANCH"

# Check for main repository bundle
MAIN_BUNDLE="$BUNDLE_SOURCE/${REPO_NAME}.bundle"
if [[ ! -f "$MAIN_BUNDLE" ]]; then
    echo "Error: Main repository bundle not found: $MAIN_BUNDLE" >&2
    exit 1
fi

echo "Found main repository bundle: $MAIN_BUNDLE"

# Update main repository
echo
echo "Updating main repository..."

# Determine base branch (main or master)
BASE_BRANCH=""
if git show-ref --verify --quiet refs/heads/main; then
    BASE_BRANCH="main"
elif git show-ref --verify --quiet refs/heads/master; then
    BASE_BRANCH="master"
else
    echo "Error: Could not determine base branch (main or master)" >&2
    exit 1
fi

echo "Base branch: $BASE_BRANCH"

# Fetch all branches from bundle
git fetch "$MAIN_BUNDLE" --all

# Check if we're on a feature branch
if [[ "$CURRENT_BRANCH" =~ ^dev/ ]]; then
    echo "Currently on feature branch: $CURRENT_BRANCH"
    echo "Updating base branch from server..."
    
    # Update base branch
    if git show-ref --verify --quiet refs/remotes/origin/"$BASE_BRANCH"; then
        git checkout "$BASE_BRANCH"
        git merge "origin/$BASE_BRANCH"
        echo "Updated base branch: $BASE_BRANCH"
        
        # Switch back to feature branch
        git checkout "$CURRENT_BRANCH"
        echo "Switched back to feature branch: $CURRENT_BRANCH"
    else
        echo "Warning: Base branch '$BASE_BRANCH' not found in bundle"
    fi
else
    echo "Currently on base branch: $CURRENT_BRANCH"
    
    # Update current branch
    if git show-ref --verify --quiet refs/remotes/origin/"$CURRENT_BRANCH"; then
        git merge "origin/$CURRENT_BRANCH"
        echo "Updated branch: $CURRENT_BRANCH"
    else
        echo "Warning: Branch '$CURRENT_BRANCH' not found in bundle"
    fi
fi

# Update submodules
echo
echo "Updating submodules..."

# Convert comma-separated modules to array
IFS=',' read -ra MODULE_ARRAY <<< "$MODULES"

for module in "${MODULE_ARRAY[@]}"; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [[ ! -d "$module" ]]; then
        echo "Warning: Submodule directory '$module' not found, skipping..."
        continue
    fi
    
    # Check if submodule is initialized
    if [[ ! -d "$module/.git" ]]; then
        echo "Warning: Submodule '$module' is not initialized, skipping..."
        continue
    fi
    
    echo "Processing submodule: $module"
    
    # Check for submodule bundle
    MODULE_BUNDLE="$BUNDLE_SOURCE/${module}.bundle"
    if [[ ! -f "$MODULE_BUNDLE" ]]; then
        echo "Warning: Submodule bundle not found: $MODULE_BUNDLE"
        echo "Skipping submodule: $module"
        continue
    fi
    
    # Get submodule current branch
    SUBMODULE_BRANCH=$(git -C "$module" branch --show-current 2>/dev/null || echo "")
    if [[ -z "$SUBMODULE_BRANCH" ]]; then
        echo "Warning: Submodule '$module' is in detached HEAD state, skipping..."
        continue
    fi
    
    echo "Submodule branch: $SUBMODULE_BRANCH"
    
    # Determine submodule base branch
    SUBMODULE_BASE_BRANCH=""
    if git -C "$module" show-ref --verify --quiet refs/heads/main; then
        SUBMODULE_BASE_BRANCH="main"
    elif git -C "$module" show-ref --verify --quiet refs/heads/master; then
        SUBMODULE_BASE_BRANCH="master"
    else
        echo "Warning: Could not determine base branch for submodule '$module', skipping..."
        continue
    fi
    
    # Fetch all branches from bundle
    git -C "$module" fetch "$MODULE_BUNDLE" --all
    
    # Check if submodule is on a feature branch
    if [[ "$SUBMODULE_BRANCH" =~ ^dev/ ]]; then
        echo "Submodule is on feature branch: $SUBMODULE_BRANCH"
        echo "Updating submodule base branch from server..."
        
        # Update submodule base branch
        if git -C "$module" show-ref --verify --quiet refs/remotes/origin/"$SUBMODULE_BASE_BRANCH"; then
            git -C "$module" checkout "$SUBMODULE_BASE_BRANCH"
            git -C "$module" merge "origin/$SUBMODULE_BASE_BRANCH"
            echo "Updated submodule base branch: $module/$SUBMODULE_BASE_BRANCH"
            
            # Switch back to feature branch
            git -C "$module" checkout "$SUBMODULE_BRANCH"
            echo "Switched back to submodule feature branch: $module/$SUBMODULE_BRANCH"
        else
            echo "Warning: Submodule base branch '$SUBMODULE_BASE_BRANCH' not found in bundle"
        fi
    else
        echo "Submodule is on base branch: $SUBMODULE_BRANCH"
        
        # Update submodule current branch
        if git -C "$module" show-ref --verify --quiet refs/remotes/origin/"$SUBMODULE_BRANCH"; then
            git -C "$module" merge "origin/$SUBMODULE_BRANCH"
            echo "Updated submodule branch: $module/$SUBMODULE_BRANCH"
        else
            echo "Warning: Submodule branch '$SUBMODULE_BRANCH' not found in bundle"
        fi
    fi
done

echo
echo "=== Update completed ==="
echo "Repository and submodules have been updated from server bundles" 