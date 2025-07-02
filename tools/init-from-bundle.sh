#!/usr/bin/env bash

# Initialize repository from bundle files
# Local-side script for initial clone from bundle

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
    echo "Make sure bundle files are available in the bundle_source directory:"
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
    echo "No modules specified in config, will auto-detect from .gitmodules after cloning..."
    MODULES=""
else
    echo "Using configured modules: $MODULES"
fi

# Validate bundle source directory
if [[ ! -d "$BUNDLE_SOURCE" ]]; then
    echo "Error: Bundle source directory '$BUNDLE_SOURCE' does not exist" >&2
    exit 1
fi

# Get repository name from path
REPO_NAME=$(basename "$REPO_PATH")

echo "=== Initializing repository from bundle ==="
echo "Repository path: $REPO_PATH"
echo "Bundle source: $BUNDLE_SOURCE"
echo "Modules: $MODULES"
echo

# Check if repository already exists
if [[ -d "$REPO_PATH" ]]; then
    echo "Error: Repository directory '$REPO_PATH' already exists" >&2
    echo "Please remove it first or choose a different path" >&2
    exit 1
fi

# Check for main repository bundle
MAIN_BUNDLE="$BUNDLE_SOURCE/${REPO_NAME}.bundle"
if [[ ! -f "$MAIN_BUNDLE" ]]; then
    echo "Error: Main repository bundle not found: $MAIN_BUNDLE" >&2
    exit 1
fi

echo "Found main repository bundle: $MAIN_BUNDLE"

# Create parent directory if needed
PARENT_DIR=$(dirname "$REPO_PATH")
if [[ ! -d "$PARENT_DIR" ]]; then
    echo "Creating parent directory: $PARENT_DIR"
    mkdir -p "$PARENT_DIR"
fi

# Clone main repository from bundle
echo
echo "Cloning main repository from bundle..."
git clone "$MAIN_BUNDLE" "$REPO_PATH"
cd "$REPO_PATH"

# Initialize submodules
echo
echo "Initializing submodules..."

# Auto-detect modules from .gitmodules if not specified
if [[ -z "$MODULES" ]]; then
    echo "Auto-detecting submodules from .gitmodules..."
    MODULES=$(detect_submodules "$REPO_PATH")
    if [[ -z "$MODULES" ]]; then
        echo "No submodules found in .gitmodules"
        MODULE_ARRAY=()
    else
        echo "Detected submodules: $MODULES"
        IFS=',' read -ra MODULE_ARRAY <<< "$MODULES"
    fi
else
    # Convert comma-separated modules to array
    IFS=',' read -ra MODULE_ARRAY <<< "$MODULES"
fi

for module in "${MODULE_ARRAY[@]}"; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    echo "Initializing submodule: $module"
    
    # Check if submodule bundle exists
    MODULE_BUNDLE="$BUNDLE_SOURCE/${module}.bundle"
    if [[ ! -f "$MODULE_BUNDLE" ]]; then
        echo "Warning: Submodule bundle not found: $MODULE_BUNDLE"
        echo "Skipping submodule: $module"
        continue
    fi
    
    # Initialize submodule
    git submodule init "$module"
    
    # Initialize git repository in submodule directory
    git -C "$module" init
    
    # Add bundle as remote origin
    git -C "$module" remote add origin "$MODULE_BUNDLE"
    
    # Fetch all branches from bundle
    git -C "$module" fetch origin --all
    
    # Checkout main branch (assuming it exists)
    if git -C "$module" show-ref --verify --quiet refs/remotes/origin/main; then
        git -C "$module" checkout -b main origin/main
        echo "Successfully initialized submodule: $module (main branch)"
    elif git -C "$module" show-ref --verify --quiet refs/remotes/origin/master; then
        git -C "$module" checkout -b master origin/master
        echo "Successfully initialized submodule: $module (master branch)"
    else
        # Try to checkout the first available branch
        FIRST_BRANCH=$(git -C "$module" branch -r | head -n1 | sed 's/origin\///')
        if [[ -n "$FIRST_BRANCH" ]]; then
            git -C "$module" checkout -b "$FIRST_BRANCH" "origin/$FIRST_BRANCH"
            echo "Successfully initialized submodule: $module ($FIRST_BRANCH branch)"
        else
            echo "Warning: No branches found in submodule bundle: $module"
        fi
    fi
done

echo
echo "=== Repository initialization completed ==="
echo "Repository location: $REPO_PATH"
echo
echo "Next steps:"
echo "1. cd $REPO_PATH"
echo "2. Create a feature branch: git checkout -b dev/your-feature"
echo "3. Create feature branches for submodules:"
for module in "${MODULE_ARRAY[@]}"; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "   git -C $module checkout -b dev/your-feature"
done 