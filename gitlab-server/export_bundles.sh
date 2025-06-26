#!/usr/bin/env bash
set -euo pipefail

# Git Offline Tool - Ubuntu Export Script
# Supports config file and environment variable overrides

# Default config
DEFAULT_ROOT="/work/develop_gitlab/slam-core"
DEFAULT_OUTPUT="bundles"

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
        OUT=$(jq -r ".environments.$PLATFORM.paths.bundles_dir // empty" "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_OUTPUT")
        MAIN_REPO_NAME=$(jq -r '.global.bundle.main_repo_name // "slam-core"' "$CONFIG_FILE" 2>/dev/null)
    else
        echo ">>> jq not installed, using default config"
        ROOT="$DEFAULT_ROOT"
        OUT="$DEFAULT_OUTPUT"
        MAIN_REPO_NAME="slam-core"
    fi
else
    echo ">>> Config file not found, using default config"
    ROOT="$DEFAULT_ROOT"
    OUT="$DEFAULT_OUTPUT"
    MAIN_REPO_NAME="slam-core"
fi

# Environment variable overrides
ROOT="${GIT_OFFLINE_UBUNTU_REPO_DIR:-$ROOT}"
OUT="${GIT_OFFLINE_UBUNTU_BUNDLES_DIR:-$OUT}"

# Ensure OUT is relative to ROOT path
if [[ ! "$OUT" =~ ^/ ]]; then
    OUT="$ROOT/$OUT"
fi

echo ">>> Using config:"
echo "    Repo root: $ROOT"
echo "    Output dir: $OUT"

# Check repo directory
if [[ ! -d "$ROOT" ]]; then
    echo "ERROR: Repo directory does not exist: $ROOT"
    exit 1
fi

# Create output directory
mkdir -p "$OUT"

# Check for existing bundles and ask for confirmation to delete
echo ">>> Checking for existing bundles..."
existing_bundles=()

# Get submodule paths for checking
sub_paths=$(git submodule status --recursive | sed -n 's/^[[:space:]]*[a-f0-9]*[[:space:]]\+\([^[:space:]]\+\)[[:space:]]\+([^)]*)$/\1/p')

# Check main repo bundle
main_bundle="$OUT/$MAIN_REPO_NAME.bundle"
if [[ -f "$main_bundle" ]]; then
    existing_bundles+=("$main_bundle")
fi

# Check submodule bundles
for path in $sub_paths; do
    bundle_name=$(echo "$path" | tr '/' '_').bundle
    sub_bundle="$OUT/$bundle_name"
    if [[ -f "$sub_bundle" ]]; then
        existing_bundles+=("$sub_bundle")
    fi
done

# Ask for confirmation if existing bundles found
if [[ ${#existing_bundles[@]} -gt 0 ]]; then
    echo ">>> Found existing bundle files:"
    for bundle in "${existing_bundles[@]}"; do
        echo "  - $bundle"
    done
    echo ""
    
    # Check if confirmation is required from config
    if command -v jq &> /dev/null && [[ -f "$CONFIG_FILE" ]]; then
        confirm_required=$(jq -r ".environments.$PLATFORM.sync.confirm_before_actions // true" "$CONFIG_FILE" 2>/dev/null)
    else
        confirm_required="true"
    fi
    
    if [[ "$confirm_required" == "true" ]]; then
        read -p "Do you want to delete these existing files and create new bundles? (y/N): " response
        if [[ ! "$response" =~ ^[yY] ]]; then
            echo ">>> Operation cancelled by user."
            exit 0
        fi
    fi
    
    echo ">>> Deleting existing bundle files..."
    for bundle in "${existing_bundles[@]}"; do
        rm -f "$bundle"
        echo "  Deleted: $bundle"
    done
    echo ""
else
    # Check for any existing bundle files
    all_existing_bundles=()
    if [[ -d "$OUT" ]]; then
        while IFS= read -r -d '' file; do
            filename=$(basename "$file")
            if [[ "$filename" =~ \.bundle$ ]]; then
                all_existing_bundles+=("$file")
            fi
        done < <(find "$OUT" -maxdepth 1 -type f -name "*.bundle" -print0 2>/dev/null)
    fi
    
    if [[ ${#all_existing_bundles[@]} -gt 0 ]]; then
        # Check if confirmation is required from config
        if command -v jq &> /dev/null && [[ -f "$CONFIG_FILE" ]]; then
            confirm_required=$(jq -r ".environments.$PLATFORM.sync.confirm_before_actions // true" "$CONFIG_FILE" 2>/dev/null)
        else
            confirm_required="true"
        fi
        
        if [[ "$confirm_required" == "true" ]]; then
            echo ">>> Found other existing bundle files in the directory:"
            for bundle in "${all_existing_bundles[@]:0:5}"; do
                echo "  - $(basename "$bundle")"
            done
            if [[ ${#all_existing_bundles[@]} -gt 5 ]]; then
                echo "  ... and $((${#all_existing_bundles[@]} - 5)) more files"
            fi
            echo ""
            
            read -p "Do you want to delete all existing bundle files before creating new ones? (y/N): " response
            if [[ "$response" =~ ^[yY] ]]; then
                echo ">>> Deleting all existing bundle files..."
                for bundle in "${all_existing_bundles[@]}"; do
                    rm -f "$bundle"
                    echo "  Deleted: $(basename "$bundle")"
                done
                echo ""
            fi
        fi
    fi
fi

echo ">>> Bundling super-project"
cd "$ROOT"
git bundle create "$OUT/$MAIN_REPO_NAME.bundle" --all

echo ">>> Bundling submodules"
export OUT                                 # Make available to subprocesses
git submodule foreach --recursive '
  # 1) Replace all / with _ in multi-level paths
  bundle_name=$(echo "$name" | tr "/" "_").bundle
  echo "    -> $bundle_name"
  # 2) Write to main repo $OUT directory
  git bundle create "$OUT/$bundle_name" --all
'

echo "SUCCESS: All bundles in $OUT"
echo "Next steps:"
echo "1. Copy $OUT directory to Windows computer"
echo "2. Run Setup-OfflineRepo.ps1 on Windows"

