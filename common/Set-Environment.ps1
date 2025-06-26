<#
.SYNOPSIS
Set environment variables for Git offline tool
#>

# Import config manager module
$modulePath = Join-Path $PSScriptRoot "Config-Manager.psm1"
Import-Module $modulePath -Force

function Show-EnvironmentVariables {
    Write-Host "=== Current Environment Variables ===" -ForegroundColor Cyan
    $envVars = @(
        "GIT_OFFLINE_CONFIG",
        "GIT_OFFLINE_REPO_DIR",
        "GIT_OFFLINE_BUNDLES_DIR", 
        "GIT_OFFLINE_LOCAL_BUNDLES_DIR",
        "GIT_OFFLINE_BACKUP_DIR",
        "GIT_OFFLINE_USER_NAME",
        "GIT_OFFLINE_USER_EMAIL"
    )
    foreach ($var in $envVars) {
        $value = [Environment]::GetEnvironmentVariable($var, "User")
        $status = if ($value) { "OK" } else { "-" }
        $color = if ($value) { "Green" } else { "Gray" }
        Write-Host "  $status $var: $value" -ForegroundColor $color
    }
}

function Clear-EnvironmentVariables {
    Write-Host "Clearing all environment variables..." -ForegroundColor Yellow
    $envVars = @(
        "GIT_OFFLINE_CONFIG",
        "GIT_OFFLINE_REPO_DIR",
        "GIT_OFFLINE_BUNDLES_DIR", 
        "GIT_OFFLINE_LOCAL_BUNDLES_DIR",
        "GIT_OFFLINE_BACKUP_DIR",
        "GIT_OFFLINE_USER_NAME",
        "GIT_OFFLINE_USER_EMAIL"
    )
    foreach ($var in $envVars) {
        [Environment]::SetEnvironmentVariable($var, $null, "User")
        Write-Host "  Cleared: $var" -ForegroundColor Gray
    }
    Write-Host "All environment variables cleared." -ForegroundColor Green
}

function Set-EnvironmentFromConfig {
    try {
        $config = Read-Config
        $platform = Get-PathConfig
        $gitConfig = Get-GitConfig
        Write-Host "Setting environment variables from config file..." -ForegroundColor Yellow
        [Environment]::SetEnvironmentVariable("GIT_OFFLINE_REPO_DIR", $platform.repo_dir, "User")
        [Environment]::SetEnvironmentVariable("GIT_OFFLINE_BUNDLES_DIR", $platform.bundles_dir, "User")
        [Environment]::SetEnvironmentVariable("GIT_OFFLINE_LOCAL_BUNDLES_DIR", $platform.local_bundles_dir, "User")
        if ($platform.backup_dir) {
            [Environment]::SetEnvironmentVariable("GIT_OFFLINE_BACKUP_DIR", $platform.backup_dir, "User")
        }
        [Environment]::SetEnvironmentVariable("GIT_OFFLINE_USER_NAME", $gitConfig.user_name, "User")
        [Environment]::SetEnvironmentVariable("GIT_OFFLINE_USER_EMAIL", $gitConfig.user_email, "User")
        Write-Host "Environment variables set." -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to set environment variables: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Check command line arguments
$args = $args -join " "
if ($args -match "-ShowCurrent" -or $args -match "--show-current") {
    Show-EnvironmentVariables
} elseif ($args -match "-ClearAll" -or $args -match "--clear-all") {
    Clear-EnvironmentVariables
} else {
    Set-EnvironmentFromConfig
    Show-EnvironmentVariables
}

Write-Host ""
Write-Host "INFO:" -ForegroundColor Yellow
Write-Host "1. Environment variables are set at user level. Restart PowerShell to take effect." -ForegroundColor White
Write-Host "2. Use -ShowCurrent to view current environment variables." -ForegroundColor White
Write-Host "3. Use -ClearAll to clear all environment variables." -ForegroundColor White 