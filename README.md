# slam-core Offline Bundle Workflow

> **Last updated:** 2025-07-02

---

## 0  Purpose

在无网络或受限网络环境下，通过 **`git bundle`** 在 *Server* 与 *Local* 之间同步包含 **子模块 (submodule)** 的整仓库，并支持基于 **新建分支** 的离线协作开发。

---

## 1  Repository Topology

```
slam-core/                    # 主仓库 (super-project)
├── .gitmodules              # 子模块声明
├── module_a/  (submodule)
└── module_b/  (submodule)
```

> 所有子模块均位于 `slam-core` 根目录下一级，使用 **相对路径** 声明。

---

## 2  Roles & Responsibilities

| 角色         | 主要职责                                                                                                                                      |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| **Server** | ① 打包/发布 `slam-core` 及全部子模块的 *完整 bundle* 供下载<br>② 接收 Local 提交的 *feature bundle*，合并至仓库                                                      |
| **Local**  | ① 首次用完整 bundle 初始化仓库<br>② 仅在 **新分支** (`dev/*`) 上开发<br>③ 为每个新分支（含子模块）生成 *增量 bundle* 并发送给 Server<br>④ 通过 Server 提供的更新 bundle 手动同步 (离线 pull) |

---

## 3  Prerequisites

* Git ≥ 2.20（必须支持 `git bundle`）
* Bash 环境（脚本示例基于 Bash）
* 所有脚本必须为 **纯英文**，以避免在某些终端或平台上出现字符编码问题
* 若使用 Git LFS，请额外打包 LFS 对象（本文不展开）

---

## 4  One-time Setup

### 4.1 Server — 导出完整仓库

```bash
#!/usr/bin/env bash
cd /path/to/slam-core
# 1️⃣ Export main repo
git bundle create ../slam-core.bundle --all
# 2️⃣ Export each submodule
git submodule foreach '
  git bundle create ../../${name}.bundle --all
'
```

> Output: `slam-core.bundle`, `module_a.bundle`, etc.

### 4.2 Local — 初次克隆

```bash
# Clone main repo from bundle
git clone /media/usb/slam-core.bundle slam-core
cd slam-core
# Init submodules
git submodule init
# Clone each submodule bundle
for mod in module_a module_b; do
  git -C $mod init
  git -C $mod remote add origin ../${mod}.bundle
  git -C $mod fetch origin --all
  git -C $mod checkout -b main FETCH_HEAD
done
```

> Can be wrapped into `init-from-bundle.sh`

---

## 5  Daily Development Workflow (Local)

1. **Create feature branch** (only `dev/*` allowed):

   ```bash
   git checkout -b dev/awesome-feature
   git submodule foreach 'git checkout -b dev/awesome-feature'
   ```
2. **Develop, commit, test as usual**
3. **Export incremental bundle (main + submodules)**:

   ```bash
   # Main repo
   ```

git bundle create dev-awesome-feature.bundle main..dev/awesome-feature

# Submodules

git submodule foreach '
git bundle create ../../\${name}-dev-awesome-feature.bundle&#x20;
main..dev/awesome-feature
'

````
4. **Deliver** all `*.bundle` to Server (USB / LAN)

---

## 6  Integrating Feature Bundles (Server)
```bash
cd /srv/git/slam-core
# Merge feature bundle into main repo
git fetch /path/dev-awesome-feature.bundle \
dev/awesome-feature:dev/awesome-feature

# Merge submodules
git submodule foreach '
git fetch ../../${name}-dev-awesome-feature.bundle \
 dev/awesome-feature:dev/awesome-feature
'
````

> After review, merge `dev/*` to `main` as needed

---

## 7  Syncing Server Updates Back to Local

When Server publishes a new full bundle:

```bash
# Main repo update
git fetch /media/usb/slam-core.bundle --all
git merge origin/main   # or git rebase

# Submodules
for mod in module_a module_b; do
  git -C $mod fetch ../${mod}.bundle --all
  git -C $mod merge origin/main
done
```

---

## 8  Branch & Bundle Naming Convention

| Object             | Naming Example                                                |
| ------------------ | ------------------------------------------------------------- |
| Feature Branch     | `dev/imu-refactor`                                            |
| Full Bundle        | `slam-core.bundle`, `module_a.bundle`                         |
| Incremental Bundle | `dev-imu-refactor.bundle`, `module_a-dev-imu-refactor.bundle` |

---

## 9  Helper Scripts (建议放置于 `tools/`)

| Script                  | Purpose                               |
| ----------------------- | ------------------------------------- |
| `export-full.sh`        | Server: generate full repo bundle     |
| `init-from-bundle.sh`   | Local: initial clone from bundle      |
| `export-feature.sh`     | Local: export feature branch bundles  |
| `import-feature.sh`     | Server: import feature branch bundles |
| `update-from-server.sh` | Local: fetch server updates           |

---

## 10  Configuration Files

To simplify usage, configuration files can be used:

### server.config

```ini
[main]
repo_path=/srv/git/slam-core
output_dir=/srv/bundles
modules=module_a,module_b
```

### local.config

```ini
[main]
repo_path=~/projects/slam-core
bundle_source=/media/usb
modules=module_a,module_b
feature_branch=dev/awesome-feature
```

Scripts can load these configs using tools like `source config_file` or `ini-parser` functions.

---

## 11  Troubleshooting

| Issue                                          | Reason & Solution                                                         |
| ---------------------------------------------- | ------------------------------------------------------------------------- |
| `fatal: refusing to fetch into current branch` | Current branch is checked out; switch to `dev/*` before fetch             |
| Submodule path error                           | `.gitmodules` not using relative path; run `git submodule sync` after fix |
| Missing LFS content                            | Use `git lfs fetch --all` and bundle `.lfs` separately                    |

---

## 12  License

本流程脚本示例遵循 MIT 许可证，可自由修改与分发。
