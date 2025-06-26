<#
.SYNOPSIS
  Automated offline development workflow:
    1. Check local status
    2. Backup current work
    3. Update to latest bundle
    4. Merge local changes
    5. Optional: Create local bundle for sync
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import config manager module
$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "common\Config-Manager.psm1"
Import-Module $modulePath -Force

function Write-Step {
    param([string]$Message, [string]$Color = "Green")
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor $Color
}

function Confirm-Continue {
    param([string]$Message)
    $response = Read-Host "$Message (y/N)"
    return $response -eq 'y' -or $response -eq 'Y'
}

function Create-Backup {
    param([string]$RepoDir, [string]$BackupDir)
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $repoName = Split-Path $RepoDir -Leaf
    $backupName = "${repoName}-backup-$timestamp"
    $backupPath = Join-Path $BackupDir $backupName
    
    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    
    Write-Host "Creating backup: $backupPath" -ForegroundColor Cyan
    Copy-Item -Path $RepoDir -Destination $backupPath -Recurse -Force
    
    return $backupPath
}

function Update-FromBundle {
    param([string]$RepoDir, [string]$BundlesDir)
    
    # Update main repo
    $mainBundle = Join-Path $BundlesDir "slam-core.bundle"
    if (Test-Path $mainBundle) {
        Write-Host "Updating main repo from bundle..." -ForegroundColor Cyan
        git -C $RepoDir fetch $mainBundle "refs/heads/*:refs/heads/*" --update-head-ok
    } else {
        throw "ERROR: Main bundle not found: $mainBundle"
    }
    
    # Update submodules
    $subStatus = git -C $RepoDir submodule status --recursive
    $subPaths = $subStatus | ForEach-Object { 
        if ($_ -match '^\s*[+-]?\w+\s+(\S+)\s+') { $matches[1] }
    }
    
    foreach ($path in $subPaths) {
        $bundleName = $path -replace '/', '_'
        $subBundle = Join-Path $BundlesDir "$bundleName.bundle"
        
        if (Test-Path $subBundle) {
            Write-Host "  Updating submodule: $path" -ForegroundColor Cyan
            $subDir = Join-Path $RepoDir $path
            git -C $subDir fetch $subBundle "refs/heads/*:refs/heads/*" --update-head-ok
        } else {
            Write-Host "WARNING: Submodule bundle not found: $subBundle" -ForegroundColor Yellow
        }
    }
    
    # Update last-sync tags
    Write-Host "Updating sync tags..." -ForegroundColor Cyan
    git -C $RepoDir tag -f last-sync
    git -C $RepoDir submodule foreach --recursive 'git tag -f last-sync'
}

function Auto-MergeChanges {
    param([string]$RepoDir)
    
    Write-Host "Using auto-merge mode..." -ForegroundColor Cyan
    # Simple auto-merge: stash and pop
    git -C $RepoDir stash push -m "Auto-stash before merge"
    $stashResult = git -C $RepoDir stash pop 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Auto-merge failed, manual resolution needed" -ForegroundColor Yellow
        Write-Host $stashResult
    }
}

# Read config
try {
    $config = Read-Config
    $platform = Get-PathConfig
    $syncConfig = Get-SyncConfig
    
    $RepoDir = $platform.repo_dir
    $BundlesDir = $platform.bundles_dir
    $LocalBundlesDir = $platform.local_bundles_dir
    $BackupDir = $platform.backup_dir
    
    $AutoResolve = $syncConfig.auto_resolve_conflicts
    $SkipBackup = -not $syncConfig.backup_before_update
    $CreateLocalBundle = $false  # Default to false, can be enabled via config if needed
    
    Write-Host "Config:" -ForegroundColor Cyan
    Write-Host "  Repo dir: $RepoDir" -ForegroundColor White
    Write-Host "  Bundles dir: $BundlesDir" -ForegroundColor White
    Write-Host "  Local bundles dir: $LocalBundlesDir" -ForegroundColor White
    Write-Host "  Backup dir: $BackupDir" -ForegroundColor White
    Write-Host "  Auto resolve conflicts: $AutoResolve" -ForegroundColor White
    Write-Host "  Skip backup: $SkipBackup" -ForegroundColor White
    
} catch {
    Write-Host "ERROR: Failed to read config: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Run .\common\test-config.ps1 to check config status" -ForegroundColor Yellow
    exit 1
}

# 0) Check environment
Write-Step "Checking work environment" "Cyan"

if (-not (Test-Path $RepoDir)) {
    throw "ERROR: Repo directory does not exist: $RepoDir"
}

if (-not (Test-Path $BundlesDir)) {
    throw "ERROR: Bundles directory does not exist: $BundlesDir"
}

# 1) Check local status
Write-Step "Checking local repo status" "Yellow"

$mainStatus = git -C $RepoDir status --porcelain
$subStatus = git -C $RepoDir submodule foreach --recursive 'git status --porcelain'

$hasChanges = $mainStatus -or ($subStatus -and $subStatus -notmatch '^Entering')

if ($hasChanges) {
    Write-Host "WARNING: Local changes detected:" -ForegroundColor Yellow
    if ($mainStatus) {
        Write-Host "Main repo changes:" -ForegroundColor Red
        Write-Host $mainStatus
    }
    if ($subStatus -and $subStatus -notmatch '^Entering') {
        Write-Host "Submodule changes:" -ForegroundColor Red
        Write-Host $subStatus
    }
    
    if (-not (Confirm-Continue "Continue with sync?")) {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# 2) Create backup
if (-not $SkipBackup) {
    Write-Step "Creating backup" "Yellow"
    
    if (Confirm-Continue "Create backup before update?") {
        try {
            $backupPath = Create-Backup -RepoDir $RepoDir -BackupDir $BackupDir
            Write-Host "SUCCESS: Backup completed: $backupPath" -ForegroundColor Green
        } catch {
            Write-Host "ERROR: Backup failed: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
}

# 3) Handle local changes
if ($hasChanges) {
    Write-Step "Handling local changes" "Yellow"
    
    if ($AutoResolve) {
        Auto-MergeChanges -RepoDir $RepoDir
    } else {
        Write-Host "Starting interactive merge..." -ForegroundColor Cyan
        & "$PSScriptRoot\interactive-merge.ps1"
    }
}

# 4) Update to latest bundle
Write-Step "Updating to latest bundle" "Green"

try {
    Update-FromBundle -RepoDir $RepoDir -BundlesDir $BundlesDir
    Write-Host "SUCCESS: Update completed" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Update failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 5) Create local bundle (optional)
if ($CreateLocalBundle) {
    Write-Step "Creating local bundle" "Cyan"
    
    if (Confirm-Continue "Create local bundle for sync?") {
        try {
            & "$PSScriptRoot\create-bundle-from-local.ps1"
            Write-Host "SUCCESS: Local bundle creation completed" -ForegroundColor Green
            Write-Host "Output directory: $LocalBundlesDir" -ForegroundColor Cyan
        } catch {
            Write-Host "ERROR: Failed to create local bundle: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# 6) Show final status
Write-Step "Sync completed" "Green"

Write-Host "Current repo status:" -ForegroundColor Cyan
git -C $RepoDir status --short

Write-Host ""
Write-Host "Submodule status:" -ForegroundColor Cyan
git -C $RepoDir submodule status --recursive

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Check if code works properly" -ForegroundColor White
Write-Host "2. Run tests to ensure quality" -ForegroundColor White
Write-Host "3. Continue development work" -ForegroundColor White

if ($CreateLocalBundle -and (Test-Path $LocalBundlesDir)) {
    Write-Host "4. Copy files from $LocalBundlesDir to Ubuntu for sync" -ForegroundColor White
}

Write-Host ""
Write-Host "SUCCESS: Automated sync workflow completed!" -ForegroundColor Green 