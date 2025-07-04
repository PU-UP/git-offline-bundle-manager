#!/bin/bash

# config_root.sh - ROOT环境配置文件
# 简化版本，只包含最必要的配置项
#
# 重要说明：
# 1. 此工具从本地Git仓库创建离线包，不是从远程仓库拉取
# 2. 必须配置 LOCAL_REPO_PATH 指向您的本地Git仓库
# 3. 确保指定的路径是一个有效的Git仓库（包含 .git 目录）
#
# 使用步骤：
# 1. 设置 LOCAL_REPO_PATH 为您的本地仓库路径
# 2. 根据需要调整其他配置
# 3. 运行 ./make_offline_package.sh 创建离线包

# =============================================================================
# 基础配置（必需）
# =============================================================================

# 项目名称
PROJECT_NAME="slam-core"

# 默认分支名称
DEFAULT_BRANCH="main"

# 默认子模块提交深度（控制离线包大小）
DEFAULT_DEPTH=10

# 源仓库地址（用于创建离线包时验证）
# 格式: https://github.com/username/repo.git 或 git@github.com:username/repo.git
# 注意: 此工具从本地仓库创建离线包，此配置主要用于验证
SOURCE_REPO_URL=""

# 远程仓库名称（通常是origin）
REMOTE_NAME="origin"

# 本地仓库路径（相对于当前目录或绝对路径）
# 如果为空，假设当前目录就是仓库根目录
# 示例: "/path/to/your/repo" 或 "../my-project"
LOCAL_REPO_PATH=""

# =============================================================================
# Git配置
# =============================================================================

# Git版本要求
MIN_GIT_VERSION="2.25.0"

# =============================================================================
# 打包配置
# =============================================================================

# 压缩格式 (tar.gz, tar.bz2, tar.xz)
COMPRESSION_FORMAT="tar.gz"

# 是否在打包后清理临时文件
CLEANUP_TEMP_FILES=true

# =============================================================================
# 导入配置
# =============================================================================

# 是否在导入前备份当前分支
BACKUP_BEFORE_IMPORT=true

# 合并策略 (recursive, octopus, subtree, ours, theirs)
MERGE_STRATEGY="recursive"

# =============================================================================
# 日志配置
# =============================================================================

# 是否生成详细日志
VERBOSE_LOGGING=true

# 日志文件位置
LOG_FILE="offline_package.log"

# =============================================================================
# 验证配置
# =============================================================================

# 验证函数：检查配置的有效性
validate_config() {
    local errors=0
    
    # 检查必需配置
    if [ -z "$PROJECT_NAME" ]; then
        echo "错误: PROJECT_NAME 不能为空"
        ((errors++))
    fi
    
    if [ -z "$DEFAULT_BRANCH" ]; then
        echo "错误: DEFAULT_BRANCH 不能为空"
        ((errors++))
    fi
    
    if [ "$DEFAULT_DEPTH" -lt 1 ]; then
        echo "错误: DEFAULT_DEPTH 必须大于0"
        ((errors++))
    fi
    
    # 检查Git版本
    local current_version=$(git --version | awk '{print $3}')
    if ! version_compare "$current_version" "$MIN_GIT_VERSION"; then
        echo "错误: Git版本过低，需要 $MIN_GIT_VERSION 或更高版本"
        ((errors++))
    fi
    
    # 检查压缩格式
    case "$COMPRESSION_FORMAT" in
        "tar.gz"|"tar.bz2"|"tar.xz")
            ;;
        *)
            echo "错误: 不支持的压缩格式: $COMPRESSION_FORMAT"
            ((errors++))
            ;;
    esac
    
    if [ $errors -gt 0 ]; then
        echo "配置验证失败，发现 $errors 个错误"
        return 1
    fi
    
    echo "配置验证通过"
    return 0
}

# 版本比较函数
version_compare() {
    local version1=$1
    local version2=$2
    
    IFS='.' read -ra v1 <<< "$version1"
    IFS='.' read -ra v2 <<< "$version2"
    
    for i in "${!v1[@]}"; do
        if [ "${v1[$i]}" -gt "${v2[$i]}" ]; then
            return 0
        elif [ "${v1[$i]}" -lt "${v2[$i]}" ]; then
            return 1
        fi
    done
    
    return 0
}

# 导出配置到环境变量
export_config() {
    export PROJECT_NAME
    export DEFAULT_BRANCH
    export DEFAULT_DEPTH
    export MIN_GIT_VERSION
    export COMPRESSION_FORMAT
    export CLEANUP_TEMP_FILES
    export BACKUP_BEFORE_IMPORT
    export MERGE_STRATEGY
    export VERBOSE_LOGGING
    export LOG_FILE
    export SOURCE_REPO_URL
    export REMOTE_NAME
    export LOCAL_REPO_PATH
}

# 如果直接执行此脚本，则验证配置
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "验证ROOT环境配置..."
    validate_config
fi 