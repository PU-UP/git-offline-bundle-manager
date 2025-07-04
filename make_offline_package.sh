#!/bin/bash

# make_offline_package.sh - 首次分发脚本
# 用法: ./make_offline_package.sh <branch> <depth>
# 功能: 创建包含slam-core和子模块的离线包

set -e

# 加载配置文件
if [ -f "config_root.sh" ]; then
    source config_root.sh
    export_config
else
    echo "错误: 找不到配置文件 config_root.sh"
    exit 1
fi

# 参数检查
if [ $# -eq 0 ]; then
    # 没有参数，使用配置文件中的默认分支
    BRANCH=$DEFAULT_BRANCH
    echo "使用配置文件中的默认分支: $BRANCH"
elif [ $# -eq 1 ]; then
    # 有参数，使用指定的分支
    BRANCH=$1
    echo "使用指定的分支: $BRANCH"
else
    echo "用法: $0 [branch]"
    echo "示例: $0          # 使用配置文件中的默认分支"
    echo "示例: $0 main     # 使用指定的分支"
    echo "注意: depth参数在config_root.sh中配置"
    exit 1
fi

DEPTH=$DEFAULT_DEPTH
DATE=$(date +%Y%m%d)
PACKAGE_NAME="offline_pkg_${DATE}.tar.gz"
SUBMODULES_DIR="submodules"

echo "=== 开始创建离线包 ==="
echo "分支: $BRANCH"
echo "深度: $DEPTH"
echo "包名: $PACKAGE_NAME"

# 检查Git版本
GIT_VERSION=$(git --version | awk '{print $3}')
echo "Git版本: $GIT_VERSION"

# 确定本地仓库路径
if [ -n "$LOCAL_REPO_PATH" ]; then
    REPO_PATH="$LOCAL_REPO_PATH"
    echo "使用配置的本地仓库路径: $REPO_PATH"
else
    REPO_PATH="."
    echo "使用当前目录作为本地仓库路径"
fi

# 检查本地仓库路径是否存在
if [ ! -d "$REPO_PATH" ]; then
    echo "错误: 本地仓库路径不存在: $REPO_PATH"
    exit 1
fi

# 检查是否在Git仓库中
if [ ! -d "$REPO_PATH/.git" ]; then
    echo "错误: 指定的路径不是Git仓库: $REPO_PATH"
    exit 1
fi

# 保存当前目录
CURRENT_DIR=$(pwd)

# 切换到本地仓库目录
echo "切换到本地仓库目录: $REPO_PATH"
cd "$REPO_PATH"

# 检查分支是否存在
if ! git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
    echo "错误: 分支 '$BRANCH' 不存在"
    cd "$CURRENT_DIR"
    exit 1
fi

# 切换到指定分支
echo "切换到分支: $BRANCH"
git checkout "$BRANCH"

# 创建临时目录
TEMP_DIR=$(mktemp -d)
echo "创建临时目录: $TEMP_DIR"

# 创建slam-core.bundle（仅指针）
echo "创建slam-core.bundle..."
git bundle create "$TEMP_DIR/slam-core.bundle" "$BRANCH" --all

# 创建子模块目录
mkdir -p "$TEMP_DIR/$SUBMODULES_DIR"

# 检查.gitmodules文件
if [ ! -f ".gitmodules" ]; then
    echo "警告: 没有找到.gitmodules文件，跳过子模块处理"
else
    # 从.gitmodules文件读取子模块列表
    SUBMODULES=$(grep '^\[submodule' .gitmodules | sed 's/^\[submodule "\(.*\)"\]/\1/')
    
    if [ -z "$SUBMODULES" ]; then
        echo "警告: 在.gitmodules文件中没有找到子模块"
    else
        echo "从.gitmodules文件发现子模块: $SUBMODULES"
        
        # 为每个子模块创建bundle
        for submodule in $SUBMODULES; do
        echo "处理子模块: $submodule"
        
        # 进入子模块目录
        cd "$submodule"
        
        # 获取子模块的当前分支
        SUBMODULE_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        
        # 创建子模块bundle，限制提交数量
        BUNDLE_NAME="$TEMP_DIR/$SUBMODULES_DIR/${submodule}.bundle"
        echo "创建bundle: $BUNDLE_NAME (深度: $DEPTH)"
        
        # 获取最近的N个提交
        RECENT_COMMITS=$(git log --oneline -n "$DEPTH" --format="%H" | tac)
        
        if [ -n "$RECENT_COMMITS" ]; then
            # 创建bundle，包含最近的提交
            git bundle create "$BUNDLE_NAME" $RECENT_COMMITS
            echo "✓ 子模块 $submodule 的bundle创建完成"
        else
            echo "警告: 子模块 $submodule 没有提交历史"
            # 创建空的bundle
            git bundle create "$BUNDLE_NAME" HEAD
        fi
        
        # 返回上级目录
        cd ..
        done
    fi
fi

# 创建初始化脚本
cat > "$TEMP_DIR/init_repository.sh" << 'EOF'
#!/bin/bash

# init_repository.sh - 本地仓库初始化脚本
# 用法: ./init_repository.sh

set -e

echo "=== 开始初始化本地仓库 ==="

# 检查Git版本
GIT_VERSION=$(git --version | awk '{print $3}')
echo "Git版本: $GIT_VERSION"

# 创建slam-core仓库
echo "创建slam-core仓库..."
git clone slam-core.bundle slam-core
cd slam-core

# 初始化子模块
echo "初始化子模块..."
for bundle in ../submodules/*.bundle; do
    if [ -f "$bundle" ]; then
        submodule_name=$(basename "$bundle" .bundle)
        echo "处理子模块: $submodule_name"
        
        # 创建子模块目录
        mkdir -p "$submodule_name"
        
        # 克隆子模块bundle
        git clone "$bundle" "$submodule_name"
        
        # 添加到.gitmodules（如果不存在）
        if ! grep -q "\[submodule \"$submodule_name\"\]" .gitmodules 2>/dev/null; then
            echo "" >> .gitmodules
            echo "[submodule \"$submodule_name\"]" >> .gitmodules
            echo "    path = $submodule_name" >> .gitmodules
            echo "    url = $bundle" >> .gitmodules
        fi
        
        # 注册子模块
        git submodule add "$bundle" "$submodule_name"
    fi
done

echo "✓ 本地仓库初始化完成"
echo "现在可以开始开发了！"
echo ""
echo "开发步骤:"
echo "1. cd slam-core"
echo "2. 在子模块中创建分支: git checkout -b feature/your-feature"
echo "3. 正常开发并提交"
echo "4. 回到slam-core提交指针更新"
EOF

chmod +x "$TEMP_DIR/init_repository.sh"

# 创建README
cat > "$TEMP_DIR/README.md" << EOF
# 离线Git包 - $DATE

## 包内容
- \`slam-core.bundle\`: 主项目bundle（仅包含指针）
- \`submodules/\`: 子模块bundle目录
- \`init_repository.sh\`: 本地仓库初始化脚本

## 使用方法
1. 解压包: \`tar -xzf $PACKAGE_NAME\`
2. 运行初始化: \`./init_repository.sh\`
3. 开始开发: \`cd slam-core\`

## 参数信息
- 分支: $BRANCH
- 深度: $DEPTH
- Git版本: $GIT_VERSION
EOF

# 打包
echo "创建最终包: $PACKAGE_NAME"
cd "$TEMP_DIR"
tar -czf "../$PACKAGE_NAME" .

# 清理临时目录
cd ..
rm -rf "$TEMP_DIR"

# 返回到原始目录
cd "$CURRENT_DIR"

echo "=== 离线包创建完成 ==="
echo "包名: $PACKAGE_NAME"
echo "大小: $(du -h "$PACKAGE_NAME" | cut -f1)"
echo ""
echo "下一步: 将 $PACKAGE_NAME 分发给本地开发者" 