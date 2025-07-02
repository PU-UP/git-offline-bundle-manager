#!/usr/bin/env bash

# Export full repository bundle including all submodules
# Server-side script for generating complete repository bundles

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

# Create timestamped directory
TIMESTAMP=$(date +"%Y%m%d_%H%M")
BUNDLE_DIR="$OUTPUT_DIR/${TIMESTAMP}_bundles"

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

# Validate paths
if [[ ! -d "$REPO_PATH" ]]; then
    echo "Error: Repository path '$REPO_PATH' does not exist" >&2
    exit 1
fi

# Create bundle directory
echo "Creating bundle directory: $BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# Get repository name
REPO_NAME=$(basename "$REPO_PATH")

echo "=== Exporting full repository bundle ==="
echo "Repository: $REPO_PATH"
echo "Bundle directory: $BUNDLE_DIR"
echo "Modules: $MODULES"
echo

# Change to repository directory
cd "$REPO_PATH"

# Check if this is a git repository
if [[ ! -d ".git" ]]; then
    echo "Error: '$REPO_PATH' is not a git repository" >&2
    exit 1
fi

# Initialize documentation
DOC_FILE="$BUNDLE_DIR/bundle_report.md"
echo "# Git Bundle Export Report" > "$DOC_FILE"
echo "" >> "$DOC_FILE"
echo "## Export Information" >> "$DOC_FILE"
echo "- **Export Time**: $(date '+%Y-%m-%d %H:%M:%S')" >> "$DOC_FILE"
echo "- **Repository**: $REPO_NAME" >> "$DOC_FILE"
echo "- **Repository Path**: $REPO_PATH" >> "$DOC_FILE"
echo "- **Bundle Directory**: $BUNDLE_DIR" >> "$DOC_FILE"
echo "" >> "$DOC_FILE"

# Function to get repository statistics
get_repo_stats() {
    local repo_path="$1"
    local repo_name="$2"
    
    echo "## $repo_name Repository Statistics" >> "$DOC_FILE"
    
    # Get branch count
    local branch_count=$(git -C "$repo_path" branch -r | wc -l)
    echo "- **Total Branches**: $branch_count" >> "$DOC_FILE"
    
    # Get tag count
    local tag_count=$(git -C "$repo_path" tag | wc -l)
    echo "- **Total Tags**: $tag_count" >> "$DOC_FILE"
    
    # Get commit count
    local commit_count=$(git -C "$repo_path" rev-list --count HEAD)
    echo "- **Total Commits**: $commit_count" >> "$DOC_FILE"
    
    # Get recent branches (commits in last 7 days)
    echo "" >> "$DOC_FILE"
    echo "### Recent Activity (Last 7 Days)" >> "$DOC_FILE"
    local recent_branches=$(git -C "$repo_path" for-each-ref --format='%(refname:short) %(committerdate:iso)' refs/heads refs/remotes | \
        awk -v date="$(date -d '7 days ago' +%s)" '$2 >= date {print $1}' | sort -u)
    
    if [[ -n "$recent_branches" ]]; then
        echo "Branches with recent commits:" >> "$DOC_FILE"
        echo "$recent_branches" | while read -r branch; do
            echo "- $branch" >> "$DOC_FILE"
        done
    else
        echo "No branches with commits in the last 7 days." >> "$DOC_FILE"
    fi
    
    # Get latest commit info
    echo "" >> "$DOC_FILE"
    echo "### Latest Commit" >> "$DOC_FILE"
    local latest_commit=$(git -C "$repo_path" log -1 --pretty=format:"- **Hash**: %H%n- **Author**: %an%n- **Date**: %ad%n- **Message**: %s")
    echo "$latest_commit" >> "$DOC_FILE"
    
    echo "" >> "$DOC_FILE"
}

# Export main repository bundle
echo "Exporting main repository bundle..."
MAIN_BUNDLE="$BUNDLE_DIR/${REPO_NAME}.bundle"
git bundle create "$MAIN_BUNDLE" --all
echo "Created: $MAIN_BUNDLE"

# Get main repository statistics
get_repo_stats "$REPO_PATH" "Main"

# Export submodule bundles
echo
echo "Exporting submodule bundles..."

# Convert comma-separated modules to array
IFS=',' read -ra MODULE_ARRAY <<< "$MODULES"

for module in "${MODULE_ARRAY[@]}"; do
    module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [[ -d "$module" ]]; then
        echo "Exporting submodule: $module"
        # Create a safe filename by replacing slashes with underscores
        SAFE_MODULE_NAME=$(echo "$module" | sed 's/[\/\\]/_/g')
        MODULE_BUNDLE="$BUNDLE_DIR/${SAFE_MODULE_NAME}.bundle"
        
        # Check if submodule is initialized
        if [[ -e "$module/.git" ]]; then
            git -C "$module" bundle create "$MODULE_BUNDLE" --all
            echo "Created: $MODULE_BUNDLE"
            
            # Get submodule statistics
            get_repo_stats "$module" "Submodule: $module"
        else
            echo "Warning: Submodule '$module' is not initialized, skipping..."
            echo "## Submodule: $module" >> "$DOC_FILE"
            echo "- **Status**: Not initialized, skipped" >> "$DOC_FILE"
            echo "" >> "$DOC_FILE"
        fi
    else
        echo "Warning: Submodule directory '$module' not found, skipping..."
        echo "## Submodule: $module" >> "$DOC_FILE"
        echo "- **Status**: Directory not found, skipped" >> "$DOC_FILE"
        echo "" >> "$DOC_FILE"
    fi
done

# Add bundle files summary
echo "## Bundle Files" >> "$DOC_FILE"
echo "" >> "$DOC_FILE"
echo "Generated bundle files:" >> "$DOC_FILE"
for bundle_file in "$BUNDLE_DIR"/*.bundle; do
    if [[ -f "$bundle_file" ]]; then
        file_size=$(du -h "$bundle_file" | cut -f1)
        file_name=$(basename "$bundle_file")
        echo "- **$file_name**: $file_size" >> "$DOC_FILE"
    fi
done

echo
echo "=== Export completed ==="
echo "Bundles created in: $BUNDLE_DIR"
echo "Report generated: $DOC_FILE"
ls -la "$BUNDLE_DIR"/*.bundle 2>/dev/null || echo "No bundle files found" 