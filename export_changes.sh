#!/bin/bash

# export_changes.sh - 交付差分脚本
# 用法: ./export_changes.sh
# 功能: 导出本地开发的变化，创建增量bundle

set -e

# 加载配置文件
if [ -f "config_local.sh" ]; then
    source config_local.sh
    export_config
else
    echo "错误: 找不到配置文件 config_local.sh"
    exit 1
fi

# 获取时间戳
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="$EXPORT_OUTPUT_PATH/local_out_${TIMESTAMP}"
SUBMODULES_DIR="submodules"

echo "=== 开始导出本地变化 ==="
echo "输出目录: $OUTPUT_DIR"
echo "时间戳: $TIMESTAMP"

# 使用配置的slam-core路径
if [ -n "$SLAM_CORE_PATH" ]; then
    REPO_PATH="$SLAM_CORE_PATH"
    echo "使用配置的slam-core路径: $REPO_PATH"
else
    echo "错误: 请在config_local.sh中配置SLAM_CORE_PATH"
    exit 1
fi

# 检查slam-core路径是否存在
if [ ! -d "$REPO_PATH" ]; then
    echo "错误: slam-core路径不存在: $REPO_PATH"
    exit 1
fi

# 检查是否在Git仓库中
if [ ! -d "$REPO_PATH/.git" ]; then
    echo "错误: 指定的路径不是Git仓库: $REPO_PATH"
    exit 1
fi

# 保存当前目录
CURRENT_DIR=$(pwd)

# 切换到slam-core目录
echo "切换到slam-core目录: $REPO_PATH"
cd "$REPO_PATH"

# 检查是否有子模块
if [ ! -f ".gitmodules" ]; then
    echo "警告: 没有找到.gitmodules文件"
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR/$SUBMODULES_DIR"

# 获取当前分支
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "当前分支: $CURRENT_BRANCH"

# 检查是否有未提交的更改
if [ -n "$(git status --porcelain)" ]; then
    echo "警告: 有未提交的更改，请先提交或暂存"
    git status --short
    echo ""
    read -p "是否继续？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        cd "$CURRENT_DIR"
        exit 1
    fi
fi

# 创建slam-core的delta bundle
echo "创建slam-core.delta.bundle..."

# 获取上次bundle的基础提交（假设是main分支的最新提交）
BASE_COMMIT=$(git rev-parse main 2>/dev/null || git rev-parse origin/main 2>/dev/null || git rev-list --max-parents=0 HEAD | head -1)

if [ -n "$BASE_COMMIT" ]; then
    # 检查是否有新的提交
    NEW_COMMITS=$(git log --oneline "$BASE_COMMIT..HEAD" --format="%H")
    
    if [ -n "$NEW_COMMITS" ]; then
        echo "发现新提交，创建delta bundle..."
        git bundle create "$OUTPUT_DIR/slam-core.delta.bundle" "$BASE_COMMIT..HEAD"
        echo "✓ slam-core.delta.bundle 创建完成"
    else
        echo "slam-core 没有新提交"
        # 创建空的delta bundle
        git bundle create "$OUTPUT_DIR/slam-core.delta.bundle" HEAD
    fi
else
    echo "警告: 无法确定基础提交，创建完整bundle"
    git bundle create "$OUTPUT_DIR/slam-core.delta.bundle" --all
fi

# 处理子模块
if [ ! -f ".gitmodules" ]; then
    echo "警告: 没有找到.gitmodules文件，跳过子模块处理"
else
    # 从.gitmodules文件读取子模块列表
    SUBMODULES=$(grep '^\[submodule' .gitmodules | sed 's/^\[submodule "\(.*\)"\]/\1/')
    
    if [ -n "$SUBMODULES" ]; then
        echo "处理子模块变化..."
        
        for submodule in $SUBMODULES; do
        echo "处理子模块: $submodule"
        
        if [ -d "$submodule" ] && [ -d "$submodule/.git" ]; then
            cd "$submodule"
            
            # 获取子模块的当前分支
            SUBMODULE_BRANCH=$(git rev-parse --abbrev-ref HEAD)
            echo "  子模块分支: $SUBMODULE_BRANCH"
            
            # 检查子模块是否有未提交的更改
            if [ -n "$(git status --porcelain)" ]; then
                echo "  警告: 子模块 $submodule 有未提交的更改"
                git status --short
            fi
            
            # 获取子模块的基础提交（假设是main分支）
            SUBMODULE_BASE=$(git rev-parse main 2>/dev/null || git rev-parse origin/main 2>/dev/null || git rev-list --max-parents=0 HEAD | head -1)
            
            if [ -n "$SUBMODULE_BASE" ]; then
                # 检查子模块是否有新的提交
                SUBMODULE_NEW_COMMITS=$(git log --oneline "$SUBMODULE_BASE..HEAD" --format="%H")
                
                if [ -n "$SUBMODULE_NEW_COMMITS" ]; then
                    echo "  发现新提交，创建delta bundle..."
                    DELTA_BUNDLE="../$OUTPUT_DIR/$SUBMODULES_DIR/${submodule}.delta.bundle"
                    git bundle create "$DELTA_BUNDLE" "$SUBMODULE_BASE..HEAD"
                    echo "  ✓ ${submodule}.delta.bundle 创建完成"
                else
                    echo "  子模块 $submodule 没有新提交"
                    # 创建空的delta bundle
                    DELTA_BUNDLE="../$OUTPUT_DIR/$SUBMODULES_DIR/${submodule}.delta.bundle"
                    git bundle create "$DELTA_BUNDLE" HEAD
                fi
            else
                echo "  警告: 无法确定子模块基础提交，创建完整bundle"
                DELTA_BUNDLE="../$OUTPUT_DIR/$SUBMODULES_DIR/${submodule}.delta.bundle"
                git bundle create "$DELTA_BUNDLE" --all
            fi
            
            cd ..
        else
            echo "  警告: 子模块 $submodule 目录不存在或不是Git仓库"
        fi
        done
    else
        echo "在.gitmodules文件中没有找到子模块"
    fi
fi

# 创建导出信息文件
cat > "$OUTPUT_DIR/export_info.txt" << EOF
导出时间: $(date)
分支: $CURRENT_BRANCH
Git版本: $(git --version | awk '{print $3}')

包含的文件:
- slam-core.delta.bundle
$(for bundle in $OUTPUT_DIR/$SUBMODULES_DIR/*.delta.bundle 2>/dev/null; do
    if [ -f "$bundle" ]; then
        echo "- $(basename "$bundle")"
    fi
done)

使用说明:
1. 将此目录复制到ROOT环境
2. 运行 import_from_local.sh 导入变化
EOF

# 返回到原始目录
cd "$CURRENT_DIR"

# 计算包大小
TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)
echo ""
echo "=== 导出完成 ==="
echo "输出目录: $OUTPUT_DIR"
echo "总大小: $TOTAL_SIZE"
echo ""
echo "包含的文件:"
ls -la "$OUTPUT_DIR"
echo ""
echo "下一步: 将 $OUTPUT_DIR 复制到ROOT环境并运行 import_from_local.sh" 