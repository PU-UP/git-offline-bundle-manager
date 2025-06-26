# Git Offline Tool Config Manager Module

function Get-ConfigPath {
    <#
    .SYNOPSIS
    Get config file path
    #>
    param(
        [string]$ConfigFile = "config.json"
    )
    
    # First check script directory
    $scriptDir = Split-Path $PSScriptRoot -Parent
    $configPath = Join-Path $scriptDir $ConfigFile
    
    if (Test-Path $configPath) {
        return $configPath
    }
    
    # Check current directory
    $currentDir = Get-Location
    $configPath = Join-Path $currentDir $ConfigFile
    
    if (Test-Path $configPath) {
        return $configPath
    }
    
    # Check environment variable specified path
    $envConfigPath = $env:GIT_OFFLINE_CONFIG
    if ($envConfigPath -and (Test-Path $envConfigPath)) {
        return $envConfigPath
    }
    
    throw "Config file not found: $ConfigFile"
}

function Read-Config {
    <#
    .SYNOPSIS
    Read config file
    #>
    param(
        [string]$ConfigFile = "config.json"
    )
    
    $configPath = Get-ConfigPath -ConfigFile $ConfigFile
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    
    # Apply environment variable overrides
    $config = Apply-EnvironmentOverrides -Config $config
    
    return $config
}

function Apply-EnvironmentOverrides {
    <#
    .SYNOPSIS
    Apply environment variable overrides to config
    #>
    param(
        [PSCustomObject]$Config
    )
    
    # Windows path overrides
    if ($env:GIT_OFFLINE_REPO_DIR) {
        $Config.paths.windows.repo_dir = $env:GIT_OFFLINE_REPO_DIR
    }
    
    if ($env:GIT_OFFLINE_BUNDLES_DIR) {
        $Config.paths.windows.bundles_dir = $env:GIT_OFFLINE_BUNDLES_DIR
    }
    
    if ($env:GIT_OFFLINE_LOCAL_BUNDLES_DIR) {
        $Config.paths.windows.local_bundles_dir = $env:GIT_OFFLINE_LOCAL_BUNDLES_DIR
    }
    
    if ($env:GIT_OFFLINE_BACKUP_DIR) {
        $Config.paths.windows.backup_dir = $env:GIT_OFFLINE_BACKUP_DIR
    }
    
    # Ubuntu path overrides
    if ($env:GIT_OFFLINE_UBUNTU_REPO_DIR) {
        $Config.paths.ubuntu.repo_dir = $env:GIT_OFFLINE_UBUNTU_REPO_DIR
    }
    
    if ($env:GIT_OFFLINE_UBUNTU_BUNDLES_DIR) {
        $Config.paths.ubuntu.bundles_dir = $env:GIT_OFFLINE_UBUNTU_BUNDLES_DIR
    }
    
    if ($env:GIT_OFFLINE_UBUNTU_LOCAL_BUNDLES_DIR) {
        $Config.paths.ubuntu.local_bundles_dir = $env:GIT_OFFLINE_UBUNTU_LOCAL_BUNDLES_DIR
    }
    
    # Git config overrides
    if ($env:GIT_OFFLINE_USER_NAME) {
        $Config.git.user_name = $env:GIT_OFFLINE_USER_NAME
    }
    
    if ($env:GIT_OFFLINE_USER_EMAIL) {
        $Config.git.user_email = $env:GIT_OFFLINE_USER_EMAIL
    }
    
    return $Config
}

function Get-PlatformConfig {
    <#
    .SYNOPSIS
    Get config for current platform
    #>
    param(
        [string]$ConfigFile = "config.json"
    )
    
    $config = Read-Config -ConfigFile $ConfigFile
    
    # Detect operating system
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        return $config.paths.windows
    } else {
        return $config.paths.ubuntu
    }
}

function Get-ConfigValue {
    <#
    .SYNOPSIS
    Get config value by dot-separated path
    #>
    param(
        [string]$Path,
        [string]$ConfigFile = "config.json"
    )
    
    $config = Read-Config -ConfigFile $ConfigFile
    
    $pathParts = $Path -split '\.'
    $current = $config
    
    foreach ($part in $pathParts) {
        if ($current.PSObject.Properties.Name -contains $part) {
            $current = $current.$part
        } else {
            throw "Config path not found: $Path"
        }
    }
    
    return $current
}

function Test-ConfigPaths {
    <#
    .SYNOPSIS
    Test if config paths exist
    #>
    param(
        [string]$ConfigFile = "config.json"
    )
    
    $config = Read-Config -ConfigFile $ConfigFile
    $platform = Get-PlatformConfig -ConfigFile $ConfigFile
    
    $results = @{}
    
    foreach ($pathName in $platform.PSObject.Properties.Name) {
        $path = $platform.$pathName
        $exists = Test-Path $path
        $results[$pathName] = @{
            Path = $path
            Exists = $exists
        }
    }
    
    return $results
}

function Show-ConfigStatus {
    <#
    .SYNOPSIS
    Show config status
    #>
    param(
        [string]$ConfigFile = "config.json"
    )
    
    Write-Host "=== Git Offline Tool Config Status ===" -ForegroundColor Cyan
    
    try {
        $config = Read-Config -ConfigFile $ConfigFile
        $platform = Get-PlatformConfig -ConfigFile $ConfigFile
        $pathStatus = Test-ConfigPaths -ConfigFile $ConfigFile
        
        Write-Host "Config file: $(Get-ConfigPath -ConfigFile $ConfigFile)" -ForegroundColor Green
        Write-Host "Current platform: $(if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'Windows' } else { 'Ubuntu' })" -ForegroundColor Green
        
        Write-Host "\nPath status:" -ForegroundColor Yellow
        foreach ($pathName in $pathStatus.Keys) {
            $status = $pathStatus[$pathName]
            $color = if ($status.Exists) { "Green" } else { "Red" }
            $icon = if ($status.Exists) { "OK" } else { "ERROR" }
            Write-Host "  $icon $pathName`: $($status.Path)" -ForegroundColor $color
        }
        
        Write-Host "\nGit config:" -ForegroundColor Yellow
        Write-Host "  user_name: $($config.git.user_name)" -ForegroundColor White
        Write-Host "  user_email: $($config.git.user_email)" -ForegroundColor White
        
    } catch {
        Write-Host "ERROR: Config error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-ConfigPath',
    'Read-Config',
    'Get-PlatformConfig',
    'Get-ConfigValue',
    'Test-ConfigPaths',
    'Show-ConfigStatus'
) 