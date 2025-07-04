# 配置文件使用指南

## 概述

本工具用于从本地Git仓库创建离线包，支持主项目和子模块的完整离线开发环境。

Git离线包管理系统提供了两个简化的配置文件：

- `config_root.sh` - ROOT环境配置文件（有网络连接）
- `config_local.sh` - LOCAL环境配置文件（离线开发）

## 配置文件说明

### config_root.sh (ROOT环境)

用于创建离线包的配置，包含以下主要设置：

#### 基础配置
- `PROJECT_NAME`: 项目名称（默认: "slam-core"）
- `DEFAULT_BRANCH`: 默认分支名称（默认: "main"）
- `DEFAULT_DEPTH`: 子模块提交深度，控制离线包大小（默认: 10）

#### 本地仓库配置
- `LOCAL_REPO_PATH`: **本地仓库路径**（重要配置）
  - 如果为空：假设当前目录就是Git仓库根目录
  - 相对路径：如 `"../my-project"` 或 `"../../repos/slam-core"`
  - 绝对路径：如 `"/home/user/projects/slam-core"`
  - 示例：`LOCAL_REPO_PATH="/path/to/your/local/repo"`

- `REMOTE_NAME`: 远程仓库名称（默认: "origin"）
- `SOURCE_REPO_URL`: 源仓库URL（可选，主要用于验证）

#### 打包配置
- `COMPRESSION_FORMAT`: 压缩格式（tar.gz, tar.bz2, tar.xz）
- `CLEANUP_TEMP_FILES`: 是否清理临时文件

#### 导入配置
- `BACKUP_BEFORE_IMPORT`: 导入前备份（默认: true）
- `MERGE_STRATEGY`: 合并策略（默认: "recursive"）

#### 日志配置
- `VERBOSE_LOGGING`: 详细日志（默认: true）
- `LOG_FILE`: 日志文件（默认: "offline_package.log"）

### config_local.sh (LOCAL环境)

用于本地开发环境的配置：

#### 基础配置
- `PROJECT_NAME`: 项目名称（应与ROOT环境一致）
- `LOCAL_DEV_DIR`: 本地开发目录名称
- `SUBMODULES_DIR`: 子模块目录名称
- `DEFAULT_BRANCH`: 默认分支名称（应与ROOT环境一致）

#### 本地仓库配置
- `LOCAL_REPO_PATH`: 本地仓库路径
  - 如果为空：使用 `LOCAL_DEV_DIR` 作为路径
  - 示例：`LOCAL_REPO_PATH="./slam-core"`

#### Git配置
- `MIN_GIT_VERSION`: Git版本要求（默认: "2.25.0"）
- `CHECK_UNCOMMITTED_CHANGES`: 检查未提交更改（默认: true）

#### 导出配置
- `VERIFY_BUNDLE_INTEGRITY`: 验证bundle完整性（默认: true）

#### 日志配置
- `VERBOSE_LOGGING`: 详细日志（默认: true）
- `LOG_FILE`: 日志文件（默认: "local_development.log"）

## 常用配置修改

### 1. 修改项目名称

**在两个配置文件中同时修改**：
```bash
PROJECT_NAME="your-project-name"
```

### 2. 修改默认分支

**在两个配置文件中同时修改**：
```bash
DEFAULT_BRANCH="develop"
```

### 3. 调整子模块深度

**只在config_root.sh中修改**：
```bash
DEFAULT_DEPTH=20  # 包含更多历史提交
```

### 4. 修改压缩格式

**只在config_root.sh中修改**：
```bash
COMPRESSION_FORMAT="tar.bz2"  # 或 tar.xz
```

### 5. 禁用详细日志

**在两个配置文件中同时修改**：
```bash
VERBOSE_LOGGING=false
```

## 配置验证

验证配置文件是否正确：

```bash
# 验证ROOT环境配置
./config_root.sh

# 验证LOCAL环境配置
./config_local.sh
```

## 使用配置

在脚本中使用配置：

```bash
# 加载ROOT环境配置
source config_root.sh
export_config

# 使用配置变量
echo "项目名称: $PROJECT_NAME"
echo "默认分支: $DEFAULT_BRANCH"
```

## 注意事项

1. **配置一致性**: `PROJECT_NAME`和`DEFAULT_BRANCH`必须在两个配置文件中保持一致
2. **必需配置**: 基础配置中的所有项目都是必需的，不能为空
3. **子模块自动检测**: 系统会自动从`.gitmodules`文件读取子模块，无需手动配置
4. **Git版本**: 确保系统Git版本满足要求（2.25.0+）
5. **本地仓库路径**：确保指定的路径是一个有效的Git仓库（包含 `.git` 目录）
6. **权限**：确保脚本有权限访问指定的本地仓库路径
7. **分支存在**：确保指定的分支在本地仓库中存在
8. **子模块**：如果项目包含子模块，确保子模块已正确初始化

## 故障排除

### 常见错误

1. **项目名称不匹配**：
   ```
   错误: ROOT和LOCAL环境的PROJECT_NAME不一致
   解决: 确保两个配置文件中的PROJECT_NAME相同
   ```

2. **Git版本过低**：
   ```
   错误: Git版本过低，需要 2.25.0 或更高版本
   解决: 升级Git版本
   ```

3. **无效的压缩格式**：
   ```
   错误: 不支持的压缩格式: invalid_format
   解决: 使用支持的格式: tar.gz, tar.bz2, tar.xz
   ```

4. **本地仓库路径不存在**：
   ```
   错误: 本地仓库路径不存在: /path/to/repo
   ```
   **解决方案**：检查 `LOCAL_REPO_PATH` 配置是否正确，确保路径存在。

5. **指定的路径不是Git仓库**：
   ```
   错误: 指定的路径不是Git仓库: /path/to/repo
   ```
   **解决方案**：确保指定路径包含 `.git` 目录，是一个有效的Git仓库。

6. **分支不存在**：
   ```
   错误: 分支 'main' 不存在
   ```
   **解决方案**：检查本地仓库中是否存在指定的分支，或修改 `DEFAULT_BRANCH` 配置。

### 配置调试

启用详细日志查看配置信息：

```bash
# 在配置文件中设置
VERBOSE_LOGGING=true

# 运行脚本查看详细输出
./make_offline_package.sh main 10
``` 