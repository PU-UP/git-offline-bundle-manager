#!/usr/bin/env bash

# Export feature branch bundles for local development
# Local-side script for exporting feature branch bundles

set -euo pipefail

# Load configuration utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

# Function to detect submodule branch from gitmodules and remote
detect_submodule_branch() {
    local module_path="$1"
    local current_branch="$2"
    
    # First check if there's a branch mapping in config
    if [[ -n "${SUBMODULE_BRANCHES[$module_path]:-}" ]]; then
        echo "${SUBMODULE_BRANCHES[$module_path]}"
        return 0
    fi
    
    # Try to detect from .gitmodules file
    local gitmodules_file=".gitmodules"
    if [[ -f "$gitmodules_file" ]]; then
        local branch_line=$(grep -A1 "path = $module_path" "$gitmodules_file" | grep "branch = " | cut -d'=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$branch_line" ]]; then
            echo "$branch_line"
            return 0
        fi
    fi
    
    # Default to same branch as main repository
    echo "$current_branch"
}

# Default config file
CONFIG_FILE="${1:-$SCRIPT_DIR/local.config}"

# Load and validate configuration
if ! validate_config "$CONFIG_FILE" "repo_path"; then
    echo "Usage: $0 [config_file]"
    echo "Default config file: $SCRIPT_DIR/local.config"
    echo
    echo "This script exports the current feature branch as bundles."
    echo "Make sure you are on a feature branch (dev/*) before running."
    exit 1
fi

load_config "$CONFIG_FILE"

REPO_PATH="${CONFIG_REPO_PATH:-}"
if [[ -z "$REPO_PATH" ]]; then
    echo "Error: repo_path not found in configuration file '$CONFIG_FILE'" >&2
    exit 1
fi

# Auto-detect modules if not specified in config
MODULES="${CONFIG_MODULES:-}"
if [[ -z "$MODULES" ]]; then
    echo "No modules specified in config, auto-detecting from .gitmodules..."
    MODULES=$(get_submodules "$CONFIG_FILE" "$REPO_PATH")
    if [[ -z "$MODULES" ]]; then
        echo "Warning: No submodules detected. Proceeding with main repository only."
    else
        echo "Detected submodules: $MODULES"
    fi
fi

# Parse submodule branch mapping
declare -A SUBMODULE_BRANCHES
if [[ -n "${CONFIG_SUBMODULE_BRANCHES:-}" ]]; then
    echo "Submodule branch mapping: $CONFIG_SUBMODULE_BRANCHES"
    IFS=',' read -ra BRANCH_MAPPINGS <<< "$CONFIG_SUBMODULE_BRANCHES"
    for mapping in "${BRANCH_MAPPINGS[@]}"; do
        IFS=':' read -ra PARTS <<< "$mapping"
        if [[ ${#PARTS[@]} -eq 2 ]]; then
            module_name=$(echo "${PARTS[0]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            branch_name=$(echo "${PARTS[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            SUBMODULE_BRANCHES["$module_name"]="$branch_name"
        fi
    done
fi

# Validate repository path
if [[ ! -d "$REPO_PATH" ]]; then
    echo "Error: Repository path '$REPO_PATH' does not exist" >&2
    exit 1
fi

# Get repository name
REPO_NAME=$(basename "$REPO_PATH")

echo "=== Exporting feature branch bundles ==="
echo "Repository: $REPO_PATH"
echo "Modules: $MODULES"
echo

# Change to repository directory
cd "$REPO_PATH"

# Check if this is a git repository
if [[ ! -d ".git" ]]; then
    echo "Error: '$REPO_PATH' is not a git repository" >&2
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ -z "$CURRENT_BRANCH" ]]; then
    echo "Error: Not on any branch (detached HEAD)" >&2
    exit 1
fi

echo "Current branch: $CURRENT_BRANCH"

# Validate that we're on a feature branch
if [[ ! "$CURRENT_BRANCH" =~ ^(dev/|feature/) ]]; then
    echo "Error: Not on a feature branch. Current branch: $CURRENT_BRANCH" >&2
    echo "Please checkout a feature branch (dev/* or feature/*) before exporting" >&2
    exit 1
fi

# Create output directory
OUTPUT_DIR="${CONFIG_OUTPUT_DIR:-bundles}"
# Convert relative path to absolute path if needed
if [[ "$OUTPUT_DIR" != /* ]]; then
    OUTPUT_DIR="$REPO_PATH/$OUTPUT_DIR"
fi
if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

# Determine base branch (main or master or config)
BASE_BRANCH=""
if [[ -n "${CONFIG_BASE_BRANCH:-}" ]]; then
    BASE_BRANCH="$CONFIG_BASE_BRANCH"
    echo "Base branch (from config): $BASE_BRANCH"
else
    if git show-ref --verify --quiet refs/heads/main; then
        BASE_BRANCH="main"
    elif git show-ref --verify --quiet refs/heads/master; then
        BASE_BRANCH="master"
    else
        echo "Error: Could not determine base branch (main, master, or config base_branch)" >&2
        exit 1
    fi
    echo "Base branch: $BASE_BRANCH"
fi

# Export main repository feature bundle
echo
echo "Exporting main repository feature bundle..."

# Check if there are commits to export
COMMIT_COUNT=$(git rev-list --count "$BASE_BRANCH..$CURRENT_BRANCH" 2>/dev/null || echo "0")
if [[ "$COMMIT_COUNT" == "0" ]]; then
    echo "Warning: No commits to export for main repository"
    echo "Feature branch is up to date with base branch"
    echo "Skipping main repository"
else
    echo "Found $COMMIT_COUNT commits to export for main repository"
    # Sanitize branch name for filename (replace / with _)
    SAFE_BRANCH_NAME=$(echo "$CURRENT_BRANCH" | sed 's/\//_/g')
    MAIN_BUNDLE="$OUTPUT_DIR/${REPO_NAME}-${SAFE_BRANCH_NAME}.bundle"
    git bundle create "$MAIN_BUNDLE" "$BASE_BRANCH..$CURRENT_BRANCH"
    echo "Created: $MAIN_BUNDLE"
fi

# Export submodule feature bundles
echo
echo "Exporting submodule feature bundles..."

# 1. 获取所有真实子模块路径
SUBMODULE_PATHS=$(git config --file .gitmodules --get-regexp path | awk '{print $2}')

if [[ -z "$SUBMODULE_PATHS" ]]; then
    echo "No submodules found in .gitmodules, skipping submodule bundle creation."
else
    echo "Submodules found: $SUBMODULE_PATHS"
    # 2. 检查每个子模块在base分支和target分支的commit id是否有变化
    for module in $SUBMODULE_PATHS; do
        BASE_COMMIT=$(git ls-tree $BASE_BRANCH $module 2>/dev/null | awk '{print $3}')
        TARGET_COMMIT=$(git ls-tree $CURRENT_BRANCH $module 2>/dev/null | awk '{print $3}')
        if [[ -z "$BASE_COMMIT" || -z "$TARGET_COMMIT" ]]; then
            echo "Warning: Cannot get submodule commit for $module, skipping..."
            continue
        fi
        if [[ "$BASE_COMMIT" == "$TARGET_COMMIT" ]]; then
            echo "Submodule $module has no changes between $BASE_BRANCH and $CURRENT_BRANCH, skipping."
            continue
        fi
        echo "Submodule $module has changes: $BASE_COMMIT -> $TARGET_COMMIT"
        # 3. 只处理真正的git子仓库
        if [[ ! -d "$module/.git" && ! -f "$module/.git" ]]; then
            echo "Warning: $module 不是一个有效的git子仓库，跳过。"
            continue
        fi
        # 初始化或更新子模块到正确的commit
        if [[ ! -d "$module/.git" && -f "$module/.git" ]]; then
            # .git为文件（git worktree或submodule特殊情况），尝试更新
            echo "Submodule '$module' .git为文件，尝试git submodule update..."
            if git submodule update "$module" 2>/dev/null; then
                echo "Successfully updated submodule: $module"
            else
                echo "Failed to update submodule: $module, skipping..."
                continue
            fi
        elif [[ -d "$module/.git" ]]; then
            # .git为目录，正常处理
            echo "Submodule '$module' exists, updating to correct commit..."
            if git submodule update "$module" 2>/dev/null; then
                echo "Successfully updated submodule: $module"
            else
                echo "Failed to update submodule: $module, skipping..."
                continue
            fi
        fi
        # 4. 找到TARGET_COMMIT所在的分支，然后打包该分支
        echo "准备打包子模块: $module ($BASE_COMMIT -> $TARGET_COMMIT)"
        
        # 找到TARGET_COMMIT所在的分支
        TARGET_BRANCH=$(git -C "$module" branch --contains "$TARGET_COMMIT" | grep -v "HEAD" | head -1 | sed 's/^[* ]*//')
        if [[ -z "$TARGET_BRANCH" ]]; then
            echo "Warning: Could not find branch containing commit $TARGET_COMMIT, skipping..."
            continue
        fi
        echo "Target commit $TARGET_COMMIT is on branch: $TARGET_BRANCH"
        
        # 判断该分支的base分支
        SUBMODULE_BASE_BRANCH=""
        if git -C "$module" show-ref --verify --quiet refs/heads/main; then
            SUBMODULE_BASE_BRANCH="main"
        elif git -C "$module" show-ref --verify --quiet refs/heads/master; then
            SUBMODULE_BASE_BRANCH="master"
        elif git -C "$module" show-ref --verify --quiet refs/heads/release_2.3.7; then
            SUBMODULE_BASE_BRANCH="release_2.3.7"
        elif git -C "$module" show-ref --verify --quiet refs/remotes/origin/master; then
            SUBMODULE_BASE_BRANCH="origin/master"
        else
            echo "Warning: Could not determine base branch for submodule '$module', skipping..."
            continue
        fi
        echo "Submodule base branch: $SUBMODULE_BASE_BRANCH"
        
        # 判断是否有新提交
        COMMIT_COUNT=$(git -C "$module" rev-list --count "$SUBMODULE_BASE_BRANCH..$TARGET_BRANCH" 2>/dev/null || echo "0")
        if [[ "$COMMIT_COUNT" == "0" ]]; then
            echo "No new commits between $SUBMODULE_BASE_BRANCH and $TARGET_BRANCH, skipping bundle."
            continue
        fi
        
        SAFE_MODULE_NAME=$(echo "$module" | sed 's/\//_/g')
        SAFE_TARGET_BRANCH_NAME=$(echo "$TARGET_BRANCH" | sed 's/\//_/g')
        MODULE_BUNDLE="$OUTPUT_DIR/${SAFE_MODULE_NAME}-${SAFE_TARGET_BRANCH_NAME}.bundle"
        git -C "$module" bundle create "$MODULE_BUNDLE" "$SUBMODULE_BASE_BRANCH..$TARGET_BRANCH"
        echo "Created: $MODULE_BUNDLE"
    done
fi

echo
echo "=== Export completed ==="
echo "Bundles created in: $OUTPUT_DIR"

# Count and list created bundles
BUNDLE_COUNT=$(ls -1 "$OUTPUT_DIR"/*.bundle 2>/dev/null | wc -l)
if [[ "$BUNDLE_COUNT" -gt 0 ]]; then
    echo "Created $BUNDLE_COUNT bundle(s):"
    ls -la "$OUTPUT_DIR"/*.bundle
else
    echo "No bundle files created (no changes detected)"
fi

echo
echo "Next steps:"
echo "1. Copy bundles to server: cp $OUTPUT_DIR/*.bundle /path/to/server/"
echo "2. Run import-feature.sh on server to import the bundles" 