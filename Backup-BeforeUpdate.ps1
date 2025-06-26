<#
.SYNOPSIS
Backup repository before update
#>

param(
    [string]$RepoDir,
    [string]$BackupDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "Creating backup..." -ForegroundColor Yellow
Write-Host "Repo: $RepoDir" -ForegroundColor White
Write-Host "Backup: $BackupDir" -ForegroundColor White

# Create backup directory
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir | Out-Null
}

# Copy repository
Copy-Item -Path $RepoDir -Destination $BackupDir -Recurse -Force

Write-Host "SUCCESS: Backup completed" -ForegroundColor Green 