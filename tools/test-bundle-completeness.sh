#!/usr/bin/env bash

# Test script to verify bundle completeness
# This script checks if bundles contain all branches and tags

set -euo pipefail

# Load configuration utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

# Default config file
CONFIG_FILE="${1:-$SCRIPT_DIR/local.config}"

# Load and validate configuration
if ! validate_config "$CONFIG_FILE" "bundle_source"; then
    echo "Usage: $0 [config_file]"
    echo "Default config file: $SCRIPT_DIR/local.config"
    exit 1
fi

load_config "$CONFIG_FILE"

BUNDLE_SOURCE="$CONFIG_BUNDLE_SOURCE"

echo "=== Testing Bundle Completeness ==="
echo "Bundle source: $BUNDLE_SOURCE"
echo

# Function to find the latest timestamped bundle directory
find_latest_bundle_dir() {
    local base_dir="$1"
    local pattern="*_bundles"
    
    # Find all timestamped bundle directories
    local bundle_dirs=($(find "$base_dir" -maxdepth 1 -type d -name "$pattern" 2>/dev/null | sort))
    
    if [[ ${#bundle_dirs[@]} -eq 0 ]]; then
        echo ""
        return 1
    fi
    
    # Return the latest one (last in sorted list)
    echo "${bundle_dirs[-1]}"
}

# Find latest bundle directory
LATEST_BUNDLE_DIR=$(find_latest_bundle_dir "$BUNDLE_SOURCE")
if [[ -n "$LATEST_BUNDLE_DIR" ]]; then
    echo "Found latest bundle directory: $LATEST_BUNDLE_DIR"
    BUNDLE_SOURCE="$LATEST_BUNDLE_DIR"
else
    echo "No timestamped bundle directory found, using: $BUNDLE_SOURCE"
fi

# Function to test a single bundle
test_bundle() {
    local bundle_file="$1"
    local bundle_name=$(basename "$bundle_file" .bundle)
    
    echo "=== Testing bundle: $bundle_name ==="
    
    if [[ ! -f "$bundle_file" ]]; then
        echo "❌ Bundle file not found: $bundle_file"
        return 1
    fi
    
    # Create temporary directory
    TEMP_DIR="/tmp/test-bundle-${bundle_name}"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    cd "$TEMP_DIR"
    
    # Initialize git and add bundle as remote
    git init
    git remote add origin "$bundle_file"
    
    # Fetch all branches and tags
    echo "Fetching all branches and tags..."
    git fetch --all
    
    # Show all branches
    echo "📋 Available branches:"
    if git branch -r | grep -q .; then
        git branch -r | sed 's/origin\///' | sort
        BRANCH_COUNT=$(git branch -r | wc -l)
        echo "Total branches: $BRANCH_COUNT"
    else
        echo "❌ No branches found!"
    fi
    
    # Show all tags
    echo "🏷️  Available tags:"
    if git tag | grep -q .; then
        git tag | sort
        TAG_COUNT=$(git tag | wc -l)
        echo "Total tags: $TAG_COUNT"
    else
        echo "❌ No tags found!"
    fi
    
    # Show commit count
    echo "📊 Repository statistics:"
    COMMIT_COUNT=$(git rev-list --count --all 2>/dev/null || echo "0")
    echo "Total commits: $COMMIT_COUNT"
    
    # Show file size
    BUNDLE_SIZE=$(du -h "$bundle_file" | cut -f1)
    echo "Bundle size: $BUNDLE_SIZE"
    
    # Test if we can checkout different branches
    echo "🔍 Testing branch checkout:"
    for branch in $(git branch -r | sed 's/origin\///' | head -5); do
        if git checkout -b "test-$branch" "origin/$branch" 2>/dev/null; then
            echo "  ✅ $branch - $(git rev-parse --short HEAD)"
            git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
        else
            echo "  ❌ $branch - checkout failed"
        fi
    done
    
    cd /
    rm -rf "$TEMP_DIR"
    echo
}

# Test all bundle files
echo "🔍 Testing all bundle files in: $BUNDLE_SOURCE"
echo

BUNDLE_FILES=($(find "$BUNDLE_SOURCE" -name "*.bundle" 2>/dev/null | sort))

if [[ ${#BUNDLE_FILES[@]} -eq 0 ]]; then
    echo "❌ No bundle files found in: $BUNDLE_SOURCE"
    exit 1
fi

echo "Found ${#BUNDLE_FILES[@]} bundle file(s):"
for bundle in "${BUNDLE_FILES[@]}"; do
    echo "  - $(basename "$bundle")"
done
echo

# Test each bundle
for bundle in "${BUNDLE_FILES[@]}"; do
    test_bundle "$bundle"
done

echo "=== Bundle Completeness Test Completed ==="
echo
echo "💡 Tips:"
echo "- If you see 'No branches found', the bundle may not contain all branches"
echo "- If you see 'No tags found', the bundle may not contain all tags"
echo "- Make sure export-full.sh was run with '--all' flag"
echo "- Check that the original repository has multiple branches and tags" 