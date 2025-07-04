#!/bin/bash

# config_local.sh - LOCAL环境配置文件
# 简化版本，只包含最必要的配置项
#
# 重要说明：
# 1. 此配置文件用于本地开发环境
# 2. 必须配置三个路径：SLAM_CORE_PATH、PACKAGE_READ_PATH、EXPORT_OUTPUT_PATH
# 3. 确保指定的路径都是有效的
#
# 使用步骤：
# 1. 设置三个路径配置
# 2. 运行 ./init_repository.sh 初始化本地仓库
# 3. 开始离线开发

# =============================================================================
# 基础配置（必需）
# =============================================================================

# 项目名称（应与ROOT环境保持一致）
PROJECT_NAME="slam-core"

# 本地开发目录名称
LOCAL_DEV_DIR="slam-core"

# 子模块目录名称
SUBMODULES_DIR="submodules"

# 默认分支名称（应与ROOT环境保持一致）
DEFAULT_BRANCH="main"

# 远程仓库名称（通常是origin）
REMOTE_NAME="origin"

# =============================================================================
# 路径配置（必需）
# =============================================================================

# 1. slam-core所在位置（本地开发目录）
# 示例: "/path/to/slam-core" 或 "./slam-core"
SLAM_CORE_PATH=""

# 2. 从哪读取完整package（离线包路径）
# 示例: "/path/to/packages" 或 "./packages"
PACKAGE_READ_PATH=""

# 3. export changes到哪里（导出输出路径）
# 示例: "/path/to/exports" 或 "./exports"
EXPORT_OUTPUT_PATH=""

# =============================================================================
# Git配置
# =============================================================================

# Git版本要求
MIN_GIT_VERSION="2.25.0"

# 是否在导出前检查未提交的更改
CHECK_UNCOMMITTED_CHANGES=true

# =============================================================================
# 导出配置
# =============================================================================

# 是否验证bundle完整性
VERIFY_BUNDLE_INTEGRITY=true

# =============================================================================
# 日志配置
# =============================================================================

# 是否生成详细日志
VERBOSE_LOGGING=true

# 日志文件位置
LOG_FILE="local_development.log"

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
    
    if [ -z "$LOCAL_DEV_DIR" ]; then
        echo "错误: LOCAL_DEV_DIR 不能为空"
        ((errors++))
    fi
    
    if [ -z "$SUBMODULES_DIR" ]; then
        echo "错误: SUBMODULES_DIR 不能为空"
        ((errors++))
    fi
    
    if [ -z "$DEFAULT_BRANCH" ]; then
        echo "错误: DEFAULT_BRANCH 不能为空"
        ((errors++))
    fi
    
    # 检查路径配置
    if [ -z "$SLAM_CORE_PATH" ]; then
        echo "错误: SLAM_CORE_PATH 不能为空"
        ((errors++))
    fi
    
    if [ -z "$PACKAGE_READ_PATH" ]; then
        echo "错误: PACKAGE_READ_PATH 不能为空"
        ((errors++))
    fi
    
    if [ -z "$EXPORT_OUTPUT_PATH" ]; then
        echo "错误: EXPORT_OUTPUT_PATH 不能为空"
        ((errors++))
    fi
    
    # 检查路径是否存在
    if [ ! -d "$SLAM_CORE_PATH" ]; then
        echo "错误: SLAM_CORE_PATH 不存在: $SLAM_CORE_PATH"
        ((errors++))
    fi
    
    if [ ! -d "$PACKAGE_READ_PATH" ]; then
        echo "错误: PACKAGE_READ_PATH 不存在: $PACKAGE_READ_PATH"
        ((errors++))
    fi
    
    if [ ! -d "$EXPORT_OUTPUT_PATH" ]; then
        echo "错误: EXPORT_OUTPUT_PATH 不存在: $EXPORT_OUTPUT_PATH"
        ((errors++))
    fi
    
    # 检查Git版本
    local current_version=$(git --version | awk '{print $3}')
    if ! version_compare "$current_version" "$MIN_GIT_VERSION"; then
        echo "错误: Git版本过低，需要 $MIN_GIT_VERSION 或更高版本"
        ((errors++))
    fi
    
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
    export LOCAL_DEV_DIR
    export SUBMODULES_DIR
    export DEFAULT_BRANCH
    export REMOTE_NAME
    export MIN_GIT_VERSION
    export CHECK_UNCOMMITTED_CHANGES
    export VERIFY_BUNDLE_INTEGRITY
    export VERBOSE_LOGGING
    export LOG_FILE
    export SLAM_CORE_PATH
    export PACKAGE_READ_PATH
    export EXPORT_OUTPUT_PATH
}

# 如果直接执行此脚本，则验证配置
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "验证LOCAL环境配置..."
    validate_config
fi 