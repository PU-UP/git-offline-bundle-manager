# 配置文件使用指南

## 概述

Git离线包管理系统提供了两个简化的配置文件：

- `config_root.sh` - ROOT环境配置文件（有网络连接）
- `config_local.sh` - LOCAL环境配置文件（离线开发）

## 配置文件说明

### config_root.sh (ROOT环境)

```bash
# 基础配置（必需）
PROJECT_NAME="slam-core"        # 项目名称
DEFAULT_BRANCH="main"           # 默认分支
DEFAULT_DEPTH=10               # 子模块提交深度

# Git配置
MIN_GIT_VERSION="2.25.0"       # Git版本要求

# 打包配置
COMPRESSION_FORMAT="tar.gz"    # 压缩格式
CLEANUP_TEMP_FILES=true        # 清理临时文件

# 导入配置
BACKUP_BEFORE_IMPORT=true      # 导入前备份
MERGE_STRATEGY="recursive"     # 合并策略

# 日志配置
VERBOSE_LOGGING=true           # 详细日志
LOG_FILE="offline_package.log" # 日志文件
```

### config_local.sh (LOCAL环境)

```bash
# 基础配置（必需）
PROJECT_NAME="slam-core"        # 项目名称（与ROOT保持一致）
LOCAL_DEV_DIR="slam-core"      # 本地开发目录
SUBMODULES_DIR="submodules"    # 子模块目录
DEFAULT_BRANCH="main"          # 默认分支（与ROOT保持一致）

# Git配置
MIN_GIT_VERSION="2.25.0"       # Git版本要求
CHECK_UNCOMMITTED_CHANGES=true # 检查未提交更改

# 导出配置
VERIFY_BUNDLE_INTEGRITY=true   # 验证bundle完整性

# 日志配置
VERBOSE_LOGGING=true           # 详细日志
LOG_FILE="local_development.log" # 日志文件
```

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

### 配置调试

启用详细日志查看配置信息：

```bash
# 在配置文件中设置
VERBOSE_LOGGING=true

# 运行脚本查看详细输出
./make_offline_package.sh main 10
``` 