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
$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "common\Config-Manager.psm1"
Import-Module $modulePath -Force

# Read config
try {
    $config = Read-Config
    $platform = Get-PathConfig
    $globalConfig = Get-GlobalConfig
    $syncConfig = Get-SyncConfig
    
    $RepoDir = $platform.repo_dir
    $BundlesDir = $platform.bundles_dir
    $LocalBundlesDir = $platform.local_bundles_dir
    
    $IncludeAll = $globalConfig.bundle.include_all_branches
    $CreateDiff = $syncConfig.create_diff_report
    
    Write-Host "Config:" -ForegroundColor Cyan
    Write-Host "  Repo dir: $RepoDir" -ForegroundColor White
    Write-Host "  Bundles dir: $BundlesDir" -ForegroundColor White
    Write-Host "  Local bundles dir: $LocalBundlesDir" -ForegroundColor White
    Write-Host "  Include all branches: $IncludeAll" -ForegroundColor White
    Write-Host "  Create diff report: $CreateDiff" -ForegroundColor White
    
} catch {
    Write-Host "ERROR: Failed to read config: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Run .\common\test-config.ps1 to check config status" -ForegroundColor Yellow
    exit 1
}

# 0) Check repo status
Write-Host "Checking local repo status..." -ForegroundColor Yellow

if (-not (Test-Path "$RepoDir/.git")) {
    throw "ERROR: Not a valid Git repository: $RepoDir"
}

# 1) Create output directory
if (-not (Test-Path $LocalBundlesDir)) {
    Write-Host "Creating output directory: $LocalBundlesDir" -ForegroundColor Green
    New-Item -ItemType Directory -Path $LocalBundlesDir | Out-Null
}

# 2) Get current timestamp
$timestamp = Get-Date -Format $globalConfig.bundle.timestamp_format
$bundlePrefix = "$($globalConfig.bundle.local_prefix)$timestamp"

# 2.1) Get submodule paths (used in multiple places)
$subPaths = @(git -C $RepoDir submodule status --recursive |
            ForEach-Object { 
                $line = $_.Trim()
                if ($line -match '^\s*([a-f0-9]+)\s+(.+?)\s+\((.+)\)$') {
                    $matches[2]  # 返回路径部分
                }
            } |
            Where-Object { $_ -ne $null })

# 2.5) Check for existing bundles and ask for confirmation to delete
Write-Host "Checking for existing bundles..." -ForegroundColor Yellow
$existingBundles = @()

# Check main repo bundle
$mainBundle = Join-Path $LocalBundlesDir "$bundlePrefix`_slam-core.bundle"
if (Test-Path $mainBundle) {
    $existingBundles += $mainBundle
}

# Check submodule bundles
foreach ($path in $subPaths) {
    $bundleName = ($path -replace '/', '_')
    $subBundle = Join-Path $LocalBundlesDir "$bundlePrefix`_$bundleName.bundle"
    if (Test-Path $subBundle) {
        $existingBundles += $subBundle
    }
}

# Check for info and diff report files
$infoFile = Join-Path $LocalBundlesDir "$bundlePrefix`_info.json"
if (Test-Path $infoFile) {
    $existingBundles += $infoFile
}

if ($CreateDiff) {
    $diffReport = Join-Path $LocalBundlesDir "$bundlePrefix`_$($globalConfig.bundle.main_repo_name)_diff_report.txt"
    if (Test-Path $diffReport) {
        $existingBundles += $diffReport
    }
}

# Also check for any existing bundle files with the same prefix pattern (for testing purposes)
# This allows testing the confirmation logic even with different timestamps
$allExistingBundles = @()
if (Test-Path $LocalBundlesDir) {
    $allExistingBundles = @(Get-ChildItem $LocalBundlesDir -File | Where-Object { 
        $_.Name -match "^$($globalConfig.bundle.local_prefix).*\.bundle$" -or 
        $_.Name -match "^$($globalConfig.bundle.local_prefix).*\.json$" -or
        $_.Name -match "^$($globalConfig.bundle.local_prefix).*_diff_report\.txt$"
    })
}

# Ask for confirmation if existing bundles found
if ($existingBundles.Count -gt 0) {
    Write-Host "Found existing bundle files with the same timestamp:" -ForegroundColor Yellow
    foreach ($bundle in $existingBundles) {
        Write-Host "  - $bundle" -ForegroundColor White
    }
    Write-Host ""
    
    if ($syncConfig.confirm_before_actions) {
        $response = Read-Host "Do you want to delete these existing files and create new bundles? (y/N)"
        if ($response -notmatch '^[yY]') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }
    
    Write-Host "Deleting existing bundle files..." -ForegroundColor Green
    foreach ($bundle in $existingBundles) {
        Remove-Item $bundle -Force
        Write-Host "  Deleted: $bundle" -ForegroundColor White
    }
    Write-Host ""
} elseif ($allExistingBundles.Count -gt 0 -and $syncConfig.confirm_before_actions) {
    # If no same-timestamp files but other bundle files exist, ask if user wants to clean up
    Write-Host "Found other existing bundle files in the directory:" -ForegroundColor Yellow
    foreach ($bundle in $allExistingBundles | Select-Object -First 5) {
        Write-Host "  - $($bundle.Name)" -ForegroundColor White
    }
    if ($allExistingBundles.Count -gt 5) {
        Write-Host "  ... and $($allExistingBundles.Count - 5) more files" -ForegroundColor White
    }
    Write-Host ""
    
    $response = Read-Host "Do you want to delete all existing bundle files before creating new ones? (y/N)"
    if ($response -match '^[yY]') {
        Write-Host "Deleting all existing bundle files..." -ForegroundColor Green
        foreach ($bundle in $allExistingBundles) {
            Remove-Item $bundle.FullName -Force
            Write-Host "  Deleted: $($bundle.Name)" -ForegroundColor White
        }
        Write-Host ""
    }
}

# 3) Create main repo bundle
Write-Host "Creating main repo bundle..." -ForegroundColor Green
$mainBundle = Join-Path $LocalBundlesDir "$bundlePrefix`_slam-core.bundle"

if ($IncludeAll) {
    git -C $RepoDir bundle create $mainBundle --all
} else {
    # Only include current branch and last-sync tag
    git -C $RepoDir bundle create $mainBundle HEAD last-sync
}

# 4) Create submodule bundles
Write-Host "Creating submodule bundles..." -ForegroundColor Green

foreach ($path in $subPaths) {
    $bundleName = ($path -replace '/', '_')
    $subBundle = Join-Path $LocalBundlesDir "$bundlePrefix`_$bundleName.bundle"
    $subRepo = Join-Path $RepoDir $path
    
    Write-Host "  Creating submodule bundle: $path" -ForegroundColor White
    
    if (Test-Path $subRepo) {
        if ($IncludeAll) {
            git -C $subRepo bundle create $subBundle --all
        } else {
            git -C $subRepo bundle create $subBundle HEAD last-sync
        }
    } else {
        Write-Host "    WARNING: Submodule path not found: $subRepo" -ForegroundColor Yellow
    }
}

# 5) Create diff report
if ($CreateDiff) {
    Write-Host "Creating diff report..." -ForegroundColor Green
    $diffReport = Join-Path $LocalBundlesDir "$bundlePrefix`_$($globalConfig.bundle.main_repo_name)_diff_report.txt"
    
    # Main repo diff
    $mainDiff = git -C $RepoDir diff last-sync..HEAD --stat
    "=== Main repo diff (last-sync..HEAD) ===" | Out-File $diffReport -Encoding UTF8
    $mainDiff | Out-File $diffReport -Append -Encoding UTF8
    
    # Submodule diffs
    foreach ($path in $subPaths) {
        $subRepo = Join-Path $RepoDir $path
        if (Test-Path $subRepo) {
            $subDiff = git -C $subRepo diff last-sync..HEAD --stat
            if ($subDiff) {
                ""
                "=== Submodule $path diff ===" | Out-File $diffReport -Append -Encoding UTF8
                $subDiff | Out-File $diffReport -Append -Encoding UTF8
            }
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
        bundles_dir = $BundlesDir
        local_bundles_dir = $LocalBundlesDir
        include_all = $IncludeAll
        create_diff = $CreateDiff
    }
}

foreach ($path in $subPaths) {
    $bundleName = ($path -replace '/', '_')
    $syncInfo.sub_bundles += "$bundlePrefix`_$bundleName.bundle"
}

$syncInfo | ConvertTo-Json -Depth 3 | Out-File (Join-Path $LocalBundlesDir "$bundlePrefix`_info.json") -Encoding UTF8

# 7) Show results
Write-Host ""
Write-Host "SUCCESS: Bundle creation completed!" -ForegroundColor Green
Write-Host "Output directory: $LocalBundlesDir" -ForegroundColor Cyan
Write-Host "Main repo bundle: $bundlePrefix`_slam-core.bundle" -ForegroundColor Cyan
Write-Host "Submodule bundle count: $($subPaths.Count)" -ForegroundColor Cyan

if ($CreateDiff) {
    Write-Host "Diff report: $bundlePrefix`_$($globalConfig.bundle.main_repo_name)_diff_report.txt" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Copy files from $LocalBundlesDir to Ubuntu" -ForegroundColor White
Write-Host "2. Use import_local_bundles.sh on Ubuntu to import changes" -ForegroundColor White 