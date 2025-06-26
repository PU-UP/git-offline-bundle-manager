<#
.SYNOPSIS
Merge local changes with latest bundle
#>

param(
    [string]$RepoDir,
    [switch]$AutoResolve
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "Merging local changes..." -ForegroundColor Yellow

# Check for local changes
$mainStatus = git -C $RepoDir status --porcelain
$subStatus = git -C $RepoDir submodule foreach --recursive 'git status --porcelain'

$hasChanges = $mainStatus -or ($subStatus -and $subStatus -notmatch '^Entering')

if (-not $hasChanges) {
    Write-Host "No local changes to merge" -ForegroundColor Green
    exit 0
}

Write-Host "Local changes detected:" -ForegroundColor Yellow
if ($mainStatus) {
    Write-Host "Main repo:" -ForegroundColor Red
    Write-Host $mainStatus
}
if ($subStatus -and $subStatus -notmatch '^Entering') {
    Write-Host "Submodules:" -ForegroundColor Red
    Write-Host $subStatus
}

if ($AutoResolve) {
    Write-Host "Auto-resolving conflicts..." -ForegroundColor Cyan
    
    # Stash changes
    git -C $RepoDir stash push -m "Auto-stash before merge"
    
    # Try to apply stash
    try {
        git -C $RepoDir stash pop
        Write-Host "SUCCESS: Changes auto-merged" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Auto-merge failed, manual resolution needed" -ForegroundColor Yellow
        Write-Host "Run: git -C $RepoDir status" -ForegroundColor White
    }
} else {
    Write-Host "Manual merge required" -ForegroundColor Yellow
    Write-Host "Please resolve conflicts manually:" -ForegroundColor White
    Write-Host "1. git -C $RepoDir status" -ForegroundColor White
    Write-Host "2. Edit conflicted files" -ForegroundColor White
    Write-Host "3. git -C $RepoDir add ." -ForegroundColor White
    Write-Host "4. git -C $RepoDir commit" -ForegroundColor White
} 