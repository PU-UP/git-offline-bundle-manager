#!/usr/bin/env bash

# Fix submodules to point to the exact commits expected by the main repository

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

CONFIG_FILE="$SCRIPT_DIR/local.config"
load_config "$CONFIG_FILE"

REPO_PATH="$CONFIG_REPO_PATH"

echo "=== Fixing Submodule Commits ==="
echo "Repository: $REPO_PATH"
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
    
    # Get the commit that the main repository expects for this submodule
    EXPECTED_COMMIT=$(git ls-tree HEAD "$module" | awk '{print $3}')
    echo "Expected commit: $EXPECTED_COMMIT"
    
    cd "$module"
    
    # Check current commit
    CURRENT_COMMIT=$(git rev-parse HEAD)
    echo "Current commit: $CURRENT_COMMIT"
    
    if [[ "$CURRENT_COMMIT" == "$EXPECTED_COMMIT" ]]; then
        echo "✓ Submodule is already at the expected commit"
    else
        echo "✗ Submodule is at wrong commit"
        echo "Switching to expected commit..."
        
        # Check if the expected commit exists in the repository
        if git cat-file -e "$EXPECTED_COMMIT" 2>/dev/null; then
            # Reset to the expected commit
            git reset --hard "$EXPECTED_COMMIT"
            echo "✓ Switched to expected commit"
        else
            echo "✗ Expected commit not found in submodule repository"
            echo "This might indicate a problem with the bundle file or submodule initialization"
        fi
    fi
    
    # Show current branch and commit info
    CURRENT_BRANCH=$(git branch --show-current)
    echo "Current branch: $CURRENT_BRANCH"
    echo "Current commit: $(git rev-parse --short HEAD)"
    
    cd - > /dev/null
done

echo
echo "=== Final Status ==="
git status

echo
echo "If submodules still show 'new commits', the issue might be:"
echo "1. Bundle files don't contain the expected commits"
echo "2. Submodule initialization was incomplete"
echo "3. Main repository's submodule references are incorrect" 