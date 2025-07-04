# Git 离线包管理系统

这是一个用于管理大型Git项目（包含子模块）的离线开发解决方案，特别适用于网络受限或需要离线开发的环境。

## 系统概述

该系统通过Git bundle技术实现离线开发，支持：
- 首次全量分发
- 增量更新
- 子模块管理
- 自动合并

## 工作流程

```
阶段    角色    脚本/动作    产物    备注
① 首次分发    ROOT    make_offline_package.sh <branch> <depth>    offline_pkg_YYYYMMDD.tar.gz    slam-core.bundle（空架子）+ submodules/*.bundle（各子模块最近 N 次提交）    Git 2.25；仅一次全量
② 初始化    LOCAL    解压包 → clone+init 子模块（脚本已内嵌）    本地可编辑仓库    子模块拥有 Git 历史
③ 开发    LOCAL    在子模块建分支 feature/*，正常 commit；回到 slam-core 提交指针    —    无需管远程
④ 交付差分    LOCAL    export_changes.sh    local_out_<ts>/    └ slam-core.delta.bundle    └ submodules/*.delta.bundle    只含增量，通常几 MB
⑤ 导入合并    ROOT    import_from_local.sh /path/to/local_out    本地新分支 + 合并 commit    通过后 git push/MR
⑥ 周期循环    ROOT → LOCAL    再跑 ①（增量），LOCAL fetch 后继续 ③    —    迭代轻量进行
```

## 脚本说明

### 1. 离线包创建脚本

#### create_package.sh - 完全基于配置文件的脚本（推荐）

**功能**: 使用配置文件中的所有参数创建离线包

**用法**: 
```bash
./create_package.sh
```

**特点**: 无需任何参数，完全基于配置文件

**示例**:
```bash
./create_package.sh
```

#### make_offline_package.sh - 可指定分支的脚本

**功能**: 创建包含slam-core和子模块的离线包

**用法**: 
```bash
./make_offline_package.sh [branch]
```

**参数**:
- `branch`: 可选，要打包的分支名（如 main）。不指定则使用配置文件中的默认分支

**示例**:
```bash
./make_offline_package.sh        # 使用配置文件中的默认分支
./make_offline_package.sh main   # 使用指定的分支
```

**注意**: depth参数在`config_root.sh`中配置

**产物**:
- `offline_pkg_YYYYMMDD.tar.gz` - 完整的离线包
- 包含 `slam-core.bundle` 和 `submodules/*.bundle`
- 自动生成 `init_repository.sh` 初始化脚本

### 2. export_changes.sh - 交付差分脚本

**功能**: 导出本地开发的变化，创建增量bundle

**用法**: 
```bash
./export_changes.sh
```

**要求**: 在slam-core目录中运行

**产物**:
- `local_out_<timestamp>/` - 增量包目录
- `slam-core.delta.bundle` - 主项目增量
- `submodules/*.delta.bundle` - 子模块增量

### 3. import_from_local.sh - 导入合并脚本

**功能**: 将本地开发的变化导入到ROOT环境

**用法**: 
```bash
./import_from_local.sh /path/to/local_out
```

**参数**:
- `local_out`: 本地导出目录的路径

**示例**:
```bash
./import_from_local.sh ./local_out_20231201_143022
```

## 使用步骤

### 阶段①: 首次分发 (ROOT环境)

1. 在包含子模块的Git仓库中运行：
```bash
# 方式一：完全基于配置文件（推荐）
./create_package.sh

# 方式二：指定分支
./make_offline_package.sh main
```

2. 将生成的 `offline_pkg_YYYYMMDD.tar.gz` 分发给开发者

### 阶段②: 初始化 (LOCAL环境)

1. 解压离线包：
```bash
tar -xzf offline_pkg_YYYYMMDD.tar.gz
```

2. 运行初始化脚本：
```bash
./init_repository.sh
```

3. 进入开发目录：
```bash
cd slam-core
```

### 阶段③: 开发 (LOCAL环境)

1. 在子模块中创建功能分支：
```bash
cd submodule_name
git checkout -b feature/your-feature
```

2. 正常开发并提交：
```bash
# 修改代码
git add .
git commit -m "添加新功能"
```

3. 回到slam-core提交指针更新：
```bash
cd ..
git add submodule_name
git commit -m "更新子模块指针"
```

### 阶段④: 交付差分 (LOCAL环境)

1. 在slam-core目录中运行：
```bash
./export_changes.sh
```

2. 将生成的 `local_out_<timestamp>/` 目录复制到ROOT环境

### 阶段⑤: 导入合并 (ROOT环境)

1. 在原始Git仓库中运行：
```bash
./import_from_local.sh /path/to/local_out_<timestamp>
```

2. 检查合并结果并推送到远程：
```bash
git log --oneline -10  # 检查导入的提交
git push origin main   # 推送到远程
```

### 阶段⑥: 周期循环

重复阶段①-⑤，进行增量更新。

## 系统要求

- **Git版本**: 2.25+ (兼容Ubuntu 20.04的Git 2.25.1)
- **操作系统**: Linux (Ubuntu 20.04+)
- **权限**: 脚本需要执行权限

## 配置文件

系统提供了两个简化的配置文件，让用户可以通过修改配置文件来定制系统行为：

- **`config_root.sh`** - ROOT环境配置文件（有网络连接）
- **`config_local.sh`** - LOCAL环境配置文件（离线开发）

### 快速配置

1. **修改项目名称**：
   ```bash
   # 在两个配置文件中同时修改
   PROJECT_NAME="your-project-name"
   ```

2. **修改默认分支**：
   ```bash
   # 在两个配置文件中同时修改
   DEFAULT_BRANCH="develop"
   ```

3. **调整子模块深度**：
   ```bash
   # 只在config_root.sh中修改
   DEFAULT_DEPTH=20
   ```

4. **验证配置**：
   ```bash
   ./config_root.sh    # 验证ROOT环境配置
   ./config_local.sh   # 验证LOCAL环境配置
   ```

详细配置说明请参考：`CONFIG_GUIDE.md`

## 注意事项

1. **Git版本兼容性**: 确保使用Git 2.25+版本
2. **子模块管理**: 所有代码都在子模块中，slam-core只保存指针
3. **增量更新**: 每轮只传输差分，通常几MB大小
4. **冲突处理**: 导入时如遇冲突需要手动解决
5. **备份**: 建议在重要操作前备份数据

## 故障排除

### 常见问题

1. **权限错误**: 确保脚本有执行权限
```bash
chmod +x *.sh
```

2. **Git版本过低**: 检查Git版本
```bash
git --version
```

3. **子模块问题**: 确保子模块正确初始化
```bash
git submodule update --init --recursive
```

4. **合并冲突**: 手动解决冲突后继续
```bash
# 解决冲突
git add .
git commit
```

### 调试模式

在脚本开头添加调试信息：
```bash
set -x  # 显示执行的命令
```

## 扩展功能

- **自动化**: 可以集成到CI/CD流程
- **版本管理**: 支持多版本离线包管理
- **压缩优化**: 支持不同的压缩算法
- **安全**: 可以添加签名验证
- **配置化**: 支持通过配置文件定制系统行为
- **并行处理**: 支持多核并行处理提高性能
- **通知系统**: 支持邮件通知和自定义钩子

## 文件结构

```
git-offline-bundle-manager/
├── make_offline_package.sh    # 首次分发脚本
├── export_changes.sh          # 交付差分脚本
├── import_from_local.sh       # 导入合并脚本
├── config_root.sh             # ROOT环境配置文件
├── config_local.sh            # LOCAL环境配置文件
├── test_system.sh             # 系统测试脚本
├── README.md                  # 详细使用文档
├── QUICKSTART.md              # 快速开始指南
├── CONFIG_GUIDE.md            # 配置文件使用指南
└── .gitignore                 # Git忽略文件
```

## 贡献

欢迎提交Issue和Pull Request来改进这个系统。
