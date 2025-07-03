#!/usr/bin/env bash

# Debug script for init-from-bundle.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

CONFIG_FILE="$SCRIPT_DIR/local.config"

echo "=== Debug: Configuration Loading ==="
load_config "$CONFIG_FILE"

echo "CONFIG_REPO_PATH: ${CONFIG_REPO_PATH:-'NOT SET'}"
echo "CONFIG_BUNDLE_SOURCE: ${CONFIG_BUNDLE_SOURCE:-'NOT SET'}"
echo "CONFIG_BASE_BRANCH: ${CONFIG_BASE_BRANCH:-'NOT SET'}"

REPO_PATH="$CONFIG_REPO_PATH"
BUNDLE_SOURCE="$CONFIG_BUNDLE_SOURCE"
BASE_BRANCH="${CONFIG_BASE_BRANCH:-}"

echo
echo "=== Debug: Variables ==="
echo "REPO_PATH: $REPO_PATH"
echo "BUNDLE_SOURCE: $BUNDLE_SOURCE"
echo "BASE_BRANCH: $BASE_BRANCH"

echo
echo "=== Debug: Bundle Directory ==="
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
    echo "Latest bundle directory: $BUNDLE_SOURCE"
fi

echo
echo "=== Debug: Test Submodule Bundle ==="
MODULE="tools/calibration-tools"
MODULE_BUNDLE_NAME=$(echo "$MODULE" | sed 's|/|_|g')
MODULE_BUNDLE="$BUNDLE_SOURCE/${MODULE_BUNDLE_NAME}.bundle"

echo "Module: $MODULE"
echo "Bundle name: $MODULE_BUNDLE_NAME"
echo "Bundle path: $MODULE_BUNDLE"
echo "Bundle exists: $([[ -f "$MODULE_BUNDLE" ]] && echo "YES" || echo "NO")"

if [[ -f "$MODULE_BUNDLE" ]]; then
    echo
    echo "=== Debug: Bundle Content ==="
    TEMP_DIR="/tmp/debug-bundle"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    cd "$TEMP_DIR"
    git init
    git remote add origin "$MODULE_BUNDLE"
    git fetch --all
    
    echo "Available branches:"
    git branch -r
    
    echo
    echo "=== Debug: Branch Selection ==="
    echo "BASE_BRANCH: $BASE_BRANCH"
    
    if [[ -n "$BASE_BRANCH" ]]; then
        echo "Checking for configured base branch: $BASE_BRANCH"
        if git show-ref --verify --quiet refs/remotes/origin/"$BASE_BRANCH"; then
            echo "✓ Found configured base branch: $BASE_BRANCH"
        else
            echo "✗ Configured base branch not found: $BASE_BRANCH"
        fi
    fi
    
    if git show-ref --verify --quiet refs/remotes/origin/main; then
        echo "✓ Found main branch"
    else
        echo "✗ No main branch"
    fi
    
    if git show-ref --verify --quiet refs/remotes/origin/master; then
        echo "✓ Found master branch"
    else
        echo "✗ No master branch"
    fi
    
    cd /
    rm -rf "$TEMP_DIR"
fi 