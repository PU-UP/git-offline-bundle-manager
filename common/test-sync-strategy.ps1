<#
.SYNOPSIS
Test sync strategy configuration for different branches
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import config manager module
$modulePath = Join-Path $PSScriptRoot "Config-Manager.psm1"
Import-Module $modulePath -Force

Write-Host "=== Testing Sync Strategy Configuration ===" -ForegroundColor Cyan
Write-Host ""

# Read config
try {
    $syncStrategy = Get-SyncStrategyConfig
    
    Write-Host "Sync Strategy Config:" -ForegroundColor Green
    Write-Host "  Mode: $($syncStrategy.sync_mode)" -ForegroundColor White
    Write-Host "  Default behavior: $($syncStrategy.default_behavior)" -ForegroundColor White
    Write-Host "  Tracked branches: $($syncStrategy.tracked_branches -join ', ')" -ForegroundColor White
    Write-Host "  Untracked branches: $($syncStrategy.untracked_branches -join ', ')" -ForegroundColor White
    Write-Host ""
    
    # Test different branch names
    $testBranches = @(
        "main",
        "develop", 
        "feature/new-feature",
        "feature/bug-fix",
        "hotfix/critical-fix",
        "release/v1.0.0",
        "unknown-branch"
    )
    
    Write-Host "Branch Sync Mode Test:" -ForegroundColor Green
    foreach ($branch in $testBranches) {
        $isTracked = Test-BranchTracked -BranchName $branch
        $syncMode = Get-BranchSyncMode -BranchName $branch
        $status = if ($isTracked) { "TRACKED" } else { "LATEST" }
        $color = if ($isTracked) { "Yellow" } else { "Cyan" }
        
        Write-Host "  $branch`: $status ($syncMode)" -ForegroundColor $color
    }
    
    Write-Host ""
    Write-Host "SUCCESS: Sync strategy test completed!" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR: Test failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} 