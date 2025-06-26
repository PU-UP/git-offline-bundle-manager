<#
.SYNOPSIS
Update offline repository with latest bundles
#>

param(
    [string]$RepoDir,
    [string]$BundlesDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "Updating offline repository..." -ForegroundColor Yellow

# Check if bundles directory exists
if (-not (Test-Path $BundlesDir)) {
    throw "ERROR: Bundles directory does not exist: $BundlesDir"
}

# Check if repo directory exists
if (-not (Test-Path $RepoDir)) {
    throw "ERROR: Repository directory does not exist: $RepoDir"
}

# Update main repo
Write-Host "Updating main repository..." -ForegroundColor Green
$mainBundle = Join-Path $BundlesDir "slam-core.bundle"

if (-not (Test-Path $mainBundle)) {
    throw "ERROR: Main bundle not found: $mainBundle"
}

# Fetch latest changes
git -C $RepoDir fetch $mainBundle "refs/heads/*:refs/heads/*" --update-head-ok

# Update submodules
Write-Host "Updating submodules..." -ForegroundColor Green
$subPaths = git -C $RepoDir submodule status --recursive |
            ForEach-Object { ($_ -split '\s+')[1] }

foreach ($path in $subPaths) {
    $bundleName = ($path -replace '/', '_')
    $subBundle = Join-Path $BundlesDir "$bundleName.bundle"
    
    if (Test-Path $subBundle) {
        Write-Host "  Updating submodule: $path" -ForegroundColor White
        $subRepo = Join-Path $RepoDir $path
        git -C $subRepo fetch $subBundle "refs/heads/*:refs/heads/*" --update-head-ok
    } else {
        Write-Warning "WARNING: Submodule bundle not found: $subBundle"
    }
}

# Update last-sync tags
Write-Host "Updating sync tags..." -ForegroundColor Green
git -C $RepoDir tag -f last-sync
git -C $RepoDir submodule foreach --recursive 'git tag -f last-sync'

Write-Host "SUCCESS: Repository updated" -ForegroundColor Green
Write-Host "Current status:" -ForegroundColor Cyan
git -C $RepoDir status --short
