<#
.SYNOPSIS
  将本地修改打包成bundle文件，用于同步回Ubuntu：
    1. 检查本地修改状态
    2. 创建包含本地修改的bundle
    3. 生成差异报告
    4. 准备同步文件
#>

param (
    [string]$RepoDir = 'D:\Projects\github\slam-core',
    [string]$OutputDir = 'D:\Projects\github\slam-core\local-bundles',
    [switch]$IncludeAll,    # 包含所有分支
    [switch]$CreateDiff     # 创建差异报告
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 0) 检查仓库状态
Write-Host "检查本地仓库状态..." -ForegroundColor Yellow

if (-not (Test-Path "$RepoDir/.git")) {
    throw "❌ 不是有效的Git仓库: $RepoDir"
}

# 1) 创建输出目录
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# 2) 获取当前时间戳
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$bundlePrefix = "local_$timestamp"

# 3) 创建主仓库bundle
Write-Host "创建主仓库bundle..." -ForegroundColor Green
$mainBundle = Join-Path $OutputDir "$bundlePrefix`_slam-core.bundle"

if ($IncludeAll) {
    git -C $RepoDir bundle create $mainBundle --all
} else {
    # 只包含当前分支和last-sync标签
    git -C $RepoDir bundle create $mainBundle HEAD last-sync
}

# 4) 创建子模块bundle
Write-Host "创建子模块bundle..." -ForegroundColor Green
$subPaths = git -C $RepoDir submodule status --recursive |
            ForEach-Object { ($_ -split '\s+')[1] }

foreach ($path in $subPaths) {
    $bundleName = ($path -replace '/', '_')
    $subBundle = Join-Path $OutputDir "$bundlePrefix`_$bundleName.bundle"
    $subRepo = Join-Path $RepoDir $path
    
    if ($IncludeAll) {
        git -C $subRepo bundle create $subBundle --all
    } else {
        git -C $subRepo bundle create $subBundle HEAD last-sync
    }
}

# 5) 创建差异报告
if ($CreateDiff) {
    Write-Host "创建差异报告..." -ForegroundColor Green
    $diffReport = Join-Path $OutputDir "$bundlePrefix`_diff_report.txt"
    
    # 主仓库差异
    $mainDiff = git -C $RepoDir diff last-sync..HEAD --stat
    "=== 主仓库差异 (last-sync..HEAD) ===" | Out-File $diffReport -Encoding UTF8
    $mainDiff | Out-File $diffReport -Append -Encoding UTF8
    
    # 子模块差异
    foreach ($path in $subPaths) {
        $subRepo = Join-Path $RepoDir $path
        $subDiff = git -C $subRepo diff last-sync..HEAD --stat
        if ($subDiff) {
            "`n=== 子模块 $path 差异 ===" | Out-File $diffReport -Append -Encoding UTF8
            $subDiff | Out-File $diffReport -Append -Encoding UTF8
        }
    }
}

# 6) 创建同步信息文件
$syncInfo = @{
    timestamp = $timestamp
    bundle_prefix = $bundlePrefix
    main_bundle = "$bundlePrefix`_slam-core.bundle"
    sub_bundles = @()
    created_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    git_status = git -C $RepoDir status --porcelain
}

foreach ($path in $subPaths) {
    $bundleName = ($path -replace '/', '_')
    $syncInfo.sub_bundles += "$bundlePrefix`_$bundleName.bundle"
}

$syncInfo | ConvertTo-Json -Depth 3 | Out-File (Join-Path $OutputDir "$bundlePrefix`_info.json") -Encoding UTF8

# 7) 显示结果
Write-Host "`n✅ Bundle创建完成！" -ForegroundColor Green
Write-Host "输出目录: $OutputDir" -ForegroundColor Cyan
Write-Host "主仓库bundle: $bundlePrefix`_slam-core.bundle" -ForegroundColor Cyan
Write-Host "子模块bundle数量: $($subPaths.Count)" -ForegroundColor Cyan

if ($CreateDiff) {
    Write-Host "差异报告: $bundlePrefix`_diff_report.txt" -ForegroundColor Cyan
}

Write-Host "`n📋 下一步操作:" -ForegroundColor Yellow
Write-Host "1. 将 $OutputDir 目录中的文件复制到Ubuntu" -ForegroundColor White
Write-Host "2. 在Ubuntu上使用 import_local_bundles.sh 导入修改" -ForegroundColor White 