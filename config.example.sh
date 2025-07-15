#!/bin/bash

# config.example.sh - Git离线包管理器配置示例文件
# 复制此文件为 config.sh 并根据需要修改配置

# 默认配置
DEFAULT_SOURCE_REPO="tmp/slam-core"      # 源仓库路径
DEFAULT_BUNDLES_DIR="tmp/bundles"        # bundles输出目录
DEFAULT_RESTORE_DIR="tmp/restored_repo"  # 恢复目录
DEFAULT_MAIN_REPO_NAME="slam-core"        # 主仓库名称

# 新增配置参数
DEFAULT_TARGET_BRANCH="release_2.3.7"              # 目标分支（用于切换）
DEFAULT_RENAME_BRANCH="your_custom_branch"     # 重命名分支（用于打包）
DEFAULT_FULL_CODE="false"                 # 是否打包完整代码（true/false）
DEFAULT_COMPRESS_BUNDLES="true"          # 是否将bundles压缩成zip（true/false）
DEFAULT_ZIP_FILENAME=""                  # 自定义zip文件名（为空时使用默认命名：bundles-YYYYMMDD_HHMMSS.zip）
DEFAULT_LIMIT_COMMITS=""                 # 限制每个仓库的提交数量（空表示不限制，数字表示保留最近n个提交）

# 示例：自定义配置
# DEFAULT_SOURCE_REPO="/path/to/your/repo"     # 自定义源仓库路径
# DEFAULT_BUNDLES_DIR="/path/to/bundles"       # 自定义bundles输出目录
# DEFAULT_RESTORE_DIR="/path/to/restore"       # 自定义恢复目录
# DEFAULT_MAIN_REPO_NAME="your-repo-name"      # 自定义主仓库名称
# DEFAULT_TARGET_BRANCH="develop"              # 自定义目标分支
# DEFAULT_RENAME_BRANCH="release-v1.0"         # 自定义重命名分支
# DEFAULT_FULL_CODE="true"                     # 自定义是否打包完整代码
# DEFAULT_COMPRESS_BUNDLES="true"              # 自定义是否压缩bundles
# DEFAULT_ZIP_FILENAME="my-custom-bundle"      # 自定义zip文件名（不包含.zip扩展名）
# DEFAULT_LIMIT_COMMITS="50"                   # 自定义限制提交数量（每个仓库保留最近50个提交）

# 允许通过环境变量覆盖默认配置
export SOURCE_REPO="${SOURCE_REPO:-$DEFAULT_SOURCE_REPO}"
export BUNDLES_DIR="${BUNDLES_DIR:-$DEFAULT_BUNDLES_DIR}"
export RESTORE_DIR="${RESTORE_DIR:-$DEFAULT_RESTORE_DIR}"
export MAIN_REPO_NAME="${MAIN_REPO_NAME:-$DEFAULT_MAIN_REPO_NAME}"
export TARGET_BRANCH="${TARGET_BRANCH:-$DEFAULT_TARGET_BRANCH}"
export RENAME_BRANCH="${RENAME_BRANCH:-$DEFAULT_RENAME_BRANCH}"
export FULL_CODE="${FULL_CODE:-$DEFAULT_FULL_CODE}"
export COMPRESS_BUNDLES="${COMPRESS_BUNDLES:-$DEFAULT_COMPRESS_BUNDLES}"
export ZIP_FILENAME="${ZIP_FILENAME:-$DEFAULT_ZIP_FILENAME}"
export LIMIT_COMMITS="${LIMIT_COMMITS:-$DEFAULT_LIMIT_COMMITS}"

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
    
    # 验证分支名称
    if [[ ! "$TARGET_BRANCH" =~ ^[a-zA-Z0-9\/\-_\.]+$ ]]; then
        echo "[ERROR] 目标分支名称无效: $TARGET_BRANCH"
        errors=$((errors + 1))
    fi
    
    if [[ ! "$RENAME_BRANCH" =~ ^[a-zA-Z0-9\/\-_\.]+$ ]]; then
        echo "[ERROR] 重命名分支名称无效: $RENAME_BRANCH"
        errors=$((errors + 1))
    fi
    
    # 验证FULL_CODE参数
    if [[ "$FULL_CODE" != "true" && "$FULL_CODE" != "false" ]]; then
        echo "[ERROR] FULL_CODE参数必须是 'true' 或 'false': $FULL_CODE"
        errors=$((errors + 1))
    fi
    
    # 验证COMPRESS_BUNDLES参数
    if [[ "$COMPRESS_BUNDLES" != "true" && "$COMPRESS_BUNDLES" != "false" ]]; then
        echo "[ERROR] COMPRESS_BUNDLES参数必须是 'true' 或 'false': $COMPRESS_BUNDLES"
        errors=$((errors + 1))
    fi
    
    # 验证ZIP_FILENAME参数（如果提供了自定义文件名）
    if [ -n "$ZIP_FILENAME" ]; then
        # 检查文件名是否包含非法字符
        if [[ "$ZIP_FILENAME" =~ [/\\\\:*?\"\<\>\|] ]]; then
            echo "[ERROR] ZIP_FILENAME包含非法字符: $ZIP_FILENAME"
            errors=$((errors + 1))
        fi
        
        # 检查文件名长度
        if [ ${#ZIP_FILENAME} -gt 100 ]; then
            echo "[ERROR] ZIP_FILENAME过长（超过100字符）: $ZIP_FILENAME"
            errors=$((errors + 1))
        fi
    fi
    
    # 验证LIMIT_COMMITS参数（如果提供了限制数量）
    if [ -n "$LIMIT_COMMITS" ]; then
        # 检查是否为正整数
        if ! [[ "$LIMIT_COMMITS" =~ ^[1-9][0-9]*$ ]]; then
            echo "[ERROR] LIMIT_COMMITS必须是正整数: $LIMIT_COMMITS"
            errors=$((errors + 1))
        fi
        
        # 检查范围合理性
        if [ "$LIMIT_COMMITS" -lt 1 ] || [ "$LIMIT_COMMITS" -gt 10000 ]; then
            echo "[ERROR] LIMIT_COMMITS范围应在1-10000之间: $LIMIT_COMMITS"
            errors=$((errors + 1))
        fi
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
    echo "目标分支: $TARGET_BRANCH"
    echo "重命名分支: $RENAME_BRANCH"
    echo "打包完整代码: $FULL_CODE"
    echo "压缩bundles: $COMPRESS_BUNDLES"
    if [ -n "$ZIP_FILENAME" ]; then
        echo "自定义zip文件名: $ZIP_FILENAME.zip"
    else
        echo "zip文件名: 自动生成（bundles-YYYYMMDD_HHMMSS.zip）"
    fi
    if [ -n "$LIMIT_COMMITS" ]; then
        echo "限制提交数量: $LIMIT_COMMITS 个（每个仓库保留最近提交）"
    else
        echo "限制提交数量: 不限制（包含完整历史）"
    fi
    echo "=========================="
}

# 如果直接运行此脚本，显示配置
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 先验证配置
    if validate_config; then
        show_config
    else
        exit 1
    fi
fi 