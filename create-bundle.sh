#!/bin/bash

# create-bundle.sh - 将slam-core仓库（包含子仓库）生成bundles

set -e  # 遇到错误时退出

# 加载配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要的命令是否存在
check_requirements() {
    print_info "检查必要的命令..."
    
    if ! command -v git &> /dev/null; then
        print_error "git 命令未找到，请先安装git"
        exit 1
    fi
    
    if ! command -v tar &> /dev/null; then
        print_error "tar 命令未找到，请先安装tar"
        exit 1
    fi
    
    print_success "所有必要的命令都已找到"
}

# 检查目录是否存在
check_directories() {
    print_info "检查目录结构..."
    
    # 验证配置
    if ! validate_config; then
        exit 1
    fi
    
    if [ ! -d "$SOURCE_REPO" ]; then
        print_error "$SOURCE_REPO 目录不存在"
        exit 1
    fi
    
    if [ ! -d "$BUNDLES_DIR" ]; then
        print_info "创建 $BUNDLES_DIR 目录"
        mkdir -p "$BUNDLES_DIR"
    else
        # 检查bundles目录是否非空
        local file_count=$(find "$BUNDLES_DIR" -maxdepth 1 -type f -name "*.bundle" 2>/dev/null | wc -l)
        if [ "$file_count" -gt 0 ]; then
            print_warning "$BUNDLES_DIR 目录已存在且包含 $file_count 个bundle文件"
            echo -e "${YELLOW}你确定要清空 $BUNDLES_DIR 吗？此操作不可恢复。输入 yes 继续，否则退出：${NC}"
            read -r confirm
            if [ "$confirm" != "yes" ]; then
                print_error "用户取消操作，退出。"
                exit 1
            fi
            print_info "清空 $BUNDLES_DIR 目录"
            rm -f "$BUNDLES_DIR"/*.bundle
            rm -f "$BUNDLES_DIR"/bundle-info.txt
        fi
    fi
    
    print_success "目录结构检查完成"
}

# 检查仓库是否有未提交的更改
check_repo_clean() {
    local repo_path="$1"
    local branch_name="$2"
    
    print_info "检查仓库 $repo_path 在分支 $branch_name 上的状态..."
    
    cd "$repo_path"
    
    # 确保在正确的分支上
    local current_branch=$(git branch --show-current 2>/dev/null || echo "detached")
    if [ "$current_branch" != "$branch_name" ]; then
        print_error "  当前不在目标分支 $branch_name 上，当前分支: $current_branch"
        cd - > /dev/null
        return 1
    fi
    
    # 检查是否有未提交的更改
    local status_output=$(git status --porcelain 2>/dev/null)
    if [ -n "$status_output" ]; then
        print_error "  目标分支 $branch_name 不纯净，发现未提交的更改："
        echo ""
        git status
        echo ""
        print_error "请先提交或暂存所有更改，然后重新运行脚本。"
        cd - > /dev/null
        return 1
    fi
    
    print_success "  目标分支 $branch_name 状态纯净，无未提交的更改"
    cd - > /dev/null
    return 0
}

# 切换仓库到指定分支
switch_repo_to_branch() {
    local repo_path="$1"
    local target_branch="$2"
    local rename_branch="$3"
    
    print_info "切换仓库 $repo_path 到分支 $target_branch"
    
    cd "$repo_path"
    
    # 检查当前状态
    local current_branch=$(git branch --show-current 2>/dev/null || echo "detached")
    print_info "  当前分支: $current_branch"
    
    # 如果是detached HEAD状态，先切换到目标分支
    if [ "$current_branch" = "detached" ]; then
        print_info "  检测到detached HEAD状态，切换到目标分支"
        git checkout "$target_branch" 2>/dev/null || {
            print_warning "  目标分支 $target_branch 不存在，创建新分支"
            git checkout -b "$target_branch"
        }
    elif [ "$current_branch" != "$target_branch" ]; then
        print_info "  从 $current_branch 切换到 $target_branch"
        git checkout "$target_branch" 2>/dev/null || {
            print_warning "  目标分支 $target_branch 不存在，创建新分支"
            git checkout -b "$target_branch"
        }
    fi
    
    cd - > /dev/null
}

# 切换到重命名分支
switch_to_rename_branch() {
    local repo_path="$1"
    local rename_branch="$2"
    
    print_info "切换到重命名分支 $rename_branch"
    
    cd "$repo_path"
    
    # 创建或切换到重命名分支
    print_info "  切换到重命名分支 $rename_branch"
    git checkout "$rename_branch" 2>/dev/null || {
        print_info "  重命名分支不存在，从当前分支创建"
        git checkout -b "$rename_branch"
    }
    
    cd - > /dev/null
}

# 切换所有子模块到重命名分支
switch_submodules_to_rename_branch() {
    local base_repo="$1"
    local rename_branch="$2"
    
    if [ ! -f "$base_repo/.gitmodules" ]; then
        print_info "没有找到.gitmodules文件，跳过子模块切换"
        return
    fi
    
    print_info "切换所有子模块到重命名分支..."
    
    cd "$base_repo"
    
    # 使用git submodule foreach让所有子模块基于当前状态创建重命名分支
    git submodule foreach "
        echo \"[INFO] 处理子模块: \$name\"
        current_branch=\$(git branch --show-current 2>/dev/null || echo 'detached')
        echo \"  当前分支: \$current_branch\"
        
        # 直接创建或切换到重命名分支（基于当前状态）
        echo \"  切换到重命名分支 $rename_branch\"
        git checkout \"$rename_branch\" 2>/dev/null || {
            echo \"  重命名分支不存在，从当前分支创建\"
            git checkout -b \"$rename_branch\"
        }
    "
    
    cd - > /dev/null
}

# 获取仓库信息
get_repo_info() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    if [ -d "$repo_path/.git" ] || [ -f "$repo_path/.git" ]; then
        local remote_url=$(cd "$repo_path" && git remote get-url origin 2>/dev/null || echo "no-remote")
        local current_branch=$(cd "$repo_path" && git branch --show-current 2>/dev/null || echo "unknown")
        local commit_hash=$(cd "$repo_path" && git rev-parse HEAD 2>/dev/null || echo "unknown")
        
        echo "$repo_name|$remote_url|$current_branch|$commit_hash"
    else
        echo "$repo_name|no-git|no-branch|no-commit"
    fi
}

# 创建bundle
create_bundle() {
    local repo_path="$1"
    local bundle_name="$2"
    local bundle_path="$BUNDLES_DIR/$bundle_name.bundle"
    local bundle_dir="$(cd "$(dirname "$bundle_path")" && pwd)"
    local abs_bundle_path="$bundle_dir/$bundle_name.bundle"
    
    print_info "创建bundle: $bundle_name.bundle"
    
    # 确保bundle目录存在
    mkdir -p "$bundle_dir"
    
    # 检查是否为Git仓库（包括子模块）
    if [ -d "$repo_path/.git" ] || [ -f "$repo_path/.git" ]; then
        print_info "  检测到Git仓库，创建Git bundle..."
        cd "$repo_path"
        
        # 根据FULL_CODE参数决定打包内容
        if [ "$FULL_CODE" = "true" ]; then
            print_info "  打包完整代码（所有分支）"
            git bundle create "$abs_bundle_path" --all
        else
            print_info "  仅打包当前分支 $RENAME_BRANCH"
            git bundle create "$abs_bundle_path" "$RENAME_BRANCH"
        fi
        
        cd - > /dev/null
    else
        print_warning "  目录 $repo_path 不是Git仓库，跳过。"
    fi
    
    print_success "Bundle创建完成: $abs_bundle_path"
}

# 主函数
main() {
    print_info "开始创建slam-core仓库的bundles..."
    
    check_requirements
    check_directories
    
    local base_repo="$SOURCE_REPO"
    local bundles_dir="$BUNDLES_DIR"
    
    print_info "配置信息:"
    print_info "  目标分支: $TARGET_BRANCH"
    print_info "  重命名分支: $RENAME_BRANCH"
    print_info "  打包完整代码: $FULL_CODE"
    
    # 记录原始状态
    cd "$base_repo"
    local original_branch=$(git branch --show-current 2>/dev/null || echo "detached")
    print_info "记录原始状态: $original_branch"
    cd - > /dev/null
    
    # 第一步：切换主仓库到目标分支并检查状态
    print_info "第一步：切换主仓库到目标分支 $TARGET_BRANCH"
    switch_repo_to_branch "$base_repo" "$TARGET_BRANCH" "$RENAME_BRANCH"
    
    # 检查目标分支状态（在目标分支上检查）
    print_info "检查目标分支 $TARGET_BRANCH 的状态..."
    if ! check_repo_clean "$base_repo" "$TARGET_BRANCH"; then
        print_error "目标分支 $TARGET_BRANCH 不纯净，终止生成Bundles。"
        exit 1
    fi
    
    # 切换到重命名分支
    switch_to_rename_branch "$base_repo" "$RENAME_BRANCH"
    
    # 第二步：让所有子模块基于当前状态创建重命名分支
    print_info "第二步：让所有子模块基于当前状态创建重命名分支 $RENAME_BRANCH"
    switch_submodules_to_rename_branch "$base_repo" "$RENAME_BRANCH"
    
    # 第四步：基于重命名分支创建bundle
    print_info "第四步：基于重命名分支创建bundles"
    
    # 创建主仓库的bundle
    create_bundle "$base_repo" "$MAIN_REPO_NAME"
    
    # 处理子模块
    if [ -f "$base_repo/.gitmodules" ]; then
        print_info "处理子模块..."
        
        # 读取.gitmodules文件并处理每个子模块
        while IFS= read -r line; do
            if [[ $line =~ ^\[submodule ]]; then
                # 提取子模块名称
                submodule_name=$(echo "$line" | sed 's/\[submodule "\([^"]*\)"\]/\1/')
                print_info "处理子模块: $submodule_name"
                
                # 查找子模块路径
                submodule_path=""
                while IFS= read -r subline; do
                    if [[ $subline =~ ^[[:space:]]*path[[:space:]]*=[[:space:]]*(.+)$ ]]; then
                        submodule_path="${BASH_REMATCH[1]}"
                        break
                    fi
                done
                
                if [ -n "$submodule_path" ] && [ -d "$base_repo/$submodule_path" ]; then
                    # 将子模块名称中的路径分隔符替换为下划线，避免路径问题
                    local safe_submodule_name=$(echo "$submodule_name" | sed 's/[\/\-]/_/g')
                    create_bundle "$base_repo/$submodule_path" "$MAIN_REPO_NAME-$safe_submodule_name"
                fi
            fi
        done < "$base_repo/.gitmodules"
    fi
    
    # 生成bundle信息文件
    print_info "生成bundle信息文件..."
    {
        echo "# Bundle信息文件"
        echo "# 生成时间: $(date)"
        echo "# 配置信息:"
        echo "#   目标分支: $TARGET_BRANCH"
        echo "#   重命名分支: $RENAME_BRANCH"
        echo "#   打包完整代码: $FULL_CODE"
        echo ""
        echo "# 主仓库信息:"
        get_repo_info "$base_repo"
        echo ""
        echo "# 子模块信息:"
        
        if [ -f "$base_repo/.gitmodules" ]; then
            while IFS= read -r line; do
                if [[ $line =~ ^\[submodule ]]; then
                    submodule_name=$(echo "$line" | sed 's/\[submodule "\([^"]*\)"\]/\1/')
                    submodule_path=""
                    while IFS= read -r subline; do
                        if [[ $subline =~ ^[[:space:]]*path[[:space:]]*=[[:space:]]*(.+)$ ]]; then
                            submodule_path="${BASH_REMATCH[1]}"
                            break
                        fi
                    done
                    
                    if [ -n "$submodule_path" ] && [ -d "$base_repo/$submodule_path" ]; then
                        get_repo_info "$base_repo/$submodule_path"
                    fi
                fi
            done < "$base_repo/.gitmodules"
        fi
    } > "$bundles_dir/bundle-info.txt"
    
    print_success "所有bundles创建完成！"
    print_info "Bundles位置: $bundles_dir"
    print_info "Bundle信息文件: $bundles_dir/bundle-info.txt"
    
    # 回到原始状态
    print_info "回到原始状态: $original_branch"
    cd "$base_repo"
    if [ "$original_branch" != "detached" ]; then
        # 尝试多种方式切换回原始分支
        if git checkout "$original_branch" 2>/dev/null; then
            print_success "成功回到原始分支: $original_branch"
        elif git switch "$original_branch" 2>/dev/null; then
            print_success "成功回到原始分支: $original_branch"
        else
            print_warning "无法回到原始分支 $original_branch，保持在当前分支"
            print_info "当前分支: $(git branch --show-current 2>/dev/null || echo 'unknown')"
        fi
    else
        print_info "原始状态为detached HEAD，保持当前状态"
    fi
    cd - > /dev/null
    
    # 显示当前配置
    echo ""
    show_config
    
    # 显示创建的bundles
    echo ""
    print_info "创建的bundles:"
    ls -la "$bundles_dir"/*.bundle 2>/dev/null || print_warning "没有找到.bundle文件"
}

# 运行主函数
main "$@" 