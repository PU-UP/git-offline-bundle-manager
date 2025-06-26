Write-Host "=== Debug Test ===" -ForegroundColor Cyan

# Step 1: Basic output test
Write-Host "Step 1: Basic output test" -ForegroundColor Green

# Step 2: Check if we can import the module
Write-Host "Step 2: Testing module import" -ForegroundColor Green
try {
    $modulePath = Join-Path $PSScriptRoot "common\Config-Manager.psm1"
    Write-Host "Module path: $modulePath" -ForegroundColor Yellow
    
    if (Test-Path $modulePath) {
        Write-Host "Module file exists" -ForegroundColor Green
        Import-Module $modulePath -Force
        Write-Host "Module imported successfully" -ForegroundColor Green
    } else {
        Write-Host "Module file not found" -ForegroundColor Red
    }
} catch {
    Write-Host "Error importing module: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 3: Test config reading
Write-Host "Step 3: Testing config reading" -ForegroundColor Green
try {
    if (Test-Path "config.json") {
        Write-Host "Config file exists" -ForegroundColor Green
        $content = Get-Content "config.json" -Raw
        Write-Host "Config file size: $($content.Length) characters" -ForegroundColor Yellow
    } else {
        Write-Host "Config file not found" -ForegroundColor Red
    }
} catch {
    Write-Host "Error reading config: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Debug test completed" -ForegroundColor Yellow 