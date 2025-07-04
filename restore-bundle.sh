#!/bin/bash

# restore-bundle.sh - 将bundles恢复成代码

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
    
    # 只检查 BUNDLES_DIR 和 RESTORE_DIR，不再调用 validate_config
    if [ ! -d "$BUNDLES_DIR" ]; then
        print_error "$BUNDLES_DIR 目录不存在"
        exit 1
    fi
    
    # 检查是否有bundle文件
    local bundle_count=$(find "$BUNDLES_DIR" -name "*.bundle" 2>/dev/null | wc -l)
    if [ "$bundle_count" -eq 0 ]; then
        print_error "$BUNDLES_DIR 目录中没有找到.bundle文件"
        exit 1
    fi
    
    # 创建恢复目录
    if [ ! -d "$RESTORE_DIR" ]; then
        print_info "创建 $RESTORE_DIR 目录"
        mkdir -p "$RESTORE_DIR"
    else
        print_warning "$RESTORE_DIR 目录已存在，将清空内容"
        echo -e "${YELLOW}你确定要清空 $RESTORE_DIR 吗？此操作不可恢复。输入 yes 继续，否则退出：${NC}"
        read -r confirm
        if [ "$confirm" != "yes" ]; then
            print_error "用户取消操作，退出。"
            exit 1
        fi
        rm -rf "$RESTORE_DIR"/*
    fi
    
    print_success "目录结构检查完成"
}

# 恢复bundle
restore_bundle() {
    local bundle_file="$1"
    local restore_dir="$2"
    local bundle_name=$(basename "$bundle_file" .bundle)
    
    print_info "恢复bundle: $bundle_name"
    
    # 检查是否为Git bundle
    if [ -f "$bundle_file" ]; then
        print_info "  检测到Git bundle，使用git clone恢复..."
        # 如果目录已存在，先彻底删除
        if [ -d "$restore_dir" ]; then
            rm -rf "$restore_dir"
        fi
        git clone "$bundle_file" "$restore_dir"
    else
        print_error "  没有找到Git bundle: $bundle_file"
    fi
    print_success "Bundle恢复完成: $restore_dir"
}

# 恢复子模块
restore_submodules() {
    local base_repo="$1"
    local bundles_dir="$2"
    
    if [ ! -f "$base_repo/.gitmodules" ]; then
        print_info "没有找到.gitmodules文件，跳过子模块恢复"
        return
    fi
    
    print_info "恢复子模块..."
    
    local submodule_path=""
    local submodule_name=""
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*path[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            submodule_path=$(echo "${BASH_REMATCH[1]}" | xargs)
            # 路径转为bundle名：将/和-都替换为_
            submodule_bundle_name=$(echo "$submodule_path" | sed 's#[/-]#_#g')
            local bundle_file="$bundles_dir/$MAIN_REPO_NAME-$submodule_bundle_name.bundle"
            local submodule_dir="$base_repo/$submodule_path"
            if [ -f "$bundle_file" ]; then
                print_info "恢复子模块: $submodule_path"
                restore_bundle "$bundle_file" "$submodule_dir"
            else
                print_warning "子模块bundle文件不存在: $bundle_file"
            fi
        fi
    done < "$base_repo/.gitmodules"
}

# 主函数
main() {
    print_info "开始恢复bundles..."
    
    check_requirements
    check_directories
    
    local bundles_dir="$BUNDLES_DIR"
    local restore_base_dir="$RESTORE_DIR"
    local main_repo_dir="$restore_base_dir/$MAIN_REPO_NAME"
    
    # 恢复主仓库
    local main_bundle="$bundles_dir/$MAIN_REPO_NAME.bundle"
    if [ -f "$main_bundle" ]; then
        print_info "恢复主仓库..."
        restore_bundle "$main_bundle" "$main_repo_dir"
        
        # 恢复子模块
        restore_submodules "$main_repo_dir" "$bundles_dir"
        
        print_success "所有bundles恢复完成！"
        print_info "恢复位置: $main_repo_dir"
        
        # 显示当前配置
        echo ""
        show_config
        
        # 显示恢复的仓库信息
        echo ""
        print_info "恢复的仓库信息:"
        if [ -d "$main_repo_dir/.git" ]; then
            cd "$main_repo_dir"
            echo "  当前分支: $(git branch --show-current)"
            echo "  远程仓库: $(git remote get-url origin 2>/dev/null || echo '无远程仓库')"
            echo "  提交哈希: $(git rev-parse HEAD)"
            cd - > /dev/null
        fi
        
        # 显示子模块信息
        if [ -f "$main_repo_dir/.gitmodules" ]; then
            echo ""
            print_info "子模块信息:"
            cd "$main_repo_dir"
            git submodule status 2>/dev/null || echo "  无子模块信息"
            cd - > /dev/null
        fi
        
    else
        print_error "主仓库bundle文件不存在: $main_bundle"
        exit 1
    fi
}

# 运行主函数
main "$@" 