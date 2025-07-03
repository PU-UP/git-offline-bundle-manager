#!/usr/bin/env bash

# Check what branches are available in bundle files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

CONFIG_FILE="$SCRIPT_DIR/local.config"
load_config "$CONFIG_FILE"

BUNDLE_SOURCE="$CONFIG_BUNDLE_SOURCE"
BASE_BRANCH="${CONFIG_BASE_BRANCH:-}"

echo "=== Checking Bundle Branches ==="
echo "Bundle source: $BUNDLE_SOURCE"
echo "Target base branch: $BASE_BRANCH"
echo

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

# Test submodules
MODULES=(
    "tools/calibration-tools"
    "slam_architect_ws/algorithm/dr-odom"
    "slam_architect_ws/algorithm/depth-estimation"
    "slam_architect_ws/algorithm/map-fusion"
    "slam_architect_ws/algorithm/vision-tag"
    "slam_architect_ws/algorithm/viw"
    "slam_architect_ws/algorithm/pose-graph"
    "slam_architect_ws/slam-base"
    "slam_architect_ws/integration"
    "slam_architect_ws/algorithm/odom-fusion"
)

for module in "${MODULES[@]}"; do
    echo
    echo "=== $module ==="
    
    MODULE_BUNDLE_NAME=$(echo "$module" | sed 's|/|_|g')
    MODULE_BUNDLE="$BUNDLE_SOURCE/${MODULE_BUNDLE_NAME}.bundle"
    
    if [[ ! -f "$MODULE_BUNDLE" ]]; then
        echo "Bundle file not found: $MODULE_BUNDLE"
        continue
    fi
    
    echo "Bundle file: $MODULE_BUNDLE"
    
    # Create temporary directory to inspect bundle
    TEMP_DIR="/tmp/check-bundle-$(basename "$module" | sed 's|/|_|g')"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    cd "$TEMP_DIR"
    
    # Initialize git and add bundle as remote
    git init
    git remote add origin "$MODULE_BUNDLE"
    
    # Fetch all branches
    git fetch --all
    
    # Show all branches
    echo "Available branches:"
    git branch -r | sed 's/origin\///' | sort
    
    # Check if target branch exists
    if [[ -n "$BASE_BRANCH" ]]; then
        if git show-ref --verify --quiet refs/remotes/origin/"$BASE_BRANCH"; then
            echo "✓ Target branch '$BASE_BRANCH' found"
        else
            echo "✗ Target branch '$BASE_BRANCH' NOT found"
        fi
    fi
    
    # Show commit info for each branch
    echo "Branch commits:"
    for branch in $(git branch -r | sed 's/origin\///'); do
        COMMIT=$(git rev-parse "origin/$branch")
        SHORT_COMMIT=$(git rev-parse --short "origin/$branch")
        echo "  $branch: $SHORT_COMMIT"
    done
    
    cd /
    rm -rf "$TEMP_DIR"
done

echo
echo "=== Summary ==="
echo "If target branch '$BASE_BRANCH' is not found in some bundles,"
echo "you may need to:"
echo "1. Use a different base branch that exists in all submodules"
echo "2. Or update the bundle files to include the target branch"
echo "3. Or modify the configuration to use a branch that exists" 