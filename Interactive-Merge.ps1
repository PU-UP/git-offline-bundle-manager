<#
.SYNOPSIS
Interactive merge for resolving conflicts
#>

param(
    [string]$RepoDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "Starting interactive merge..." -ForegroundColor Yellow

# Check for conflicts
$conflicts = git -C $RepoDir diff --name-only --diff-filter=U

if (-not $conflicts) {
    Write-Host "No conflicts detected" -ForegroundColor Green
    exit 0
}

Write-Host "Conflicts found in:" -ForegroundColor Red
foreach ($file in $conflicts) {
    Write-Host "  $file" -ForegroundColor White
}

Write-Host "\nOptions:" -ForegroundColor Yellow
Write-Host "1. Use 'ours' (local changes)" -ForegroundColor White
Write-Host "2. Use 'theirs' (incoming changes)" -ForegroundColor White
Write-Host "3. Manual edit" -ForegroundColor White
Write-Host "4. Skip this file" -ForegroundColor White

foreach ($file in $conflicts) {
    Write-Host "\nResolving: $file" -ForegroundColor Cyan
    
    $choice = Read-Host "Choose option (1-4)"
    
    switch ($choice) {
        "1" {
            Write-Host "Using local changes for: $file" -ForegroundColor Green
            git -C $RepoDir checkout --ours $file
            git -C $RepoDir add $file
        }
        "2" {
            Write-Host "Using incoming changes for: $file" -ForegroundColor Green
            git -C $RepoDir checkout --theirs $file
            git -C $RepoDir add $file
        }
        "3" {
            Write-Host "Opening file for manual edit: $file" -ForegroundColor Yellow
            # Open file in default editor
            $editor = $env:EDITOR
            if (-not $editor) { $editor = "notepad" }
            & $editor $file
            
            $continue = Read-Host "Press Enter when done editing"
            git -C $RepoDir add $file
        }
        "4" {
            Write-Host "Skipping: $file" -ForegroundColor Gray
        }
        default {
            Write-Host "Invalid choice, skipping: $file" -ForegroundColor Yellow
        }
    }
}

# Check if all conflicts resolved
$remainingConflicts = git -C $RepoDir diff --name-only --diff-filter=U

if ($remainingConflicts) {
    Write-Host "\nWARNING: Some conflicts remain:" -ForegroundColor Yellow
    foreach ($file in $remainingConflicts) {
        Write-Host "  $file" -ForegroundColor White
    }
    Write-Host "Please resolve manually and run: git add ." -ForegroundColor White
} else {
    Write-Host "\nSUCCESS: All conflicts resolved" -ForegroundColor Green
    Write-Host "Run: git commit to complete merge" -ForegroundColor White
} 