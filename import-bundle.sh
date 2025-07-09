#!/bin/bash

# Import-bundle.sh - 将bundles导入已存在的代码仓库

set -e  # 遇到错误时退出

# 加载配置文件（如果存在）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
fi

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

# 显示使用说明
show_usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -s, --source-repo PATH     目标导入的代码仓库路径"
    echo "  -b, --bundles-dir PATH     bundles位置"
    echo "  -r, --rename-branch NAME   优先在bundle中寻找的分支名"
    echo "  -h, --help                 显示此帮助信息"
    echo ""
    echo "环境变量:"
    echo "  SOURCE_REPO                目标导入的代码仓库路径"
    echo "  BUNDLES_DIR                bundles位置"
    echo "  RENAME_BRANCH              优先在bundle中寻找的分支名"
    echo ""
    echo "示例:"
    echo "  $0 -s /path/to/repo -b /path/to/bundles -r feature/test"
    echo "  SOURCE_REPO=/path/to/repo BUNDLES_DIR=/path/to/bundles RENAME_BRANCH=feature/test $0"
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--source-repo)
                SOURCE_REPO="$2"
                shift 2
                ;;
            -b|--bundles-dir)
                BUNDLES_DIR="$2"
                shift 2
                ;;
            -r|--rename-branch)
                RENAME_BRANCH="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# 检查必要的命令是否存在
check_requirements() {
    print_info "检查必要的命令..."
    
    if ! command -v git &> /dev/null; then
        print_error "git 命令未找到，请先安装git"
        exit 1
    fi
    
    print_success "所有必要的命令都已找到"
}

# 验证参数
validate_parameters() {
    print_info "验证参数..."
    
    # 检查SOURCE_REPO
    if [ -z "$SOURCE_REPO" ]; then
        print_error "SOURCE_REPO 参数未设置"
        show_usage
        exit 1
    fi
    
    if [ ! -d "$SOURCE_REPO" ]; then
        print_error "目标仓库路径不存在: $SOURCE_REPO"
        exit 1
    fi
    
    if [ ! -d "$SOURCE_REPO/.git" ]; then
        print_error "目标路径不是Git仓库: $SOURCE_REPO"
        exit 1
    fi
    
    # 检查BUNDLES_DIR
    if [ -z "$BUNDLES_DIR" ]; then
        print_error "BUNDLES_DIR 参数未设置"
        show_usage
        exit 1
    fi
    
    if [ ! -d "$BUNDLES_DIR" ]; then
        print_error "Bundles目录不存在: $BUNDLES_DIR"
        exit 1
    fi
    
    # 检查是否有bundle文件
    local bundle_count=$(find "$BUNDLES_DIR" -name "*.bundle" 2>/dev/null | wc -l)
    if [ "$bundle_count" -eq 0 ]; then
        print_error "$BUNDLES_DIR 目录中没有找到.bundle文件"
        exit 1
    fi
    
    # 检查RENAME_BRANCH
    if [ -z "$RENAME_BRANCH" ]; then
        print_warning "RENAME_BRANCH 参数未设置，将导入所有差异内容"
    fi
    
    print_success "参数验证完成"
}

# 获取仓库名称
get_repo_name() {
    local repo_path="$1"
    cd "$repo_path" 2>/dev/null || return 1
    local repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
    cd - > /dev/null 2>&1 || true
    echo "$repo_name"
}

# 导入bundle到仓库
import_bundle() {
    local bundle_file="$1"
    local target_repo="$2"
    local tmp_base="$3"
    local bundle_name=$(basename "$bundle_file" .bundle)
    
    print_info "导入bundle: $bundle_name"
    
    if [ ! -f "$bundle_file" ]; then
        print_error "Bundle文件不存在: $bundle_file"
        return 1
    fi
    
    # 创建临时目录来克隆bundle
    local temp_dir="$tmp_base/bundle_$bundle_name"
    mkdir -p "$temp_dir" 2>/dev/null || {
        print_error "无法创建临时目录: $temp_dir"
        return 1
    }
    print_info "  创建临时目录: $temp_dir"
    
    # 克隆bundle到临时目录
    print_info "  克隆bundle到临时目录..."
    if ! git clone "$bundle_file" "$temp_dir" >/dev/null 2>&1; then
        print_error "  克隆bundle失败: $bundle_file"
        rm -rf "$temp_dir" 2>/dev/null || true
        return 1
    fi
    
    cd "$temp_dir" 2>/dev/null || {
        print_error "无法进入临时目录: $temp_dir"
        return 1
    }
    
    # 获取bundle中的所有分支
    local bundle_branches=$(git branch -r 2>/dev/null | sed 's/^[[:space:]]*origin\///' 2>/dev/null || echo "")
    
    print_info "  Bundle中的分支:"
    echo "$bundle_branches" | sed 's/^/    /'
    
    # 检查是否包含指定的分支
    local target_branch_found=false
    if [ -n "$RENAME_BRANCH" ]; then
        if echo "$bundle_branches" | grep -q "^$RENAME_BRANCH$" 2>/dev/null; then
            print_info "  找到指定分支: $RENAME_BRANCH"
            target_branch_found=true
            # 从远程分支创建本地分支
            git checkout -b "$RENAME_BRANCH" "origin/$RENAME_BRANCH" >/dev/null 2>&1 || {
                print_warning "  无法创建分支: $RENAME_BRANCH"
                target_branch_found=false
            }
        else
            print_warning "  未找到指定分支: $RENAME_BRANCH"
        fi
    fi
    
    # 如果没有找到指定分支或没有指定分支，切换到第一个可用分支
    if [ "$target_branch_found" = false ]; then
        print_info "  切换到第一个可用分支..."
        local first_branch=$(echo "$bundle_branches" | head -1)
        if [ -n "$first_branch" ]; then
            git checkout -b "$first_branch" "origin/$first_branch" >/dev/null 2>&1 || {
                print_warning "  无法创建分支: $first_branch"
                return 1
            }
        fi
    fi
    
    # 获取当前分支的提交
    local current_bundle_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    print_info "  当前bundle分支: $current_bundle_branch"
    
    # 获取bundle中的所有提交（只获取前5个用于检查）
    local bundle_commits=$(git log --oneline --all 2>/dev/null | head -5 2>/dev/null || echo "")
    
    print_info "  Bundle中的提交 (前5个):"
    echo "$bundle_commits" | sed 's/^/    /'
    
    # 保存当前目录
    local current_bundle_dir=$(pwd)
    
    # 返回到目标仓库
    cd "$target_repo" 2>/dev/null || {
        print_error "无法返回到目标仓库: $target_repo"
        return 1
    }
    
    # 保存目标仓库的当前分支
    local current_branch=$(git branch --show-current 2>/dev/null || echo "master")
    
    # 添加临时目录作为远程仓库
    local remote_name="bundle_$(date +%s)"
    print_info "  添加临时目录作为远程仓库: $remote_name"
    git remote add "$remote_name" "$temp_dir" >/dev/null 2>&1 || {
        print_error "无法添加远程仓库"
        return 1
    }
    
    # 获取远程分支
    git fetch "$remote_name" >/dev/null 2>&1 || {
        print_warning "获取远程分支失败"
    }
    
    # 检查哪些提交不在当前仓库中
    local new_commits=()
    while IFS= read -r commit_line; do
        if [ -n "$commit_line" ]; then
            local commit_hash=$(echo "$commit_line" | cut -d' ' -f1)
            if ! git rev-parse --verify "$commit_hash" >/dev/null 2>&1; then
                new_commits+=("$commit_hash")
            fi
        fi
    done <<< "$bundle_commits"
    
    # 如果指定了分支且找到了，导入该分支的内容
    if [ "$target_branch_found" = true ]; then
        print_info "  导入指定分支: $RENAME_BRANCH"
        
        # 检查目标仓库是否已经有这个分支
        if git show-ref --verify --quiet "refs/heads/$RENAME_BRANCH" 2>/dev/null; then
            print_info "    目标仓库已有分支 $RENAME_BRANCH，切换到该分支"
            git checkout "$RENAME_BRANCH" >/dev/null 2>&1 || {
                print_warning "无法切换到分支: $RENAME_BRANCH"
            }
        else
            print_info "    在目标仓库创建分支 $RENAME_BRANCH"
            git checkout -b "$RENAME_BRANCH" "$remote_name/$RENAME_BRANCH" >/dev/null 2>&1 || {
                print_warning "无法创建分支: $RENAME_BRANCH"
            }
        fi
        
        print_info "    分支 $RENAME_BRANCH 已是最新状态"
        
        # 返回到原来的分支
        git checkout "$current_branch" >/dev/null 2>&1 || {
            print_warning "无法返回到原分支: $current_branch"
        }
        
    elif [ ${#new_commits[@]} -gt 0 ]; then
        print_info "  导入所有新提交..."
        for commit in "${new_commits[@]}"; do
            print_info "    导入提交: $commit"
            git cherry-pick "$commit" >/dev/null 2>&1 || {
                print_warning "    提交 $commit 导入失败，可能存在冲突"
                git cherry-pick --abort >/dev/null 2>&1 || true
            }
        done
    else
        print_info "  没有发现新的提交"
    fi
    
    # 清理远程仓库
    git remote remove "$remote_name" >/dev/null 2>&1 || true
    
    # 返回到bundle临时目录并删除
    cd "$current_bundle_dir" 2>/dev/null || true
    # 确保不在要删除的目录中
    cd "$SCRIPT_ROOT" 2>/dev/null || true
    rm -rf "$temp_dir" 2>/dev/null || true
    
    print_success "Bundle导入完成: $bundle_name"
}

# 导入子模块bundle
import_submodules() {
    local target_repo="$1"
    local bundles_dir="$2"
    local repo_name="$3"
    local tmp_base="$4"
    
    if [ ! -f "$target_repo/.gitmodules" ]; then
        print_info "没有找到.gitmodules文件，跳过子模块导入"
        return
    fi
    
    print_info "导入子模块bundles..."
    
    # 保存当前目录
    local current_dir=$(pwd)
    cd "$target_repo" 2>/dev/null || return 1
    
    local submodule_path=""
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*path[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            submodule_path=$(echo "${BASH_REMATCH[1]}" | xargs)
            # 路径转为bundle名：将/和-都替换为_
            submodule_bundle_name=$(echo "$submodule_path" | sed 's#[/-]#_#g')
            local bundle_file="$bundles_dir/$repo_name-$submodule_bundle_name.bundle"
            local submodule_dir="$target_repo/$submodule_path"
            
            if [ -f "$bundle_file" ]; then
                print_info "导入子模块: $submodule_path"
                if [ -d "$submodule_dir" ]; then
                    # 子模块目录已存在，导入bundle
                    import_bundle "$bundle_file" "$submodule_dir" "$tmp_base"
                else
                    print_warning "子模块目录不存在: $submodule_dir"
                fi
            else
                print_warning "子模块bundle文件不存在: $bundle_file"
            fi
        fi
    done < "$target_repo/.gitmodules"
    
    # 返回到原始目录
    cd "$current_dir" 2>/dev/null || true
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

# 显示导入结果
show_import_result() {
    local target_repo="$1"
    
    print_success "导入完成！"
    echo ""
    print_info "目标仓库信息:"
    cd "$target_repo" 2>/dev/null || return 1
    echo "  路径: $(pwd)"
    echo "  当前分支: $(git branch --show-current 2>/dev/null || echo 'detached')"
    echo "  当前提交: $(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
    echo "  远程仓库: $(git remote get-url origin 2>/dev/null || echo '无远程仓库')"
    echo "  可用分支:"
    git branch -a 2>/dev/null | sed 's/^/    /' || echo "    无分支信息"
    
    # 显示最近的提交
    echo ""
    print_info "最近的提交:"
    git log --oneline -5 2>/dev/null | sed 's/^/  /' || echo "  无提交信息"
    
    # 显示子模块信息
    if [ -f ".gitmodules" ]; then
        echo ""
        print_info "子模块信息:"
        git submodule status 2>/dev/null | sed 's/^/  /' || echo "  无子模块信息"
    fi
    
    cd - > /dev/null 2>&1 || true
}

# 主函数
main() {
    print_info "开始导入bundles到目标仓库..."
    
    # 解析命令行参数
    parse_arguments "$@"
    
    check_requirements
    validate_parameters
    
    # 将BUNDLES_DIR和SOURCE_REPO转为绝对路径
    BUNDLES_DIR="$(cd "$BUNDLES_DIR" 2>/dev/null && pwd)" || {
        print_error "无法获取BUNDLES_DIR的绝对路径"
        exit 1
    }
    SOURCE_REPO="$(cd "$SOURCE_REPO" 2>/dev/null && pwd)" || {
        print_error "无法获取SOURCE_REPO的绝对路径"
        exit 1
    }
    SCRIPT_ROOT="$SCRIPT_DIR"
    
    # 创建临时目录（在脚本根目录下）
    TMP_BASE="$SCRIPT_ROOT/.import_tmp"
    mkdir -p "$TMP_BASE" 2>/dev/null || {
        print_error "无法创建临时目录: $TMP_BASE"
        exit 1
    }
    TMP_DIR="$TMP_BASE/$$-$(date +%s%N)"
    mkdir -p "$TMP_DIR" 2>/dev/null || {
        print_error "无法创建临时目录: $TMP_DIR"
        exit 1
    }
    # 退出时自动清理
    trap 'rm -rf "$TMP_DIR" 2>/dev/null || true' EXIT
    
    # 获取仓库名称
    local repo_name=$(get_repo_name "$SOURCE_REPO")
    print_info "目标仓库名称: $repo_name"
    
    # 读取bundle信息
    read_bundle_info "$BUNDLES_DIR"
    
    # 显示当前配置
    print_info "当前配置信息:"
    print_info "  目标仓库: $SOURCE_REPO"
    print_info "  Bundles目录: $BUNDLES_DIR"
    print_info "  优先分支: $RENAME_BRANCH"
    
    # 导入主仓库bundle
    local main_bundle="$BUNDLES_DIR/$repo_name.bundle"
    if [ -f "$main_bundle" ]; then
        print_info "导入主仓库bundle..."
        import_bundle "$main_bundle" "$SOURCE_REPO" "$TMP_DIR"
        
        # 导入子模块bundles
        import_submodules "$SOURCE_REPO" "$BUNDLES_DIR" "$repo_name" "$TMP_DIR"
        
        # 显示导入结果
        show_import_result "$SOURCE_REPO"
        
    else
        print_error "主仓库bundle文件不存在: $main_bundle"
        print_info "可用的bundle文件:"
        find "$BUNDLES_DIR" -name "*.bundle" -exec basename {} \; 2>/dev/null | sed 's/^/  /' || echo "  无bundle文件"
        exit 1
    fi
}

# 运行主函数
main "$@" 