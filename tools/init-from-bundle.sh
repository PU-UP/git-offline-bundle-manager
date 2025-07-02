#!/usr/bin/env bash

# Initialize repository from bundle files
# Local-side script for initial clone from bundle

set -euo pipefail

# Load configuration utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

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
MODULES="${CONFIG_MODULES:-}"
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
    echo
    # 打印最新 bundle 目录信息
    LATEST_BUNDLE_DIR=$(find_latest_bundle_dir "$CONFIG_BUNDLE_SOURCE")
    if [[ -n "$LATEST_BUNDLE_DIR" ]]; then
        echo "--- 最新 bundle 目录信息 ---"
        echo "目录: $LATEST_BUNDLE_DIR"
        echo "包含的 bundle 文件:"
        ls -lh "$LATEST_BUNDLE_DIR"/*.bundle 2>/dev/null || echo "无 bundle 文件"
        if [[ -f "$LATEST_BUNDLE_DIR/bundle_report.md" ]]; then
            echo
            echo "bundle_report.md 部分内容:"
            head -20 "$LATEST_BUNDLE_DIR/bundle_report.md"
        fi
        echo "--------------------------"
    fi
    echo
    read -p "是否删除已存在的目录并用最新 bundle 重新初始化？(y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo "正在删除旧目录: $REPO_PATH ..."
        rm -rf "$REPO_PATH"
        echo "已删除，继续初始化..."
    else
        echo "已取消操作。"
        exit 1
    fi
fi

# Check for main repository bundle
MAIN_BUNDLE="$BUNDLE_SOURCE/${REPO_NAME}.bundle"

# If bundle not found in specified directory, try to find latest timestamped directory
if [[ ! -f "$MAIN_BUNDLE" ]]; then
    echo "Main repository bundle not found in: $BUNDLE_SOURCE"
    echo "Searching for latest timestamped bundle directory..."
    
    LATEST_BUNDLE_DIR=$(find_latest_bundle_dir "$BUNDLE_SOURCE")
    if [[ -n "$LATEST_BUNDLE_DIR" ]]; then
        echo "Found latest bundle directory: $LATEST_BUNDLE_DIR"
        BUNDLE_SOURCE="$LATEST_BUNDLE_DIR"
        MAIN_BUNDLE="$BUNDLE_SOURCE/${REPO_NAME}.bundle"
    fi
fi

if [[ ! -f "$MAIN_BUNDLE" ]]; then
    echo "Error: Main repository bundle not found: $MAIN_BUNDLE" >&2
    echo "Searched in: $CONFIG_BUNDLE_SOURCE" >&2
    if [[ -n "$LATEST_BUNDLE_DIR" ]]; then
        echo "And in latest bundle directory: $LATEST_BUNDLE_DIR" >&2
    fi
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