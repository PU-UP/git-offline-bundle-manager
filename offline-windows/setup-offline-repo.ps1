<#
.SYNOPSIS
  Initialize offline workspace (main repo + submodules):
    1. Clone slam-core.bundle as main repo
    2. Rewrite submodule URLs to local absolute path
    3. Offline init/update all submodules
    4. Tag last-sync for main & submodules
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import config manager module
$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "common\Config-Manager.psm1"
Import-Module $modulePath -Force

# Read config
try {
    $config = Read-Config
    $platform = Get-PathConfig
    $gitConfig = Get-GitConfig
    $BundlesDir = $platform.bundles_dir
    $RepoDir = $platform.repo_dir
    Write-Host "Config:" -ForegroundColor Cyan
    Write-Host "  Bundles dir: $BundlesDir" -ForegroundColor White
    Write-Host "  Repo dir: $RepoDir" -ForegroundColor White
    Write-Host "  Git user: $($gitConfig.user_name)" -ForegroundColor White
    Write-Host "  Git email: $($gitConfig.user_email)" -ForegroundColor White
} catch {
    Write-Host "ERROR: Failed to read config: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Run .\common\test-config.ps1 to check config status" -ForegroundColor Yellow
    exit 1
}

# 0) Path check
if (-not (Test-Path $BundlesDir)) {
    throw "ERROR: Bundles directory does not exist: $BundlesDir"
}

# 1) Clone main repo (skip if .git exists)
if (-not (Test-Path "$RepoDir/.git")) {
    Write-Host "Cloning main repo..." -ForegroundColor Green
    git clone "$BundlesDir/slam-core.bundle" $RepoDir
} else {
    Write-Host "Main repo already exists, skip clone" -ForegroundColor Yellow
}

# 2) Set local git identity
Write-Host "Configuring git identity..." -ForegroundColor Green
git -C $RepoDir config --local user.name $gitConfig.user_name
git -C $RepoDir config --local user.email $gitConfig.user_email

# 3) Unpack all bundles to _unpacked dir
$UnpackDir = Join-Path $BundlesDir '_unpacked'
if (-not (Test-Path $UnpackDir)) {
    Write-Host "Creating unpack dir..." -ForegroundColor Green
    New-Item -ItemType Directory -Path $UnpackDir | Out-Null
}

Write-Host "Unpacking bundle files..." -ForegroundColor Green
$bundleFiles = Get-ChildItem -Path $BundlesDir -Filter '*.bundle'
foreach ($bundle in $bundleFiles) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($bundle.Name)
    $target = Join-Path $UnpackDir $name
    if (-not (Test-Path $target)) {
        Write-Host "  Unpack: $($bundle.Name)" -ForegroundColor White
        git clone --bare $bundle.FullName $target
    } else {
        Write-Host "  Exists: $($bundle.Name)" -ForegroundColor White
    }
}

# 4) Rewrite submodule URLs to unpacked bare repo dir
Write-Host "Configuring submodule URLs..." -ForegroundColor Green
$subPaths = git -C $RepoDir submodule status --recursive |
            ForEach-Object { ($_ -split '\s+')[1] }
foreach ($path in $subPaths) {
    $bundleName = ($path -replace '/', '_')
    $bareRepo = Join-Path $UnpackDir $bundleName
    if (-not (Test-Path $bareRepo)) {
        Write-Warning "WARNING: Bare repo not found: $bareRepo"
        continue
    }
    $ABS = ($bareRepo -replace '\\','/')
    Write-Host "  Set submodule: $path -> $ABS" -ForegroundColor White
    git -C $RepoDir config submodule.$path.url $ABS
}

# 5) Offline init & update submodules
Write-Host "Initializing submodules..." -ForegroundColor Green
$env:GIT_ALLOW_PROTOCOL = $gitConfig.allow_protocol
git -C $RepoDir submodule update --init --recursive
$env:GIT_ALLOW_PROTOCOL = $null

# 6) Tag last-sync for main & submodules
Write-Host "Tagging last-sync..." -ForegroundColor Green
git -C $RepoDir tag -f last-sync
git -C $RepoDir submodule foreach --recursive 'git tag -f last-sync'

Write-Host ""
Write-Host "SUCCESS: Offline repo ready: $RepoDir" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Check repo status: git -C $RepoDir status" -ForegroundColor White
Write-Host "2. Start development" -ForegroundColor White
Write-Host "3. Use .\Auto-Sync-Workflow.ps1 for sync" -ForegroundColor White
