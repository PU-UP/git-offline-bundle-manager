#!/usr/bin/env bash
set -euo pipefail

# Ubuntu Offline Repository Setup Script
# Initialize offline workspace (main repo + submodules):
# 1. Clone slam-core.bundle as main repo
# 2. Rewrite submodule URLs to local absolute path
# 3. Offline init/update all submodules
# 4. Tag last-sync for main & submodules

# Default config
DEFAULT_ROOT="/work/develop_gitlab/slam-core"
DEFAULT_BUNDLES_DIR="/work/develop_gitlab/slam-core/bundles"

# Read config file (if exists)
CONFIG_FILE="config.json"
if [[ -f "$CONFIG_FILE" ]]; then
    echo ">>> Reading config file: $CONFIG_FILE"
    # Use jq to parse config file (if available)
    if command -v jq &> /dev/null; then
        # Check if platform is forced
        FORCE_PLATFORM=$(jq -r '.platform.force_platform // empty' "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$FORCE_PLATFORM" ]]; then
            PLATFORM="$FORCE_PLATFORM"
        else
            PLATFORM="ubuntu"
        fi
        
        ROOT=$(jq -r ".paths.$PLATFORM.repo_dir // empty" "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_ROOT")
        BUNDLES_DIR=$(jq -r ".paths.$PLATFORM.bundles_dir // empty" "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_BUNDLES_DIR")
        MAIN_REPO_NAME=$(jq -r '.bundle.main_repo_name // "slam-core"' "$CONFIG_FILE" 2>/dev/null)
        GIT_USER_NAME=$(jq -r '.git.user_name // "Your Name"' "$CONFIG_FILE" 2>/dev/null)
        GIT_USER_EMAIL=$(jq -r '.git.user_email // "your.email@company.com"' "$CONFIG_FILE" 2>/dev/null)
    else
        echo ">>> jq not installed, using default config"
        ROOT="$DEFAULT_ROOT"
        BUNDLES_DIR="$DEFAULT_BUNDLES_DIR"
        MAIN_REPO_NAME="slam-core"
        GIT_USER_NAME="Your Name"
        GIT_USER_EMAIL="your.email@company.com"
    fi
else
    echo ">>> Config file not found, using default config"
    ROOT="$DEFAULT_ROOT"
    BUNDLES_DIR="$DEFAULT_BUNDLES_DIR"
    MAIN_REPO_NAME="slam-core"
    GIT_USER_NAME="Your Name"
    GIT_USER_EMAIL="your.email@company.com"
fi

# Environment variable overrides
ROOT="${GIT_OFFLINE_UBUNTU_REPO_DIR:-$ROOT}"
BUNDLES_DIR="${GIT_OFFLINE_UBUNTU_BUNDLES_DIR:-$BUNDLES_DIR}"

echo ">>> Using config:"
echo "    Bundles dir: $BUNDLES_DIR"
echo "    Repo dir: $ROOT"
echo "    Git user: $GIT_USER_NAME"
echo "    Git email: $GIT_USER_EMAIL"

# 0) Path check
if [[ ! -d "$BUNDLES_DIR" ]]; then
    echo "ERROR: Bundles directory does not exist: $BUNDLES_DIR"
    exit 1
fi

# 1) Clone main repo (skip if .git exists)
if [[ ! -d "$ROOT/.git" ]]; then
    echo ">>> Cloning main repo..."
    git clone "$BUNDLES_DIR/$MAIN_REPO_NAME.bundle" "$ROOT"
else
    echo ">>> Main repo already exists, skip clone"
fi

# 2) Set local git identity
echo ">>> Configuring git identity..."
git -C "$ROOT" config --local user.name "$GIT_USER_NAME"
git -C "$ROOT" config --local user.email "$GIT_USER_EMAIL"

# 3) Unpack all bundles to _unpacked dir
UNPACK_DIR="$BUNDLES_DIR/_unpacked"
if [[ ! -d "$UNPACK_DIR" ]]; then
    echo ">>> Creating unpack dir..."
    mkdir -p "$UNPACK_DIR"
fi

echo ">>> Unpacking bundle files..."
for bundle in "$BUNDLES_DIR"/*.bundle; do
    if [[ -f "$bundle" ]]; then
        name=$(basename "$bundle" .bundle)
        target="$UNPACK_DIR/$name"
        if [[ ! -d "$target" ]]; then
            echo "  Unpack: $(basename "$bundle")"
            git clone --bare "$bundle" "$target"
        else
            echo "  Exists: $(basename "$bundle")"
        fi
    fi
done

# 4) Rewrite submodule URLs to unpacked bare repo dir
echo ">>> Configuring submodule URLs..."
cd "$ROOT"
sub_paths=$(git submodule status --recursive | awk '{print $2}')

for path in $sub_paths; do
    bundle_name=$(echo "$path" | tr '/' '_')
    bare_repo="$UNPACK_DIR/$bundle_name"
    if [[ ! -d "$bare_repo" ]]; then
        echo "WARNING: Bare repo not found: $bare_repo"
        continue
    fi
    abs_path=$(realpath "$bare_repo")
    echo "  Set submodule: $path -> $abs_path"
    git config "submodule.$path.url" "$abs_path"
done

# 5) Offline init & update submodules
echo ">>> Initializing submodules..."
export GIT_ALLOW_PROTOCOL=file
git submodule update --init --recursive
unset GIT_ALLOW_PROTOCOL

# 6) Tag last-sync for main & submodules
echo ">>> Tagging last-sync..."
git tag -f last-sync
git submodule foreach --recursive 'git tag -f last-sync'

echo ""
echo "SUCCESS: Offline repo ready: $ROOT"
echo "Next steps:"
echo "1. Check repo status: git -C $ROOT status"
echo "2. Start development"
echo "3. Use ./auto-sync-workflow.sh for sync" 