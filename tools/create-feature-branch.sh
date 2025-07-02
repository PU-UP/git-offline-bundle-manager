#!/usr/bin/env bash

# Create feature branch for main repository and all submodules
# Helper script for creating feature branches

set -euo pipefail

# Load configuration utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

# Default config file
CONFIG_FILE="${1:-$SCRIPT_DIR/local.config}"

# Load and validate configuration
if ! validate_config "$CONFIG_FILE" "repo_path"; then
    echo "Usage: $0 <feature_branch_name> [config_file]"
    echo "Default config file: $SCRIPT_DIR/local.config"
    echo
    echo "Example: $0 awesome-feature"
    echo "This will create: dev/awesome-feature"
    exit 1
fi

FEATURE_NAME="${1:-}"
if [[ -z "$FEATURE_NAME" ]]; then
    echo "Error: Feature branch name not specified" >&2
    echo "Usage: $0 <feature_branch_name> [config_file]"
    exit 1
fi

# Validate feature name format
if [[ ! "$FEATURE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Feature name contains invalid characters" >&2
    echo "Only letters, numbers, hyphens, and underscores are allowed" >&2
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

echo "=== Creating feature branch ==="
echo "Repository: $REPO_PATH"
echo "Feature name: $FEATURE_NAME"
echo "Feature branch: dev/$FEATURE_NAME"
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

# Check if we're already on the target feature branch
FEATURE_BRANCH="dev/$FEATURE_NAME"
if [[ "$CURRENT_BRANCH" == "$FEATURE_BRANCH" ]]; then
    echo "Already on target feature branch: $FEATURE_BRANCH"
else
    # Create feature branch for main repository
    echo
    echo "Creating feature branch for main repository..."
    
    # Switch to base branch first
    if [[ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]]; then
        echo "Switching to base branch: $BASE_BRANCH"
        git checkout "$BASE_BRANCH"
    fi
    
    # Create and switch to feature branch
    git checkout -b "$FEATURE_BRANCH"
    echo "Created and switched to feature branch: $FEATURE_BRANCH"
fi

# Create feature branches for submodules
echo
echo "Creating feature branches for submodules..."

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
    
    # Get submodule current branch
    SUBMODULE_BRANCH=$(git -C "$module" branch --show-current 2>/dev/null || echo "")
    if [[ -z "$SUBMODULE_BRANCH" ]]; then
        echo "Warning: Submodule '$module' is in detached HEAD state, skipping..."
        continue
    fi
    
    # Check if submodule is already on the target feature branch
    if [[ "$SUBMODULE_BRANCH" == "$FEATURE_BRANCH" ]]; then
        echo "Submodule already on target feature branch: $module/$FEATURE_BRANCH"
        continue
    fi
    
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
    
    # Switch to base branch first
    if [[ "$SUBMODULE_BRANCH" != "$SUBMODULE_BASE_BRANCH" ]]; then
        echo "Switching submodule to base branch: $module/$SUBMODULE_BASE_BRANCH"
        git -C "$module" checkout "$SUBMODULE_BASE_BRANCH"
    fi
    
    # Create and switch to feature branch
    git -C "$module" checkout -b "$FEATURE_BRANCH"
    echo "Created and switched to submodule feature branch: $module/$FEATURE_BRANCH"
done

echo
echo "=== Feature branch creation completed ==="
echo "Feature branch: $FEATURE_BRANCH"
echo
echo "Next steps:"
echo "1. Make your changes"
echo "2. Commit your changes"
echo "3. Run export-feature.sh to create bundles" 