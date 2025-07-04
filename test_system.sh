#!/bin/bash

# test_system.sh - 测试离线包管理系统
# 用法: ./test_system.sh
# 功能: 创建测试环境并验证系统功能

set -e

echo "=== 开始测试离线包管理系统 ==="

# 检查Git版本
GIT_VERSION=$(git --version | awk '{print $3}')
echo "Git版本: $GIT_VERSION"

# 检查脚本是否存在
SCRIPTS=("make_offline_package.sh" "export_changes.sh" "import_from_local.sh")
for script in "${SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        echo "错误: 找不到脚本 $script"
        exit 1
    fi
    if [ ! -x "$script" ]; then
        echo "错误: 脚本 $script 没有执行权限"
        exit 1
    fi
    echo "✓ 脚本 $script 检查通过"
done

# 创建测试目录
TEST_DIR="test_offline_system_$(date +%Y%m%d_%H%M%S)"
echo "创建测试目录: $TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# 创建模拟的Git仓库结构
echo "创建模拟的Git仓库结构..."

# 创建主仓库
git init slam-core-test
cd slam-core-test

# 创建初始文件
echo "# SLAM Core Project" > README.md
git add README.md
git commit -m "初始提交"

# 创建子模块1
mkdir -p ../submodule1
cd ../submodule1
git init
echo "# Submodule 1" > README.md
git add README.md
git commit -m "子模块1初始提交"
echo "feature1" > feature1.txt
git add feature1.txt
git commit -m "添加功能1"
cd ..

# 创建子模块2
mkdir -p ../submodule2
cd ../submodule2
git init
echo "# Submodule 2" > README.md
git add README.md
git commit -m "子模块2初始提交"
echo "feature2" > feature2.txt
git add feature2.txt
git commit -m "添加功能2"
cd ..

# 添加子模块到主仓库
cd slam-core-test
git submodule add ../submodule1 submodule1
git submodule add ../submodule2 submodule2
git commit -m "添加子模块"

# 创建main分支
git checkout -b main
git checkout -b develop

echo "✓ 测试仓库创建完成"

# 测试make_offline_package.sh
echo ""
echo "=== 测试 make_offline_package.sh ==="
cd ..
cp ../make_offline_package.sh .
chmod +x make_offline_package.sh

# 运行打包脚本
./make_offline_package.sh develop

# 检查产物
if [ -f "offline_pkg_*.tar.gz" ]; then
    echo "✓ 离线包创建成功"
    PACKAGE_NAME=$(ls offline_pkg_*.tar.gz)
    echo "包名: $PACKAGE_NAME"
    echo "包大小: $(du -h "$PACKAGE_NAME" | cut -f1)"
else
    echo "✗ 离线包创建失败"
    exit 1
fi

# 测试解压和初始化
echo ""
echo "=== 测试解压和初始化 ==="
tar -xzf "$PACKAGE_NAME"
cd slam-core

# 运行初始化脚本
./init_repository.sh

if [ -d "slam-core" ]; then
    echo "✓ 本地仓库初始化成功"
    cd slam-core
    
    # 检查子模块
    if [ -d "submodule1" ] && [ -d "submodule2" ]; then
        echo "✓ 子模块初始化成功"
    else
        echo "✗ 子模块初始化失败"
        exit 1
    fi
else
    echo "✗ 本地仓库初始化失败"
    exit 1
fi

# 模拟开发过程
echo ""
echo "=== 模拟开发过程 ==="

# 在子模块1中开发
cd submodule1
git checkout -b feature/test-feature
echo "new feature" > new_feature.txt
git add new_feature.txt
git commit -m "添加新功能"
cd ..

# 在子模块2中开发
cd submodule2
git checkout -b feature/another-feature
echo "another feature" > another_feature.txt
git add another_feature.txt
git commit -m "添加另一个功能"
cd ..

# 更新主仓库指针
git add submodule1 submodule2
git commit -m "更新子模块指针"

echo "✓ 开发过程模拟完成"

# 测试export_changes.sh
echo ""
echo "=== 测试 export_changes.sh ==="
cp ../../export_changes.sh .
chmod +x export_changes.sh

./export_changes.sh

# 检查导出产物
if [ -d "local_out_*" ]; then
    echo "✓ 变化导出成功"
    EXPORT_DIR=$(ls -d local_out_*)
    echo "导出目录: $EXPORT_DIR"
    ls -la "$EXPORT_DIR"
else
    echo "✗ 变化导出失败"
    exit 1
fi

# 测试import_from_local.sh
echo ""
echo "=== 测试 import_from_local.sh ==="
cd ../..
cp ../import_from_local.sh .
chmod +x import_from_local.sh

# 回到原始仓库
cd slam-core-test

# 运行导入脚本
../import_from_local.sh "../$EXPORT_DIR"

echo "✓ 导入测试完成"

# 清理测试环境
echo ""
echo "=== 清理测试环境 ==="
cd ..
rm -rf "$TEST_DIR"

echo ""
echo "=== 测试完成 ==="
echo "✓ 所有功能测试通过"
echo "✓ 离线包管理系统工作正常"
echo ""
echo "系统已准备就绪，可以开始使用！" 