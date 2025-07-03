#!/usr/bin/env bash

# Sync submodules to match the main repository's expectations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

CONFIG_FILE="$SCRIPT_DIR/local.config"
load_config "$CONFIG_FILE"

REPO_PATH="$CONFIG_REPO_PATH"
BASE_BRANCH="${CONFIG_BASE_BRANCH:-}"

echo "=== Syncing Submodules ==="
echo "Repository: $REPO_PATH"
echo "Base branch: $BASE_BRANCH"
echo

cd "$REPO_PATH"

# Check main repository status
echo "Main repository status:"
git status --porcelain
echo

# Get submodules
MODULES=$(detect_submodules "$REPO_PATH")
if [[ -z "$MODULES" ]]; then
    echo "No submodules found"
    exit 0
fi

IFS=',' read -ra MODULE_ARRAY <<< "$MODULES"

echo "Processing submodules..."

for module in "${MODULE_ARRAY[@]}"; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    echo
    echo "=== $module ==="
    
    if [[ ! -d "$module" ]]; then
        echo "Submodule directory not found"
        continue
    fi
    
    cd "$module"
    
    # Check current state
    CURRENT_BRANCH=$(git branch --show-current)
    echo "Current branch: $CURRENT_BRANCH"
    
    # Show available branches
    echo "Available branches:"
    git branch -r | sed 's/origin\///' | sort
    
    # Check if target branch exists
    if [[ -n "$BASE_BRANCH" ]]; then
        if git show-ref --verify --quiet refs/remotes/origin/"$BASE_BRANCH"; then
            echo "✓ Target branch '$BASE_BRANCH' found"
            
            if [[ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]]; then
                echo "Switching to $BASE_BRANCH..."
                git checkout -b "$BASE_BRANCH" "origin/$BASE_BRANCH" 2>/dev/null || git checkout "$BASE_BRANCH"
                echo "✓ Switched to $BASE_BRANCH"
            else
                echo "✓ Already on $BASE_BRANCH"
            fi
        else
            echo "✗ Target branch '$BASE_BRANCH' not found"
            echo "Keeping current branch: $CURRENT_BRANCH"
        fi
    else
        echo "No base branch configured, keeping current branch"
    fi
    
    # Show current commit
    CURRENT_COMMIT=$(git rev-parse HEAD)
    echo "Current commit: $CURRENT_COMMIT"
    
    cd - > /dev/null
done

echo
echo "=== Updating Main Repository Submodule References ==="

# Update submodule references in main repository
echo "Updating submodule references..."
git submodule update --init --recursive

echo
echo "=== Final Status ==="
git status

echo
echo "If submodules still show 'new commits', you may need to:"
echo "1. Check if the bundle files contain the correct branches"
echo "2. Manually reset submodules to the expected commits"
echo "3. Or update the main repository's submodule references" 