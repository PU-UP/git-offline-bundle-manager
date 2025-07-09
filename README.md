# Git离线Bundle管理器

管理Git仓库的离线bundle，特别适用于包含子模块的大型项目。

## 快速开始

1. **配置**（可选）：
   ```bash
   cp config.example.sh config.sh
   # 编辑 config.sh 设置路径和分支参数
   ```

2. **创建bundle**：
   ```bash
   ./create-bundle.sh
   ```

3. **恢复仓库**：
   ```bash
   ./restore-bundle.sh
   ```
   
4. **导入bundle到已有仓库**：
   ```bash
   ./import-bundle.sh
   ```

## 脚本参数说明

### create-bundle.sh
**功能**：将源仓库（包含子模块）生成bundles

**参数**（通过环境变量或config.sh配置）：
- `SOURCE_REPO` - 源仓库路径（默认：`test/slam-core`）
- `BUNDLES_DIR` - bundles输出目录（默认：`test/bundles`）
- `MAIN_REPO_NAME` - 主仓库名称（默认：`slam-core`）
- `TARGET_BRANCH` - 目标分支，用于切换（默认：`release_2.3.7`）
- `RENAME_BRANCH` - 重命名分支，用于打包（默认：`your_custom_branch`）
- `FULL_CODE` - 是否打包完整代码（`true`/`false`，默认：`false`）

**输出**：
- `{BUNDLES_DIR}/{MAIN_REPO_NAME}.bundle` - 主仓库bundle
- `{BUNDLES_DIR}/{MAIN_REPO_NAME}-{submodule_name}.bundle` - 子模块bundle
- `{BUNDLES_DIR}/bundle-info.txt` - bundle信息文件

### restore-bundle.sh
**功能**：将bundles恢复成完整的代码仓库

**参数**（通过环境变量或config.sh配置）：
- `BUNDLES_DIR` - bundles输入目录（默认：`test/bundles`）
- `RESTORE_DIR` - 恢复目录（默认：`test/restored_repo`）
- `MAIN_REPO_NAME` - 主仓库名称（默认：`slam-core`）
- `RENAME_BRANCH` - 重命名分支，用于切换（默认：`your_custom_branch`）

**输出**：
- `{RESTORE_DIR}/{MAIN_REPO_NAME}/` - 完整的恢复后的仓库

### import-bundle.sh
**功能**：将bundles导入到已存在的代码仓库中

**参数**（支持命令行参数和环境变量）：
- `SOURCE_REPO` - 目标导入的代码仓库路径（必需）
- `BUNDLES_DIR` - bundles位置（必需）
- `RENAME_BRANCH` - 优先在bundle中寻找的分支名（可选）

**输出**：
- 将bundle中的内容导入到指定的目标仓库中
- 自动处理子模块导入
- 显示导入后的仓库状态信息

### config.sh
**功能**：配置文件，定义所有路径和分支参数

**配置项**：
- `DEFAULT_SOURCE_REPO` - 默认源仓库路径
- `DEFAULT_BUNDLES_DIR` - 默认bundles目录
- `DEFAULT_RESTORE_DIR` - 默认恢复目录
- `DEFAULT_MAIN_REPO_NAME` - 默认主仓库名称
- `DEFAULT_TARGET_BRANCH` - 默认目标分支
- `DEFAULT_RENAME_BRANCH` - 默认重命名分支
- `DEFAULT_FULL_CODE` - 默认是否打包完整代码

## 使用示例

### 基本使用
```bash
# 使用默认配置
./create-bundle.sh
./restore-bundle.sh
```

### 自定义配置
```bash
# 方法1：修改配置文件
cp config.example.sh config.sh
# 编辑 config.sh

# 方法2：使用环境变量
export SOURCE_REPO="/path/to/your/repo"
export TARGET_BRANCH="develop"
export RENAME_BRANCH="release-v1.0"
export FULL_CODE="true"
./create-bundle.sh
```

### 分支管理示例
```bash
# 从develop分支创建release bundle
export TARGET_BRANCH="develop"
export RENAME_BRANCH="release-v1.0"
export FULL_CODE="false"
./create-bundle.sh

# 打包完整代码用于离线开发
export TARGET_BRANCH="main"
export RENAME_BRANCH="offline-dev"
export FULL_CODE="true"
./create-bundle.sh
```

### 导入bundle示例
```bash
# 使用命令行参数
./import-bundle.sh -s /path/to/existing/repo -b /path/to/bundles -r feature/test

# 使用环境变量
export SOURCE_REPO="/path/to/existing/repo"
export BUNDLES_DIR="/path/to/bundles"
export RENAME_BRANCH="feature/test"
./import-bundle.sh
```

## 目录结构
```
.
├── create-bundle.sh          # 创建bundle脚本
├── restore-bundle.sh         # 恢复bundle脚本
├── import-bundle.sh          # 导入bundle脚本
├── config.sh                 # 配置文件
├── config.example.sh         # 配置示例文件
├── test/                     # 默认目录（可配置）
│   ├── slam-core/           # 原始仓库（包含子模块）
│   ├── bundles/             # 生成的bundle文件
│   └── restored_repo/       # 恢复后的仓库
└── README.md
```

## 注意事项

- 确保系统已安装`git`和`tar`命令
- 脚本会自动检查必要的依赖和目录结构
- 恢复时会清空恢复目录
- 支持包含多个子模块的复杂Git仓库结构
- 分支名称必须符合Git命名规范（字母、数字、斜杠、连字符、下划线、点）
- `FULL_CODE`参数只能是`true`或`false`

## 功能特点

- **智能分支管理**：自动切换目标分支，创建重命名分支
- **子模块支持**：自动检测和处理Git子模块
- **灵活配置**：支持配置文件和环境变量两种配置方式
- **空间优化**：可选择完整代码或仅当前分支
- **错误处理**：完整的错误检查和彩色输出 