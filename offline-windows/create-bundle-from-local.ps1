<#
.SYNOPSIS
  Create bundle files from local changes for syncing back to Ubuntu:
    1. Check local change status
    2. Create bundles containing local changes
    3. Generate diff report
    4. Prepare sync files
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import config manager module
$modulePath = Join-Path $PSScriptRoot "Config-Manager.psm1"
Import-Module $modulePath -Force

# Read config
try {
    $config = Read-Config
    $platform = Get-PlatformConfig
    
    $RepoDir = $platform.repo_dir
    $OutputDir = $platform.local_bundles_dir
    $IncludeAll = $config.bundle.include_all_branches
    $CreateDiff = $config.sync.create_diff_report
    
    Write-Host "Config:" -ForegroundColor Cyan
    Write-Host "  Repo dir: $RepoDir" -ForegroundColor White
    Write-Host "  Output dir: $OutputDir" -ForegroundColor White
    Write-Host "  Include all branches: $IncludeAll" -ForegroundColor White
    Write-Host "  Create diff report: $CreateDiff" -ForegroundColor White
    
} catch {
    Write-Host "ERROR: Failed to read config: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Run .\Show-Config.ps1 to check config status" -ForegroundColor Yellow
    exit 1
}

# 0) Check repo status
Write-Host "Checking local repo status..." -ForegroundColor Yellow

if (-not (Test-Path "$RepoDir/.git")) {
    throw "ERROR: Not a valid Git repository: $RepoDir"
}

# 1) Create output directory
if (-not (Test-Path $OutputDir)) {
    Write-Host "Creating output directory: $OutputDir" -ForegroundColor Green
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# 2) Get current timestamp
$timestamp = Get-Date -Format $config.bundle.timestamp_format
$bundlePrefix = "$($config.bundle.local_prefix)$timestamp"

# 3) Create main repo bundle
Write-Host "Creating main repo bundle..." -ForegroundColor Green
$mainBundle = Join-Path $OutputDir "$bundlePrefix`_slam-core.bundle"

if ($IncludeAll) {
    git -C $RepoDir bundle create $mainBundle --all
} else {
    # Only include current branch and last-sync tag
    git -C $RepoDir bundle create $mainBundle HEAD last-sync
}

# 4) Create submodule bundles
Write-Host "Creating submodule bundles..." -ForegroundColor Green
$subPaths = git -C $RepoDir submodule status --recursive |
            ForEach-Object { ($_ -split '\s+')[1] }

foreach ($path in $subPaths) {
    $bundleName = ($path -replace '/', '_')
    $subBundle = Join-Path $OutputDir "$bundlePrefix`_$bundleName.bundle"
    $subRepo = Join-Path $RepoDir $path
    
    Write-Host "  Creating submodule bundle: $path" -ForegroundColor White
    
    if ($IncludeAll) {
        git -C $subRepo bundle create $subBundle --all
    } else {
        git -C $subRepo bundle create $subBundle HEAD last-sync
    }
}

# 5) Create diff report
if ($CreateDiff) {
    Write-Host "Creating diff report..." -ForegroundColor Green
    $diffReport = Join-Path $OutputDir "$bundlePrefix`_diff_report.txt"
    
    # Main repo diff
    $mainDiff = git -C $RepoDir diff last-sync..HEAD --stat
    "=== Main repo diff (last-sync..HEAD) ===" | Out-File $diffReport -Encoding UTF8
    $mainDiff | Out-File $diffReport -Append -Encoding UTF8
    
    # Submodule diffs
    foreach ($path in $subPaths) {
        $subRepo = Join-Path $RepoDir $path
        $subDiff = git -C $subRepo diff last-sync..HEAD --stat
        if ($subDiff) {
            ""
            "=== Submodule $path diff ===" | Out-File $diffReport -Append -Encoding UTF8
            $subDiff | Out-File $diffReport -Append -Encoding UTF8
        }
    }
}

# 6) Create sync info file
$syncInfo = @{
    timestamp = $timestamp
    bundle_prefix = $bundlePrefix
    main_bundle = "$bundlePrefix`_slam-core.bundle"
    sub_bundles = @()
    created_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    git_status = git -C $RepoDir status --porcelain
    config_used = @{
        repo_dir = $RepoDir
        output_dir = $OutputDir
        include_all = $IncludeAll
        create_diff = $CreateDiff
    }
}

foreach ($path in $subPaths) {
    $bundleName = ($path -replace '/', '_')
    $syncInfo.sub_bundles += "$bundlePrefix`_$bundleName.bundle"
}

$syncInfo | ConvertTo-Json -Depth 3 | Out-File (Join-Path $OutputDir "$bundlePrefix`_info.json") -Encoding UTF8

# 7) Show results
Write-Host ""
Write-Host "SUCCESS: Bundle creation completed!" -ForegroundColor Green
Write-Host "Output directory: $OutputDir" -ForegroundColor Cyan
Write-Host "Main repo bundle: $bundlePrefix`_slam-core.bundle" -ForegroundColor Cyan
Write-Host "Submodule bundle count: $($subPaths.Count)" -ForegroundColor Cyan

if ($CreateDiff) {
    Write-Host "Diff report: $bundlePrefix`_diff_report.txt" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Copy files from $OutputDir to Ubuntu" -ForegroundColor White
Write-Host "2. Use import_local_bundles.sh on Ubuntu to import changes" -ForegroundColor White 