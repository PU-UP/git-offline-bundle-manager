<#
.SYNOPSIS
  初始化离线工作区（主仓 + 任意深度子仓）：
    1. 克隆 slam-core.bundle 为主仓
    2. 将每个子模块 URL 重写为本地绝对路径（无 file://）
    3. 离线 init/update 所有子模块
    4. 给主仓 & 子仓都打 last-sync 标签
#>

param (
    [string]$BundlesDir = 'D:/Work/code/2025/0625/bundles',
    [string]$RepoDir    = 'D:/Projects/github/slam-core'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 0) 路径检查
if (-not (Test-Path $BundlesDir)) {
    throw "❌ Bundles 目录不存在: $BundlesDir"
}

# 1) 克隆主仓（已有 .git 则跳过）
if (-not (Test-Path "$RepoDir/.git")) {
    git clone "$BundlesDir/slam-core.bundle" $RepoDir
}

# 2) （可选）写入本地身份脱敏
git -C $RepoDir config --local user.name  "Internal Bot"
git -C $RepoDir config --local user.email "internal@corp"

# 3) 解包所有 bundle 到 _unpacked 目录
$UnpackDir = Join-Path $BundlesDir '_unpacked'
if (-not (Test-Path $UnpackDir)) {
    New-Item -ItemType Directory -Path $UnpackDir | Out-Null
}

$bundleFiles = Get-ChildItem -Path $BundlesDir -Filter '*.bundle'
foreach ($bundle in $bundleFiles) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($bundle.Name)
    $target = Join-Path $UnpackDir $name
    if (-not (Test-Path $target)) {
        git clone --bare $bundle.FullName $target
    }
}

# 4) 重写每个子模块 URL 为解包后的裸仓库目录（用正斜杠）
$subPaths = git -C $RepoDir submodule status --recursive |
            ForEach-Object { ($_ -split '\s+')[1] }
foreach ($path in $subPaths) {
    $bundleName = ($path -replace '/', '_')
    $bareRepo = Join-Path $UnpackDir $bundleName
    if (-not (Test-Path $bareRepo)) {
        Write-Warning "⚠ 找不到裸仓库： $bareRepo"
        continue
    }
    # 转成 forward-slash 绝对路径
    $ABS = ($bareRepo -replace '\\','/')
    git -C $RepoDir config submodule.$path.url $ABS
}

# 5) 离线初始化 & 更新子模块
$env:GIT_ALLOW_PROTOCOL = "file"
git -C $RepoDir submodule update --init --recursive
$env:GIT_ALLOW_PROTOCOL = $null

# 6) 给主仓 & 子仓打 last-sync
git -C $RepoDir tag -f last-sync
git -C $RepoDir submodule foreach --recursive 'git tag -f last-sync'

Write-Host "`n✅ 离线仓库就绪： $RepoDir" -ForegroundColor Green
