# Git 离线包管理器

> 通过工具脚本实现包含子模块的仓库离线同步与协作开发

---

## 🎯 快速开始

### 环境要求
- Git ≥ 2.20
- Bash 环境

### 仓库结构
```
slam-core/                    # 主仓库
├── .gitmodules              # 子模块配置
├── module_a/                # 子模块A
└── module_b/                # 子模块B
```

---

## 📋 工具概览

本工具集提供完整的离线开发工作流，包含以下脚本：

| 脚本 | 用途 | 使用场景 |
|------|------|----------|
| `export-full.sh` | 导出完整仓库包 | 服务器端发布 |
| `import-feature.sh` | 导入功能分支包 | 服务器端接收 |
| `init-from-bundle.sh` | 从包文件初始化仓库 | 本地端首次设置 |
| `create-feature-branch.sh` | 创建功能分支 | 本地开发准备 |
| `export-feature.sh` | 导出功能分支包 | 本地提交代码 |
| `update-from-server.sh` | 从服务器更新 | 本地同步更新 |

---

## ⚙️ 配置设置

### 1. 服务器端配置

编辑 `tools/server.config`：

```ini
[main]
repo_path=/srv/git/slam-core
output_dir=/srv/bundles
# modules=module_a,module_b  # 可选：不指定则自动检测
```

### 2. 本地端配置

编辑 `tools/local.config`：

```ini
[main]
repo_path=~/projects/slam-core
bundle_source=/media/usb
# modules=module_a,module_b  # 可选：不指定则自动检测
feature_branch=dev/awesome-feature
```

---

## 🚀 使用指南

### 1. 服务器端 - 导出完整仓库

```bash
cd tools
./export-full.sh
```

**功能：**
- 自动检测子模块
- 生成带时间戳的包目录
- 创建详细的导出报告
- 支持自定义配置文件

**输出：**
```
/srv/bundles/20241201_1430_bundles/
├── slam-core.bundle
├── module_a.bundle
├── module_b.bundle
└── bundle_report.md
```

### 2. 本地端 - 初始化仓库

```bash
cd tools
./init-from-bundle.sh
```

**功能：**
- 从包文件克隆主仓库
- 自动初始化所有子模块
- 智能检测分支名称（main/master）
- 提供后续步骤指导

**前置条件：**
- 确保包文件在 `bundle_source` 目录中
- 确保目标路径不存在

### 3. 创建功能分支

```bash
cd tools
./create-feature-branch.sh my-feature
```

**功能：**
- 为主仓库和所有子模块创建 `dev/my-feature` 分支
- 自动切换到新分支
- 验证分支名称格式
- 提供开发指导

### 4. 导出功能分支包

```bash
cd tools
./export-feature.sh
```

**功能：**
- 导出当前功能分支的增量包
- 自动检测子模块变更
- 生成标准命名的包文件
- 提供提交指导

**输出：**
```
./bundles/
├── slam-core-dev-my-feature.bundle
├── module_a-dev-my-feature.bundle
└── module_b-dev-my-feature.bundle
```

### 5. 服务器端 - 导入功能包

```bash
cd tools
./import-feature.sh /path/to/bundles
```

**功能：**
- 从指定目录导入所有功能包
- 自动匹配主仓库和子模块包
- 提取功能分支名称
- 提供合并指导

### 6. 同步服务器更新

```bash
cd tools
./update-from-server.sh
```

**功能：**
- 从服务器包更新本地仓库
- 智能处理功能分支和主分支
- 自动更新所有子模块
- 保持开发分支状态

---

## 📁 文件命名规范

| 类型 | 命名示例 | 说明 |
|------|----------|------|
| 完整包 | `slam-core.bundle` | 包含所有分支和标签 |
| 功能包 | `slam-core-dev-feature.bundle` | 增量包，仅包含变更 |
| 子模块包 | `module_a.bundle` | 子模块的完整包 |
| 子模块功能包 | `module_a-dev-feature.bundle` | 子模块的增量包 |

---

## 🔧 高级用法

### 使用自定义配置文件

```bash
# 服务器端
./export-full.sh /path/to/custom-server.config

# 本地端
./init-from-bundle.sh /path/to/custom-local.config
```

### 自动检测子模块

工具会自动从 `.gitmodules` 文件检测子模块，无需手动配置：

```bash
# 自动检测结果示例
Detected submodules: module_a,module_b
```

### 批量处理

```bash
# 批量创建多个功能分支
for feature in feature1 feature2 feature3; do
    ./create-feature-branch.sh $feature
done
```

---

## 🛠️ 故障排除

### 常见问题

| 问题 | 解决方案 |
|------|----------|
| 配置文件路径错误 | 检查 `repo_path` 和 `bundle_source` 路径 |
| 子模块未初始化 | 运行 `git submodule init` 后重试 |
| 包文件不存在 | 确保包文件在指定目录中 |
| 分支名称冲突 | 使用 `create-feature-branch.sh` 创建新分支 |

### 调试模式

所有脚本都支持详细输出，遇到问题时可以查看：

```bash
# 查看脚本执行过程
bash -x ./export-full.sh
```

---

## 📄 许可证

MIT License - 可自由修改与分发
