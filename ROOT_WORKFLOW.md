# ROOT环境工作流程详解

## 概述

ROOT环境是有网络连接的环境，负责创建离线包和导入开发者的变化。

## 配置文件与脚本的关系

### 配置文件：config_root.sh

配置文件定义了系统的行为参数，脚本会读取这些配置：

```bash
# config_root.sh - 您需要修改的配置
PROJECT_NAME="my-slam-project"     # ← 您的项目名称
DEFAULT_BRANCH="main"              # ← 您的主分支
DEFAULT_DEPTH=10                   # ← 子模块历史深度
COMPRESSION_FORMAT="tar.gz"        # ← 压缩格式
BACKUP_BEFORE_IMPORT=true          # ← 导入前是否备份
```

### 脚本：make_offline_package.sh

脚本使用配置文件中的参数来执行操作：

```bash
# 脚本内部逻辑（简化版）
source config_root.sh              # 加载您的配置
export_config                      # 导出配置到环境变量

BRANCH=$1                          # 从命令行获取分支参数
DEPTH=$DEFAULT_DEPTH               # 从配置文件获取深度
PROJECT=$PROJECT_NAME              # 从配置文件获取项目名

# 使用这些参数创建离线包
git bundle create ... $BRANCH
# 为每个子模块创建bundle，深度为$DEPTH
```

## 完整工作流程示例

### 场景：您有一个SLAM项目，包含多个子模块

#### 1. 初始配置

**您的项目结构**：
```
my-slam-project/
├── .gitmodules          # 包含子模块定义
├── slam-core/           # 主模块
├── modules/             # 子模块目录
│   ├── frontend/        # 前端子模块
│   ├── backend/         # 后端子模块
│   └── algorithms/      # 算法子模块
└── config_root.sh       # 配置文件
```

**修改配置文件**：
```bash
# 编辑 config_root.sh
vim config_root.sh

# 修改这些配置：
PROJECT_NAME="my-slam-project"     # 您的项目名称
DEFAULT_BRANCH="main"              # 您的主分支
DEFAULT_DEPTH=15                   # 包含15个历史提交
```

#### 2. 创建离线包

```bash
# 在项目根目录运行
./make_offline_package.sh main

# 脚本执行过程：
# 1. 加载 config_root.sh 中的配置
# 2. 读取 .gitmodules 文件，发现3个子模块
# 3. 创建 slam-core.bundle（主项目）
# 4. 为每个子模块创建bundle，包含最近15个提交
# 5. 打包为 offline_pkg_20231201_my-slam-project_main_depth15.tar.gz
```

#### 3. 分发包

```bash
# 将包发送给开发者
scp offline_pkg_20231201_my-slam-project_main_depth15.tar.gz developer@remote:/home/developer/
```

#### 4. 开发者工作（离线环境）

开发者收到包后：
```bash
# 解压并初始化
tar -xzf offline_pkg_20231201_my-slam-project_main_depth15.tar.gz
./init_repository.sh

# 开发并导出变化
cd slam-core
# ... 开发工作 ...
./export_changes.sh
```

#### 5. 接收并导入变化

开发者返回变化包：
```bash
# 您收到 local_out_20231201_143022/ 目录
./import_from_local.sh local_out_20231201_143022

# 脚本执行过程：
# 1. 加载 config_root.sh 中的配置
# 2. 创建备份分支（如果BACKUP_BEFORE_IMPORT=true）
# 3. 导入 slam-core 的变化
# 4. 读取 .gitmodules，导入所有子模块的变化
# 5. 合并到主分支
# 6. 生成导入报告
```

## 配置文件的作用

### 为什么需要配置文件？

1. **参数化脚本**：避免硬编码，让脚本更灵活
2. **环境隔离**：不同项目可以有不同的配置
3. **易于维护**：修改配置不需要改脚本代码
4. **版本控制**：配置文件可以加入版本控制

### 配置项说明

| 配置项 | 作用 | 示例 |
|--------|------|------|
| `PROJECT_NAME` | 项目名称，用于包命名 | `"my-slam-project"` |
| `DEFAULT_BRANCH` | 主分支名称 | `"main"` 或 `"develop"` |
| `DEFAULT_DEPTH` | 子模块历史深度 | `10` (包含10个提交) |
| `COMPRESSION_FORMAT` | 压缩格式 | `"tar.gz"` 或 `"tar.bz2"` |
| `BACKUP_BEFORE_IMPORT` | 导入前是否备份 | `true` 或 `false` |

## 常见操作

### 创建不同深度的包

```bash
# 修改配置文件
vim config_root.sh
DEFAULT_DEPTH=5    # 只包含5个提交，包更小

# 创建包
./make_offline_package.sh main
```

### 为不同分支创建包

```bash
# 创建develop分支的包
./make_offline_package.sh develop

# 创建feature分支的包
./make_offline_package.sh feature/new-algorithm
```

### 导入多个开发者的变化

```bash
# 导入开发者A的变化
./import_from_local.sh local_out_20231201_143022

# 导入开发者B的变化
./import_from_local.sh local_out_20231201_150000
```

## 故障排除

### 配置文件找不到

```bash
# 确保配置文件存在
ls -la config_root.sh

# 确保有执行权限
chmod +x config_root.sh
```

### 子模块读取失败

```bash
# 检查.gitmodules文件
cat .gitmodules

# 确保子模块已初始化
git submodule update --init --recursive
```

### 导入冲突

```bash
# 查看冲突
git status

# 手动解决冲突
vim conflicted_file.txt
git add conflicted_file.txt
git commit
```

## 最佳实践

1. **配置文件版本控制**：将配置文件加入Git，但不要包含敏感信息
2. **定期备份**：在导入前启用备份功能
3. **测试配置**：在生产环境使用前先测试
4. **文档化配置**：为团队记录配置项的用途
5. **环境隔离**：不同项目使用不同的配置文件 