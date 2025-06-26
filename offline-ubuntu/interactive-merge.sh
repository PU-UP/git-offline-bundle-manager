#!/usr/bin/env bash
set -euo pipefail

# Ubuntu Interactive Merge Script
# Interactive conflict resolution for offline development

# Default config
DEFAULT_ROOT="/work/develop_gitlab/slam-core"

# Read config file (if exists)
CONFIG_FILE="config.json"
if [[ -f "$CONFIG_FILE" ]]; then
    echo ">>> Reading config file: $CONFIG_FILE"
    if command -v jq &> /dev/null; then
        FORCE_PLATFORM=$(jq -r '.platform.force_platform // empty' "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$FORCE_PLATFORM" ]]; then
            PLATFORM="$FORCE_PLATFORM"
        else
            PLATFORM="ubuntu"
        fi
        
        ROOT=$(jq -r ".paths.$PLATFORM.repo_dir // empty" "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_ROOT")
        ENABLE_INTERACTIVE=$(jq -r '.workflow.enable_interactive_mode // true' "$CONFIG_FILE" 2>/dev/null)
    else
        echo ">>> jq not installed, using default config"
        ROOT="$DEFAULT_ROOT"
        ENABLE_INTERACTIVE=true
    fi
else
    echo ">>> Config file not found, using default config"
    ROOT="$DEFAULT_ROOT"
    ENABLE_INTERACTIVE=true
fi

# Environment variable overrides
ROOT="${GIT_OFFLINE_UBUNTU_REPO_DIR:-$ROOT}"

echo ">>> Using config:"
echo "    Repo dir: $ROOT"
echo "    Interactive mode: $ENABLE_INTERACTIVE"

# Check if repo exists
if [[ ! -d "$ROOT/.git" ]]; then
    echo "ERROR: Not a valid Git repository: $ROOT"
    exit 1
fi

cd "$ROOT"

# Check for conflicts
conflicts=$(git diff --name-only --diff-filter=U)
if [[ -z "$conflicts" ]]; then
    echo ">>> No conflicts found"
    exit 0
fi

echo ">>> Found conflicts in the following files:"
echo "$conflicts"
echo ""

if [[ "$ENABLE_INTERACTIVE" == "true" ]]; then
    echo ">>> Starting interactive merge..."
    echo "Options:"
    echo "1. Use 'git mergetool' for each file"
    echo "2. Use 'git add' to mark as resolved"
    echo "3. Use 'git checkout --ours/--theirs' to choose one side"
    echo "4. Edit files manually"
    echo ""
    
    read -p "Choose option (1-4) or press Enter to use git mergetool: " choice
    
    case $choice in
        1|"")
            echo ">>> Using git mergetool..."
            git mergetool
            ;;
        2)
            echo ">>> Marking all conflicts as resolved..."
            git add .
            ;;
        3)
            echo ">>> Choose conflict resolution strategy:"
            echo "1. Use 'ours' (current branch)"
            echo "2. Use 'theirs' (incoming branch)"
            read -p "Choose (1-2): " strategy
            if [[ "$strategy" == "1" ]]; then
                git checkout --ours .
            elif [[ "$strategy" == "2" ]]; then
                git checkout --theirs .
            fi
            git add .
            ;;
        4)
            echo ">>> Manual resolution mode"
            echo "Please edit the conflicted files manually, then run:"
            echo "  git add <resolved-files>"
            echo "  git commit"
            exit 0
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
else
    echo ">>> Interactive mode disabled, using automatic resolution..."
    git checkout --ours .
    git add .
fi

# Check if merge is complete
if git diff --cached --quiet; then
    echo ">>> No staged changes, merge may be incomplete"
else
    echo ">>> Merge completed successfully"
    echo ">>> You can now commit the changes:"
    echo "  git commit -m 'Resolve merge conflicts'"
fi 