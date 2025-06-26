# Git Offline Bundle Manager - 变更日志

## 版本 2.5.0 - 新增跨平台配置测试脚本 (2025-01-01)

### 主要改进

#### 1. 新增跨平台test-config脚本
- **PowerShell版本**: `common/test-config.ps1` - Windows环境配置测试
- **Bash版本**: `common/test-config.sh` - Ubuntu环境配置测试
- **功能统一**: 两个版本提供相同的测试功能和输出格式

#### 2. 快速配置验证功能
- **自动环境检测**: 智能识别当前运行环境
- **路径访问测试**: 验证所有配置路径是否存在且可访问
- **Git配置验证**: 检查Git安装和用户配置
- **配置文件格式检查**: 验证JSON格式和结构完整性
- **实时状态反馈**: 带时间戳的彩色状态输出

#### 3. 用户体验改进
- **一键测试**: 无需复杂命令，直接运行脚本即可
- **详细报告**: 显示测试通过率和具体问题
- **修复建议**: 针对失败项提供具体的修复指导
- **支持参数**: 可指定特定环境进行测试

### 脚本功能特性

#### 测试项目
1. **配置文件读取** - 检查config.json是否存在且格式正确
2. **环境检测** - 自动识别当前运行环境
3. **Git安装检查** - 验证Git是否已安装
4. **环境配置验证** - 检查对应环境的配置是否存在
5. **路径配置测试** - 验证所有路径是否存在且可访问
6. **Git配置验证** - 检查用户名和邮箱是否已设置
7. **同步配置检查** - 验证同步相关配置
8. **全局配置验证** - 检查全局配置完整性

#### 输出格式
- **彩色状态**: 使用不同颜色区分OK、ERROR、WARNING、INFO
- **时间戳**: 每个状态都带有时间戳
- **测试总结**: 显示通过测试数量和总体结果
- **下一步指导**: 根据测试结果提供具体操作建议

### 使用方式

#### Windows环境
```powershell
# 自动检测环境并测试
.\common\test-config.ps1

# 指定环境测试
.\common\test-config.ps1 -Environment offline_windows
```

#### Ubuntu环境
```bash
# 自动检测环境并测试
./common/test-config.sh

# 指定环境测试
./common/test-config.sh offline_ubuntu

# 显示帮助信息
./common/test-config.sh --help
```

### 环境变量支持

#### 配置文件路径
- `CONFIG_FILE` - 指定配置文件路径（默认：config.json）

#### 示例输出
```
=== Git离线开发工具套件 - 配置测试 ===

[14:30:15] [INFO] 开始配置测试...

[14:30:15] [OK] 配置文件读取成功
[14:30:15] [INFO] 检测到的环境: offline_windows
[14:30:15] [OK] Git已安装: git version 2.40.0.windows.1
[14:30:15] [OK] 环境配置加载成功
[14:30:15] [INFO] 测试路径配置...
[14:30:15] [OK] 路径可访问: D:/Projects/github/slam-core
[14:30:15] [OK] 路径可访问: D:/Work/code/2025/0625/bundles
[14:30:15] [INFO] 测试Git配置...
[14:30:15] [OK] Git用户名: Your Name
[14:30:15] [WARNING] Git邮箱未设置或使用默认值
[14:30:15] [INFO] 测试同步配置...
[14:30:15] [OK] 同步配置存在
[14:30:15] [INFO] 测试全局配置...
[14:30:15] [OK] 全局配置存在

=== 测试总结 ===
[14:30:15] [INFO] 通过测试: 7/8
[14:30:15] [WARNING] 配置测试通过！可以开始使用Git离线开发工具套件

下一步操作:
1. 运行对应的初始化脚本
2. 开始离线开发工作
```

### 文档更新

- 更新README.md，添加test-config脚本说明
- 简化配置检查流程，使用新的测试脚本
- 更新命令速查表，包含新的测试命令
- 添加权限设置说明

### 向后兼容性

- 完全兼容现有配置文件结构
- 不影响现有脚本功能
- 提供更简单的配置验证方式

### 文件变化

#### 新增文件
- `common/test-config.ps1` - Windows配置测试脚本
- `common/test-config.sh` - Ubuntu配置测试脚本

#### 更新的文件
- `README.md` - 添加test-config脚本说明和使用指南
- `CHANGELOG.md` - 添加版本2.5.0变更记录

### 技术实现

#### PowerShell版本特性
- 使用PowerShell模块系统
- 集成现有的Config-Manager.psm1
- 支持参数验证和错误处理
- 彩色输出和格式化显示

#### Bash版本特性
- 使用jq进行JSON解析
- 支持ANSI颜色输出
- 完整的错误处理机制
- 跨平台兼容性

## 版本 2.4.0 - 脚本优化和冗余删除 (2025-01-01)

### 主要改进

#### 1. 脚本数量优化
- **减少脚本数量**：从14个脚本减少到8个脚本，减少43%
- **保留完整功能**：所有原有功能都得到保留，只是整合到更少的脚本中
- **提高维护性**：减少重复代码，降低维护成本

#### 2. 功能整合
- **自动同步工作流整合**：`auto-sync-workflow.ps1/sh` 现在包含备份、更新、合并功能
- **删除独立脚本**：以下功能已整合到主工作流中：
  - `backup-before-update.ps1/sh` - 备份功能整合到 `auto-sync-workflow`
  - `merge-local-changes.ps1/sh` - 合并功能整合到 `auto-sync-workflow`
  - `update-offline-repo.ps1/sh` - 更新功能整合到 `auto-sync-workflow`

#### 3. 通用工具简化
- **删除简单脚本**：以下过于简单的脚本被删除：
  - `Show-Config.ps1` - 功能直接通过 `Config-Manager.psm1` 模块调用
  - `Test-Config.ps1` - 功能直接通过 `Config-Manager.psm1` 模块调用

### 优化后的脚本结构

#### GitLab服务器环境 (2个脚本)
- `export_bundles.sh` - 从GitLab导出bundle文件
- `import_local_bundles.sh` - 导入本地bundle更新代码

#### Windows离线环境 (4个脚本)
- `setup-offline-repo.ps1` - 初始化离线仓库
- `auto-sync-workflow.ps1` - 自动同步工作流（包含备份、更新、合并功能）
- `create-bundle-from-local.ps1` - 从本地创建bundle
- `interactive-merge.ps1` - 交互式合并（高级冲突解决）

#### Ubuntu离线环境 (4个脚本)
- `setup-offline-repo.sh` - 初始化离线仓库
- `auto-sync-workflow.sh` - 自动同步工作流（包含备份、更新、合并功能）
- `create-bundle-from-local.sh` - 从本地创建bundle
- `interactive-merge.sh` - 交互式合并（高级冲突解决）

#### 通用工具 (2个文件)
- `Config-Manager.psm1` - PowerShell配置管理模块
- `Set-Environment.ps1` - 环境设置脚本

### 用户体验改进

#### 使用更简单
- **一键同步**：`auto-sync-workflow` 现在包含完整的同步流程
- **减少命令记忆**：用户只需要记住4个主要命令
- **配置检查简化**：直接使用模块函数，无需额外脚本

#### 维护更容易
- **减少重复代码**：相同功能不再分散在多个文件中
- **统一工作流**：所有同步操作都在一个脚本中完成
- **更好的错误处理**：整合后的脚本有更完整的错误处理

#### 文档更新
- 更新README.md反映新的脚本结构
- 简化命令速查表
- 更新使用示例

### 向后兼容性

- **功能完全保留**：所有原有功能都得到保留
- **配置文件不变**：配置文件结构和使用方式保持不变
- **工作流简化**：用户现在可以使用更少的命令完成相同的工作

### 文件变化

#### 删除的脚本
- `offline-windows/backup-before-update.ps1`
- `offline-windows/merge-local-changes.ps1`
- `offline-windows/update-offline-repo.ps1`
- `offline-ubuntu/backup-before-update.sh`
- `offline-ubuntu/merge-local-changes.sh`
- `offline-ubuntu/update-offline-repo.sh`
- `common/Show-Config.ps1`
- `common/Test-Config.ps1`

#### 更新的文件
- `README.md` - 更新脚本结构说明和使用指南
- `CHANGELOG.md` - 添加版本2.4.0变更记录

### 使用方式变化

#### 旧版本使用方式
```powershell
# 需要多个步骤
.\backup-before-update.ps1
.\update-offline-repo.ps1
.\merge-local-changes.ps1
```

#### 新版本使用方式
```powershell
# 一键完成所有操作
.\auto-sync-workflow.ps1
```

#### 配置检查方式
```powershell
# 旧版本
.\Show-Config.ps1
.\Test-Config.ps1

# 新版本
Import-Module .\common\Config-Manager.psm1
Show-Config
Test-Config
```

## 版本 2.3.0 - 脚本命名统一 (2025-01-01)

### 主要改进

#### 1. 脚本命名统一
- **统一Windows和Ubuntu脚本命名规范**，使用kebab-case命名风格
- Windows脚本从PascalCase改为kebab-case：`Auto-Sync-Workflow.ps1` → `auto-sync-workflow.ps1`
- 确保两个平台的脚本功能完全对等，数量一致

#### 2. 功能对等性完善
- **Ubuntu环境新增4个脚本**，与Windows环境功能完全一致：
  - `interactive-merge.sh` - 交互式合并
  - `merge-local-changes.sh` - 合并本地更改
  - `backup-before-update.sh` - 更新前备份
  - `update-offline-repo.sh` - 更新离线仓库

#### 3. 脚本功能对比
| 功能 | Windows脚本 | Ubuntu脚本 | 状态 |
|------|-------------|------------|------|
| 初始化仓库 | `setup-offline-repo.ps1` | `setup-offline-repo.sh` | ✅ 统一 |
| 自动同步 | `auto-sync-workflow.ps1` | `auto-sync-workflow.sh` | ✅ 统一 |
| 创建bundle | `create-bundle-from-local.ps1` | `create-bundle-from-local.sh` | ✅ 统一 |
| 交互式合并 | `interactive-merge.ps1` | `interactive-merge.sh` | ✅ 新增 |
| 合并本地更改 | `merge-local-changes.ps1` | `merge-local-changes.sh` | ✅ 新增 |
| 更新前备份 | `backup-before-update.ps1` | `backup-before-update.sh` | ✅ 新增 |
| 更新离线仓库 | `update-offline-repo.ps1` | `update-offline-repo.sh` | ✅ 新增 |

### 脚本重命名详情

#### Windows脚本重命名
- `Auto-Sync-Workflow.ps1` → `auto-sync-workflow.ps1`
- `Create-Bundle-From-Local.ps1` → `create-bundle-from-local.ps1`
- `Setup-OfflineRepo.ps1` → `setup-offline-repo.ps1`
- `Interactive-Merge.ps1` → `interactive-merge.ps1`
- `Merge-LocalChanges.ps1` → `merge-local-changes.ps1`
- `Backup-BeforeUpdate.ps1` → `backup-before-update.ps1`
- `Update-OfflineRepo.ps1` → `update-offline-repo.ps1`

#### Ubuntu脚本新增
- `interactive-merge.sh` - 交互式冲突解决
- `merge-local-changes.sh` - 自动合并本地更改
- `backup-before-update.sh` - 更新前自动备份
- `update-offline-repo.sh` - 从bundle更新仓库

### 用户体验改进

#### 命名一致性
- 所有脚本使用统一的kebab-case命名风格
- 跨平台脚本名称对应，便于记忆和使用
- 减少用户在不同平台间的学习成本

#### 功能完整性
- Ubuntu环境现在拥有与Windows环境完全相同的功能
- 支持完整的离线开发工作流
- 包括冲突解决、备份、更新等高级功能

#### 文档更新
- 更新README.md中的脚本名称和命令示例
- 更新命令速查表，反映新的命名规范
- 确保文档与实际脚本名称一致

### 向后兼容性

- 脚本功能完全保持不变
- 配置文件结构保持不变
- 只是脚本名称发生变化，需要更新使用习惯

### 文件变化

#### 重命名
- `offline-windows/Auto-Sync-Workflow.ps1` → `offline-windows/auto-sync-workflow.ps1`
- `offline-windows/Create-Bundle-From-Local.ps1` → `offline-windows/create-bundle-from-local.ps1`
- `offline-windows/Setup-OfflineRepo.ps1` → `offline-windows/setup-offline-repo.ps1`
- `offline-windows/Interactive-Merge.ps1` → `offline-windows/interactive-merge.ps1`
- `offline-windows/Merge-LocalChanges.ps1` → `offline-windows/merge-local-changes.ps1`
- `offline-windows/Backup-BeforeUpdate.ps1` → `offline-windows/backup-before-update.ps1`
- `offline-windows/Update-OfflineRepo.ps1` → `offline-windows/update-offline-repo.ps1`

#### 新增
- `offline-ubuntu/interactive-merge.sh`
- `offline-ubuntu/merge-local-changes.sh`
- `offline-ubuntu/backup-before-update.sh`
- `offline-ubuntu/update-offline-repo.sh`

#### 更新
- `README.md` - 更新脚本名称和命令示例
- `CHANGELOG.md` - 添加版本2.3.0变更记录

## 版本 2.2.0 - 配置优化和文档统一 (2025-01-01)

### 主要改进

#### 1. 配置文件结构优化
- **按环境分类配置**，让用户清楚知道在对应电脑改哪些配置
- 新增 `environments` 配置段，包含 `gitlab_server`、`offline_windows`、`offline_ubuntu`
- 新增 `global` 配置段，包含所有环境共享的全局配置
- 每个环境配置包含完整的 `paths`、`git`、`sync` 配置

#### 2. 配置管理模块重构
- 完全重写 `Config-Manager.psm1` 模块
- 支持新的环境分类配置结构
- 改进环境检测逻辑
- 增强配置验证功能

#### 3. 文档统一和简化
- **合并所有.md文件为一个清晰的README**
- 删除冗余文档：`README-Directory-Structure.md`、`QUICK-START.md`、`README-Enhanced.md`、`example-usage.md`
- 重新组织README结构，提高可读性
- 添加详细的配置说明和使用指南

### 配置文件结构变化

#### 旧版本结构
```json
{
  "paths": {
    "windows": { ... },
    "ubuntu": { ... }
  },
  "git": { ... },
  "sync": { ... }
}
```

#### 新版本结构
```json
{
  "environments": {
    "gitlab_server": {
      "description": "GitLab服务器环境配置（有GitLab权限的Ubuntu机器）",
      "paths": { ... },
      "git": { ... },
      "sync": { ... }
    },
    "offline_windows": {
      "description": "Windows离线开发环境配置（无GitLab权限的Windows机器）",
      "paths": { ... },
      "git": { ... },
      "sync": { ... }
    },
    "offline_ubuntu": {
      "description": "Ubuntu离线开发环境配置（无GitLab权限的Ubuntu机器）",
      "paths": { ... },
      "git": { ... },
      "sync": { ... }
    }
  },
  "global": {
    "description": "全局配置（所有环境共享）",
    "bundle": { ... },
    "workflow": { ... },
    "platform": { ... }
  }
}
```

### 用户体验改进

#### 配置更清晰
- 用户可以根据自己的环境直接修改对应的配置段
- 每个配置段都有明确的描述说明
- 避免配置混淆和错误

#### 文档更简洁
- 一个README文件包含所有必要信息
- 结构清晰，易于查找
- 减少文档维护成本

#### 配置管理更强大
- 支持环境自动检测
- 增强的配置验证
- 更好的错误提示

### 向后兼容性

- 提供了配置迁移指南
- 旧版本配置文件可以通过简单修改适配新结构
- 脚本功能保持不变

### 文件变化

#### 新增/修改
- `config.json` - 使用新的环境分类结构
- `config.example.json` - 更新示例配置
- `common/Config-Manager.psm1` - 完全重写
- `common/Show-Config.ps1` - 更新以支持新结构
- `common/Test-Config.ps1` - 更新以支持新结构
- `README.md` - 合并所有文档，重新组织

#### 删除
- `README-Directory-Structure.md`
- `QUICK-START.md`
- `README-Enhanced.md`
- `example-usage.md`

## 版本 2.1.0 - 目录结构重组 (2025-01-01)

### 主要改进

#### 1. 目录结构重组
- **按功能和使用环境重新组织脚本**
- 创建四个主要目录：`gitlab-server/`、`offline-windows/`、`offline-ubuntu/`、`common/`
- 提高项目可维护性和用户体验
- 清晰的功能分离和使用场景区分

#### 2. 新增Ubuntu离线环境支持
- 新增 `offline-ubuntu/` 目录
- 创建Ubuntu版本的离线开发脚本
- 与Windows版本功能对等，支持完整的离线开发流程

#### 3. 目录结构说明
- 新增 `README-Directory-Structure.md` 详细说明文档
- 更新主README文件，添加目录结构说明
- 提供清晰的使用指南和文件分类

### 新增目录和文件

#### `gitlab-server/` - GitLab服务器环境
- `export_bundles.sh` - 从GitLab导出bundle文件
- `import_local_bundles.sh` - 导入本地bundle更新代码

#### `offline-windows/` - Windows离线开发环境
- `Setup-OfflineRepo.ps1` - 初始化离线仓库
- `Auto-Sync-Workflow.ps1` - 自动同步工作流
- `Create-Bundle-From-Local.ps1` - 从本地创建bundle
- `Interactive-Merge.ps1` - 交互式合并
- `Merge-LocalChanges.ps1` - 合并本地更改
- `Backup-BeforeUpdate.ps1` - 更新前备份
- `Update-OfflineRepo.ps1` - 更新离线仓库

#### `offline-ubuntu/` - Ubuntu离线开发环境
- `setup-offline-repo.sh` - 初始化离线仓库
- `auto-sync-workflow.sh` - 自动同步工作流
- `create-bundle-from-local.sh` - 从本地创建bundle

#### `common/` - 通用工具
- `Config-Manager.psm1` - PowerShell配置管理模块
- `Show-Config.ps1` - 显示配置信息
- `Set-Environment.ps1` - 设置环境变量
- `Test-Config.ps1` - 测试配置

### 新增文档
- `README-Directory-Structure.md` - 目录结构详细说明
- 更新主README文件，添加目录结构和使用指南

### 使用方式变化

#### 旧版本（脚本在根目录）
```powershell
.\Auto-Sync-Workflow.ps1
.\Setup-OfflineRepo.ps1
```

#### 新版本（按目录组织）
```powershell
# Windows离线环境
.\offline-windows\Auto-Sync-Workflow.ps1
.\offline-windows\Setup-OfflineRepo.ps1

# Ubuntu离线环境
./offline-ubuntu/auto-sync-workflow.sh
./offline-ubuntu/setup-offline-repo.sh

# GitLab服务器环境
./gitlab-server/export_bundles.sh
./gitlab-server/import_local_bundles.sh

# 通用工具
.\common\Show-Config.ps1
.\common\Test-Config.ps1
```

### 功能对等性

#### Windows和Ubuntu离线环境功能对比
| 功能 | Windows脚本 | Ubuntu脚本 |
|------|-------------|------------|
| 初始化仓库 | `Setup-OfflineRepo.ps1` | `setup-offline-repo.sh` |
| 自动同步 | `Auto-Sync-Workflow.ps1` | `auto-sync-workflow.sh` |
| 创建bundle | `Create-Bundle-From-Local.ps1` | `create-bundle-from-local.sh` |

### 向后兼容性

- 所有脚本功能保持不变
- 配置文件结构保持不变
- 只是文件位置发生变化
- 提供了详细的迁移指南

### 用户体验改进

- 更清晰的文件组织
- 更容易找到相关脚本
- 更好的功能分离
- 支持Ubuntu离线环境

## 版本 2.0.0 - 统一配置系统 (2025-01-01)

### 主要改进

#### 1. 统一配置文件支持
- **所有脚本现在完全使用 `config.json` 配置文件**
- 移除了所有脚本的命令行参数依赖
- 用户只需修改配置文件即可运行所有脚本
- 支持环境变量覆盖配置

#### 2. 跨平台支持增强
- 自动检测Windows和Ubuntu环境
- 支持强制指定平台 (`force_platform` 配置)
- 统一的路径配置结构
- 改进的平台检测逻辑

#### 3. 配置系统重构
- 新增 `Config-Manager.psm1` 模块
- 支持点分隔的配置路径访问
- 环境变量覆盖支持
- 配置验证和状态检查

### 新增功能

#### 配置选项
- `platform.detect_automatically`: 自动平台检测
- `platform.force_platform`: 强制指定平台
- `sync.confirm_before_actions`: 操作前确认
- `bundle.main_repo_name`: 主仓库名称
- `workflow.auto_create_local_bundle`: 自动创建本地bundle
- `workflow.enable_interactive_mode`: 启用交互模式
- `workflow.show_detailed_status`: 显示详细状态

#### 新增脚本
- `Test-Config.ps1`: 配置系统测试脚本
- `example-usage.md`: 详细使用示例文档

### 修改的脚本

#### PowerShell脚本
- `Auto-Sync-Workflow.ps1`: 移除所有命令行参数
- `Update-OfflineRepo.ps1`: 移除命令行参数，使用配置文件
- `Create-Bundle-From-Local.ps1`: 移除命令行参数，使用配置文件
- `Interactive-Merge.ps1`: 移除命令行参数，使用配置文件
- `Merge-LocalChanges.ps1`: 移除命令行参数，使用配置文件
- `Backup-BeforeUpdate.ps1`: 移除命令行参数，使用配置文件
- `Setup-OfflineRepo.ps1`: 移除命令行参数，使用配置文件
- `Set-Environment.ps1`: 移除命令行参数，使用配置文件
- `Show-Config.ps1`: 增强配置状态显示

#### Shell脚本
- `export_bundles.sh`: 改进配置文件支持，支持平台检测
- `import_local_bundles.sh`: 改进配置文件支持，支持平台检测

#### 配置管理
- `Config-Manager.psm1`: 完全重写，新增多个功能函数
- `config.json`: 扩展配置结构，新增多个配置选项

### 配置文件结构

```json
{
  "paths": {
    "windows": {
      "repo_dir": "D:/Projects/github/slam-core",
      "bundles_dir": "D:/Work/code/2025/0625/bundles",
      "local_bundles_dir": "D:/Projects/github/slam-core/local-bundles",
      "backup_dir": "D:/Projects/github/slam-core-backups"
    },
    "ubuntu": {
      "repo_dir": "/work/develop_gitlab/slam-core",
      "bundles_dir": "/work/develop_gitlab/slam-core/bundles",
      "local_bundles_dir": "./local-bundles",
      "backup_dir": "/work/develop_gitlab/slam-core-backups"
    }
  },
  "git": {
    "user_name": "Your Name",
    "user_email": "your.email@company.com",
    "allow_protocol": "file"
  },
  "sync": {
    "backup_before_update": true,
    "create_diff_report": true,
    "auto_resolve_conflicts": false,
    "confirm_before_actions": true
  },
  "bundle": {
    "include_all_branches": false,
    "timestamp_format": "yyyyMMdd_HHmmss",
    "local_prefix": "local_",
    "main_repo_name": "slam-core"
  },
  "workflow": {
    "auto_create_local_bundle": false,
    "enable_interactive_mode": true,
    "show_detailed_status": true
  },
  "platform": {
    "detect_automatically": true,
    "force_platform": null
  }
}
```

### 环境变量支持

#### Windows环境变量
- `GIT_OFFLINE_REPO_DIR`
- `GIT_OFFLINE_BUNDLES_DIR`
- `GIT_OFFLINE_LOCAL_BUNDLES_DIR`
- `GIT_OFFLINE_BACKUP_DIR`
- `GIT_OFFLINE_USER_NAME`
- `GIT_OFFLINE_USER_EMAIL`

#### Ubuntu环境变量
- `GIT_OFFLINE_UBUNTU_REPO_DIR`
- `GIT_OFFLINE_UBUNTU_BUNDLES_DIR`
- `GIT_OFFLINE_UBUNTU_LOCAL_BUNDLES_DIR`
- `GIT_OFFLINE_UBUNTU_BACKUP_DIR`

### 使用方式变化

#### 旧版本（需要命令行参数）
```powershell
.\Auto-Sync-Workflow.ps1 -RepoDir "D:/Projects/github/slam-core" -BundlesDir "D:/Work/bundles"
```

#### 新版本（仅需配置文件）
```powershell
# 1. 编辑 config.json
# 2. 运行脚本
.\Auto-Sync-Workflow.ps1
```

### 向后兼容性

- 旧版本的配置文件仍然可以工作
- 环境变量覆盖仍然支持
- 脚本功能保持不变，只是参数传递方式改变

### 测试和验证

- 新增 `Test-Config.ps1` 脚本用于验证配置系统
- 所有脚本都经过测试，确保配置文件正常工作
- 提供了详细的使用示例和文档

### 文档更新

- 更新了 `README-Enhanced.md` 文档
- 新增了 `example-usage.md` 使用示例
- 提供了详细的配置说明和最佳实践

## 版本 1.x - 原始版本

### 功能
- 基本的离线Git开发支持
- 命令行参数配置
- Windows和Ubuntu环境支持
- Bundle导入导出功能

### 限制
- 需要命令行参数
- 配置分散在各个脚本中
- 平台检测不够灵活
- 缺乏统一的配置管理 