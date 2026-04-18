<#
    VeriHash.Config.ps1 - Configuration management for VeriHash

    Copyright (C) 2024-2025 arcticpinecone <arcticpinecone@arcticpinecone.eu>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Provides unified configuration management with priority:
    Environment variables > Config file > Defaults

    Functions:
    - Get-VeriHashConfigPath: Returns platform-specific config directory
    - Get-VeriHashDefaultConfig: Returns default configuration hashtable
    - Get-VeriHashConfig: Loads merged configuration from all sources
    - Set-VeriHashConfig: Saves configuration to file
    - Initialize-VeriHashConfig: Creates default config on first run
#>

#region Platform Detection
$script:RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform
$script:RunningOnLinux = $PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Linux'
$script:RunningOnMacOS = $PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Darwin'
#endregion Platform Detection

#region Valid Values
$script:ValidLogLevels = @('DEBUG', 'VERBOSE', 'INFO', 'WARNING', 'ERROR', 'NONE')
#endregion Valid Values

function Get-VeriHashConfigPath {
    <#
    .SYNOPSIS
        Returns the platform-specific configuration directory path for VeriHash.

    .DESCRIPTION
        Returns the appropriate configuration directory based on the operating system:
        - Windows: $env:APPDATA\VeriHash
        - Linux/macOS: ~/.verihash

    .OUTPUTS
        System.String - The configuration directory path

    .EXAMPLE
        $configDir = Get-VeriHashConfigPath
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($script:RunningOnWindows) {
        Join-Path $env:APPDATA "VeriHash"
    } else {
        Join-Path $HOME ".verihash"
    }
}

function Get-VeriHashDefaultConfig {
    <#
    .SYNOPSIS
        Returns the default VeriHash configuration.

    .DESCRIPTION
        Returns a hashtable containing all default configuration values for VeriHash.
        This serves as the base configuration that file and environment settings override.

    .OUTPUTS
        System.Collections.Hashtable - Default configuration

    .EXAMPLE
        $defaults = Get-VeriHashDefaultConfig
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    @{
        logging = @{
            level   = 'INFO'
            file    = $true
            console = $true
        }
        virustotal = @{
            apiKey    = ''
            enabled   = $true
            preferApi = $true
            autoOpen  = $false
        }
    }
}

function Get-VeriHashConfig {
    <#
    .SYNOPSIS
        Loads VeriHash configuration with proper priority merging.

    .DESCRIPTION
        Loads configuration from multiple sources with priority:
        1. Environment variables (highest priority)
        2. Config file
        3. Defaults (lowest priority)

        Environment variables:
        - VERIHASH_LOG_LEVEL: Logging level (DEBUG, VERBOSE, INFO, WARNING, ERROR, NONE)
        - VERIHASH_LOG_FILE: Enable file logging (true/false)
        - VERIHASH_LOG_CONSOLE: Enable console logging (true/false)
        - VERIHASH_VT_APIKEY: VirusTotal API key
        - VERIHASH_VT_ENABLED: Enable VirusTotal integration (true/false)

    .PARAMETER ConfigDirectory
        Optional. Override the config directory path. Defaults to platform-specific path.

    .PARAMETER IncludeSource
        If specified, includes a _source property showing where each setting came from.

    .OUTPUTS
        System.Collections.Hashtable - Merged configuration

    .EXAMPLE
        $config = Get-VeriHashConfig
        Write-Host "Log level: $($config.logging.level)"

    .EXAMPLE
        $config = Get-VeriHashConfig -IncludeSource
        Write-Host "Log level source: $($config._source.'logging.level')"
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigDirectory,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeSource
    )

    # Determine config directory
    $configDir = if ($ConfigDirectory) { $ConfigDirectory } else { Get-VeriHashConfigPath }
    $configFile = Join-Path $configDir "config.json"

    # Start with defaults
    $config = Get-VeriHashDefaultConfig
    $source = @{}

    # Initialize source tracking with defaults
    $source.'logging.level' = 'default'
    $source.'logging.file' = 'default'
    $source.'logging.console' = 'default'
    $source.'virustotal.apiKey' = 'default'
    $source.'virustotal.enabled' = 'default'
    $source.'virustotal.preferApi' = 'default'
    $source.'virustotal.autoOpen' = 'default'

    # Log config loading start
    if ($script:PSFrameworkAvailable) {
        Write-PSFMessage -Level Debug -Message "Loading VeriHash configuration" -Tag 'Config', 'Entry' -Data @{
            ConfigDirectory = $configDir
            ConfigFile = $configFile
        }
    }

    # Load from config file if it exists
    if (Test-Path $configFile) {
        try {
            $fileContent = Get-Content $configFile -Raw | ConvertFrom-Json

            # Merge logging settings from file
            if ($fileContent.logging) {
                if ($null -ne $fileContent.logging.level -and $fileContent.logging.level -ne '') {
                    if ($fileContent.logging.level -in $script:ValidLogLevels) {
                        $config.logging.level = $fileContent.logging.level
                        $source.'logging.level' = 'file'
                    } else {
                        if ($script:PSFrameworkAvailable) {
                            Write-PSFMessage -Level Warning -Message "Invalid log level in config file: $($fileContent.logging.level)" -Tag 'Config', 'Validation'
                        }
                    }
                }
                if ($null -ne $fileContent.logging.file) {
                    $config.logging.file = [bool]$fileContent.logging.file
                    $source.'logging.file' = 'file'
                }
                if ($null -ne $fileContent.logging.console) {
                    $config.logging.console = [bool]$fileContent.logging.console
                    $source.'logging.console' = 'file'
                }
            }

            # Merge virustotal settings from file
            if ($fileContent.virustotal) {
                if ($null -ne $fileContent.virustotal.apiKey) {
                    $config.virustotal.apiKey = $fileContent.virustotal.apiKey
                    $source.'virustotal.apiKey' = 'file'
                }
                if ($null -ne $fileContent.virustotal.enabled) {
                    $config.virustotal.enabled = [bool]$fileContent.virustotal.enabled
                    $source.'virustotal.enabled' = 'file'
                }
                if ($null -ne $fileContent.virustotal.preferApi) {
                    $config.virustotal.preferApi = [bool]$fileContent.virustotal.preferApi
                    $source.'virustotal.preferApi' = 'file'
                }
                if ($null -ne $fileContent.virustotal.autoOpen) {
                    $config.virustotal.autoOpen = [bool]$fileContent.virustotal.autoOpen
                    $source.'virustotal.autoOpen' = 'file'
                }
            }

            if ($script:PSFrameworkAvailable) {
                Write-PSFMessage -Level Debug -Message "Loaded configuration from file" -Tag 'Config', 'File' -Data @{
                    ConfigFile = $configFile
                }
            }
        }
        catch {
            # Config file exists but is malformed - use defaults
            if ($script:PSFrameworkAvailable) {
                Write-PSFMessage -Level Warning -Message "Failed to parse config file, using defaults" -Tag 'Config', 'Error' -ErrorRecord $_
            }
        }
    } else {
        if ($script:PSFrameworkAvailable) {
            Write-PSFMessage -Level Debug -Message "No config file found, using defaults" -Tag 'Config' -Data @{
                ConfigFile = $configFile
            }
        }
    }

    # Apply environment variable overrides (highest priority)
    if ($env:VERIHASH_LOG_LEVEL) {
        $envLevel = $env:VERIHASH_LOG_LEVEL.ToUpper()
        if ($envLevel -in $script:ValidLogLevels) {
            $config.logging.level = $envLevel
            $source.'logging.level' = 'env'
        } else {
            if ($script:PSFrameworkAvailable) {
                Write-PSFMessage -Level Warning -Message "Invalid VERIHASH_LOG_LEVEL: $envLevel" -Tag 'Config', 'Validation'
            }
        }
    }

    if ($env:VERIHASH_LOG_FILE) {
        $config.logging.file = $env:VERIHASH_LOG_FILE -eq 'true'
        $source.'logging.file' = 'env'
    }

    if ($env:VERIHASH_LOG_CONSOLE) {
        $config.logging.console = $env:VERIHASH_LOG_CONSOLE -eq 'true'
        $source.'logging.console' = 'env'
    }

    if ($env:VERIHASH_VT_APIKEY) {
        $config.virustotal.apiKey = $env:VERIHASH_VT_APIKEY
        $source.'virustotal.apiKey' = 'env'
    }

    if ($env:VERIHASH_VT_ENABLED) {
        $config.virustotal.enabled = $env:VERIHASH_VT_ENABLED -eq 'true'
        $source.'virustotal.enabled' = 'env'
    }

    # Log final configuration
    if ($script:PSFrameworkAvailable) {
        Write-PSFMessage -Level Debug -Message "Configuration loaded" -Tag 'Config', 'Success' -Data @{
            LogLevel = $config.logging.level
            LogLevelSource = $source.'logging.level'
            LogFile = $config.logging.file
            LogConsole = $config.logging.console
            VTEnabled = $config.virustotal.enabled
            VTHasApiKey = ($config.virustotal.apiKey -ne '')
        }
    }

    # Include source tracking if requested
    if ($IncludeSource) {
        $config._source = $source
    }

    $config
}

function Set-VeriHashConfig {
    <#
    .SYNOPSIS
        Saves VeriHash configuration to file.

    .DESCRIPTION
        Writes the provided configuration hashtable to the config.json file.
        Creates the config directory if it doesn't exist.

    .PARAMETER Config
        The configuration hashtable to save.

    .PARAMETER ConfigDirectory
        Optional. Override the config directory path.

    .EXAMPLE
        $config = Get-VeriHashConfig
        $config.logging.level = 'DEBUG'
        Set-VeriHashConfig -Config $config
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [string]$ConfigDirectory
    )

    # Determine config directory
    $configDir = if ($ConfigDirectory) { $ConfigDirectory } else { Get-VeriHashConfigPath }
    $configFile = Join-Path $configDir "config.json"

    if ($script:PSFrameworkAvailable) {
        Write-PSFMessage -Level Debug -Message "Saving VeriHash configuration" -Tag 'Config', 'Entry' -Data @{
            ConfigDirectory = $configDir
            ConfigFile = $configFile
        }
    }

    # Create directory if needed
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        if ($script:PSFrameworkAvailable) {
            Write-PSFMessage -Level Debug -Message "Created config directory" -Tag 'Config' -Data @{
                ConfigDirectory = $configDir
            }
        }
    }

    # Remove _source if present (don't save internal tracking data)
    $configToSave = @{
        logging = $Config.logging
        virustotal = $Config.virustotal
    }

    # Write config file
    if ($PSCmdlet.ShouldProcess($configFile, 'Save VeriHash configuration')) {
        $configToSave | ConvertTo-Json -Depth 3 | Set-Content $configFile -Encoding UTF8

        if ($script:PSFrameworkAvailable) {
            Write-PSFMessage -Level Debug -Message "Configuration saved" -Tag 'Config', 'Success' -Data @{
                ConfigFile = $configFile
            }
        }
    }
}

function Initialize-VeriHashConfig {
    <#
    .SYNOPSIS
        Initializes VeriHash configuration on first run.

    .DESCRIPTION
        Creates the config directory and default config file if they don't exist.
        Does not overwrite existing configuration unless -Force is specified.

    .PARAMETER ConfigDirectory
        Optional. Override the config directory path.

    .PARAMETER Force
        If specified, overwrites existing configuration with defaults.

    .OUTPUTS
        System.Collections.Hashtable - The initialized/existing configuration

    .EXAMPLE
        $config = Initialize-VeriHashConfig

    .EXAMPLE
        $config = Initialize-VeriHashConfig -Force
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigDirectory,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    # Determine config directory
    $configDir = if ($ConfigDirectory) { $ConfigDirectory } else { Get-VeriHashConfigPath }
    $configFile = Join-Path $configDir "config.json"

    if ($script:PSFrameworkAvailable) {
        Write-PSFMessage -Level Debug -Message "Initializing VeriHash configuration" -Tag 'Config', 'Init' -Data @{
            ConfigDirectory = $configDir
            Force = $Force.IsPresent
        }
    }

    # Create directory if needed
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        if ($script:PSFrameworkAvailable) {
            Write-PSFMessage -Level Debug -Message "Created config directory" -Tag 'Config', 'Init' -Data @{
                ConfigDirectory = $configDir
            }
        }
    }

    # Check if config already exists
    if ((Test-Path $configFile) -and -not $Force) {
        if ($script:PSFrameworkAvailable) {
            Write-PSFMessage -Level Debug -Message "Config file already exists, loading existing" -Tag 'Config', 'Init'
        }
        return Get-VeriHashConfig -ConfigDirectory $configDir
    }

    # Create default config
    $defaultConfig = Get-VeriHashDefaultConfig
    Set-VeriHashConfig -Config $defaultConfig -ConfigDirectory $configDir

    if ($script:PSFrameworkAvailable) {
        Write-PSFMessage -Level Verbose -Message "Created default configuration" -Tag 'Config', 'Init' -Data @{
            ConfigFile = $configFile
        }
    }

    $defaultConfig
}

# Functions are exported by dot-sourcing this file
