# Git离线Bundle管理器

这个项目提供了脚本来管理Git仓库的离线bundle，特别适用于包含子模块的大型项目。支持灵活的路径配置，不再局限于固定的test目录。

## 脚本说明

## 配置说明

### 配置文件
项目使用 `config.sh` 文件来管理所有路径配置。默认配置使用 `test/` 目录，但可以通过以下方式自定义：

#### 方法1：修改配置文件
复制 `config.example.sh` 为 `config.sh` 并修改配置：
```bash
cp config.example.sh config.sh
# 编辑 config.sh 文件，修改以下变量：
# DEFAULT_SOURCE_REPO="your/repo/path"      # 源仓库路径
# DEFAULT_BUNDLES_DIR="your/bundles/path"   # bundles输出目录
# DEFAULT_RESTORE_DIR="your/restore/path"   # 恢复目录
# DEFAULT_MAIN_REPO_NAME="your-repo-name"   # 主仓库名称
# DEFAULT_TARGET_BRANCH="main"              # 目标分支（用于切换）
# DEFAULT_RENAME_BRANCH="bundle-branch"     # 重命名分支（用于打包）
# DEFAULT_FULL_CODE="false"                 # 是否打包完整代码（true/false）
```

#### 方法2：使用环境变量
```bash
export SOURCE_REPO="/path/to/your/repo"
export BUNDLES_DIR="/path/to/bundles"
export RESTORE_DIR="/path/to/restore"
export MAIN_REPO_NAME="your-repo-name"
export TARGET_BRANCH="develop"
export RENAME_BRANCH="release-v1.0"
export FULL_CODE="true"
./create-bundle.sh
```

#### 查看当前配置
```bash
./config.sh
```

### 新增配置参数说明

#### TARGET_BRANCH（目标分支）
- **作用**：指定在创建bundle前要切换到的目标分支
- **默认值**：`main`
- **使用场景**：当子模块处于detached HEAD状态时，先切换到目标分支再创建重命名分支

#### RENAME_BRANCH（重命名分支）
- **作用**：指定用于打包的重命名分支名称
- **默认值**：`bundle-branch`
- **使用场景**：基于此分支创建bundle，避免影响原始分支

#### FULL_CODE（是否打包完整代码）
- **作用**：控制是否打包所有分支或仅当前分支
- **默认值**：`false`
- **选项**：
  - `true`：打包所有分支和标签（完整代码）
  - `false`：仅打包重命名分支（节省空间）

### 1. create-bundle.sh
将源仓库（包含所有子仓库）生成bundles并保存在配置的bundles目录中。

**功能特点：**
- 自动检测并处理Git子模块
- 智能分支切换：先切换到目标分支，再创建重命名分支
- 支持detached HEAD状态的子模块处理
- 根据配置选择打包完整代码或仅当前分支
- 为每个仓库创建Git bundle
- 生成bundle信息文件，记录仓库元数据和配置信息

**工作流程：**
1. 切换主仓库到目标分支
2. 使用`git submodule foreach`切换所有子模块到目标分支
3. 回到主仓库，切换到重命名分支
4. 基于重命名分支创建bundle

**使用方法：**
```bash
./create-bundle.sh
```

**输出：**
- `{BUNDLES_DIR}/{MAIN_REPO_NAME}.bundle` - 主仓库bundle
- `{BUNDLES_DIR}/{MAIN_REPO_NAME}-{submodule_name}.bundle` - 各子模块bundle
- `{BUNDLES_DIR}/bundle-info.txt` - bundle信息文件（包含配置信息）

### 2. restore-bundle.sh
将bundles目录中的bundles恢复成完整的代码仓库，保存在配置的恢复目录中。

**功能特点：**
- 自动恢复Git仓库结构
- 根据FULL_CODE配置恢复相应数量的分支
- 自动重建子模块关系
- 保持原始的Git配置
- 显示bundle信息文件中的配置信息
- 显示恢复后的分支信息

**使用方法：**
```bash
./restore-bundle.sh
```

**输出：**
- `{RESTORE_DIR}/{MAIN_REPO_NAME}/` - 完整的恢复后的仓库

## 目录结构

```
.
├── create-bundle.sh          # 创建bundle脚本
├── restore-bundle.sh         # 恢复bundle脚本
├── config.sh                 # 配置文件
├── config.example.sh         # 配置示例文件
├── test/                     # 默认目录（可配置）
│   ├── slam-core/           # 原始仓库（包含子模块）
│   ├── bundles/             # 生成的bundle文件
│   └── restored_repo/       # 恢复后的仓库
└── README.md
```

## 使用流程

1. **配置路径和分支参数（可选）：**
   ```bash
   # 使用默认配置（test目录）
   ./config.sh
   
   # 或自定义配置
   cp config.example.sh config.sh
   # 编辑 config.sh，设置分支和打包选项
   ```

2. **创建bundles：**
   ```bash
   ./create-bundle.sh
   ```

3. **恢复仓库：**
   ```bash
   ./restore-bundle.sh
   ```

## 分支管理示例

### 场景1：从develop分支创建release bundle
```bash
export TARGET_BRANCH="develop"
export RENAME_BRANCH="release-v1.0"
export FULL_CODE="false"
./create-bundle.sh
```

### 场景2：打包完整代码用于离线开发
```bash
export TARGET_BRANCH="main"
export RENAME_BRANCH="offline-dev"
export FULL_CODE="true"
./create-bundle.sh
```

### 场景3：处理detached HEAD状态的子模块
```bash
export TARGET_BRANCH="main"
export RENAME_BRANCH="stable"
export FULL_CODE="false"
./create-bundle.sh
```

## 注意事项

- 确保系统已安装`git`和`tar`命令
- 脚本会自动检查必要的依赖和目录结构
- 恢复时会清空恢复目录
- 支持包含多个子模块的复杂Git仓库结构
- 配置文件支持环境变量覆盖，便于CI/CD集成
- 分支名称必须符合Git命名规范（字母、数字、斜杠、连字符、下划线、点）
- FULL_CODE参数只能是`true`或`false`

## 错误处理

脚本包含完整的错误处理机制：
- 检查必要的命令是否存在
- 验证目录结构
- 验证分支名称格式
- 验证FULL_CODE参数值
- 提供彩色输出信息
- 遇到错误时自动退出

## 示例输出

创建bundle时的输出示例：
```
[INFO] 开始创建slam-core仓库的bundles...
[INFO] 检查必要的命令...
[SUCCESS] 所有必要的命令都已找到
[INFO] 检查目录结构...
[SUCCESS] 目录结构检查完成
[INFO] 配置信息:
[INFO]   目标分支: main
[INFO]   重命名分支: bundle-branch
[INFO]   打包完整代码: false
[INFO] 第一步：切换主仓库到目标分支 main
[INFO] 切换仓库 test/slam-core 到分支 main
[INFO]   当前分支: main
[INFO]   切换到重命名分支 bundle-branch
[INFO] 第二步：切换所有子模块到目标分支 main
[INFO] 切换所有子模块到目标分支...
[INFO] 第三步：主仓库切换到重命名分支 bundle-branch
[INFO] 第四步：基于重命名分支创建bundles
[INFO] 创建bundle: slam-core
[INFO]   检测到Git仓库，创建Git bundle...
[INFO]   仅打包当前分支 bundle-branch
[SUCCESS] Bundle创建完成: test/bundles/slam-core.bundle
...
[SUCCESS] 所有bundles创建完成！
```

恢复bundle时的输出示例：
```
[INFO] 开始恢复bundles...
[INFO] 读取bundle信息文件...
=== Bundle信息 ===
#   目标分支: main
#   重命名分支: bundle-branch
#   打包完整代码: false
==================
[INFO] 当前配置信息:
[INFO]   目标分支: main
[INFO]   重命名分支: bundle-branch
[INFO]   打包完整代码: false
[INFO] 恢复主仓库...
[INFO] 恢复bundle: slam-core
[INFO]   检测到Git bundle，使用git clone恢复...
[INFO]   恢复完成，当前分支: bundle-branch
[INFO]   可用分支数量: 1
[SUCCESS] Bundle恢复完成: test/restored_repo/slam-core
...
[SUCCESS] 所有bundles恢复完成！
```

## 功能
- 打包：Git仓库 → 离线文件
- 恢复：离线文件 → Git仓库  
- 增量：离线变更 → 增量包
- 导入：增量包 → 原始仓库
- 分支管理：智能切换和重命名分支
- 空间优化：可选择完整代码或仅当前分支

## 脚本
- `create-bundle.sh` - 创建离线包
- `restore-bundle.sh` - 恢复仓库
- `config.sh` - 配置文件
- `config.example.sh` - 配置示例文件 