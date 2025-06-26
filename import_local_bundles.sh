#!/usr/bin/env bash
set -euo pipefail

# Import local change bundle files from Windows
# Usage: ./import_local_bundles.sh [bundle_prefix] [local_bundles_dir]

# Default config
DEFAULT_ROOT="/work/develop_gitlab/slam-core"
DEFAULT_LOCAL_BUNDLES_DIR="./local-bundles"

# Read config file (if exists)
CONFIG_FILE="config.json"
if [[ -f "$CONFIG_FILE" ]]; then
    echo ">>> Reading config file: $CONFIG_FILE"
    # Use jq to parse config file (if available)
    if command -v jq &> /dev/null; then
        ROOT=$(jq -r '.paths.ubuntu.repo_dir // empty' "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_ROOT")
        DEFAULT_LOCAL_BUNDLES_DIR=$(jq -r '.paths.ubuntu.local_bundles_dir // empty' "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_LOCAL_BUNDLES_DIR")
    else
        echo ">>> jq not installed, using default config"
        ROOT="$DEFAULT_ROOT"
        DEFAULT_LOCAL_BUNDLES_DIR="$DEFAULT_LOCAL_BUNDLES_DIR"
    fi
else
    echo ">>> Config file not found, using default config"
    ROOT="$DEFAULT_ROOT"
    DEFAULT_LOCAL_BUNDLES_DIR="$DEFAULT_LOCAL_BUNDLES_DIR"
fi

# Environment variable overrides
ROOT="${GIT_OFFLINE_UBUNTU_REPO_DIR:-$ROOT}"
DEFAULT_LOCAL_BUNDLES_DIR="${GIT_OFFLINE_UBUNTU_LOCAL_BUNDLES_DIR:-$DEFAULT_LOCAL_BUNDLES_DIR}"

# Parameter processing
BUNDLE_PREFIX=${1:-""}
LOCAL_BUNDLES_DIR=${2:-"$DEFAULT_LOCAL_BUNDLES_DIR"}

echo ">>> Using config:"
echo "    Repo root: $ROOT"
echo "    Local bundles dir: $LOCAL_BUNDLES_DIR"

if [[ -z "$BUNDLE_PREFIX" ]]; then
    echo "ERROR: Please specify bundle prefix"
    echo "Usage: $0 <bundle_prefix> [local_bundles_dir]"
    echo "Example: $0 local_20250101_120000"
    echo ""
    echo "Available bundle prefixes:"
    if [[ -d "$LOCAL_BUNDLES_DIR" ]]; then
        ls "$LOCAL_BUNDLES_DIR"/*_info.json 2>/dev/null | sed 's/.*\///' | sed 's/_info\.json$//' || echo "  No bundles available"
    else
        echo "  Local bundles directory does not exist: $LOCAL_BUNDLES_DIR"
    fi
    exit 1
fi

if [[ ! -d "$LOCAL_BUNDLES_DIR" ]]; then
    echo "ERROR: Local bundles directory does not exist: $LOCAL_BUNDLES_DIR"
    exit 1
fi

echo ">>> Importing local change bundle: $BUNDLE_PREFIX"
echo ">>> Source directory: $LOCAL_BUNDLES_DIR"
echo ">>> Target repository: $ROOT"

# Check info file
INFO_FILE="$LOCAL_BUNDLES_DIR/${BUNDLE_PREFIX}_info.json"
if [[ ! -f "$INFO_FILE" ]]; then
    echo "ERROR: Info file not found: $INFO_FILE"
    exit 1
fi

# Parse info file
echo ">>> Parsing bundle info..."
if command -v jq &> /dev/null; then
    BUNDLE_INFO=$(cat "$INFO_FILE")
    MAIN_BUNDLE=$(echo "$BUNDLE_INFO" | jq -r '.main_bundle')
    SUB_BUNDLES=$(echo "$BUNDLE_INFO" | jq -r '.sub_bundles[]')
    CREATED_AT=$(echo "$BUNDLE_INFO" | jq -r '.created_at')
else
    echo ">>> jq not installed, using simple parsing"
    # Simple parsing, assuming fixed format
    MAIN_BUNDLE="${BUNDLE_PREFIX}_slam-core.bundle"
    CREATED_AT="Unknown"
    # Find all submodule bundles
    SUB_BUNDLES=$(ls "$LOCAL_BUNDLES_DIR"/${BUNDLE_PREFIX}_*.bundle 2>/dev/null | grep -v "${BUNDLE_PREFIX}_slam-core.bundle" | sed 's/.*\///' || true)
fi

echo ">>> Created at: $CREATED_AT"
echo ">>> Main repo bundle: $MAIN_BUNDLE"

# Check main repo bundle
MAIN_BUNDLE_PATH="$LOCAL_BUNDLES_DIR/$MAIN_BUNDLE"
if [[ ! -f "$MAIN_BUNDLE_PATH" ]]; then
    echo "ERROR: Main repo bundle does not exist: $MAIN_BUNDLE_PATH"
    exit 1
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
for sub_bundle in $SUB_BUNDLES; do
    SUB_BUNDLE_PATH="$LOCAL_BUNDLES_DIR/$sub_bundle"
    if [[ ! -f "$SUB_BUNDLE_PATH" ]]; then
        echo "WARNING: Submodule bundle does not exist: $SUB_BUNDLE_PATH"
        continue
    fi
    
    # Infer submodule path from bundle name
    SUB_PATH=$(echo "$sub_bundle" | sed "s/${BUNDLE_PREFIX}_//" | sed 's/\.bundle$//' | sed 's/_/\//g')
    SUB_REPO="$ROOT/$SUB_PATH"
    
    if [[ ! -d "$SUB_REPO" ]]; then
        echo "WARNING: Submodule directory does not exist: $SUB_REPO"
        continue
    fi
    
    echo "    -> $SUB_PATH"
    cd "$SUB_REPO"
    git fetch "$SUB_BUNDLE_PATH" "refs/heads/*:refs/heads/*" --update-head-ok
done

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
DIFF_REPORT="$LOCAL_BUNDLES_DIR/${BUNDLE_PREFIX}_diff_report.txt"
if [[ -f "$DIFF_REPORT" ]]; then
    echo ">>> Diff report:"
    cat "$DIFF_REPORT"
fi

echo "SUCCESS: Local changes import completed!"
echo "Next steps:"
echo "1. Check if imported changes meet expectations"
echo "2. Run tests to ensure code quality"
echo "3. Commit to GitLab repository" 