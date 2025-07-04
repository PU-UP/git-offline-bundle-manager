#!/usr/bin/env bash

# Test script to verify export-full.sh can generate complete bundles
# This script checks the export process and bundle contents

set -euo pipefail

# Load configuration utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_utils.sh"

# Default config file
CONFIG_FILE="${1:-$SCRIPT_DIR/server.config}"

# Load and validate configuration
if ! validate_config "$CONFIG_FILE" "repo_path" "output_dir"; then
    echo "Usage: $0 [config_file]"
    echo "Default config file: $SCRIPT_DIR/server.config"
    exit 1
fi

load_config "$CONFIG_FILE"

REPO_PATH="$CONFIG_REPO_PATH"
OUTPUT_DIR="$CONFIG_OUTPUT_DIR"

echo "=== Testing Export Completeness ==="
echo "Repository path: $REPO_PATH"
echo "Output directory: $OUTPUT_DIR"
echo

# Check if repository exists
if [[ ! -d "$REPO_PATH" ]]; then
    echo "❌ Error: Repository path '$REPO_PATH' does not exist"
    exit 1
fi

# Check if it's a git repository
if [[ ! -d "$REPO_PATH/.git" ]]; then
    echo "❌ Error: '$REPO_PATH' is not a git repository"
    exit 1
fi

echo "✅ Repository exists and is a git repository"

# Check main repository branches
echo
echo "=== Main Repository Analysis ==="
cd "$REPO_PATH"

echo "📋 Main repository branches:"
if git branch -r | grep -q .; then
    git branch -r | sort
    BRANCH_COUNT=$(git branch -r | wc -l)
    echo "Total remote branches: $BRANCH_COUNT"
else
    echo "❌ No remote branches found!"
fi

echo
echo "🏷️  Main repository tags:"
if git tag | grep -q .; then
    git tag | sort
    TAG_COUNT=$(git tag | wc -l)
    echo "Total tags: $TAG_COUNT"
else
    echo "❌ No tags found!"
fi

echo
echo "📊 Main repository commits:"
COMMIT_COUNT=$(git rev-list --count --all 2>/dev/null || echo "0")
echo "Total commits: $COMMIT_COUNT"

# Check submodules
echo
echo "=== Submodule Analysis ==="

# Auto-detect submodules
MODULES=$(get_submodules "$CONFIG_FILE" "$REPO_PATH")
if [[ -z "$MODULES" ]]; then
    echo "❌ No submodules detected"
    exit 1
fi

echo "Detected submodules: $MODULES"

# Convert comma-separated modules to array
IFS=',' read -ra MODULE_ARRAY <<< "$MODULES"

for module in "${MODULE_ARRAY[@]}"; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    echo
    echo "--- Submodule: $module ---"
    
    if [[ ! -d "$module" ]]; then
        echo "❌ Submodule directory not found: $module"
        continue
    fi
    
    if [[ ! -e "$module/.git" ]]; then
        echo "❌ Submodule not initialized: $module"
        echo "   Run: git submodule update --init --recursive"
        continue
    fi
    
    echo "✅ Submodule directory exists and is initialized"
    
    # Check submodule branches
    echo "📋 Submodule branches:"
    if git -C "$module" branch -r | grep -q .; then
        git -C "$module" branch -r | sort
        BRANCH_COUNT=$(git -C "$module" branch -r | wc -l)
        echo "Total remote branches: $BRANCH_COUNT"
    else
        echo "❌ No remote branches found in submodule!"
    fi
    
    # Check submodule tags
    echo "🏷️  Submodule tags:"
    if git -C "$module" tag | grep -q .; then
        git -C "$module" tag | sort
        TAG_COUNT=$(git -C "$module" tag | wc -l)
        echo "Total tags: $TAG_COUNT"
    else
        echo "❌ No tags found in submodule!"
    fi
    
    # Check submodule commits
    echo "📊 Submodule commits:"
    COMMIT_COUNT=$(git -C "$module" rev-list --count --all 2>/dev/null || echo "0")
    echo "Total commits: $COMMIT_COUNT"
    
    # Check submodule working directory
    echo "📁 Submodule working directory:"
    FILE_COUNT=$(find "$module" -type f -not -path "*/\.git/*" | wc -l)
    echo "Files in working directory: $FILE_COUNT"
    
    if [[ "$FILE_COUNT" -eq 0 ]]; then
        echo "⚠️  Warning: Submodule working directory is empty!"
        echo "   This might indicate the submodule is not properly checked out"
    fi
    
    # Check submodule status
    echo "📋 Submodule status:"
    git submodule status "$module"
done

echo
echo "=== Export Process Analysis ==="

# Simulate the export process
echo "🔍 Analyzing what export-full.sh would do:"

# Check if output directory exists
if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "❌ Output directory does not exist: $OUTPUT_DIR"
    echo "   Please create it first"
else
    echo "✅ Output directory exists: $OUTPUT_DIR"
fi

# Check bundle creation capability
echo
echo "🧪 Testing bundle creation capability:"

# Test main repository bundle creation
echo "Testing main repository bundle creation..."
TEMP_BUNDLE="/tmp/test_main.bundle"
if git bundle create "$TEMP_BUNDLE" --all 2>/dev/null; then
    echo "✅ Main repository bundle creation: SUCCESS"
    BUNDLE_SIZE=$(du -h "$TEMP_BUNDLE" | cut -f1)
    echo "   Bundle size: $BUNDLE_SIZE"
    rm -f "$TEMP_BUNDLE"
else
    echo "❌ Main repository bundle creation: FAILED"
fi

# Test submodule bundle creation
for module in "${MODULE_ARRAY[@]}"; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [[ -d "$module" && -e "$module/.git" ]]; then
        echo "Testing submodule bundle creation: $module"
        TEMP_BUNDLE="/tmp/test_${module//\//_}.bundle"
        if git -C "$module" bundle create "$TEMP_BUNDLE" --all 2>/dev/null; then
            echo "✅ Submodule bundle creation: SUCCESS"
            BUNDLE_SIZE=$(du -h "$TEMP_BUNDLE" | cut -f1)
            echo "   Bundle size: $BUNDLE_SIZE"
            rm -f "$TEMP_BUNDLE"
        else
            echo "❌ Submodule bundle creation: FAILED"
        fi
    fi
done

echo
echo "=== Recommendations ==="

# Check for potential issues
ISSUES_FOUND=0

# Check if any submodules are not initialized
for module in "${MODULE_ARRAY[@]}"; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ ! -e "$module/.git" ]]; then
        echo "⚠️  Issue: Submodule '$module' is not initialized"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
done

# Check if any submodules have no branches
for module in "${MODULE_ARRAY[@]}"; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -e "$module/.git" ]] && ! git -C "$module" branch -r | grep -q .; then
        echo "⚠️  Issue: Submodule '$module' has no remote branches"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
done

# Check if any submodules have empty working directory
for module in "${MODULE_ARRAY[@]}"; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -e "$module/.git" ]]; then
        FILE_COUNT=$(find "$module" -type f -not -path "*/\.git/*" | wc -l)
        if [[ "$FILE_COUNT" -eq 0 ]]; then
            echo "⚠️  Issue: Submodule '$module' working directory is empty"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
    fi
done

if [[ "$ISSUES_FOUND" -eq 0 ]]; then
    echo "✅ No issues found. export-full.sh should work correctly."
else
    echo
    echo "🔧 To fix these issues:"
    echo "1. Initialize all submodules: git submodule update --init --recursive"
    echo "2. Check out appropriate branches in each submodule"
    echo "3. Ensure all submodules have content and branches"
    echo "4. Run export-full.sh again"
fi

echo
echo "=== Test completed ===" 