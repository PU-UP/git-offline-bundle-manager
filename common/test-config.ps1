#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Git Offline Bundle Manager - Quick Configuration Test Script
.DESCRIPTION
    Quickly verify if the configuration file is correct, check paths, Git config, etc.
.EXAMPLE
    .\test-config.ps1
.EXAMPLE
    .\test-config.ps1 -Environment offline_windows
#>

param(
    [string]$Environment = $null
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Global variables
$script:Config = $null
$script:ConfigPath = "config.json"

function Write-Status {
    param(
        [string]$Message,
        [string]$Status = "INFO"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $statusColor = switch ($Status) {
        "OK" { "Green" }
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] [$Status] $Message" -ForegroundColor $statusColor
}

function Read-Config {
    param(
        [string]$ConfigPath = $script:ConfigPath
    )
    
    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }
    
    try {
        $content = Get-Content $ConfigPath -Raw -Encoding UTF8
        $script:Config = $content | ConvertFrom-Json
    } catch {
        throw "Config file format error: $($_.Exception.Message)"
    }
}

function Get-CurrentEnvironment {
    # Check if platform is forced
    if ($script:Config.global.platform.force_platform) {
        $forcePlatform = $script:Config.global.platform.force_platform
        switch ($forcePlatform) {
            "windows" { return "offline_windows" }
            "ubuntu" { return "offline_ubuntu" }
            "gitlab" { return "gitlab_server" }
            default { return $forcePlatform }
        }
    }
    
    # Auto-detect platform (compatible with older PowerShell versions)
    if ($env:OS -eq "Windows_NT" -or $PSVersionTable.Platform -eq "Win32NT") {
        return "offline_windows"
    } elseif ($PSVersionTable.Platform -eq "Unix" -or $PSVersionTable.Platform -eq "Linux") {
        # Check if has GitLab access (simple detection)
        try {
            $gitRemote = git remote get-url origin 2>$null
            if ($gitRemote -and $gitRemote -match "gitlab") {
                return "gitlab_server"
            } else {
                return "offline_ubuntu"
            }
        } catch {
            return "offline_ubuntu"
        }
    }
    
    return "offline_windows"  # Default
}

function Get-EnvironmentConfig {
    param(
        [string]$Environment
    )
    
    if ($script:Config.environments.$Environment) {
        return $script:Config.environments.$Environment
    }
    
    return $null
}

function Test-PathAccess {
    param(
        [string]$Path,
        [string]$PathName
    )
    
    if (-not $Path) {
        Write-Status "Path config '$PathName' is empty" "WARNING"
        return $false
    }
    
    if (-not (Test-Path $Path -ErrorAction SilentlyContinue)) {
        Write-Status "Path does not exist: $Path" "WARNING"
        return $false
    }
    
    try {
        $testFile = Join-Path $Path "test-access.tmp"
        New-Item -ItemType File -Path $testFile -Force | Out-Null
        Remove-Item $testFile -Force
        Write-Status "Path accessible: $Path" "OK"
        return $true
    } catch {
        Write-Status "Path not writable: $Path" "ERROR"
        return $false
    }
}

function Test-GitConfig {
    param(
        [object]$GitConfig
    )
    
    $isValid = $true
    
    if (-not $GitConfig.user_name -or $GitConfig.user_name -eq "Your Name") {
        Write-Status "Git username not set or using default" "WARNING"
        $isValid = $false
    } else {
        Write-Status "Git username: $($GitConfig.user_name)" "OK"
    }
    
    if (-not $GitConfig.user_email -or $GitConfig.user_email -eq "your.email@company.com") {
        Write-Status "Git email not set or using default" "WARNING"
        $isValid = $false
    } else {
        Write-Status "Git email: $($GitConfig.user_email)" "OK"
    }
    
    return $isValid
}

function Test-GitInstallation {
    try {
        $gitVersion = git --version 2>$null
        if ($gitVersion) {
            Write-Status "Git installed: $gitVersion" "OK"
            return $true
        } else {
            Write-Status "Git not installed or not in PATH" "ERROR"
            return $false
        }
    } catch {
        Write-Status "Git not installed or not in PATH" "ERROR"
        return $false
    }
}

function Test-EnvironmentDetection {
    $currentEnv = Get-CurrentEnvironment
    Write-Status "Detected environment: $currentEnv" "INFO"
    
    if ($Environment -and $Environment -ne $currentEnv) {
        Write-Status "Specified environment doesn't match detected: $Environment vs $currentEnv" "WARNING"
    }
    
    return $currentEnv
}

# Main test function
function Start-ConfigTest {
    Write-Host "=== Git Offline Bundle Manager - Configuration Test ===" -ForegroundColor Cyan
    Write-Host ""
    
    $overallSuccess = $true
    $testResults = @{}
    
    try {
        # 1. Test config file reading
        Write-Status "Starting configuration test..." "INFO"
        Write-Host ""
        
        Read-Config
        Write-Status "Config file read successfully" "OK"
        
        # 2. Test environment detection
        $detectedEnv = Test-EnvironmentDetection
        $testResults.EnvironmentDetection = $true
        
        # 3. Test Git installation
        $testResults.GitInstallation = Test-GitInstallation
        
        # 4. Get environment config
        $envConfig = Get-EnvironmentConfig -Environment $detectedEnv
        if (-not $envConfig) {
            Write-Status "Environment config '$detectedEnv' not found" "ERROR"
            $overallSuccess = $false
            $testResults.EnvironmentConfig = $false
        } else {
            Write-Status "Environment config loaded successfully" "OK"
            $testResults.EnvironmentConfig = $true
            
            # 5. Test path config
            Write-Host ""
            Write-Status "Testing path configuration..." "INFO"
            $pathSuccess = $true
            
            if ($envConfig.paths) {
                foreach ($path in $envConfig.paths.PSObject.Properties) {
                    $pathValid = Test-PathAccess -Path $path.Value -PathName $path.Name
                    if (-not $pathValid) {
                        $pathSuccess = $false
                    }
                }
            } else {
                Write-Status "Path configuration missing" "ERROR"
                $pathSuccess = $false
            }
            
            $testResults.PathConfig = $pathSuccess
            
            # 6. Test Git config
            Write-Host ""
            Write-Status "Testing Git configuration..." "INFO"
            $gitSuccess = $true
            
            if ($envConfig.git) {
                $gitValid = Test-GitConfig -GitConfig $envConfig.git
                if (-not $gitValid) {
                    $gitSuccess = $false
                }
            } else {
                Write-Status "Git configuration missing" "ERROR"
                $gitSuccess = $false
            }
            
            $testResults.GitConfig = $gitSuccess
            
            # 7. Test sync config
            Write-Host ""
            Write-Status "Testing sync configuration..." "INFO"
            if ($envConfig.sync) {
                Write-Status "Sync configuration exists" "OK"
                foreach ($sync in $envConfig.sync.PSObject.Properties) {
                    Write-Status "  $($sync.Name): $($sync.Value)" "INFO"
                }
                $testResults.SyncConfig = $true
            } else {
                Write-Status "Sync configuration missing" "WARNING"
                $testResults.SyncConfig = $false
            }
        }
        
        # 8. Test global config
        Write-Host ""
        Write-Status "Testing global configuration..." "INFO"
        if ($script:Config.global) {
            Write-Status "Global configuration exists" "OK"
            $testResults.GlobalConfig = $true
        } else {
            Write-Status "Global configuration missing" "ERROR"
            $testResults.GlobalConfig = $false
            $overallSuccess = $false
        }
        
    } catch {
        Write-Status "Configuration test failed: $($_.Exception.Message)" "ERROR"
        $overallSuccess = $false
    }
    
    # Show test summary
    Write-Host ""
    Write-Host "=== Test Summary ===" -ForegroundColor Cyan
    
    $passedTests = 0
    $totalTests = 0
    
    foreach ($result in $testResults.GetEnumerator()) {
        $totalTests++
        if ($result.Value -eq $true) {
            $passedTests++
        }
    }
    
    Write-Status "Tests passed: $passedTests/$totalTests" "INFO"
    
    if ($overallSuccess) {
        Write-Status "Configuration test passed! Ready to use Git Offline Bundle Manager" "OK"
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Run the corresponding initialization script" -ForegroundColor White
        Write-Host "2. Start offline development work" -ForegroundColor White
    } else {
        Write-Status "Configuration test failed, please fix the above issues and try again" "ERROR"
        Write-Host ""
        Write-Host "Fix suggestions:" -ForegroundColor Yellow
        Write-Host "1. Check if config file format is correct" -ForegroundColor White
        Write-Host "2. Ensure all paths exist and are accessible" -ForegroundColor White
        Write-Host "3. Set correct Git username and email" -ForegroundColor White
        Write-Host "4. Ensure Git is properly installed" -ForegroundColor White
    }
    
    return $overallSuccess
}

# Execute test
try {
    $result = Start-ConfigTest
    exit $(if ($result) { 0 } else { 1 })
} catch {
    Write-Status "Test script execution failed: $($_.Exception.Message)" "ERROR"
    exit 1
} 