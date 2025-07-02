# 本地包管理使用说明

## 概述

本地包管理系统允许您在离线环境中创建本地修改的包文件，然后同步到GitLab服务器。系统会自动记录修改信息，并在导入时显示详细的变更记录。

## 主要改进

### 1. 简化的文件命名
- 移除了时间戳前缀，使用固定的文件名
- 主仓库包：`slam-core.bundle`
- 子模块包：`{submodule_path}.bundle`（路径中的 `/` 替换为 `_`）
- 信息文件：`local_info.json`
- 差异报告：`{main_repo_name}_diff_report.txt`

### 2. 详细的修改记录
系统会自动记录以下信息：
- **主仓库**：分支名、提交数量、修改文件数
- **子模块**：每个子模块的分支名、提交数量、修改文件数
- **Git状态**：创建时的未提交更改
- **时间戳**：包创建时间

### 3. 导入时的变更预览
在导入本地包时，系统会显示：
- 详细的变更记录摘要
- 每个仓库和子模块的修改统计
- 创建时的Git状态信息

## 使用方法

### 在离线环境创建本地包

```bash
# 进入离线环境目录
cd offline-ubuntu

# 创建本地包（会自动记录修改信息）
./create-bundle-from-local.sh

# 查看生成的修改摘要
cat local-bundles/local_info.json | jq '.change_records'
```

### 在GitLab服务器导入本地包

```bash
# 进入GitLab服务器目录
cd gitlab-server

# 导入本地包（会显示详细的变更记录）
./import_local_bundles.sh [local_bundles_dir]

# 示例
./import_local_bundles.sh /path/to/local-bundles
```

## 配置文件支持

系统支持通过 `config.json` 配置文件自定义行为：

```json
{
  "environments": {
    "offline_ubuntu": {
      "paths": {
        "repo_dir": "/work/develop_gitlab/slam-core",
        "local_bundles_dir": "./local-bundles"
      },
      "sync": {
        "create_diff_report": true,
        "confirm_before_actions": true
      }
    }
  },
  "global": {
    "bundle": {
      "include_all_branches": false,
      "main_repo_name": "slam-core"
    }
  }
}
```

## 环境变量支持

可以通过环境变量覆盖配置：

```bash
export GIT_OFFLINE_UBUNTU_REPO_DIR="/custom/repo/path"
export GIT_OFFLINE_UBUNTU_LOCAL_BUNDLES_DIR="/custom/bundles/path"
```

## 变更记录格式

生成的 `local_info.json` 文件包含详细的变更记录：

```json
{
  "timestamp": "2025-01-01 12:00:00",
  "main_bundle": "slam-core.bundle",
  "sub_bundles": ["third_party_opencv.bundle", "src_utils.bundle"],
  "created_at": "2025-01-01 12:00:00",
  "git_status": "M  src/main.cpp A  src/new_file.h",
  "change_records": {
    "main_repo": {
      "branch": "develop",
      "commit_count": "5",
      "files_changed": "12"
    },
    "submodules": {
      "third_party/opencv": {
        "branch": "main",
        "commit_count": "2",
        "files_changed": "3"
      }
    }
  }
}
```

## 注意事项

1. **确认机制**：系统会在覆盖现有文件前询问确认
2. **错误处理**：如果子模块路径不存在，会显示警告但继续处理
3. **依赖检查**：如果 `jq` 不可用，会使用简单的文本解析
4. **同步标签**：导入后会自动更新 `last-sync` 标签

## 故障排除

### 常见问题

1. **JSON解析错误**：确保安装了 `jq` 工具
2. **权限问题**：确保对仓库目录有读写权限
3. **路径问题**：检查配置文件中的路径是否正确

### 调试模式

可以通过设置环境变量启用调试：

```bash
export GIT_OFFLINE_DEBUG=1
./create-bundle-from-local.sh
``` 