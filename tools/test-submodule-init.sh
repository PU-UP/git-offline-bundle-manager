#!/usr/bin/env bash

# Test script for submodule initialization logic

set -euo pipefail

# Load configuration utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

# Load config
CONFIG_FILE="$SCRIPT_DIR/local.config"
load_config "$CONFIG_FILE"

REPO_PATH="$CONFIG_REPO_PATH"
BUNDLE_SOURCE="$CONFIG_BUNDLE_SOURCE"
BASE_BRANCH="${CONFIG_BASE_BRANCH:-}"

echo "Testing submodule initialization logic..."
echo "Base branch from config: $BASE_BRANCH"
echo "Bundle source: $BUNDLE_SOURCE"

# Find latest bundle directory
find_latest_bundle_dir() {
    local base_dir="$1"
    local pattern="*_bundles"
    
    local bundle_dirs=($(find "$base_dir" -maxdepth 1 -type d -name "$pattern" 2>/dev/null | sort))
    
    if [[ ${#bundle_dirs[@]} -eq 0 ]]; then
        echo ""
        return 1
    fi
    
    echo "${bundle_dirs[-1]}"
}

LATEST_BUNDLE_DIR=$(find_latest_bundle_dir "$BUNDLE_SOURCE")
if [[ -n "$LATEST_BUNDLE_DIR" ]]; then
    BUNDLE_SOURCE="$LATEST_BUNDLE_DIR"
    echo "Using latest bundle directory: $BUNDLE_SOURCE"
fi

# Test with one submodule
MODULE="tools/calibration-tools"
MODULE_BUNDLE_NAME=$(echo "$MODULE" | sed 's|/|_|g')
MODULE_BUNDLE="$BUNDLE_SOURCE/${MODULE_BUNDLE_NAME}.bundle"

echo "Testing module: $MODULE"
echo "Bundle file: $MODULE_BUNDLE"

if [[ -f "$MODULE_BUNDLE" ]]; then
    echo "Bundle file exists!"
    
    # Create temporary directory for testing
    TEMP_DIR="/tmp/test-submodule-init"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    cd "$TEMP_DIR"
    
    # Initialize git repository
    git init
    
    # Add bundle as remote
    git remote add origin "$MODULE_BUNDLE"
    
    # Fetch all branches
    git fetch --all
    
    echo "Available branches:"
    git branch -r
    
    # Test branch selection logic
    TARGET_BRANCH=""
    
    if [[ -n "$BASE_BRANCH" ]] && git show-ref --verify --quiet refs/remotes/origin/"$BASE_BRANCH"; then
        TARGET_BRANCH="$BASE_BRANCH"
        echo "✓ Found configured base branch: $TARGET_BRANCH"
    elif git show-ref --verify --quiet refs/remotes/origin/main; then
        TARGET_BRANCH="main"
        echo "✓ Found main branch"
    elif git show-ref --verify --quiet refs/remotes/origin/master; then
        TARGET_BRANCH="master"
        echo "✓ Found master branch"
    else
        FIRST_BRANCH=$(git branch -r | head -n1 | sed 's/origin\///')
        if [[ -n "$FIRST_BRANCH" ]]; then
            TARGET_BRANCH="$FIRST_BRANCH"
            echo "✓ Using first available branch: $TARGET_BRANCH"
        else
            echo "✗ No branches found"
            exit 1
        fi
    fi
    
    echo "Selected target branch: $TARGET_BRANCH"
    
    # Cleanup
    cd /
    rm -rf "$TEMP_DIR"
    
else
    echo "Bundle file not found!"
fi 