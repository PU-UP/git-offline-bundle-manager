#!/usr/bin/env bash

# Test script for submodule auto-detection functionality
# This script tests the submodule detection from .gitmodules file

set -euo pipefail

# Load configuration utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

echo "=== Testing Submodule Auto-Detection ==="
echo

# Test 1: Create a sample .gitmodules file
echo "Test 1: Creating sample .gitmodules file..."
cat > /tmp/test.gitmodules << 'EOF'
[submodule "module_a"]
	path = module_a
	url = https://github.com/example/module_a.git
[submodule "module_b"]
	path = module_b
	url = https://github.com/example/module_b.git
[submodule "deep/module_c"]
	path = deep/module_c
	url = https://github.com/example/module_c.git
EOF

echo "Sample .gitmodules content:"
cat /tmp/test.gitmodules
echo

# Test 2: Test submodule detection
echo "Test 2: Testing submodule detection..."
mkdir -p /tmp/test_repo
cp /tmp/test.gitmodules /tmp/test_repo/.gitmodules

DETECTED_MODULES=$(detect_submodules "/tmp/test_repo")
echo "Detected modules: '$DETECTED_MODULES'"

if [[ "$DETECTED_MODULES" == "module_a,module_b,deep/module_c" ]]; then
    echo "✅ Submodule detection test PASSED"
else
    echo "❌ Submodule detection test FAILED"
    echo "Expected: module_a,module_b,deep/module_c"
    echo "Got: $DETECTED_MODULES"
fi
echo

# Test 3: Test with no .gitmodules file
echo "Test 3: Testing with no .gitmodules file..."
mkdir -p /tmp/test_repo_no_modules

DETECTED_MODULES=$(detect_submodules "/tmp/test_repo_no_modules" 2>&1 || true)
echo "Result: $DETECTED_MODULES"

if [[ "$DETECTED_MODULES" == *"Warning: .gitmodules file not found"* ]]; then
    echo "✅ No .gitmodules test PASSED"
else
    echo "❌ No .gitmodules test FAILED"
fi
echo

# Test 4: Test get_submodules function
echo "Test 4: Testing get_submodules function..."
# Create a test config file
cat > /tmp/test.config << 'EOF'
[main]
repo_path=/tmp/test_repo
modules=config_module_a,config_module_b
EOF

# Test with config modules
CONFIG_MODULES=$(get_submodules "/tmp/test.config" "/tmp/test_repo")
echo "With config modules: '$CONFIG_MODULES'"

if [[ "$CONFIG_MODULES" == "config_module_a,config_module_b" ]]; then
    echo "✅ Config modules test PASSED"
else
    echo "❌ Config modules test FAILED"
fi

# Test without config modules
cat > /tmp/test_no_modules.config << 'EOF'
[main]
repo_path=/tmp/test_repo
EOF

AUTO_MODULES=$(get_submodules "/tmp/test_no_modules.config" "/tmp/test_repo")
echo "Auto-detected modules: '$AUTO_MODULES'"

if [[ "$AUTO_MODULES" == "module_a,module_b,deep/module_c" ]]; then
    echo "✅ Auto-detection test PASSED"
else
    echo "❌ Auto-detection test FAILED"
fi
echo

# Cleanup
echo "Cleaning up test files..."
rm -rf /tmp/test_repo /tmp/test_repo_no_modules /tmp/test.gitmodules /tmp/test.config /tmp/test_no_modules.config

echo
echo "=== Test completed ===" 