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
    
    if ! command -v unzip &> /dev/null; then
        print_error "unzip 命令未找到，请先安装unzip"
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
    
    # 检查是否有bundle文件或zip文件
    local bundle_count=$(find "$BUNDLES_DIR" -name "*.bundle" 2>/dev/null | wc -l)
    local zip_count=$(find "$BUNDLES_DIR" -name "*.zip" 2>/dev/null | wc -l)
    
    if [ "$bundle_count" -eq 0 ] && [ "$zip_count" -eq 0 ]; then
        print_error "$BUNDLES_DIR 目录中没有找到.bundle文件或.zip文件"
        exit 1
    fi
    
    # 如果只有zip文件，询问是否解压
    if [ "$bundle_count" -eq 0 ] && [ "$zip_count" -gt 0 ]; then
        print_warning "在 $BUNDLES_DIR 目录中只找到 $zip_count 个zip文件，没有找到.bundle文件"
        echo -e "${YELLOW}是否要解压zip文件到 $BUNDLES_DIR 目录？输入 yes 解压，否则退出：${NC}"
        read -r confirm
        if [ "$confirm" = "yes" ]; then
            print_info "解压zip文件..."
            cd "$BUNDLES_DIR"
            for zip_file in *.zip; do
                if [ -f "$zip_file" ]; then
                    print_info "解压: $zip_file"
                    if unzip -o "$zip_file" >/dev/null 2>&1; then
                        print_success "解压完成: $zip_file"
                    else
                        print_error "解压失败: $zip_file"
                        exit 1
                    fi
                fi
            done
            cd - > /dev/null
            
            # 重新检查bundle文件
            bundle_count=$(find "$BUNDLES_DIR" -name "*.bundle" 2>/dev/null | wc -l)
            if [ "$bundle_count" -eq 0 ]; then
                print_error "解压后仍然没有找到.bundle文件"
                exit 1
            fi
            print_success "找到 $bundle_count 个bundle文件"
        else
            print_error "用户取消操作，退出。"
            exit 1
        fi
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
        
        # 检查恢复后的分支信息并自动切换到正确的分支
        cd "$restore_dir"
        
        # 获取所有分支
        local branches=$(git branch -a)
        print_info "  可用分支:"
        echo "$branches" | sed 's/^/    /'
        
        # 尝试切换到配置的重命名分支
        if git show-ref --verify --quiet "refs/heads/$RENAME_BRANCH" 2>/dev/null; then
            # 如果本地分支存在，直接切换
            print_info "  切换到本地分支: $RENAME_BRANCH"
            git checkout "$RENAME_BRANCH"
        elif git show-ref --verify --quiet "refs/remotes/origin/$RENAME_BRANCH" 2>/dev/null; then
            # 如果远程分支存在，创建本地分支并切换
            print_info "  从远程分支创建本地分支: $RENAME_BRANCH"
            git checkout -b "$RENAME_BRANCH" "origin/$RENAME_BRANCH"
        else
            # 如果重命名分支不存在，尝试切换到第一个可用的分支
            print_warning "  重命名分支 $RENAME_BRANCH 不存在，尝试切换到第一个可用分支"
            local first_branch=$(git branch -r | head -1 | sed 's/^[[:space:]]*origin\///')
            if [ -n "$first_branch" ]; then
                print_info "  切换到第一个可用分支: $first_branch"
                git checkout -b "$first_branch" "origin/$first_branch"
            else
                print_warning "  没有找到可用的分支"
            fi
        fi
        
        local available_branches=$(git branch -r | wc -l)
        local current_branch=$(git branch --show-current 2>/dev/null || echo "detached")
        print_info "  恢复完成，当前分支: $current_branch"
        print_info "  可用分支数量: $available_branches"
        cd - > /dev/null
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

# 读取bundle信息文件
read_bundle_info() {
    local bundles_dir="$1"
    local info_file="$bundles_dir/bundle-info.txt"
    
    if [ -f "$info_file" ]; then
        print_info "读取bundle信息文件..."
        echo ""
        echo "=== Bundle信息 ==="
        while IFS= read -r line; do
            if [[ $line =~ ^# ]]; then
                # 跳过注释行，但显示配置信息
                if [[ $line =~ "目标分支:" ]] || [[ $line =~ "重命名分支:" ]] || [[ $line =~ "打包完整代码:" ]]; then
                    echo "$line"
                fi
            fi
        done < "$info_file"
        echo "=================="
        echo ""
    else
        print_warning "没有找到bundle信息文件: $info_file"
    fi
}

# 主函数
main() {
    print_info "开始恢复bundles..."
    
    check_requirements
    check_directories
    
    local bundles_dir="$BUNDLES_DIR"
    local restore_base_dir="$RESTORE_DIR"
    local main_repo_dir="$restore_base_dir/$MAIN_REPO_NAME"
    
    # 读取bundle信息
    read_bundle_info "$bundles_dir"
    
    # 显示当前配置
    print_info "当前配置信息:"
    print_info "  目标分支: $TARGET_BRANCH"
    print_info "  重命名分支: $RENAME_BRANCH"
    print_info "  打包完整代码: $FULL_CODE"
    
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
            echo "  当前分支: $(git branch --show-current 2>/dev/null || echo 'detached')"
            echo "  远程仓库: $(git remote get-url origin 2>/dev/null || echo '无远程仓库')"
            echo "  提交哈希: $(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
            echo "  可用分支:"
            git branch -a 2>/dev/null | sed 's/^/    /' || echo "    无分支信息"
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