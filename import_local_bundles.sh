#!/usr/bin/env bash
set -euo pipefail

# 导入从Windows传来的本地修改bundle文件
# 用法: ./import_local_bundles.sh [bundle_prefix] [local_bundles_dir]

BUNDLE_PREFIX=${1:-""}
LOCAL_BUNDLES_DIR=${2:-"./local-bundles"}
ROOT=/work/develop_gitlab/slam-core

if [[ -z "$BUNDLE_PREFIX" ]]; then
    echo "❌ 请指定bundle前缀"
    echo "用法: $0 <bundle_prefix> [local_bundles_dir]"
    echo "示例: $0 local_20250101_120000"
    exit 1
fi

if [[ ! -d "$LOCAL_BUNDLES_DIR" ]]; then
    echo "❌ 本地bundles目录不存在: $LOCAL_BUNDLES_DIR"
    exit 1
fi

echo ">>> 导入本地修改bundle: $BUNDLE_PREFIX"
echo ">>> 源目录: $LOCAL_BUNDLES_DIR"
echo ">>> 目标仓库: $ROOT"

# 检查信息文件
INFO_FILE="$LOCAL_BUNDLES_DIR/${BUNDLE_PREFIX}_info.json"
if [[ ! -f "$INFO_FILE" ]]; then
    echo "❌ 找不到信息文件: $INFO_FILE"
    exit 1
fi

# 解析信息文件
echo ">>> 解析bundle信息..."
BUNDLE_INFO=$(cat "$INFO_FILE")
MAIN_BUNDLE=$(echo "$BUNDLE_INFO" | jq -r '.main_bundle')
SUB_BUNDLES=$(echo "$BUNDLE_INFO" | jq -r '.sub_bundles[]')
CREATED_AT=$(echo "$BUNDLE_INFO" | jq -r '.created_at')

echo ">>> 创建时间: $CREATED_AT"
echo ">>> 主仓库bundle: $MAIN_BUNDLE"

# 检查主仓库bundle
MAIN_BUNDLE_PATH="$LOCAL_BUNDLES_DIR/$MAIN_BUNDLE"
if [[ ! -f "$MAIN_BUNDLE_PATH" ]]; then
    echo "❌ 主仓库bundle不存在: $MAIN_BUNDLE_PATH"
    exit 1
fi

# 1. 导入主仓库修改
echo ">>> 导入主仓库修改..."
cd "$ROOT"

# 检查是否有未提交的修改
if [[ -n "$(git status --porcelain)" ]]; then
    echo "⚠️  主仓库有未提交的修改，建议先提交或stash"
    read -p "是否继续？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "操作已取消"
        exit 0
    fi
fi

# 从bundle获取更新
git fetch "$MAIN_BUNDLE_PATH" "refs/heads/*:refs/heads/*" --update-head-ok

# 2. 导入子模块修改
echo ">>> 导入子模块修改..."
for sub_bundle in $SUB_BUNDLES; do
    SUB_BUNDLE_PATH="$LOCAL_BUNDLES_DIR/$sub_bundle"
    if [[ ! -f "$SUB_BUNDLE_PATH" ]]; then
        echo "⚠️  子模块bundle不存在: $SUB_BUNDLE_PATH"
        continue
    fi
    
    # 从bundle名称推断子模块路径
    SUB_PATH=$(echo "$sub_bundle" | sed "s/${BUNDLE_PREFIX}_//" | sed 's/\.bundle$//' | sed 's/_/\//g')
    SUB_REPO="$ROOT/$SUB_PATH"
    
    if [[ ! -d "$SUB_REPO" ]]; then
        echo "⚠️  子模块目录不存在: $SUB_REPO"
        continue
    fi
    
    echo "    → $SUB_PATH"
    cd "$SUB_REPO"
    git fetch "$SUB_BUNDLE_PATH" "refs/heads/*:refs/heads/*" --update-head-ok
done

# 3. 更新last-sync标签
echo ">>> 更新同步标签..."
cd "$ROOT"
git tag -f last-sync
git submodule foreach --recursive 'git tag -f last-sync'

# 4. 显示导入结果
echo ">>> 导入完成！"
echo ">>> 当前状态:"
git status --short

echo ">>> 子模块状态:"
git submodule status --recursive

# 5. 可选：显示差异报告
DIFF_REPORT="$LOCAL_BUNDLES_DIR/${BUNDLE_PREFIX}_diff_report.txt"
if [[ -f "$DIFF_REPORT" ]]; then
    echo ">>> 差异报告:"
    cat "$DIFF_REPORT"
fi

echo "✅ 本地修改导入完成！"
echo "📋 下一步操作:"
echo "1. 检查导入的修改是否符合预期"
echo "2. 运行测试确保代码质量"
echo "3. 提交到GitLab仓库" 