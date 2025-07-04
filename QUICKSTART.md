# 快速开始指南

## 5分钟快速上手

### 1. 环境准备

确保您的系统满足以下要求：
- Git 2.25+ (Ubuntu 20.04默认版本)
- Bash shell
- 执行权限

```bash
# 检查Git版本
git --version

# 给脚本添加执行权限
chmod +x *.sh
```

### 2. 测试系统

运行测试脚本验证系统功能：

```bash
./test_system.sh
```

### 3. 实际使用

#### ROOT环境（有网络连接）

1. **创建离线包**：
```bash
./make_offline_package.sh main
```

2. **分发包**：
将生成的 `offline_pkg_YYYYMMDD.tar.gz` 复制给开发者

#### LOCAL环境（离线开发）

1. **解压并初始化**：
```bash
tar -xzf offline_pkg_YYYYMMDD.tar.gz
./init_repository.sh
cd slam-core
```

2. **开始开发**：
```bash
# 在子模块中开发
cd submodule_name
git checkout -b feature/your-feature
# 修改代码...
git add .
git commit -m "添加功能"

# 回到主仓库更新指针
cd ..
git add submodule_name
git commit -m "更新子模块指针"
```

3. **导出变化**：
```bash
./export_changes.sh
```

#### ROOT环境（导入变化）

1. **导入并合并**：
```bash
./import_from_local.sh /path/to/local_out_<timestamp>
```

2. **推送到远程**：
```bash
git push origin main
```

## 常用命令速查

| 操作 | ROOT环境 | LOCAL环境 |
|------|----------|-----------|
| 创建离线包 | `./make_offline_package.sh main` | - |
| 初始化仓库 | - | `./init_repository.sh` |
| 导出变化 | - | `./export_changes.sh` |
| 导入变化 | `./import_from_local.sh <dir>` | - |

## 工作流程图

```
ROOT环境                    LOCAL环境
    |                          |
    | 1. 创建离线包              |
    | ./make_offline_package.sh |
    |                          |
    | 2. 分发包                |
    | offline_pkg_*.tar.gz     |
    |                          |
    |                          | 3. 解压并初始化
    |                          | ./init_repository.sh
    |                          |
    |                          | 4. 开发
    |                          | git checkout -b feature/*
    |                          | git commit
    |                          |
    |                          | 5. 导出变化
    |                          | ./export_changes.sh
    |                          |
    | 6. 导入变化               |
    | ./import_from_local.sh   |
    |                          |
    | 7. 推送到远程             |
    | git push                 |
    |                          |
```

## 故障排除

### 常见错误

1. **权限错误**：
```bash
chmod +x *.sh
```

2. **Git版本过低**：
```bash
# Ubuntu 20.04
sudo apt update
sudo apt install git
```

3. **子模块问题**：
```bash
git submodule update --init --recursive
```

### 获取帮助

- 查看详细文档：`README.md`
- 运行测试：`./test_system.sh`
- 检查脚本帮助：`./script_name.sh` (不带参数)

## 下一步

1. 阅读完整文档：`README.md`
2. 运行测试脚本验证功能
3. 在实际项目中试用
4. 根据需要调整参数和配置 