<##
.SYNOPSIS
Show config status for Git offline tool
#>

param(
    [string]$ConfigFile = "config.json"
)

# Import config manager module
$modulePath = Join-Path $PSScriptRoot "Config-Manager.psm1"
Import-Module $modulePath -Force

try {
    Show-ConfigStatus -ConfigFile $ConfigFile
} catch {
    Write-Host "ERROR: Config check failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "\nPlease check:" -ForegroundColor Yellow
    Write-Host "1. Config file exists" -ForegroundColor White
    Write-Host "2. Config file format is correct" -ForegroundColor White
    Write-Host "3. Environment variables are set correctly" -ForegroundColor White
    exit 1
} 