<#
.SYNOPSIS
  合并本地修改与bundle更新
#>

param (
    [string]$RepoDir = 'D:\Projects\github\slam-core',
    [switch]$AutoResolve,
    [switch]$CreateBackup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "开始合并本地修改..." -ForegroundColor Yellow

# 1. 检查是否有本地修改
$mainStatus = git -C $RepoDir status --porcelain
$hasLocalChanges = $mainStatus -and $mainStatus -notmatch '^Entering'

if (-not $hasLocalChanges) {
    Write-Host "✅ 没有本地修改需要合并" -ForegroundColor Green
    exit 0
}

# 2. 创建备份（可选）
if ($CreateBackup) {
    $backupDir = Join-Path $RepoDir ".." "merge-backup-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Write-Host "创建备份到: $backupDir" -ForegroundColor Yellow
    Copy-Item -Path $RepoDir -Destination $backupDir -Recurse -Force
}

# 3. 创建本地修改分支
$localBranch = "local-changes-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Write-Host "创建本地修改分支: $localBranch" -ForegroundColor Yellow

# 暂存当前修改
git -C $RepoDir stash push -m "合并前的本地修改"

# 创建并切换到新分支
git -C $RepoDir checkout -b $localBranch

# 应用暂存的修改
git -C $RepoDir stash pop

# 提交本地修改
git -C $RepoDir add .
git -C $RepoDir commit -m "本地修改 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# 4. 切换回主分支
git -C $RepoDir checkout main

# 5. 合并本地修改
Write-Host "合并本地修改到主分支..." -ForegroundColor Yellow
$mergeResult = git -C $RepoDir merge $localBranch 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 合并成功！" -ForegroundColor Green
} else {
    Write-Warning "⚠ 合并出现冲突，需要手动解决"
    Write-Host $mergeResult -ForegroundColor Red
    
    if ($AutoResolve) {
        Write-Host "尝试自动解决冲突..." -ForegroundColor Yellow
        # 这里可以添加自动冲突解决的逻辑
        # 比如使用 git mergetool 或特定的冲突解决策略
    } else {
        Write-Host "请手动解决冲突后运行:" -ForegroundColor Cyan
        Write-Host "  git add ." -ForegroundColor White
        Write-Host "  git commit" -ForegroundColor White
    }
}

# 6. 清理临时分支
$cleanup = Read-Host "是否删除临时分支 $localBranch？(y/N)"
if ($cleanup -eq 'y' -or $cleanup -eq 'Y') {
    git -C $RepoDir branch -d $localBranch
    Write-Host "临时分支已删除" -ForegroundColor Green
}

Write-Host "`n✅ 合并操作完成" -ForegroundColor Green 