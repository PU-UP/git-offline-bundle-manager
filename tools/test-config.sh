#!/usr/bin/env bash

# Test script to verify configuration loading

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

CONFIG_FILE="$SCRIPT_DIR/local.config"

echo "Testing configuration loading..."
echo "Config file: $CONFIG_FILE"

# Load config
load_config "$CONFIG_FILE"

# Print all CONFIG_ variables
echo
echo "Loaded configuration variables:"
env | grep "^CONFIG_" | sort

echo
echo "Specific values:"
echo "CONFIG_REPO_PATH: ${CONFIG_REPO_PATH:-'NOT SET'}"
echo "CONFIG_BUNDLE_SOURCE: ${CONFIG_BUNDLE_SOURCE:-'NOT SET'}"
echo "CONFIG_BASE_BRANCH: ${CONFIG_BASE_BRANCH:-'NOT SET'}"
echo "CONFIG_OUTPUT_DIR: ${CONFIG_OUTPUT_DIR:-'NOT SET'}"
echo "CONFIG_FEATURE_BRANCH: ${CONFIG_FEATURE_BRANCH:-'NOT SET'}" 