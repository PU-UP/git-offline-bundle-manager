#!/usr/bin/env bash
set -euo pipefail

# Ubuntu Auto Sync Workflow Script
# Automated offline development workflow:
# 1. Check local status
# 2. Backup current work
# 3. Update to latest bundle
# 4. Merge local changes
# 5. Optional: Create local bundle for sync

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
        FORCE_PLATFORM=$(jq -r '.global.platform.force_platform // empty' "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$FORCE_PLATFORM" ]]; then
            PLATFORM="$FORCE_PLATFORM"
        else
            PLATFORM="offline_ubuntu"
        fi
        
        ROOT=$(jq -r ".environments.$PLATFORM.paths.repo_dir // empty" "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_ROOT")
        BUNDLES_DIR=$(jq -r ".environments.$PLATFORM.paths.bundles_dir // empty" "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_BUNDLES_DIR")
        LOCAL_BUNDLES_DIR=$(jq -r ".environments.$PLATFORM.paths.local_bundles_dir // empty" "$CONFIG_FILE" 2>/dev/null || echo "./local-bundles")
        BACKUP_DIR=$(jq -r ".environments.$PLATFORM.paths.backup_dir // empty" "$CONFIG_FILE" 2>/dev/null || echo "./backups")
        AUTO_RESOLVE=$(jq -r ".environments.$PLATFORM.sync.auto_resolve_conflicts // false" "$CONFIG_FILE" 2>/dev/null)
        SKIP_BACKUP=$(jq -r ".environments.$PLATFORM.sync.backup_before_update // true" "$CONFIG_FILE" 2>/dev/null)
        SKIP_BACKUP=$([[ "$SKIP_BACKUP" == "true" ]] && echo "false" || echo "true")
        CREATE_LOCAL_BUNDLE=$(jq -r '.global.workflow.auto_create_local_bundle // false' "$CONFIG_FILE" 2>/dev/null)
        ENABLE_INTERACTIVE=$(jq -r '.global.workflow.enable_interactive_mode // true' "$CONFIG_FILE" 2>/dev/null)
    else
        echo ">>> jq not installed, using default config"
        ROOT="$DEFAULT_ROOT"
        BUNDLES_DIR="$DEFAULT_BUNDLES_DIR"
        LOCAL_BUNDLES_DIR="./local-bundles"
        BACKUP_DIR="./backups"
        AUTO_RESOLVE=false
        SKIP_BACKUP=false
        CREATE_LOCAL_BUNDLE=false
        ENABLE_INTERACTIVE=true
    fi
else
    echo ">>> Config file not found, using default config"
    ROOT="$DEFAULT_ROOT"
    BUNDLES_DIR="$DEFAULT_BUNDLES_DIR"
    LOCAL_BUNDLES_DIR="./local-bundles"
    BACKUP_DIR="./backups"
    AUTO_RESOLVE=false
    SKIP_BACKUP=false
    CREATE_LOCAL_BUNDLE=false
    ENABLE_INTERACTIVE=true
fi

# Environment variable overrides
ROOT="${GIT_OFFLINE_UBUNTU_REPO_DIR:-$ROOT}"
BUNDLES_DIR="${GIT_OFFLINE_UBUNTU_BUNDLES_DIR:-$BUNDLES_DIR}"

echo ">>> Using config:"
echo "    Repo dir: $ROOT"
echo "    Bundles dir: $BUNDLES_DIR"
echo "    Auto resolve conflicts: $AUTO_RESOLVE"
echo "    Backup before update: $SKIP_BACKUP"

# Helper functions
write_step() {
    local message="$1"
    local color="$2"
    echo ""
    echo "=== $message ==="
}

confirm_continue() {
    local message="$1"
    if [[ "$ENABLE_INTERACTIVE" == "true" ]]; then
        read -p "$message (y/N): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]]
    else
        return 0
    fi
}

# 0) Check environment
write_step "Checking work environment" "Cyan"

if [[ ! -d "$ROOT" ]]; then
    echo "ERROR: Repo directory does not exist: $ROOT"
    exit 1
fi

if [[ ! -d "$BUNDLES_DIR" ]]; then
    echo "ERROR: Bundles directory does not exist: $BUNDLES_DIR"
    exit 1
fi

# 1) Check local status
write_step "Checking local repo status" "Yellow"

cd "$ROOT"
main_status=$(git status --porcelain)
sub_status=$(git submodule foreach --recursive 'git status --porcelain')

has_changes=false
if [[ -n "$main_status" ]] || [[ -n "$sub_status" ]]; then
    has_changes=true
fi

if [[ "$has_changes" == "true" ]]; then
    echo "WARNING: Local changes detected:"
    if [[ -n "$main_status" ]]; then
        echo "Main repo changes:"
        echo "$main_status"
    fi
    if [[ -n "$sub_status" ]]; then
        echo "Submodule changes:"
        echo "$sub_status"
    fi
    
    if ! confirm_continue "Continue with sync?"; then
        echo "Operation cancelled"
        exit 0
    fi
fi

# 2) Create backup
if [[ "$SKIP_BACKUP" == "false" ]]; then
    write_step "Creating backup" "Yellow"
    
    if confirm_continue "Create backup before update?"; then
        timestamp=$(date +"%Y%m%d_%H%M%S")
        backup_name="$(basename "$ROOT")-backup-$timestamp"
        backup_path="$BACKUP_DIR/$backup_name"
        
        mkdir -p "$BACKUP_DIR"
        cp -r "$ROOT" "$backup_path"
        echo "SUCCESS: Backup completed: $backup_path"
    fi
fi

# 3) Handle local changes
if [[ "$has_changes" == "true" ]]; then
    write_step "Handling local changes" "Yellow"
    
    if [[ "$AUTO_RESOLVE" == "true" ]]; then
        echo "Using auto-merge mode..."
        # Simple auto-merge: stash and pop
        git stash push -m "Auto-stash before merge"
        git stash pop || echo "WARNING: Auto-merge failed, manual resolution needed"
    else
        echo "Manual merge required"
        echo "Please resolve conflicts manually:"
        echo "1. git status"
        echo "2. Edit conflicted files"
        echo "3. git add ."
        echo "4. git commit"
    fi
fi

# 4) Update to latest bundle
write_step "Updating to latest bundle" "Green"

# Update main repo
main_bundle="$BUNDLES_DIR/slam-core.bundle"
if [[ -f "$main_bundle" ]]; then
    git fetch "$main_bundle" "refs/heads/*:refs/heads/*" --update-head-ok
else
    echo "ERROR: Main bundle not found: $main_bundle"
    exit 1
fi

# Update submodules
sub_paths=$(git submodule status --recursive | awk '{print $2}')
for path in $sub_paths; do
    bundle_name=$(echo "$path" | tr '/' '_')
    sub_bundle="$BUNDLES_DIR/$bundle_name.bundle"
    
    if [[ -f "$sub_bundle" ]]; then
        echo "  Updating submodule: $path"
        cd "$ROOT/$path"
        git fetch "$sub_bundle" "refs/heads/*:refs/heads/*" --update-head-ok
        cd "$ROOT"
    else
        echo "WARNING: Submodule bundle not found: $sub_bundle"
    fi
done

# Update last-sync tags
echo "Updating sync tags..."
git tag -f last-sync
git submodule foreach --recursive 'git tag -f last-sync'

echo "SUCCESS: Update completed"

# 5) Create local bundle (optional)
if [[ "$CREATE_LOCAL_BUNDLE" == "true" ]]; then
    write_step "Creating local bundle" "Cyan"
    
    mkdir -p "$LOCAL_BUNDLES_DIR"
    timestamp=$(date +"%Y%m%d_%H%M%S")
    bundle_prefix="local_$timestamp"
    
    # Create main repo bundle
    echo "Creating main repo bundle..."
    git bundle create "$LOCAL_BUNDLES_DIR/${bundle_prefix}_slam-core.bundle" HEAD last-sync
    
    # Create submodule bundles
    echo "Creating submodule bundles..."
    for path in $sub_paths; do
        bundle_name=$(echo "$path" | tr '/' '_')
        echo "  Creating submodule bundle: $path"
        cd "$ROOT/$path"
        git bundle create "$LOCAL_BUNDLES_DIR/${bundle_prefix}_${bundle_name}.bundle" HEAD last-sync
        cd "$ROOT"
    done
    
    echo "SUCCESS: Local bundle creation completed"
    echo "Output directory: $LOCAL_BUNDLES_DIR"
fi

# 6) Show final status
write_step "Sync completed" "Green"

echo "Current repo status:"
git status --short

echo ""
echo "Submodule status:"
git submodule status --recursive

echo ""
echo "Next steps:"
echo "1. Check if code works properly"
echo "2. Run tests to ensure quality"
echo "3. Continue development work"

if [[ -d "$LOCAL_BUNDLES_DIR" ]]; then
    echo "4. Copy files from $LOCAL_BUNDLES_DIR to GitLab server for sync"
fi

echo ""
echo "SUCCESS: Automated sync workflow completed!" 