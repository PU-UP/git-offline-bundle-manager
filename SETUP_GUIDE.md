# Git 离线包管理系统 - 设置指南

## 概述

本系统支持完全离线的Git开发工作流，通过三个路径配置实现灵活的离线包管理。

## 重要特性

1. **完全离线操作** - 不涉及远程Git仓库
2. **三路径配置** - 为ROOT和LOCAL环境分别提供三个独立路径
3. **避免/tmp依赖** - 所有临时操作都在配置路径中进行

## 快速设置

### 步骤1: 配置ROOT环境

1. 复制示例配置文件：
```bash
cp config_root_example.sh config_root.sh
```

2. 编辑 `config_root.sh`，设置三个路径：
```bash
# 1. slam-core所在位置（源仓库路径）
SLAM_CORE_PATH="/path/to/your/slam-core"

# 2. 把package生成到某个路径（输出目录）
PACKAGE_OUTPUT_PATH="/path/to/your/packages"

# 3. 从哪里import_from_local（导入来源路径）
IMPORT_SOURCE_PATH="/path/to/your/imports"
```

3. 验证配置：
```bash
./config_root.sh
```

### 步骤2: 配置LOCAL环境

1. 复制示例配置文件：
```bash
cp config_local_example.sh config_local.sh
```

2. 编辑 `config_local.sh`，设置三个路径：
```bash
# 1. slam-core所在位置（本地开发目录）
SLAM_CORE_PATH="/path/to/your/local/slam-core"

# 2. 从哪读取完整package（离线包路径）
PACKAGE_READ_PATH="/path/to/your/packages"

# 3. export changes到哪里（导出输出路径）
EXPORT_OUTPUT_PATH="/path/to/your/exports"
```

3. 验证配置：
```bash
./config_local.sh
```

## 使用流程

### ROOT环境（有网络连接）

1. **创建离线包**：
```bash
./make_offline_package.sh main
```

2. **导入本地变化**：
```bash
./import_from_local.sh
```

### LOCAL环境（离线开发）

1. **初始化本地仓库**：
```bash
tar -xzf offline_pkg_YYYYMMDD.tar.gz
./init_repository.sh
cd slam-core
```

2. **开发**：
```bash
# 在子模块中开发
cd submodule_name
git checkout -b feature/your-feature
# ... 开发代码 ...
git add . && git commit -m "新功能"

# 回到slam-core更新指针
cd ..
git add submodule_name
git commit -m "更新子模块指针"
```

3. **导出变化**：
```bash
./export_changes.sh
```

## 路径配置说明

### ROOT环境路径

| 路径变量 | 说明 | 示例 |
|---------|------|------|
| `SLAM_CORE_PATH` | slam-core源仓库位置 | `/home/user/projects/slam-core` |
| `PACKAGE_OUTPUT_PATH` | 离线包输出目录 | `/home/user/packages` |
| `IMPORT_SOURCE_PATH` | 导入文件来源目录 | `/home/user/imports` |

### LOCAL环境路径

| 路径变量 | 说明 | 示例 |
|---------|------|------|
| `SLAM_CORE_PATH` | 本地slam-core开发目录 | `/home/user/workspace/slam-core` |
| `PACKAGE_READ_PATH` | 离线包读取目录 | `/home/user/packages` |
| `EXPORT_OUTPUT_PATH` | 导出文件输出目录 | `/home/user/exports` |

## 常见问题

### Q: 为什么需要三个路径配置？
A: 三个路径配置提供了最大的灵活性，允许用户：
- 将源仓库、输出目录、导入目录分开管理
- 避免路径冲突和权限问题
- 支持不同的存储位置和备份策略

### Q: 可以不使用/tmp目录吗？
A: 是的，系统完全避免使用/tmp目录。所有临时操作都在配置的路径中进行，确保在任何环境下都能正常工作。

### Q: 如何验证配置是否正确？
A: 运行配置文件本身即可验证：
```bash
./config_root.sh    # 验证ROOT配置
./config_local.sh   # 验证LOCAL配置
```

### Q: 配置文件中的路径必须是绝对路径吗？
A: 建议使用绝对路径以确保稳定性，但相对路径也是支持的。

## 注意事项

1. **路径权限**：确保所有配置的路径都有适当的读写权限
2. **磁盘空间**：确保输出路径有足够的磁盘空间存储离线包
3. **路径一致性**：ROOT和LOCAL环境中的相关路径应该保持一致（如package路径）
4. **备份策略**：建议定期备份重要的配置和离线包

## 故障排除

### 配置验证失败
- 检查所有路径是否存在
- 确认路径有正确的权限
- 验证Git版本是否符合要求

### 脚本执行失败
- 检查配置文件是否正确加载
- 确认所有必需的环境变量都已设置
- 查看错误信息中的具体路径问题

### 导入/导出失败
- 确认源路径和目标路径都存在
- 检查文件权限
- 验证Git仓库状态 