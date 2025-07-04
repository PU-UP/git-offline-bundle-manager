#!/bin/bash

# import_from_local.sh - 导入合并脚本
# 用法: ./import_from_local.sh /path/to/local_out
# 功能: 将本地开发的变化导入到ROOT环境

set -e

# 参数检查
if [ $# -ne 1 ]; then
    echo "用法: $0 /path/to/local_out"
    echo "示例: $0 ./local_out_20231201_143022"
    exit 1
fi

LOCAL_OUT_DIR="$1"
SUBMODULES_DIR="submodules"

echo "=== 开始导入本地变化 ==="
echo "本地输出目录: $LOCAL_OUT_DIR"

# 检查目录是否存在
if [ ! -d "$LOCAL_OUT_DIR" ]; then
    echo "错误: 目录 '$LOCAL_OUT_DIR' 不存在"
    exit 1
fi

# 检查是否在Git仓库中
if [ ! -d ".git" ]; then
    echo "错误: 当前目录不是Git仓库"
    exit 1
fi

# 检查必要的文件
if [ ! -f "$LOCAL_OUT_DIR/slam-core.delta.bundle" ]; then
    echo "错误: 找不到 slam-core.delta.bundle"
    exit 1
fi

# 获取当前分支
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "当前分支: $CURRENT_BRANCH"

# 创建临时分支用于导入
IMPORT_BRANCH="import_$(date +%Y%m%d_%H%M%S)"
echo "创建导入分支: $IMPORT_BRANCH"

# 创建并切换到导入分支
git checkout -b "$IMPORT_BRANCH"

# 导入slam-core的变化
echo "导入slam-core变化..."
git fetch "$LOCAL_OUT_DIR/slam-core.delta.bundle" "$CURRENT_BRANCH:$IMPORT_BRANCH"

# 检查是否有新的提交
NEW_COMMITS=$(git log --oneline "$CURRENT_BRANCH..$IMPORT_BRANCH" --format="%H")

if [ -n "$NEW_COMMITS" ]; then
    echo "发现新的slam-core提交:"
    git log --oneline "$CURRENT_BRANCH..$IMPORT_BRANCH"
else
    echo "slam-core 没有新提交"
fi

# 加载配置文件
if [ -f "config_root.sh" ]; then
    source config_root.sh
    export_config
else
    echo "错误: 找不到配置文件 config_root.sh"
    exit 1
fi

# 处理子模块
if [ -d "$LOCAL_OUT_DIR/$SUBMODULES_DIR" ]; then
    echo "处理子模块变化..."
    
    # 从.gitmodules文件读取子模块列表
    if [ ! -f ".gitmodules" ]; then
        echo "警告: 没有找到.gitmodules文件，跳过子模块处理"
    else
        SUBMODULES=$(grep '^\[submodule' .gitmodules | sed 's/^\[submodule "\(.*\)"\]/\1/')
        
        if [ -n "$SUBMODULES" ]; then
            for submodule in $SUBMODULES; do
            echo "处理子模块: $submodule"
            
            DELTA_BUNDLE="$LOCAL_OUT_DIR/$SUBMODULES_DIR/${submodule}.delta.bundle"
            
            if [ -f "$DELTA_BUNDLE" ]; then
                if [ -d "$submodule" ] && [ -d "$submodule/.git" ]; then
                    cd "$submodule"
                    
                    # 获取子模块的当前分支
                    SUBMODULE_BRANCH=$(git rev-parse --abbrev-ref HEAD)
                    echo "  子模块分支: $SUBMODULE_BRANCH"
                    
                    # 创建子模块的临时分支
                    SUBMODULE_IMPORT_BRANCH="import_${submodule}_$(date +%Y%m%d_%H%M%S)"
                    
                    # 导入子模块变化
                    git fetch "../$DELTA_BUNDLE" "$SUBMODULE_BRANCH:$SUBMODULE_IMPORT_BRANCH"
                    
                    # 检查子模块是否有新提交
                    SUBMODULE_NEW_COMMITS=$(git log --oneline "$SUBMODULE_BRANCH..$SUBMODULE_IMPORT_BRANCH" --format="%H")
                    
                    if [ -n "$SUBMODULE_NEW_COMMITS" ]; then
                        echo "  发现新的子模块提交:"
                        git log --oneline "$SUBMODULE_BRANCH..$SUBMODULE_IMPORT_BRANCH"
                        
                        # 合并到主分支
                        git checkout "$SUBMODULE_BRANCH"
                        git merge "$SUBMODULE_IMPORT_BRANCH" --no-edit
                        
                        # 删除临时分支
                        git branch -D "$SUBMODULE_IMPORT_BRANCH"
                        
                        echo "  ✓ 子模块 $submodule 合并完成"
                    else
                        echo "  子模块 $submodule 没有新提交"
                        # 删除临时分支
                        git branch -D "$SUBMODULE_IMPORT_BRANCH"
                    fi
                    
                    cd ..
                else
                    echo "  警告: 子模块 $submodule 目录不存在或不是Git仓库"
                fi
            else
                echo "  警告: 找不到子模块 $submodule 的delta bundle"
            fi
            done
        else
            echo "在.gitmodules文件中没有找到子模块"
        fi
    fi
else
    echo "没有找到子模块目录"
fi

# 更新子模块指针
echo "更新子模块指针..."
git submodule update --init --recursive

# 提交子模块指针更新
if [ -n "$(git status --porcelain)" ]; then
    echo "提交子模块指针更新..."
    git add .
    git commit -m "更新子模块指针 - 导入时间: $(date)"
fi

# 合并到主分支
echo "合并到主分支..."
git checkout "$CURRENT_BRANCH"

# 检查是否有冲突
if git merge "$IMPORT_BRANCH" --no-edit; then
    echo "✓ 合并成功"
else
    echo "⚠ 合并冲突，请手动解决"
    echo "解决冲突后运行: git add . && git commit"
    exit 1
fi

# 删除临时分支
git branch -D "$IMPORT_BRANCH"

# 创建导入报告
IMPORT_REPORT="import_report_$(date +%Y%m%d_%H%M%S).txt"
cat > "$IMPORT_REPORT" << EOF
导入报告 - $(date)

导入目录: $LOCAL_OUT_DIR
目标分支: $CURRENT_BRANCH

导入的提交:
$(git log --oneline "$CURRENT_BRANCH@{1}..$CURRENT_BRANCH")

子模块更新:
$(git submodule status)

下一步:
1. 检查代码: git log --oneline -10
2. 测试功能
3. 推送到远程: git push origin $CURRENT_BRANCH
4. 创建合并请求 (MR)
EOF

echo ""
echo "=== 导入完成 ==="
echo "导入报告: $IMPORT_REPORT"
echo ""
echo "下一步操作:"
echo "1. 检查导入的代码: git log --oneline -10"
echo "2. 运行测试确保功能正常"
echo "3. 推送到远程: git push origin $CURRENT_BRANCH"
echo "4. 创建合并请求 (MR)"
echo ""
echo "导入报告已保存到: $IMPORT_REPORT" 