#!/usr/bin/env bash

# Fix submodule branches to match the configured base branch

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

CONFIG_FILE="$SCRIPT_DIR/local.config"
load_config "$CONFIG_FILE"

REPO_PATH="$CONFIG_REPO_PATH"
BASE_BRANCH="${CONFIG_BASE_BRANCH:-}"

echo "=== Fixing Submodule Branches ==="
echo "Repository: $REPO_PATH"
echo "Target base branch: $BASE_BRANCH"
echo

cd "$REPO_PATH"

# Get submodules from .gitmodules
MODULES=$(detect_submodules "$REPO_PATH")
if [[ -z "$MODULES" ]]; then
    echo "No submodules found"
    exit 0
fi

IFS=',' read -ra MODULE_ARRAY <<< "$MODULES"

for module in "${MODULE_ARRAY[@]}"; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    echo "Processing submodule: $module"
    
    if [[ ! -d "$module" ]]; then
        echo "  Submodule directory not found, skipping"
        continue
    fi
    
    cd "$module"
    
    # Check current branch
    CURRENT_BRANCH=$(git branch --show-current)
    echo "  Current branch: $CURRENT_BRANCH"
    
    # Check if target branch exists
    if [[ -n "$BASE_BRANCH" ]]; then
        if git show-ref --verify --quiet refs/remotes/origin/"$BASE_BRANCH"; then
            echo "  Target branch '$BASE_BRANCH' found in remote"
            
            if [[ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]]; then
                echo "  Switching from $CURRENT_BRANCH to $BASE_BRANCH"
                git checkout -b "$BASE_BRANCH" "origin/$BASE_BRANCH" 2>/dev/null || git checkout "$BASE_BRANCH"
                echo "  ✓ Switched to $BASE_BRANCH"
            else
                echo "  ✓ Already on target branch $BASE_BRANCH"
            fi
        else
            echo "  Target branch '$BASE_BRANCH' not found in remote"
            echo "  Available branches:"
            git branch -r | sed 's/origin\///' | sort
        fi
    else
        echo "  No base branch configured, keeping current branch: $CURRENT_BRANCH"
    fi
    
    echo "  Available branches:"
    git branch -r | sed 's/origin\///' | sort
    
    cd - > /dev/null
    echo
done

echo "=== Submodule Branch Fix Complete ==="
echo
echo "Next steps:"
echo "1. Check git status to see if submodules are now in sync"
echo "2. If still showing 'new commits', you may need to update the main repository's submodule references" 