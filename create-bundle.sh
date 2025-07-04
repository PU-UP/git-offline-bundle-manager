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
    fi
    
    print_success "目录结构检查完成"
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
        
        # 创建bundle（用绝对路径）
        # 直接使用 --all 参数包含所有分支和标签，避免分支名解析问题
        git bundle create "$abs_bundle_path" --all
        
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