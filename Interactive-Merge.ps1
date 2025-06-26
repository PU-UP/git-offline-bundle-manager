<#
.SYNOPSIS
  交互式合并本地修改与bundle更新
#>

param (
    [string]$RepoDir = 'D:\Projects\github\slam-core'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== 交互式合并工具 ===" -ForegroundColor Cyan

# 1. 显示当前状态
Write-Host "`n当前仓库状态:" -ForegroundColor Yellow
git -C $RepoDir status --short

# 2. 显示合并选项
Write-Host "`n请选择合并策略:" -ForegroundColor Yellow
Write-Host "1. 保留本地修改，创建新分支" -ForegroundColor White
Write-Host "2. 丢弃本地修改，使用bundle版本" -ForegroundColor White
Write-Host "3. 交互式合并（推荐）" -ForegroundColor White
Write-Host "4. 查看差异后决定" -ForegroundColor White
Write-Host "5. 取消操作" -ForegroundColor White

$choice = Read-Host "`n请输入选择 (1-5)"

switch ($choice) {
    "1" {
        # 保留本地修改，创建新分支
        Write-Host "`n创建本地修改分支..." -ForegroundColor Yellow
        $branchName = Read-Host "请输入分支名称" -Default "local-changes-$(Get-Date -Format 'yyyyMMdd')"
        
        git -C $RepoDir checkout -b $branchName
        git -C $RepoDir add .
        git -C $RepoDir commit -m "本地修改 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        
        Write-Host "✅ 本地修改已保存到分支: $branchName" -ForegroundColor Green
        Write-Host "现在可以安全地运行 Update-OfflineRepo.ps1" -ForegroundColor Cyan
    }
    
    "2" {
        # 丢弃本地修改
        Write-Host "`n⚠ 警告：这将丢弃所有本地修改！" -ForegroundColor Red
        $confirm = Read-Host "确认丢弃本地修改？(输入 'YES' 确认)"
        
        if ($confirm -eq 'YES') {
            git -C $RepoDir reset --hard HEAD
            git -C $RepoDir clean -fd
            Write-Host "✅ 本地修改已丢弃" -ForegroundColor Green
        } else {
            Write-Host "操作已取消" -ForegroundColor Yellow
        }
    }
    
    "3" {
        # 交互式合并
        Write-Host "`n开始交互式合并..." -ForegroundColor Yellow
        
        # 创建临时分支保存本地修改
        $tempBranch = "temp-local-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        git -C $RepoDir checkout -b $tempBranch
        git -C $RepoDir add .
        git -C $RepoDir commit -m "临时保存本地修改"
        
        # 切换回主分支
        git -C $RepoDir checkout main
        
        # 尝试合并
        Write-Host "尝试合并本地修改..." -ForegroundColor Yellow
        $mergeResult = git -C $RepoDir merge $tempBranch 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ 合并成功！" -ForegroundColor Green
            git -C $RepoDir branch -d $tempBranch
        } else {
            Write-Warning "⚠ 合并出现冲突"
            Write-Host "请手动解决冲突，然后运行:" -ForegroundColor Cyan
            Write-Host "  git add ." -ForegroundColor White
            Write-Host "  git commit" -ForegroundColor White
            Write-Host "  git branch -d $tempBranch" -ForegroundColor White
        }
    }
    
    "4" {
        # 查看差异
        Write-Host "`n显示本地修改的差异:" -ForegroundColor Yellow
        git -C $RepoDir diff
        
        Write-Host "`n请根据差异决定如何处理本地修改" -ForegroundColor Cyan
        Write-Host "可以重新运行此脚本选择其他选项" -ForegroundColor White
    }
    
    "5" {
        Write-Host "操作已取消" -ForegroundColor Yellow
    }
    
    default {
        Write-Warning "无效选择，操作已取消"
    }
}

Write-Host "`n=== 操作完成 ===" -ForegroundColor Cyan 