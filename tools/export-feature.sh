#!/usr/bin/env bash

# Export feature branch bundles for local development
# Local-side script for exporting feature branch bundles

set -euo pipefail

# Load configuration utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

# Default config file
CONFIG_FILE="${1:-$SCRIPT_DIR/local.config}"

# Load and validate configuration
if ! validate_config "$CONFIG_FILE" "repo_path"; then
    echo "Usage: $0 [config_file]"
    echo "Default config file: $SCRIPT_DIR/local.config"
    echo
    echo "This script exports the current feature branch as bundles."
    echo "Make sure you are on a feature branch (dev/*) before running."
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

echo "=== Exporting feature branch bundles ==="
echo "Repository: $REPO_PATH"
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

# Validate that we're on a feature branch
if [[ ! "$CURRENT_BRANCH" =~ ^dev/ ]]; then
    echo "Error: Not on a feature branch. Current branch: $CURRENT_BRANCH" >&2
    echo "Please checkout a feature branch (dev/*) before exporting" >&2
    exit 1
fi

# Create output directory
OUTPUT_DIR="./bundles"
if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

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

# Export main repository feature bundle
echo
echo "Exporting main repository feature bundle..."

# Check if there are commits to export
if git rev-list --count "$BASE_BRANCH..$CURRENT_BRANCH" | grep -q "^0$"; then
    echo "Warning: No commits to export for main repository"
    echo "Feature branch is up to date with base branch"
else
    MAIN_BUNDLE="$OUTPUT_DIR/${REPO_NAME}-${CURRENT_BRANCH}.bundle"
    git bundle create "$MAIN_BUNDLE" "$BASE_BRANCH..$CURRENT_BRANCH"
    echo "Created: $MAIN_BUNDLE"
fi

# Export submodule feature bundles
echo
echo "Exporting submodule feature bundles..."

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
    
    # Check if submodule is on the same feature branch
    SUBMODULE_BRANCH=$(git -C "$module" branch --show-current 2>/dev/null || echo "")
    if [[ -z "$SUBMODULE_BRANCH" ]]; then
        echo "Warning: Submodule '$module' is in detached HEAD state, skipping..."
        continue
    fi
    
    if [[ "$SUBMODULE_BRANCH" != "$CURRENT_BRANCH" ]]; then
        echo "Warning: Submodule '$module' is on branch '$SUBMODULE_BRANCH', expected '$CURRENT_BRANCH'"
        echo "Skipping submodule: $module"
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
    
    # Check if there are commits to export
    if git -C "$module" rev-list --count "$SUBMODULE_BASE_BRANCH..$CURRENT_BRANCH" | grep -q "^0$"; then
        echo "No commits to export for submodule: $module"
    else
        MODULE_BUNDLE="$OUTPUT_DIR/${module}-${CURRENT_BRANCH}.bundle"
        git -C "$module" bundle create "$MODULE_BUNDLE" "$SUBMODULE_BASE_BRANCH..$CURRENT_BRANCH"
        echo "Created: $MODULE_BUNDLE"
    fi
done

echo
echo "=== Export completed ==="
echo "Bundles created in: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"/*.bundle 2>/dev/null || echo "No bundle files created"

echo
echo "Next steps:"
echo "1. Copy bundles to server: cp $OUTPUT_DIR/*.bundle /path/to/server/"
echo "2. Run import-feature.sh on server to import the bundles" 