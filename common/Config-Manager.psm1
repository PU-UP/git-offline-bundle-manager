# Git Offline Bundle Manager - Config Manager (English Only)

# 全局变量
$script:Config = $null
$script:ConfigPath = "config.json"

# 获取配置值（支持新的环境分类结构）
function Get-ConfigValue {
    param(
        [string]$Path,
        [string]$Environment = $null
    )
    
    if ($null -eq $script:Config) {
        Read-Config
    }
    
    # 如果指定了环境，优先从环境配置中获取
    if ($Environment -and $script:Config.environments.$Environment) {
        $envConfig = $script:Config.environments.$Environment
        $value = Get-NestedProperty -Object $envConfig -Path $Path
        if ($null -ne $value) {
            return $value
        }
    }
    
    # 从全局配置中获取
    if ($script:Config.global) {
        return Get-NestedProperty -Object $script:Config.global -Path $Path
    }
    
    return $null
}

# 获取环境配置
function Get-EnvironmentConfig {
    param(
        [string]$Environment
    )
    
    if ($null -eq $script:Config) {
        Read-Config
    }
    
    if ($script:Config.environments.$Environment) {
        return $script:Config.environments.$Environment
    }
    
    return $null
}

# 获取当前环境名称
function Get-CurrentEnvironment {
    # 检查是否强制指定平台
    $forcePlatform = Get-ConfigValue -Path "platform.force_platform"
    if ($forcePlatform) {
        switch ($forcePlatform) {
            "windows" { return "offline_windows" }
            "ubuntu" { return "offline_ubuntu" }
            "gitlab" { return "gitlab_server" }
            default { return $forcePlatform }
        }
    }
    
    # 自动检测平台
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        return "offline_windows"
    } elseif ($IsLinux -or $IsMacOS) {
        # 检查是否有GitLab访问权限（简单检测）
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
    
    return "offline_windows"  # 默认
}

# 读取配置文件
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

# 获取嵌套属性值
function Get-NestedProperty {
    param(
        [object]$Object,
        [string]$Path
    )
    
    $keys = $Path.Split('.')
    $current = $Object
    
    foreach ($key in $keys) {
        if ($null -eq $current -or -not (Get-Member -InputObject $current -Name $key)) {
            return $null
        }
        $current = $current.$key
    }
    
    return $current
}

# 显示配置信息
function Show-Config {
    param(
        [string]$Environment = $null
    )
    
    if ($null -eq $script:Config) {
        Read-Config
    }
    
    $currentEnv = if ($Environment) { $Environment } else { Get-CurrentEnvironment }
    
    Write-Host "=== Git Offline Bundle Manager - Config Info ===" -ForegroundColor Cyan
    Write-Host ""
    
    # 显示当前环境
    Write-Host "Current environment: $currentEnv" -ForegroundColor Yellow
    if ($script:Config.environments.$currentEnv.description) {
        Write-Host "Description: $($script:Config.environments.$currentEnv.description)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # 显示环境配置
    $envConfig = Get-EnvironmentConfig -Environment $currentEnv
    if ($envConfig) {
        Write-Host "=== Environment Config ===" -ForegroundColor Green
        
        # 路径配置
        Write-Host "Paths:" -ForegroundColor Yellow
        foreach ($path in $envConfig.paths.PSObject.Properties) {
            Write-Host "  $($path.Name): $($path.Value)" -ForegroundColor White
        }
        Write-Host ""
        
        # Git配置
        Write-Host "Git:" -ForegroundColor Yellow
        foreach ($git in $envConfig.git.PSObject.Properties) {
            Write-Host "  $($git.Name): $($git.Value)" -ForegroundColor White
        }
        Write-Host ""
        
        # 同步配置
        Write-Host "Sync:" -ForegroundColor Yellow
        foreach ($sync in $envConfig.sync.PSObject.Properties) {
            Write-Host "  $($sync.Name): $($sync.Value)" -ForegroundColor White
        }
        Write-Host ""
    }
    
    # 显示全局配置
    Write-Host "=== Global Config ===" -ForegroundColor Green
    if ($script:Config.global) {
        foreach ($section in $script:Config.global.PSObject.Properties) {
            Write-Host "$($section.Name):" -ForegroundColor Yellow
            foreach ($item in $section.Value.PSObject.Properties) {
                Write-Host "  $($item.Name): $($item.Value)" -ForegroundColor White
            }
            Write-Host ""
        }
    }
    
    # 显示环境变量覆盖
    Write-Host "=== Environment Variable Overrides ===" -ForegroundColor Green
    $envVars = @(
        "GIT_OFFLINE_REPO_DIR",
        "GIT_OFFLINE_BUNDLES_DIR", 
        "GIT_OFFLINE_LOCAL_BUNDLES_DIR",
        "GIT_OFFLINE_BACKUP_DIR",
        "GIT_OFFLINE_USER_NAME",
        "GIT_OFFLINE_USER_EMAIL"
    )
    
    foreach ($var in $envVars) {
        $value = [Environment]::GetEnvironmentVariable($var)
        if ($value) {
            Write-Host "  ${var}: $value" -ForegroundColor Magenta
        }
    }
    Write-Host ""
}

# 验证配置
function Test-Config {
    param(
        [string]$Environment = $null
    )
    
    if ($null -eq $script:Config) {
        Read-Config
    }
    
    $currentEnv = if ($Environment) { $Environment } else { Get-CurrentEnvironment }
    $errors = @()
    $warnings = @()
    
    Write-Host "=== Config Validation ===" -ForegroundColor Cyan
    Write-Host "Environment: $currentEnv" -ForegroundColor Yellow
    Write-Host ""
    
    # 检查环境配置是否存在
    if (-not $script:Config.environments.$currentEnv) {
        $errors += "[ERROR] Environment config '$currentEnv' not found."
    } else {
        $envConfig = $script:Config.environments.$currentEnv
        
        # 检查路径配置
        if ($envConfig.paths) {
            foreach ($path in $envConfig.paths.PSObject.Properties) {
                $pathValue = $path.Value
                if (-not $pathValue) {
                    $warnings += "[WARNING] Path config '$($path.Name)' is empty."
                } elseif (-not (Test-Path $pathValue -ErrorAction SilentlyContinue)) {
                    $warnings += "[WARNING] Path does not exist: $pathValue"
                }
            }
        } else {
            $errors += "[ERROR] Missing path config."
        }
        
        # 检查Git配置
        if ($envConfig.git) {
            if (-not $envConfig.git.user_name -or $envConfig.git.user_name -eq "Your Name") {
                $warnings += "[WARNING] Git user_name not set or default."
            }
            if (-not $envConfig.git.user_email -or $envConfig.git.user_email -eq "your.email@company.com") {
                $warnings += "[WARNING] Git user_email not set or default."
            }
        } else {
            $errors += "[ERROR] Missing Git config."
        }
    }
    
    # 检查全局配置
    if (-not $script:Config.global) {
        $errors += "[ERROR] Missing global config."
    }
    
    # 显示结果
    if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
        Write-Host "[OK] Config validation passed." -ForegroundColor Green
    } else {
        if ($errors.Count -gt 0) {
            Write-Host "[ERROR] $($errors.Count) error(s) found:" -ForegroundColor Red
            foreach ($error in $errors) {
                Write-Host "  - $error" -ForegroundColor Red
            }
            Write-Host ""
        }
        
        if ($warnings.Count -gt 0) {
            Write-Host "[WARNING] $($warnings.Count) warning(s) found:" -ForegroundColor Yellow
            foreach ($warning in $warnings) {
                Write-Host "  - $warning" -ForegroundColor Yellow
            }
            Write-Host ""
        }
    }
    
    return $errors.Count -eq 0
}

# 获取路径配置
function Get-PathConfig {
    param(
        [string]$Environment = $null
    )
    
    $currentEnv = if ($Environment) { $Environment } else { Get-CurrentEnvironment }
    $envConfig = Get-EnvironmentConfig -Environment $currentEnv
    
    if ($envConfig -and $envConfig.paths) {
        return $envConfig.paths
    }
    
    return $null
}

# 获取Git配置
function Get-GitConfig {
    param(
        [string]$Environment = $null
    )
    
    $currentEnv = if ($Environment) { $Environment } else { Get-CurrentEnvironment }
    $envConfig = Get-EnvironmentConfig -Environment $currentEnv
    
    if ($envConfig -and $envConfig.git) {
        return $envConfig.git
    }
    
    return $null
}

# 获取同步配置
function Get-SyncConfig {
    param(
        [string]$Environment = $null
    )
    
    $currentEnv = if ($Environment) { $Environment } else { Get-CurrentEnvironment }
    $envConfig = Get-EnvironmentConfig -Environment $currentEnv
    
    if ($envConfig -and $envConfig.sync) {
        return $envConfig.sync
    }
    
    return $null
}

# 导出模块成员
Export-ModuleMember -Function @(
    'Get-ConfigValue',
    'Get-EnvironmentConfig', 
    'Get-CurrentEnvironment',
    'Read-Config',
    'Show-Config',
    'Test-Config',
    'Get-PathConfig',
    'Get-GitConfig',
    'Get-SyncConfig'
) 