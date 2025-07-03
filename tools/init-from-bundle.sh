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

# Get base branch from config
BASE_BRANCH="${CONFIG_BASE_BRANCH:-}"
if [[ -n "$BASE_BRANCH" ]]; then
    echo "Using configured base branch: $BASE_BRANCH"
else
    echo "No base branch specified in config, will use default (master/main)"
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
    # Convert path separators to underscores for bundle filename
    MODULE_BUNDLE_NAME=$(echo "$module" | sed 's|/|_|g')
    MODULE_BUNDLE="$BUNDLE_SOURCE/${MODULE_BUNDLE_NAME}.bundle"
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
    git -C "$module" fetch --all
    
    # Determine which branch to checkout
    TARGET_BRANCH=""
    
    # First, try to use configured base branch
    if [[ -n "$BASE_BRANCH" ]] && git -C "$module" show-ref --verify --quiet refs/remotes/origin/"$BASE_BRANCH"; then
        TARGET_BRANCH="$BASE_BRANCH"
        echo "Using configured base branch: $TARGET_BRANCH"
    # Then try main branch
    elif git -C "$module" show-ref --verify --quiet refs/remotes/origin/main; then
        TARGET_BRANCH="main"
        echo "Using main branch"
    # Then try master branch
    elif git -C "$module" show-ref --verify --quiet refs/remotes/origin/master; then
        TARGET_BRANCH="master"
        echo "Using master branch"
    else
        # Try to checkout the first available branch
        FIRST_BRANCH=$(git -C "$module" branch -r | head -n1 | sed 's/origin\///')
        if [[ -n "$FIRST_BRANCH" ]]; then
            TARGET_BRANCH="$FIRST_BRANCH"
            echo "Using first available branch: $TARGET_BRANCH"
        else
            echo "Warning: No branches found in submodule bundle: $module"
            continue
        fi
    fi
    
    # Get the commit that the main repository expects for this submodule
    EXPECTED_COMMIT=$(git ls-tree HEAD "$module" | awk '{print $3}')
    echo "Expected commit for $module: $EXPECTED_COMMIT"
    
    # Check if the expected commit exists in the repository
    if git -C "$module" cat-file -e "$EXPECTED_COMMIT" 2>/dev/null; then
        # Reset to the expected commit (this will put us in detached HEAD state)
        git -C "$module" reset --hard "$EXPECTED_COMMIT"
        echo "Successfully initialized submodule: $module (commit $EXPECTED_COMMIT)"
        
        # Show current branch and commit info
        CURRENT_BRANCH=$(git -C "$module" branch --show-current)
        echo "Current branch: $CURRENT_BRANCH (detached HEAD)"
        echo "Current commit: $(git -C "$module" rev-parse --short HEAD)"
    else
        echo "Warning: Expected commit $EXPECTED_COMMIT not found in submodule bundle: $module"
        echo "This might indicate a problem with the bundle file"
        
        # Fallback to branch checkout
        if [[ -n "$TARGET_BRANCH" ]]; then
            git -C "$module" checkout -b "$TARGET_BRANCH" "origin/$TARGET_BRANCH"
            echo "Fallback: Switched to $TARGET_BRANCH branch"
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