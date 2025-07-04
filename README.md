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
```

#### 方法2：使用环境变量
```bash
export SOURCE_REPO="/path/to/your/repo"
export BUNDLES_DIR="/path/to/bundles"
export RESTORE_DIR="/path/to/restore"
export MAIN_REPO_NAME="your-repo-name"
./create-bundle.sh
```

#### 查看当前配置
```bash
./config.sh
```

### 1. create-bundle.sh
将源仓库（包含所有子仓库）生成bundles并保存在配置的bundles目录中。

**功能特点：**
- 自动检测并处理Git子模块
- 为每个仓库创建Git bundle（包含所有分支）
- 生成tar.gz压缩包
- 创建bundle信息文件，记录仓库元数据

**使用方法：**
```bash
./create-bundle.sh
```

**输出：**
- `{BUNDLES_DIR}/{MAIN_REPO_NAME}.bundle` - 主仓库bundle
- `{BUNDLES_DIR}/{MAIN_REPO_NAME}-{submodule_name}.bundle` - 各子模块bundle
- `{BUNDLES_DIR}/bundle-info.txt` - bundle信息文件

### 2. restore-bundle.sh
将bundles目录中的bundles恢复成完整的代码仓库，保存在配置的恢复目录中。

**功能特点：**
- 自动恢复Git仓库结构
- 恢复所有分支和提交历史
- 自动重建子模块关系
- 保持原始的Git配置

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

1. **配置路径（可选）：**
   ```bash
   # 使用默认配置（test目录）
   ./config.sh
   
   # 或自定义配置
   cp config.example.sh config.sh
   # 编辑 config.sh
   ```

2. **创建bundles：**
   ```bash
   ./create-bundle.sh
   ```

3. **恢复仓库：**
   ```bash
   ./restore-bundle.sh
   ```

## 注意事项

- 确保系统已安装`git`和`tar`命令
- 脚本会自动检查必要的依赖和目录结构
- 恢复时会清空恢复目录
- 支持包含多个子模块的复杂Git仓库结构
- 配置文件支持环境变量覆盖，便于CI/CD集成

## 错误处理

脚本包含完整的错误处理机制：
- 检查必要的命令是否存在
- 验证目录结构
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
[INFO] 创建bundle: slam-core
[INFO]   检测到Git仓库，创建Git bundle...
[SUCCESS] Bundle创建完成: test/bundles/slam-core.tar.gz
[INFO] 处理子模块...
[INFO] 处理子模块: calibration-tools
[SUCCESS] Bundle创建完成: test/bundles/slam-core-calibration-tools.tar.gz
...
[SUCCESS] 所有bundles创建完成！
```

## 功能
- 打包：Git仓库 → 离线文件
- 恢复：离线文件 → Git仓库  
- 增量：离线变更 → 增量包
- 导入：增量包 → 原始仓库

## 脚本
- `create-bundle.sh` - 创建离线包
- `restore-bundle.sh` - 恢复仓库
- `config.sh` - 配置文件
- `config.example.sh` - 配置示例文件 