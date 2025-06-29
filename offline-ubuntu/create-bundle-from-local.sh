#!/usr/bin/env bash
set -euo pipefail

# Ubuntu Create Bundle From Local Script
# Create bundle files from local changes for syncing back to GitLab server:
# 1. Check local change status
# 2. Create bundles containing local changes
# 3. Generate diff report
# 4. Prepare sync files

# Default config
DEFAULT_ROOT="/work/develop_gitlab/slam-core"
DEFAULT_OUTPUT="./local-bundles"

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
        OUTPUT_DIR=$(jq -r ".environments.$PLATFORM.paths.local_bundles_dir // empty" "$CONFIG_FILE" 2>/dev/null || echo "$DEFAULT_OUTPUT")
        INCLUDE_ALL=$(jq -r '.global.bundle.include_all_branches // false' "$CONFIG_FILE" 2>/dev/null)
        CREATE_DIFF=$(jq -r ".environments.$PLATFORM.sync.create_diff_report // true" "$CONFIG_FILE" 2>/dev/null)
        TIMESTAMP_FORMAT=$(jq -r '.global.bundle.timestamp_format // "yyyyMMdd_HHmmss"' "$CONFIG_FILE" 2>/dev/null)
        LOCAL_PREFIX=$(jq -r '.global.bundle.local_prefix // "local_"' "$CONFIG_FILE" 2>/dev/null)
        MAIN_REPO_NAME=$(jq -r '.global.bundle.main_repo_name // "slam-core"' "$CONFIG_FILE" 2>/dev/null)
    else
        echo ">>> jq not installed, using default config"
        ROOT="$DEFAULT_ROOT"
        OUTPUT_DIR="$DEFAULT_OUTPUT"
        INCLUDE_ALL=false
        CREATE_DIFF=true
        TIMESTAMP_FORMAT="yyyyMMdd_HHmmss"
        LOCAL_PREFIX="local_"
        MAIN_REPO_NAME="slam-core"
    fi
else
    echo ">>> Config file not found, using default config"
    ROOT="$DEFAULT_ROOT"
    OUTPUT_DIR="$DEFAULT_OUTPUT"
    INCLUDE_ALL=false
    CREATE_DIFF=true
    TIMESTAMP_FORMAT="yyyyMMdd_HHmmss"
    LOCAL_PREFIX="local_"
    MAIN_REPO_NAME="slam-core"
fi

# Environment variable overrides
ROOT="${GIT_OFFLINE_UBUNTU_REPO_DIR:-$ROOT}"
OUTPUT_DIR="${GIT_OFFLINE_UBUNTU_LOCAL_BUNDLES_DIR:-$OUTPUT_DIR}"

echo ">>> Using config:"
echo "    Repo dir: $ROOT"
echo "    Output dir: $OUTPUT_DIR"
echo "    Include all branches: $INCLUDE_ALL"
echo "    Create diff report: $CREATE_DIFF"

# 0) Check repo status
echo ">>> Checking local repo status..."

if [[ ! -d "$ROOT/.git" ]]; then
    echo "ERROR: Not a valid Git repository: $ROOT"
    exit 1
fi

# 1) Create output directory
if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo ">>> Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

# 2) Get current timestamp
timestamp=$(date +"$TIMESTAMP_FORMAT")
bundle_prefix="${LOCAL_PREFIX}${timestamp}"

# 2.1) Get submodule paths (used in multiple places)
sub_paths=$(git submodule status --recursive | sed -n 's/^[[:space:]]*[a-f0-9]*[[:space:]]\+\([^[:space:]]\+\)[[:space:]]\+([^)]*)$/\1/p')

# 2.5) Check for existing bundles and ask for confirmation to delete
echo ">>> Checking for existing bundles..."
existing_bundles=()

# Check main repo bundle
main_bundle="$OUTPUT_DIR/${bundle_prefix}_${MAIN_REPO_NAME}.bundle"
if [[ -f "$main_bundle" ]]; then
    existing_bundles+=("$main_bundle")
fi

# Check submodule bundles
for path in $sub_paths; do
    bundle_name=$(echo "$path" | tr '/' '_')
    sub_bundle="$OUTPUT_DIR/${bundle_prefix}_${bundle_name}.bundle"
    if [[ -f "$sub_bundle" ]]; then
        existing_bundles+=("$sub_bundle")
    fi
done

# Check for info and diff report files
info_file="$OUTPUT_DIR/${bundle_prefix}_info.json"
if [[ -f "$info_file" ]]; then
    existing_bundles+=("$info_file")
fi

if [[ "$CREATE_DIFF" == "true" ]]; then
    diff_report="$OUTPUT_DIR/${bundle_prefix}_${MAIN_REPO_NAME}_diff_report.txt"
    if [[ -f "$diff_report" ]]; then
        existing_bundles+=("$diff_report")
    fi
fi

# Ask for confirmation if existing bundles found
if [[ ${#existing_bundles[@]} -gt 0 ]]; then
    echo ">>> Found existing bundle files with the same timestamp:"
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
    # Check for any existing bundle files with the same prefix pattern
    all_existing_bundles=()
    if [[ -d "$OUTPUT_DIR" ]]; then
        while IFS= read -r -d '' file; do
            filename=$(basename "$file")
            if [[ "$filename" =~ ^${LOCAL_PREFIX}.*\.bundle$ ]] || \
               [[ "$filename" =~ ^${LOCAL_PREFIX}.*\.json$ ]] || \
               [[ "$filename" =~ ^${LOCAL_PREFIX}.*_diff_report\.txt$ ]]; then
                all_existing_bundles+=("$file")
            fi
        done < <(find "$OUTPUT_DIR" -maxdepth 1 -type f -print0 2>/dev/null)
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

# 3) Create main repo bundle
echo ">>> Creating main repo bundle..."
main_bundle="$OUTPUT_DIR/${bundle_prefix}_${MAIN_REPO_NAME}.bundle"

cd "$ROOT"
if [[ "$INCLUDE_ALL" == "true" ]]; then
    git bundle create "$main_bundle" --all
else
    # Only include current branch and last-sync tag
    git bundle create "$main_bundle" HEAD last-sync
fi

# 4) Create submodule bundles
echo ">>> Creating submodule bundles..."
for path in $sub_paths; do
    bundle_name=$(echo "$path" | tr '/' '_')
    sub_bundle="$OUTPUT_DIR/${bundle_prefix}_${bundle_name}.bundle"
    sub_repo="$ROOT/$path"
    
    echo "  Creating submodule bundle: $path"
    
    if [[ -d "$sub_repo" ]]; then
        cd "$sub_repo"
        
        if [[ "$INCLUDE_ALL" == "true" ]]; then
            git bundle create "$sub_bundle" --all
        else
            git bundle create "$sub_bundle" HEAD last-sync
        fi
    else
        echo "    WARNING: Submodule path not found: $sub_repo"
    fi
done

cd "$ROOT"

# 5) Create diff report
if [[ "$CREATE_DIFF" == "true" ]]; then
    echo ">>> Creating diff report..."
    diff_report="$OUTPUT_DIR/${bundle_prefix}_${MAIN_REPO_NAME}_diff_report.txt"
    
    # Main repo diff
    main_diff=$(git diff last-sync..HEAD --stat)
    echo "=== Main repo diff (last-sync..HEAD) ===" > "$diff_report"
    echo "$main_diff" >> "$diff_report"
    
    # Submodule diffs
    for path in $sub_paths; do
        sub_repo="$ROOT/$path"
        if [[ -d "$sub_repo" ]]; then
            sub_diff=$(cd "$sub_repo" && git diff last-sync..HEAD --stat)
            if [[ -n "$sub_diff" ]]; then
                echo "" >> "$diff_report"
                echo "=== Submodule $path diff ===" >> "$diff_report"
                echo "$sub_diff" >> "$diff_report"
            fi
        fi
    done
fi

# 6) Create sync info file
sync_info=$(cat << EOF
{
  "timestamp": "$timestamp",
  "bundle_prefix": "$bundle_prefix",
  "main_bundle": "${bundle_prefix}_${MAIN_REPO_NAME}.bundle",
  "sub_bundles": [
EOF
)

first=true
for path in $sub_paths; do
    bundle_name=$(echo "$path" | tr '/' '_')
    if [[ "$first" == "true" ]]; then
        first=false
    else
        sync_info="$sync_info,"
    fi
    sync_info="$sync_info\n    \"${bundle_prefix}_${bundle_name}.bundle\""
done

sync_info="$sync_info
  ],
  "created_at": "$(date '+%Y-%m-%d %H:%M:%S')",
  "git_status": "$(git status --porcelain | tr '\n' ' ' | sed 's/"/\\"/g')",
  "config_used": {
    "repo_dir": "$ROOT",
    "output_dir": "$OUTPUT_DIR",
    "include_all": $INCLUDE_ALL,
    "create_diff": $CREATE_DIFF
  }
}
EOF

echo -e "$sync_info" > "$OUTPUT_DIR/${bundle_prefix}_info.json"

# 7) Show results
echo ""
echo "SUCCESS: Bundle creation completed!"
echo "Output directory: $OUTPUT_DIR"
echo "Main repo bundle: ${bundle_prefix}_${MAIN_REPO_NAME}.bundle"
echo "Submodule bundle count: $(echo "$sub_paths" | wc -w)"

if [[ "$CREATE_DIFF" == "true" ]]; then
    echo "Diff report: ${bundle_prefix}_${MAIN_REPO_NAME}_diff_report.txt"
fi

echo ""
echo "Next steps:"
echo "1. Copy files from $OUTPUT_DIR to GitLab server"
echo "2. Use import_local_bundles.sh on GitLab server to import changes" 