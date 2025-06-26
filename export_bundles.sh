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
        ROOT=$(jq -r '.paths.ubuntu.repo_dir // empty' "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_ROOT")
        OUT=$(jq -r '.paths.ubuntu.bundles_dir // empty' "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_OUTPUT")
    else
        echo ">>> jq not installed, using default config"
        ROOT="$DEFAULT_ROOT"
        OUT="$DEFAULT_OUTPUT"
    fi
else
    echo ">>> Config file not found, using default config"
    ROOT="$DEFAULT_ROOT"
    OUT="$DEFAULT_OUTPUT"
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

echo ">>> Bundling super-project"
cd "$ROOT"
git bundle create "$OUT/slam-core.bundle" --all

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

