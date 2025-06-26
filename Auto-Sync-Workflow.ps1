<#
.SYNOPSIS
  自动化离线开发工作流：
    1. 检查本地状态
    2. 备份当前工作
    3. 更新到最新bundle
    4. 合并本地修改
    5. 可选：创建本地bundle用于同步
#>

param (
    [string]$RepoDir = 'D:\Projects\github\slam-core',
    [string]$BundlesDir = 'D:\Work\code\2025\0625\bundles',
    [switch]$CreateLocalBundle,    # 是否创建本地bundle
    [switch]$AutoResolve,          # 自动解决冲突
    [switch]$SkipBackup           # 跳过备份
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message, [string]$Color = "Green")
    Write-Host "`n=== $Message ===" -ForegroundColor $Color
}

function Confirm-Continue {
    param([string]$Message)
    $response = Read-Host "$Message (y/N)"
    return $response -eq 'y' -or $response -eq 'Y'
}

# 0) 检查环境
Write-Step "检查工作环境" "Cyan"

if (-not (Test-Path $RepoDir)) {
    throw "❌ 仓库目录不存在: $RepoDir"
}

if (-not (Test-Path $BundlesDir)) {
    throw "❌ Bundles目录不存在: $BundlesDir"
}

# 1) 检查本地状态
Write-Step "检查本地仓库状态" "Yellow"

$mainStatus = git -C $RepoDir status --porcelain
$subStatus = git -C $RepoDir submodule foreach --recursive 'git status --porcelain'

$hasChanges = $mainStatus -or ($subStatus -and $subStatus -notmatch '^Entering')

if ($hasChanges) {
    Write-Host "⚠️  检测到本地修改:" -ForegroundColor Yellow
    if ($mainStatus) {
        Write-Host "主仓库修改:" -ForegroundColor Red
        Write-Host $mainStatus
    }
    if ($subStatus -and $subStatus -notmatch '^Entering') {
        Write-Host "子模块修改:" -ForegroundColor Red
        Write-Host $subStatus
    }
    
    if (-not (Confirm-Continue "是否继续同步？")) {
        Write-Host "操作已取消" -ForegroundColor Yellow
        exit 0
    }
}

# 2) 创建备份
if (-not $SkipBackup) {
    Write-Step "创建备份" "Yellow"
    
    $backupDir = Join-Path (Split-Path $RepoDir) "$(Split-Path $RepoDir -Leaf)-backup-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    if (Confirm-Continue "是否创建备份到 $backupDir？") {
        & "$PSScriptRoot\Backup-BeforeUpdate.ps1" -RepoDir $RepoDir -BackupDir $backupDir
        Write-Host "✅ 备份完成: $backupDir" -ForegroundColor Green
    }
}

# 3) 处理本地修改
if ($hasChanges) {
    Write-Step "处理本地修改" "Yellow"
    
    if ($AutoResolve) {
        Write-Host "使用自动合并模式..." -ForegroundColor Cyan
        & "$PSScriptRoot\Merge-LocalChanges.ps1" -RepoDir $RepoDir -AutoResolve
    } else {
        Write-Host "启动交互式合并..." -ForegroundColor Cyan
        & "$PSScriptRoot\Interactive-Merge.ps1" -RepoDir $RepoDir
    }
}

# 4) 更新到最新bundle
Write-Step "更新到最新bundle" "Green"

try {
    & "$PSScriptRoot\Update-OfflineRepo.ps1" -RepoDir $RepoDir -BundlesDir $BundlesDir
    Write-Host "✅ 更新完成" -ForegroundColor Green
} catch {
    Write-Host "❌ 更新失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 5) 创建本地bundle（可选）
if ($CreateLocalBundle) {
    Write-Step "创建本地bundle" "Cyan"
    
    $localBundlesDir = Join-Path $RepoDir "local-bundles"
    
    if (Confirm-Continue "是否创建本地bundle用于同步？") {
        try {
            & "$PSScriptRoot\Create-Bundle-From-Local.ps1" -RepoDir $RepoDir -OutputDir $localBundlesDir -CreateDiff
            Write-Host "✅ 本地bundle创建完成" -ForegroundColor Green
            Write-Host "📁 输出目录: $localBundlesDir" -ForegroundColor Cyan
        } catch {
            Write-Host "❌ 创建本地bundle失败: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# 6) 显示最终状态
Write-Step "同步完成" "Green"

Write-Host "当前仓库状态:" -ForegroundColor Cyan
git -C $RepoDir status --short

Write-Host "`n子模块状态:" -ForegroundColor Cyan
git -C $RepoDir submodule status --recursive

Write-Host "`n📋 下一步建议:" -ForegroundColor Yellow
Write-Host "1. 检查代码是否正常工作" -ForegroundColor White
Write-Host "2. 运行测试确保质量" -ForegroundColor White
Write-Host "3. 继续开发工作" -ForegroundColor White

if ($CreateLocalBundle -and (Test-Path $localBundlesDir)) {
    Write-Host "4. 将 $localBundlesDir 中的文件复制到Ubuntu进行同步" -ForegroundColor White
}

Write-Host "`n✅ 自动化同步工作流完成！" -ForegroundColor Green 