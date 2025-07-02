# Git Offline Bundle Manager - 快速开始指南

本指南将帮助您快速设置和使用Git离线Bundle管理器。

## 前置要求

- Git ≥ 2.20（必须支持 `git bundle`）
- Bash环境
- 包含子模块的Git仓库
- `.gitmodules` 文件（用于自动检测子模块）

## 快速设置

### 1. 服务器端设置

#### 1.1 配置服务器
```bash
cd tools
cp example-server.config server.config
# 编辑 server.config，设置正确的路径
# 注意：子模块会自动检测，无需手动配置
```

#### 1.2 导出完整仓库
```bash
./export-full.sh
```

### 2. 本地端设置

#### 2.1 配置本地环境
```bash
cd tools
cp example-local.config local.config
# 编辑 local.config，设置正确的路径
# 注意：子模块会自动检测，无需手动配置
```

#### 2.2 初始化仓库
```bash
./init-from-bundle.sh
```

## 日常使用流程

### 开发新功能

1. **创建功能分支**
   ```bash
   ./create-feature-branch.sh my-feature
   ```

2. **开发并提交代码**
   ```bash
   # 在主仓库中开发
   git add .
   git commit -m "Add new feature"
   
   # 在子模块中开发
   cd module_a
   git add .
   git commit -m "Update submodule"
   cd ..
   ```

3. **导出功能分支**
   ```bash
   ./export-feature.sh
   ```

4. **传输bundle到服务器**
   ```bash
   cp bundles/*.bundle /path/to/server/
   ```

### 服务器端处理

1. **导入功能分支**
   ```bash
   ./import-feature.sh /path/to/bundles
   ```

2. **审查并合并**
   ```bash
   # 审查代码
   git log dev/my-feature
   
   # 合并到主分支
   git checkout main
   git merge dev/my-feature
   ```

3. **导出更新后的完整仓库**
   ```bash
   ./export-full.sh
   ```

### 本地端更新

1. **获取服务器更新**
   ```bash
   ./update-from-server.sh
   ```

## 配置文件说明

### server.config
```ini
[main]
repo_path=/srv/git/slam-core    # 服务器端仓库路径
output_dir=/srv/bundles         # bundle输出目录
# modules=module_a,module_b     # 子模块列表（可选，会自动检测）
```

### local.config
```ini
[main]
repo_path=~/projects/slam-core  # 本地仓库路径
bundle_source=/media/usb        # bundle文件源目录
# modules=module_a,module_b     # 子模块列表（可选，会自动检测）
feature_branch=dev/awesome-feature  # 默认功能分支名
```

## 常见问题

### Q: 脚本提示权限错误
A: 确保脚本有执行权限：
```bash
chmod +x tools/*.sh
```

### Q: 找不到配置文件
A: 复制示例配置文件：
```bash
cp tools/example-*.config tools/
```

### Q: Git版本过低
A: 检查Git版本：
```bash
git --version
# 需要 ≥ 2.20
```

### Q: 子模块初始化失败
A: 确保bundle文件存在且路径正确：
```bash
ls -la /path/to/bundles/*.bundle
```

## 获取帮助

- 查看详细文档：`tools/README.md`
- 查看脚本帮助：`./script.sh --help` 或 `./script.sh`（不带参数）
- 检查配置文件格式和路径

## 注意事项

- 所有功能分支必须以 `dev/` 开头
- 确保在正确的分支上操作
- 定期备份重要的bundle文件
- 在无网络环境中测试所有流程 