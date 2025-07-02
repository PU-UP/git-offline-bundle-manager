#!/usr/bin/env bash
set -euo pipefail

# Ubuntu Create Bundle From Local Script
# Create bundle files from local changes for syncing back to GitLab server:
# 1. Check local change status
# 2. Create bundles containing local changes
# 3. Generate change records
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
        MAIN_REPO_NAME=$(jq -r '.global.bundle.main_repo_name // "slam-core"' "$CONFIG_FILE" 2>/dev/null)
    else
        echo ">>> jq not installed, using default config"
        ROOT="$DEFAULT_ROOT"
        OUTPUT_DIR="$DEFAULT_OUTPUT"
        INCLUDE_ALL=false
        CREATE_DIFF=true
        MAIN_REPO_NAME="slam-core"
    fi
else
    echo ">>> Config file not found, using default config"
    ROOT="$DEFAULT_ROOT"
    OUTPUT_DIR="$DEFAULT_OUTPUT"
    INCLUDE_ALL=false
    CREATE_DIFF=true
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

# 2) Get current timestamp for change records
timestamp=$(date '+%Y-%m-%d %H:%M:%S')

# 2.1) Get submodule paths (used in multiple places)
cd "$ROOT"
sub_paths=$(git submodule status --recursive | sed -n 's/^[[:space:]]*[a-f0-9]*[[:space:]]\+\([^[:space:]]\+\)[[:space:]]\+.*$/\1/p')
cd - > /dev/null

# Debug: Print submodule paths
echo ">>> Debug: Found submodule paths:"
if [[ -n "$sub_paths" ]]; then
    echo "$sub_paths" | while read -r path; do
        echo "  - $path"
    done
else
    echo "  No submodules found"
fi
echo ""

# 2.5) Check for existing bundles and ask for confirmation to delete
echo ">>> Checking for existing bundles..."
existing_bundles=()

# Check main repo bundle
main_bundle="$OUTPUT_DIR/${MAIN_REPO_NAME}.bundle"
if [[ -f "$main_bundle" ]]; then
    existing_bundles+=("$main_bundle")
fi

# Check submodule bundles
for path in $sub_paths; do
    bundle_name=$(echo "$path" | tr '/' '_').bundle
    sub_bundle="$OUTPUT_DIR/$bundle_name"
    if [[ -f "$sub_bundle" ]]; then
        existing_bundles+=("$sub_bundle")
    fi
done

# Check for info and diff report files
info_file="$OUTPUT_DIR/local_info.json"
if [[ -f "$info_file" ]]; then
    existing_bundles+=("$info_file")
fi

if [[ "$CREATE_DIFF" == "true" ]]; then
    diff_report="$OUTPUT_DIR/${MAIN_REPO_NAME}_diff_report.txt"
    if [[ -f "$diff_report" ]]; then
        existing_bundles+=("$diff_report")
    fi
fi

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
    if [[ -d "$OUTPUT_DIR" ]]; then
        while IFS= read -r -d '' file; do
            filename=$(basename "$file")
            if [[ "$filename" =~ \.bundle$ ]] || \
               [[ "$filename" =~ \.json$ ]] || \
               [[ "$filename" =~ _diff_report\.txt$ ]]; then
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
main_bundle="$OUTPUT_DIR/${MAIN_REPO_NAME}.bundle"

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
    bundle_name=$(echo "$path" | tr '/' '_').bundle
    sub_bundle="$OUTPUT_DIR/$bundle_name"
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
    diff_report="$OUTPUT_DIR/${MAIN_REPO_NAME}_diff_report.txt"
    
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

# 6) Create sync info file with change records
# Prepare sub_bundles array
sub_bundles_json=""
if [[ -n "$sub_paths" ]]; then
    sub_bundles_json="["
    first=true
    for path in $sub_paths; do
        bundle_name=$(echo "$path" | tr '/' '_').bundle
        if [[ "$first" == "true" ]]; then
            first=false
            sub_bundles_json="${sub_bundles_json}
    \"$bundle_name\""
        else
            sub_bundles_json="${sub_bundles_json},
    \"$bundle_name\""
        fi
    done
    sub_bundles_json="${sub_bundles_json}
  ]"
else
    sub_bundles_json="[]"
fi

# Prepare submodules change records
submodules_json=""
if [[ -n "$sub_paths" ]]; then
    submodules_json="{"
    first=true
    for path in $sub_paths; do
        sub_repo="$ROOT/$path"
        if [[ -d "$sub_repo" ]]; then
            sub_branch=$(cd "$sub_repo" && git branch --show-current 2>/dev/null || echo "unknown")
            sub_commit_count=$(cd "$sub_repo" && git rev-list --count last-sync..HEAD 2>/dev/null || echo "0")
            sub_files_changed=$(cd "$sub_repo" && git diff --name-only last-sync..HEAD 2>/dev/null | wc -l | tr -d ' ')
            
            if [[ "$first" == "true" ]]; then
                first=false
                submodules_json="${submodules_json}
      \"$path\": {
        \"branch\": \"$sub_branch\",
        \"commit_count\": \"$sub_commit_count\",
        \"files_changed\": \"$sub_files_changed\"
      }"
            else
                submodules_json="${submodules_json},
      \"$path\": {
        \"branch\": \"$sub_branch\",
        \"commit_count\": \"$sub_commit_count\",
        \"files_changed\": \"$sub_files_changed\"
      }"
            fi
        fi
    done
    submodules_json="${submodules_json}
    }"
else
    submodules_json="{}"
fi

sync_info=$(cat << EOF
{
  "timestamp": "$timestamp",
  "main_bundle": "${MAIN_REPO_NAME}.bundle",
  "sub_bundles": $sub_bundles_json,
  "created_at": "$timestamp",
  "git_status": "$(git status --porcelain | tr '\n' ' ' | sed 's/"/\\"/g')",
  "change_records": {
    "main_repo": {
      "branch": "$(git branch --show-current)",
      "commit_count": "$(git rev-list --count last-sync..HEAD 2>/dev/null || echo '0')",
      "files_changed": "$(git diff --name-only last-sync..HEAD 2>/dev/null | wc -l | tr -d ' ')"
    },
    "submodules": $submodules_json
  },
  "config_used": {
    "repo_dir": "$ROOT",
    "output_dir": "$OUTPUT_DIR",
    "include_all": $INCLUDE_ALL,
    "create_diff": $CREATE_DIFF
  }
}
EOF
)

echo -e "$sync_info" > "$OUTPUT_DIR/local_info.json"

# 7) Show results
echo ""
echo "SUCCESS: Bundle creation completed!"
echo "Output directory: $OUTPUT_DIR"
echo "Main repo bundle: ${MAIN_REPO_NAME}.bundle"
echo "Submodule bundle count: $(echo "$sub_paths" | wc -w)"

if [[ "$CREATE_DIFF" == "true" ]]; then
    echo "Diff report: ${MAIN_REPO_NAME}_diff_report.txt"
fi

echo ""
echo "Change Summary:"
if command -v jq &> /dev/null; then
    echo "Main repo: $(jq -r '.change_records.main_repo.branch' "$OUTPUT_DIR/local_info.json") branch, $(jq -r '.change_records.main_repo.commit_count' "$OUTPUT_DIR/local_info.json") commits, $(jq -r '.change_records.main_repo.files_changed' "$OUTPUT_DIR/local_info.json") files changed"
    
    echo "Submodules:"
    jq -r '.change_records.submodules | to_entries[] | "  \(.key): \(.value.branch) branch, \(.value.commit_count) commits, \(.value.files_changed) files changed"' "$OUTPUT_DIR/local_info.json"
else
    echo "Main repo: $(git branch --show-current) branch"
    echo "Submodules:"
    for path in $sub_paths; do
        sub_repo="$ROOT/$path"
        if [[ -d "$sub_repo" ]]; then
            sub_branch=$(cd "$sub_repo" && git branch --show-current 2>/dev/null || echo "unknown")
            echo "  $path: $sub_branch branch"
        fi
    done
fi

echo ""
echo "Next steps:"
echo "1. Copy files from $OUTPUT_DIR to GitLab server"
echo "2. Use import_local_bundles.sh on GitLab server to import changes"
