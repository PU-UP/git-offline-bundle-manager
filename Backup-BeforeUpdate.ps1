<#
.SYNOPSIS
  在更新前备份当前仓库状态
#>

param (
    [string]$RepoDir = 'D:\Projects\github\slam-core',
    [string]$BackupDir = 'D:\Projects\github\slam-core-backup'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 创建备份目录
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = Join-Path $BackupDir "backup_$timestamp"

Write-Host "创建备份到: $backupPath" -ForegroundColor Yellow

# 复制整个仓库
Copy-Item -Path $RepoDir -Destination $backupPath -Recurse -Force

# 创建备份信息文件
$backupInfo = @"
备份时间: $(Get-Date)
源目录: $RepoDir
备份目录: $backupPath

主仓库状态:
$(git -C $RepoDir status --porcelain)

子模块状态:
$(git -C $RepoDir submodule foreach --recursive 'git status --porcelain')
"@

$backupInfo | Out-File -FilePath (Join-Path $backupPath "backup-info.txt") -Encoding UTF8

Write-Host "✅ 备份完成: $backupPath" -ForegroundColor Green
Write-Host "备份信息已保存到: $(Join-Path $backupPath "backup-info.txt")" -ForegroundColor Cyan 