#!/bin/bash

# config_root_example.sh - ROOT环境配置示例文件
# 复制此文件为 config_root.sh 并根据您的环境修改路径

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
SOURCE_REPO_URL=""

# 远程仓库名称（通常是origin）
REMOTE_NAME="origin"

# =============================================================================
# 路径配置（必需）- 请根据您的环境修改这些路径
# =============================================================================

# 1. slam-core所在位置（源仓库路径）
# 示例: "/home/user/projects/slam-core" 或 "/opt/slam-core"
SLAM_CORE_PATH="/path/to/your/slam-core"

# 2. 把package生成到某个路径（输出目录）
# 示例: "/home/user/packages" 或 "/opt/packages"
PACKAGE_OUTPUT_PATH="/path/to/your/packages"

# 3. 从哪里import_from_local（导入来源路径）
# 示例: "/home/user/imports" 或 "/opt/imports"
IMPORT_SOURCE_PATH="/path/to/your/imports"

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
    
    # 检查路径配置
    if [ -z "$SLAM_CORE_PATH" ]; then
        echo "错误: SLAM_CORE_PATH 不能为空"
        ((errors++))
    fi
    
    if [ -z "$PACKAGE_OUTPUT_PATH" ]; then
        echo "错误: PACKAGE_OUTPUT_PATH 不能为空"
        ((errors++))
    fi
    
    if [ -z "$IMPORT_SOURCE_PATH" ]; then
        echo "错误: IMPORT_SOURCE_PATH 不能为空"
        ((errors++))
    fi
    
    # 检查路径是否存在
    if [ ! -d "$SLAM_CORE_PATH" ]; then
        echo "错误: SLAM_CORE_PATH 不存在: $SLAM_CORE_PATH"
        ((errors++))
    fi
    
    if [ ! -d "$PACKAGE_OUTPUT_PATH" ]; then
        echo "错误: PACKAGE_OUTPUT_PATH 不存在: $PACKAGE_OUTPUT_PATH"
        ((errors++))
    fi
    
    if [ ! -d "$IMPORT_SOURCE_PATH" ]; then
        echo "错误: IMPORT_SOURCE_PATH 不存在: $IMPORT_SOURCE_PATH"
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
    export SLAM_CORE_PATH
    export PACKAGE_OUTPUT_PATH
    export IMPORT_SOURCE_PATH
}

# 如果直接执行此脚本，则验证配置
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "验证ROOT环境配置..."
    validate_config
fi 