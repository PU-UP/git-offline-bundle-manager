# ROOT环境快速开始指南

## 5分钟上手ROOT环境

### 1. 准备工作

确保您在有网络连接的环境中，并且有完整的Git仓库（包含子模块）。

### 2. 配置系统

**编辑配置文件**：
```bash
vim config_root.sh
```

**修改关键配置**：
```bash
# 基础配置（必需）
PROJECT_NAME="your-project-name"    # ← 改为您的项目名
DEFAULT_BRANCH="main"               # ← 改为您的主分支
DEFAULT_DEPTH=10                   # ← 子模块历史深度

# 本地仓库配置（重要）
LOCAL_REPO_PATH="/path/to/repo"    # 本地仓库路径
# 或者如果当前目录就是仓库：LOCAL_REPO_PATH=""

# 其他配置保持默认即可
```

**本地仓库路径说明**：
- 如果本地仓库在指定路径：`LOCAL_REPO_PATH="/home/user/projects/your-repo"`
- 如果当前目录就是仓库：`LOCAL_REPO_PATH=""`
- 如果仓库在相对路径：`LOCAL_REPO_PATH="../my-project"`

### 3. 创建离线包

**方式一：完全基于配置文件（推荐）**
```bash
# 在项目根目录运行
./create_package.sh

# 成功后会生成：
# offline_pkg_20231201_your-project-name_main_depth10.tar.gz
```

**方式二：指定分支**
```bash
# 使用配置文件中的默认分支
./make_offline_package.sh

# 或指定特定分支
./make_offline_package.sh develop
```

### 4. 分发包

```bash
# 将包发送给开发者
scp offline_pkg_*.tar.gz developer@remote:/home/developer/
```

### 5. 接收并导入变化

当开发者返回变化时：
```bash
# 导入变化
./import_from_local.sh /path/to/local_out_20231201_143022

# 推送到远程
git push origin main
```

## 常用命令速查

| 操作 | 命令 | 说明 |
|------|------|------|
| 创建离线包（推荐） | `./create_package.sh` | 完全基于配置文件创建包 |
| 创建离线包（指定分支） | `./make_offline_package.sh [branch]` | 创建指定分支的包 |
| 导入变化 | `./import_from_local.sh <dir>` | 导入开发者的变化 |
| 验证配置 | `./config_root.sh` | 检查配置是否正确 |

## 配置文件说明

### 必须修改的配置

```bash
PROJECT_NAME="your-project-name"    # 项目名称
DEFAULT_BRANCH="main"               # 主分支
DEFAULT_DEPTH=10                   # 子模块深度
LOCAL_REPO_PATH="/path/to/repo"    # 本地仓库路径
```

### 可选修改的配置

```bash
COMPRESSION_FORMAT="tar.gz"        # 压缩格式
BACKUP_BEFORE_IMPORT=true          # 导入前备份
VERBOSE_LOGGING=true               # 详细日志
```

## 工作流程图

```
ROOT环境工作流程：

1. 配置 → 2. 创建包 → 3. 分发 → 4. 等待 → 5. 导入 → 6. 推送
   ↓         ↓         ↓         ↓         ↓         ↓
编辑配置   运行脚本   发送给    开发者    导入变化   推送到
config_   make_    开发者    离线开发    import_  远程仓库
root.sh   offline_ 包文件    并返回     from_    
         package.sh         变化包     local.sh
```

## 常见问题

### Q: 配置文件在哪里？
A: 在项目根目录的 `config_root.sh`

### Q: 如何修改子模块深度？
A: 在 `config_root.sh` 中修改 `DEFAULT_DEPTH=20`

### Q: 如何为不同分支创建包？
A: `./make_offline_package.sh <branch-name>`

### Q: 导入失败怎么办？
A: 检查冲突，手动解决后继续

## 下一步

1. 阅读详细文档：`ROOT_WORKFLOW.md`
2. 运行测试：`./test_system.sh`
3. 在实际项目中试用
4. 根据需要调整配置 