# 配置文件指南

## 概述

`config.json` 是 Git 离线包管理系统的核心配置文件，支持多环境配置和全局设置。

## 配置文件结构

### 环境配置 (environments)

每个环境包含以下配置项：

#### 路径配置 (paths)
- `repo_dir`: Git 仓库根目录路径
- `bundles_dir`: 导出包文件存储目录
- `local_bundles_dir`: 本地包文件存储目录
- `backup_dir`: 备份文件存储目录

#### Git 配置 (git)
- `user_name`: Git 用户名
- `user_email`: Git 邮箱地址

#### 同步配置 (sync)
- `backup_before_update`: 更新前是否备份 (true/false)
- `create_diff_report`: 是否创建差异报告 (true/false)
- `auto_resolve_conflicts`: 是否自动解决冲突 (true/false)
- `confirm_before_actions`: 操作前是否确认 (true/false)

### 全局配置 (global)

#### 包配置 (bundle)
- `include_all_branches`: 是否包含所有分支 (true/false)
- `main_repo_name`: 主仓库名称

#### 工作流配置 (workflow)
- `auto_create_local_bundle`: 是否自动创建本地包 (true/false)
- `enable_interactive_mode`: 是否启用交互模式 (true/false)

#### 平台配置 (platform)
- `force_platform`: 强制指定平台 (null 表示自动检测)

## 支持的环境

### 1. gitlab_server
GitLab 服务器环境（有 GitLab 访问权限的 Ubuntu 机器）

### 2. offline_windows
Windows 离线开发环境（无 GitLab 访问权限的 Windows 机器）

### 3. offline_ubuntu
Ubuntu 离线开发环境（无 GitLab 访问权限的 Ubuntu 机器）

## 配置示例

```json
{
  "environments": {
    "offline_ubuntu": {
      "description": "Ubuntu offline development environment",
      "paths": {
        "repo_dir": "/work/develop_gitlab/slam-core",
        "bundles_dir": "/work/develop_gitlab/slam-core/bundles",
        "local_bundles_dir": "./local-bundles",
        "backup_dir": "/work/develop_gitlab/slam-core-backups"
      },
      "git": {
        "user_name": "Your Name",
        "user_email": "your.email@company.com"
      },
      "sync": {
        "backup_before_update": true,
        "create_diff_report": true,
        "auto_resolve_conflicts": false,
        "confirm_before_actions": true
      }
    }
  },
  "global": {
    "bundle": {
      "include_all_branches": false,
      "main_repo_name": "slam-core"
    },
    "workflow": {
      "auto_create_local_bundle": false,
      "enable_interactive_mode": true
    },
    "platform": {
      "force_platform": null
    }
  }
}
```

## 环境变量覆盖

可以通过环境变量覆盖配置文件中的设置：

```bash
# 覆盖仓库目录
export GIT_OFFLINE_UBUNTU_REPO_DIR="/custom/repo/path"

# 覆盖本地包目录
export GIT_OFFLINE_UBUNTU_LOCAL_BUNDLES_DIR="/custom/bundles/path"

# 覆盖包目录
export GIT_OFFLINE_UBUNTU_BUNDLES_DIR="/custom/bundles/path"
```

## 平台检测

系统会自动检测当前平台，也可以通过 `force_platform` 强制指定：

```json
{
  "global": {
    "platform": {
      "force_platform": "offline_ubuntu"
    }
  }
}
```

## 配置验证

可以使用以下命令验证配置文件：

```bash
# 检查 JSON 语法
jq empty config.json

# 检查必需字段
jq -r '.environments.offline_ubuntu.paths.repo_dir' config.json
```

## 最佳实践

1. **路径配置**：使用绝对路径避免相对路径问题
2. **备份设置**：建议启用 `backup_before_update`
3. **确认机制**：建议启用 `confirm_before_actions` 避免误操作
4. **差异报告**：建议启用 `create_diff_report` 便于追踪变更
5. **分支管理**：根据需求设置 `include_all_branches`

## 故障排除

### 常见问题

1. **路径不存在**：确保配置的路径存在且有读写权限
2. **JSON 语法错误**：使用 `jq` 验证 JSON 语法
3. **权限问题**：确保对仓库目录有 Git 操作权限
4. **平台检测失败**：检查 `force_platform` 设置

### 调试技巧

```bash
# 启用调试模式
export GIT_OFFLINE_DEBUG=1

# 查看当前配置
jq '.' config.json

# 检查特定环境配置
jq '.environments.offline_ubuntu' config.json
``` 