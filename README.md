# Git离线开发工具套件

一套完整的Git离线开发解决方案，支持Windows和Ubuntu之间的代码同步，特别适用于无法直接访问GitLab的离线开发环境。

## 📁 目录结构

本项目按功能和使用环境将脚本分为四个主要目录：

### 🖥️ `gitlab-server/` - GitLab服务器环境
**用途**: 有访问GitLab权限的Ubuntu机器
**功能**: 
- 打包代码生成bundle文件
- 加载离线更新的bundle更新代码

**包含脚本**:
- `export_bundles.sh` - 从GitLab导出bundle文件
- `import_local_bundles.sh` - 导入本地bundle更新代码

### 🪟 `offline-windows/` - Windows离线开发环境
**用途**: 无GitLab访问权限的Windows机器
**功能**:
- 第一次部署（从bundle生成）
- 自动同步工作流（包含备份、更新、合并）
- 打包成bundle
- 交互式冲突解决

**包含脚本**:
- `setup-offline-repo.ps1` - 初始化离线仓库
- `auto-sync-workflow.ps1` - 自动同步工作流（包含备份、更新、合并功能）
- `create-bundle-from-local.ps1` - 从本地创建bundle
- `interactive-merge.ps1` - 交互式合并（高级冲突解决）

### 🐧 `offline-ubuntu/` - Ubuntu离线开发环境
**用途**: 无GitLab访问权限的Ubuntu机器
**功能**:
- 第一次部署（从bundle生成）
- 自动同步工作流（包含备份、更新、合并）
- 打包成bundle
- 交互式冲突解决

**包含脚本**:
- `setup-offline-repo.sh` - 初始化离线仓库
- `auto-sync-workflow.sh` - 自动同步工作流（包含备份、更新、合并功能）
- `create-bundle-from-local.sh` - 从本地创建bundle
- `interactive-merge.sh` - 交互式合并（高级冲突解决）

### 🔧 `common/` - 通用工具
**用途**: 所有环境共享的配置和工具
**功能**:
- 配置管理
- 环境设置
- 配置测试和显示

**包含文件**:
- `Config-Manager.psm1` - PowerShell配置管理模块
- `Set-Environment.ps1` - 环境设置脚本
- `test-config.ps1` - Windows配置测试脚本
- `test-config.sh` - Ubuntu配置测试脚本

## 🚀 快速开始

### 第一步：配置设置

1. **复制配置文件**：
```bash
cp config.example.json config.json
```

2. **编辑配置文件**：
根据您的环境修改对应的配置段：

#### GitLab服务器环境配置
```json
"gitlab_server": {
  "description": "GitLab服务器环境配置（有GitLab权限的Ubuntu机器）",
  "paths": {
    "repo_dir": "/work/develop_gitlab/slam-core",
    "bundles_dir": "/work/develop_gitlab/slam-core/bundles",
    "local_bundles_dir": "./local-bundles",
    "backup_dir": "/work/develop_gitlab/slam-core-backups"
  },
  "git": {
    "user_name": "Your Name",
    "user_email": "your.email@company.com"
  }
}
```

#### Windows离线环境配置
```json
"offline_windows": {
  "description": "Windows离线开发环境配置（无GitLab权限的Windows机器）",
  "paths": {
    "repo_dir": "D:/Projects/github/slam-core",
    "bundles_dir": "D:/Work/code/2025/0625/bundles",
    "local_bundles_dir": "D:/Projects/github/slam-core/local-bundles",
    "backup_dir": "D:/Projects/github/slam-core-backups"
  },
  "git": {
    "user_name": "Your Name",
    "user_email": "your.email@company.com"
  }
}
```

#### Ubuntu离线环境配置
```json
"offline_ubuntu": {
  "description": "Ubuntu离线开发环境配置（无GitLab权限的Ubuntu机器）",
  "paths": {
    "repo_dir": "/work/develop_gitlab/slam-core",
    "bundles_dir": "/work/develop_gitlab/slam-core/bundles",
    "local_bundles_dir": "./local-bundles",
    "backup_dir": "/work/develop_gitlab/slam-core-backups"
  },
  "git": {
    "user_name": "Your Name",
    "user_email": "your.email@company.com"
  }
}
```

3. **测试配置**：
```powershell
# Windows
.\common\test-config.ps1

# Ubuntu
./common/test-config.sh
```

### 第二步：开始使用

#### GitLab服务器端工作流
```bash
# 1. 导出最新代码
./gitlab-server/export_bundles.sh

# 2. 将bundles目录传输到离线环境

# 3. 接收离线环境的local bundle

# 4. 导入修改
./gitlab-server/import_local_bundles.sh local_20250101_120000

# 5. 提交到GitLab
git add .
git commit -m "从离线环境同步的修改"
git push
```

#### Windows离线端工作流
```powershell
# 1. 初始化离线仓库
.\offline-windows\setup-offline-repo.ps1

# 2. 进行开发工作
# ... 修改代码 ...
git add .
git commit -m "我的修改"

# 3. 同步更新（一键式，包含备份、更新、合并）
.\offline-windows\auto-sync-workflow.ps1

# 4. 创建同步包
.\offline-windows\create-bundle-from-local.ps1

# 5. 将local-bundles目录传输到GitLab服务器
```

#### Ubuntu离线端工作流
```bash
# 1. 初始化离线仓库
./offline-ubuntu/setup-offline-repo.sh

# 2. 进行开发工作
# ... 修改代码 ...
git add .
git commit -m "我的修改"

# 3. 同步更新（一键式，包含备份、更新、合并）
./offline-ubuntu/auto-sync-workflow.sh

# 4. 创建同步包
./offline-ubuntu/create-bundle-from-local.sh

# 5. 将local-bundles目录传输到GitLab服务器
```

## 📋 常用命令速查

### GitLab服务器环境
| 命令 | 用途 |
|------|------|
| `./export_bundles.sh` | 导出最新代码bundle |
| `./import_local_bundles.sh <prefix>` | 导入本地修改 |

### Windows离线环境
| 命令 | 用途 |
|------|------|
| `.\setup-offline-repo.ps1` | 初始化离线仓库 |
| `.\auto-sync-workflow.ps1` | 一键同步更新（包含备份、更新、合并） |
| `.\create-bundle-from-local.ps1` | 创建同步包 |
| `.\interactive-merge.ps1` | 交互式合并（高级冲突解决） |

### Ubuntu离线环境
| 命令 | 用途 |
|------|------|
| `./setup-offline-repo.sh` | 初始化离线仓库 |
| `./auto-sync-workflow.sh` | 一键同步更新（包含备份、更新、合并） |
| `./create-bundle-from-local.sh` | 创建同步包 |
| `./interactive-merge.sh` | 交互式合并（高级冲突解决） |

### 通用工具
| 命令 | 用途 |
|------|------|
| `.\common\test-config.ps1` | 快速测试配置（Windows） |
| `./common/test-config.sh` | 快速测试配置（Ubuntu） |
| `.\common\Set-Environment.ps1` | 设置环境变量 |

## ⚙️ 配置详解

### 环境配置结构
配置文件按环境分类，每个环境包含：

- **paths**: 路径配置
  - `repo_dir`: 仓库目录
  - `bundles_dir`: bundles文件目录
  - `local_bundles_dir`: 本地bundles输出目录
  - `backup_dir`: 备份目录

- **git**: Git配置
  - `user_name`: Git用户名
  - `user_email`: Git邮箱
  - `allow_protocol`: 允许的Git协议

- **sync**: 同步配置
  - `backup_before_update`: 更新前备份
  - `create_diff_report`: 创建差异报告
  - `auto_resolve_conflicts`: 自动解决冲突
  - `confirm_before_actions`: 操作前确认

### 全局配置
- **bundle**: Bundle配置
  - `include_all_branches`: 包含所有分支
  - `timestamp_format`: 时间戳格式
  - `local_prefix`: 本地前缀
  - `main_repo_name`: 主仓库名称

- **workflow**: 工作流配置
  - `auto_create_local_bundle`: 自动创建本地bundle
  - `enable_interactive_mode`: 启用交互模式
  - `show_detailed_status`: 显示详细状态

- **platform**: 平台配置
  - `detect_automatically`: 自动检测
  - `force_platform`: 强制指定平台

## 🔧 环境变量支持

### Windows环境变量
- `GIT_OFFLINE_REPO_DIR`
- `GIT_OFFLINE_BUNDLES_DIR`
- `GIT_OFFLINE_LOCAL_BUNDLES_DIR`
- `GIT_OFFLINE_BACKUP_DIR`
- `GIT_OFFLINE_USER_NAME`
- `GIT_OFFLINE_USER_EMAIL`

### Ubuntu环境变量
- `GIT_OFFLINE_UBUNTU_REPO_DIR`
- `GIT_OFFLINE_UBUNTU_BUNDLES_DIR`
- `GIT_OFFLINE_UBUNTU_LOCAL_BUNDLES_DIR`
- `GIT_OFFLINE_UBUNTU_BACKUP_DIR`

## ⚠️ 重要提示

1. **配置文件**: 所有脚本都使用 `config.json` 配置文件，无需命令行参数
2. **权限设置**: 在Ubuntu环境中，确保脚本有执行权限：
   ```bash
   chmod +x offline-ubuntu/*.sh
   chmod +x gitlab-server/*.sh
   chmod +x common/test-config.sh
   ```
3. **路径配置**: 确保配置文件中的路径正确且可访问
4. **备份**: 建议启用 `backup_before_update` 选项保护数据

## 🆘 故障排除

### 常见问题

1. **配置文件错误**
   ```powershell
   # Windows
   .\common\test-config.ps1
   
   # Ubuntu
   ./common/test-config.sh
   ```

2. **路径不存在**
   - 检查配置文件中的路径是否正确
   - 确保目录存在或有权限创建

3. **Git配置问题**
   - 确保Git用户名和邮箱已正确设置
   - 检查Git仓库状态

4. **权限问题**
   - Windows: 以管理员身份运行PowerShell
   - Ubuntu: 确保脚本有执行权限

### 获取帮助

1. 检查配置：`.\common\test-config.ps1` 或 `./common/test-config.sh`
2. 查看变更日志：`CHANGELOG.md`

## 📞 支持

- 所有脚本都有详细的注释和错误处理
- 配置文件支持环境变量覆盖
- 提供完整的测试和验证工具
- 支持跨平台使用（Windows/Ubuntu）

## 🔄 版本历史

### v2.4.0 - 脚本优化和冗余删除
- 减少脚本数量：从14个脚本减少到8个脚本，减少43%
- 自动同步工作流整合：包含备份、更新、合并功能
- 新增跨平台test-config脚本：快速验证配置
- 保留完整功能，提高维护性

### v2.3.0 - 脚本命名统一
- 统一Windows和Ubuntu脚本命名规范
- 确保两个平台的脚本功能完全对等
- 改进用户体验和文档

### v2.2.0 - 配置优化和文档统一
- 按环境分类配置结构
- 合并所有文档为一个清晰的README
- 改进配置管理模块

### v2.1.0 - 目录结构重组
- 按功能和使用环境重新组织脚本
- 新增Ubuntu离线环境支持
- 改进配置文件结构，按环境分类
- 统一文档，提高可读性

### v2.0.0 - 统一配置系统
- 所有脚本完全使用配置文件
- 移除命令行参数依赖
- 支持环境变量覆盖
- 改进平台检测逻辑

---

**Git离线开发工具套件** - 让离线开发更简单、更安全、更高效！ 