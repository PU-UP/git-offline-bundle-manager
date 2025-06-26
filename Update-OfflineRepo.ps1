<#
  用最新 *.bundle 快照刷新本地：
  ① fetch 主仓
  ② fetch 每个子仓
  ③ 移动 last-sync 标签
#>

param (
    [string]$BundlesDir = 'D:\Work\code\2025\0625\bundles',
    [string]$RepoDir    = 'D:\Projects\github\slam-core'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#--- 0. 检查本地状态
Write-Host "检查本地仓库状态..." -ForegroundColor Yellow

# 检查主仓库是否有未提交的修改
$mainStatus = git -C $RepoDir status --porcelain
if ($mainStatus) {
    Write-Warning "⚠ 主仓库有未提交的修改："
    Write-Host $mainStatus -ForegroundColor Red
    $response = Read-Host "是否继续更新？(y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "更新已取消" -ForegroundColor Yellow
        exit 0
    }
}

# 检查子模块状态
$subStatus = git -C $RepoDir submodule foreach --recursive 'git status --porcelain'
if ($subStatus -and $subStatus -notmatch '^Entering') {
    Write-Warning "⚠ 子模块有未提交的修改："
    Write-Host $subStatus -ForegroundColor Red
    $response = Read-Host "是否继续更新？(y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "更新已取消" -ForegroundColor Yellow
        exit 0
    }
}

#--- 1. 更新主仓
git -C $RepoDir fetch "$BundlesDir\slam-core.bundle" `
                   "refs/heads/*:refs/heads/*" --update-head-ok

#--- 2. 更新解包后的裸仓库
$UnpackDir = Join-Path $BundlesDir '_unpacked'
if (-not (Test-Path $UnpackDir)) {
    Write-Warning "⚠ 解包目录不存在，请先运行 Setup-OfflineRepo.ps1"
    exit 1
}

$bundleFiles = Get-ChildItem -Path $BundlesDir -Filter '*.bundle'
foreach ($bundle in $bundleFiles) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($bundle.Name)
    $bareRepo = Join-Path $UnpackDir $name
    if (Test-Path $bareRepo) {
        git -C $bareRepo fetch $bundle.FullName "refs/heads/*:refs/heads/*" --update-head-ok
    }
}

#--- 3. 逐个子仓 fetch（从裸仓库）
$subPaths = git -C $RepoDir submodule status --recursive |
            ForEach-Object { ($_ -split '\s+')[1] }

foreach ($path in $subPaths) {
    $bundleName = ($path -replace '/', '_')
    $bareRepo = Join-Path $UnpackDir $bundleName
    if (-not (Test-Path $bareRepo)) {
        Write-Warning "⚠ 找不到裸仓库： $bareRepo"
        continue
    }
    
    # 子模块目录 = 主仓目录 + 相对路径
    $subRepo = Join-Path $RepoDir $path
    git -C $subRepo fetch $bareRepo "refs/heads/*:refs/heads/*" --update-head-ok
}

#--- 4. 移动 last-sync 标签
git -C $RepoDir tag -f last-sync
git -C $RepoDir submodule foreach --recursive "git tag -f last-sync"

Write-Host "`n✅ 本地仓库已更新到最新快照" -ForegroundColor Green
