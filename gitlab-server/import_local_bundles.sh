#!/usr/bin/env bash
set -euo pipefail

# Import local change bundle files from offline environment
# Usage: ./import_local_bundles.sh [local_bundles_dir]

# Default config
DEFAULT_ROOT="/work/develop_gitlab/slam-core"
DEFAULT_LOCAL_BUNDLES_DIR="./local-bundles"

# Read config file (if exists)
CONFIG_FILE="config.json"
if [[ -f "$CONFIG_FILE" ]]; then
    echo ">>> Reading config file: $CONFIG_FILE"
    # Use jq to parse config file (if available)
    if command -v jq &> /dev/null; then
        # Check if platform is forced
        FORCE_PLATFORM=$(jq -r '.global.platform.force_platform // empty' "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$FORCE_PLATFORM" ]]; then
            PLATFORM="$FORCE_PLATFORM"
        else
            PLATFORM="gitlab_server"
        fi
        
        ROOT=$(jq -r ".environments.$PLATFORM.paths.repo_dir // empty" "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_ROOT")
        DEFAULT_LOCAL_BUNDLES_DIR=$(jq -r ".environments.$PLATFORM.paths.local_bundles_dir // empty" "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_LOCAL_BUNDLES_DIR")
        MAIN_REPO_NAME=$(jq -r '.global.bundle.main_repo_name // "slam-core"' "$CONFIG_FILE" 2>/dev/null)
    else
        echo ">>> jq not installed, using default config"
        ROOT="$DEFAULT_ROOT"
        DEFAULT_LOCAL_BUNDLES_DIR="$DEFAULT_LOCAL_BUNDLES_DIR"
        MAIN_REPO_NAME="slam-core"
    fi
else
    echo ">>> Config file not found, using default config"
    ROOT="$DEFAULT_ROOT"
    DEFAULT_LOCAL_BUNDLES_DIR="$DEFAULT_LOCAL_BUNDLES_DIR"
    MAIN_REPO_NAME="slam-core"
fi

# Environment variable overrides
ROOT="${GIT_OFFLINE_UBUNTU_REPO_DIR:-$ROOT}"
DEFAULT_LOCAL_BUNDLES_DIR="${GIT_OFFLINE_UBUNTU_LOCAL_BUNDLES_DIR:-$DEFAULT_LOCAL_BUNDLES_DIR}"

# Parameter processing
LOCAL_BUNDLES_DIR=${1:-"$DEFAULT_LOCAL_BUNDLES_DIR"}

echo ">>> Using config:"
echo "    Repo root: $ROOT"
echo "    Local bundles dir: $LOCAL_BUNDLES_DIR"
echo "    Main repo name: $MAIN_REPO_NAME"

if [[ ! -d "$LOCAL_BUNDLES_DIR" ]]; then
    echo "ERROR: Local bundles directory does not exist: $LOCAL_BUNDLES_DIR"
    exit 1
fi

echo ">>> Importing local change bundles"
echo ">>> Source directory: $LOCAL_BUNDLES_DIR"
echo ">>> Target repository: $ROOT"

# Check info file
INFO_FILE="$LOCAL_BUNDLES_DIR/local_info.json"
if [[ ! -f "$INFO_FILE" ]]; then
    echo "ERROR: Info file not found: $INFO_FILE"
    echo "Please ensure you have run create-bundle-from-local.sh first"
    exit 1
fi

# Parse info file and show change records
echo ">>> Parsing bundle info and change records..."
if command -v jq &> /dev/null; then
    BUNDLE_INFO=$(cat "$INFO_FILE")
    MAIN_BUNDLE=$(echo "$BUNDLE_INFO" | jq -r '.main_bundle')
    SUB_BUNDLES=$(echo "$BUNDLE_INFO" | jq -r '.sub_bundles[]')
    CREATED_AT=$(echo "$BUNDLE_INFO" | jq -r '.created_at')
    
    echo ""
    echo "=== CHANGE RECORDS ==="
    echo "Created at: $CREATED_AT"
    echo ""
    
    # Show main repo changes
    MAIN_BRANCH=$(echo "$BUNDLE_INFO" | jq -r '.change_records.main_repo.branch')
    MAIN_COMMITS=$(echo "$BUNDLE_INFO" | jq -r '.change_records.main_repo.commit_count')
    MAIN_FILES=$(echo "$BUNDLE_INFO" | jq -r '.change_records.main_repo.files_changed')
    echo "Main repository ($MAIN_BRANCH branch):"
    echo "  - Commits: $MAIN_COMMITS"
    echo "  - Files changed: $MAIN_FILES"
    echo ""
    
    # Show submodule changes
    echo "Submodules:"
    echo "$BUNDLE_INFO" | jq -r '.change_records.submodules | to_entries[] | "  \(.key) (\(.value.branch) branch):\n    - Commits: \(.value.commit_count)\n    - Files changed: \(.value.files_changed)"'
    echo ""
    
    # Show git status
    GIT_STATUS=$(echo "$BUNDLE_INFO" | jq -r '.git_status')
    if [[ -n "$GIT_STATUS" && "$GIT_STATUS" != " " ]]; then
        echo "Git status at creation time:"
        echo "  $GIT_STATUS"
        echo ""
    fi
else
    echo ">>> jq not installed, using simple parsing"
    # Simple parsing, assuming fixed format
    MAIN_BUNDLE="${MAIN_REPO_NAME}.bundle"
    CREATED_AT="Unknown"
    # Find all submodule bundles
    SUB_BUNDLES=$(ls "$LOCAL_BUNDLES_DIR"/*.bundle 2>/dev/null | grep -v "${MAIN_REPO_NAME}.bundle" | sed 's/.*\///' || true)
    
    echo ""
    echo "=== CHANGE RECORDS ==="
    echo "Created at: $CREATED_AT"
    echo "Main repository: $MAIN_BUNDLE"
    echo "Submodules: $(echo "$SUB_BUNDLES" | wc -w) found"
    echo ""
fi

# Check main repo bundle
MAIN_BUNDLE_PATH="$LOCAL_BUNDLES_DIR/$MAIN_BUNDLE"
if [[ ! -f "$MAIN_BUNDLE_PATH" ]]; then
    echo "ERROR: Main repo bundle does not exist: $MAIN_BUNDLE_PATH"
    exit 1
fi

# Ask for confirmation before importing
# Check if confirmation is required from config
if command -v jq &> /dev/null && [[ -f "$CONFIG_FILE" ]]; then
    confirm_required=$(jq -r ".environments.$PLATFORM.sync.confirm_before_actions // true" "$CONFIG_FILE" 2>/dev/null)
else
    confirm_required="true"
fi

if [[ "$confirm_required" == "true" ]]; then
    echo "Do you want to import these changes? (y/N): "
    read -p "" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 0
    fi
fi

# 1. Import main repo changes
echo ">>> Importing main repo changes..."
cd "$ROOT"

# Check for uncommitted changes
if [[ -n "$(git status --porcelain)" ]]; then
    echo "WARNING: Main repo has uncommitted changes, suggest commit or stash first"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 0
    fi
fi

# Get updates from bundle
git fetch "$MAIN_BUNDLE_PATH" "refs/heads/*:refs/heads/*" --update-head-ok

# 2. Import submodule changes
echo ">>> Importing submodule changes..."
if command -v jq &> /dev/null; then
    # Use jq to get submodule paths from change_records
    echo "$BUNDLE_INFO" | jq -r '.change_records.submodules | to_entries[] | .key' | while read -r sub_path; do
        # Get corresponding bundle name
        sub_bundle_name=$(echo "$sub_path" | tr '/' '_').bundle
        SUB_BUNDLE_PATH="$LOCAL_BUNDLES_DIR/$sub_bundle_name"
        
        if [[ ! -f "$SUB_BUNDLE_PATH" ]]; then
            echo "WARNING: Submodule bundle does not exist: $SUB_BUNDLE_PATH"
            continue
        fi
        
        SUB_REPO="$ROOT/$sub_path"
        
        if [[ ! -d "$SUB_REPO" ]]; then
            echo "WARNING: Submodule directory does not exist: $SUB_REPO"
            continue
        fi
        
        echo "    -> $sub_path"
        cd "$SUB_REPO"
        git fetch "$SUB_BUNDLE_PATH" "refs/heads/*:refs/heads/*" --update-head-ok
    done
else
    # Fallback to old method for non-jq environments
    for sub_bundle in $SUB_BUNDLES; do
        SUB_BUNDLE_PATH="$LOCAL_BUNDLES_DIR/$sub_bundle"
        if [[ ! -f "$SUB_BUNDLE_PATH" ]]; then
            echo "WARNING: Submodule bundle does not exist: $SUB_BUNDLE_PATH"
            continue
        fi
        
        # Infer submodule path from bundle name (fallback method)
        SUB_PATH=$(echo "$sub_bundle" | sed 's/\.bundle$//' | sed 's/_/\//g')
        SUB_REPO="$ROOT/$SUB_PATH"
        
        if [[ ! -d "$SUB_REPO" ]]; then
            echo "WARNING: Submodule directory does not exist: $SUB_REPO"
            continue
        fi
        
        echo "    -> $SUB_PATH"
        cd "$SUB_REPO"
        git fetch "$SUB_BUNDLE_PATH" "refs/heads/*:refs/heads/*" --update-head-ok
    done
fi

# 3. Update last-sync tags
echo ">>> Updating sync tags..."
cd "$ROOT"
git tag -f last-sync
git submodule foreach --recursive 'git tag -f last-sync'

# 4. Show import results
echo ">>> Import completed!"
echo ">>> Current status:"
git status --short

echo ">>> Submodule status:"
git submodule status --recursive

# 5. Optional: Show diff report
DIFF_REPORT="$LOCAL_BUNDLES_DIR/${MAIN_REPO_NAME}_diff_report.txt"
if [[ -f "$DIFF_REPORT" ]]; then
    echo ">>> Diff report:"
    cat "$DIFF_REPORT"
fi

echo "SUCCESS: Local changes import completed!"
echo "Next steps:"
echo "1. Check if imported changes meet expectations"
echo "2. Run tests to ensure code quality"
echo "3. Commit to GitLab repository" 