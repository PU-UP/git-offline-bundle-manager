#!/bin/bash

# config.example.sh - Git离线包管理器配置示例文件
# 复制此文件为 config.sh 并根据需要修改配置

# 默认配置
DEFAULT_SOURCE_REPO="test/slam-core"      # 源仓库路径
DEFAULT_BUNDLES_DIR="test/bundles"        # bundles输出目录
DEFAULT_RESTORE_DIR="test/restored_repo"  # 恢复目录
DEFAULT_MAIN_REPO_NAME="slam-core"        # 主仓库名称

# 示例：自定义配置
# DEFAULT_SOURCE_REPO="/path/to/your/repo"     # 自定义源仓库路径
# DEFAULT_BUNDLES_DIR="/path/to/bundles"       # 自定义bundles输出目录
# DEFAULT_RESTORE_DIR="/path/to/restore"       # 自定义恢复目录
# DEFAULT_MAIN_REPO_NAME="your-repo-name"      # 自定义主仓库名称

# 允许通过环境变量覆盖默认配置
export SOURCE_REPO="${SOURCE_REPO:-$DEFAULT_SOURCE_REPO}"
export BUNDLES_DIR="${BUNDLES_DIR:-$DEFAULT_BUNDLES_DIR}"
export RESTORE_DIR="${RESTORE_DIR:-$DEFAULT_RESTORE_DIR}"
export MAIN_REPO_NAME="${MAIN_REPO_NAME:-$DEFAULT_MAIN_REPO_NAME}"

# 验证配置
validate_config() {
    local errors=0
    
    # 检查源仓库路径
    if [ ! -d "$SOURCE_REPO" ]; then
        echo "[ERROR] 源仓库路径不存在: $SOURCE_REPO"
        errors=$((errors + 1))
    fi
    
    # 检查bundles目录是否可写
    if [ ! -w "$(dirname "$BUNDLES_DIR")" ] && [ ! -w "$BUNDLES_DIR" ]; then
        echo "[ERROR] bundles目录不可写: $BUNDLES_DIR"
        errors=$((errors + 1))
    fi
    
    # 检查恢复目录是否可写
    if [ ! -w "$(dirname "$RESTORE_DIR")" ] && [ ! -w "$RESTORE_DIR" ]; then
        echo "[ERROR] 恢复目录不可写: $RESTORE_DIR"
        errors=$((errors + 1))
    fi
    
    if [ $errors -gt 0 ]; then
        echo "[ERROR] 配置验证失败，请检查上述错误"
        return 1
    fi
    
    return 0
}

# 显示当前配置
show_config() {
    echo "=== Git离线包管理器配置 ==="
    echo "源仓库路径: $SOURCE_REPO"
    echo "Bundles目录: $BUNDLES_DIR"
    echo "恢复目录: $RESTORE_DIR"
    echo "主仓库名称: $MAIN_REPO_NAME"
    echo "=========================="
}

# 如果直接运行此脚本，显示配置
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_config
fi 