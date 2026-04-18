BeforeAll {
    # Import LogUtils first (Config depends on ConvertTo-SanitizedPath)
    $script:LogUtilsPath = "$PSScriptRoot\..\VeriHash.LogUtils.ps1"
    . $script:LogUtilsPath

    # Import the Config functions
    $script:ConfigPath = "$PSScriptRoot\..\VeriHash.Config.ps1"
    . $script:ConfigPath

    # Create a temp directory for test config files
    $script:TestConfigDir = Join-Path $TestDrive "ConfigTests"
    New-Item -ItemType Directory -Path $script:TestConfigDir -Force | Out-Null
}

AfterAll {
    # Clean up any environment variables we set during tests
    $env:VERIHASH_LOG_LEVEL = $null
    $env:VERIHASH_LOG_FILE = $null
    $env:VERIHASH_LOG_CONSOLE = $null
    $env:VERIHASH_VT_APIKEY = $null
    $env:VERIHASH_VT_ENABLED = $null
}

Describe 'Get-VeriHashConfigPath' {
    Context 'Returns platform-appropriate path' {
        It 'Returns a valid path string' {
            # Act
            $result = Get-VeriHashConfigPath

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [string]
        }

        It 'Returns Windows path on Windows' {
            # Skip if not Windows
            if (-not ($PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform)) {
                Set-ItResult -Skipped -Because "Not running on Windows"
                return
            }

            # Act
            $result = Get-VeriHashConfigPath

            # Assert
            $result | Should -Match 'AppData.*VeriHash'
        }

        It 'Returns Unix path on Linux/macOS' {
            # Skip if on Windows
            if ($PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform) {
                Set-ItResult -Skipped -Because "Running on Windows"
                return
            }

            # Act
            $result = Get-VeriHashConfigPath

            # Assert
            $result | Should -Match '\.verihash'
        }
    }
}

Describe 'Get-VeriHashDefaultConfig' {
    Context 'Returns default configuration' {
        It 'Returns a hashtable with logging section' {
            # Act
            $result = Get-VeriHashDefaultConfig

            # Assert
            $result | Should -BeOfType [hashtable]
            $result.logging | Should -Not -BeNullOrEmpty
        }

        It 'Returns a hashtable with virustotal section' {
            # Act
            $result = Get-VeriHashDefaultConfig

            # Assert
            $result.virustotal | Should -Not -BeNullOrEmpty
        }

        It 'Has correct default logging values' {
            # Act
            $result = Get-VeriHashDefaultConfig

            # Assert
            $result.logging.level | Should -Be 'INFO'
            $result.logging.file | Should -Be $true
            $result.logging.console | Should -Be $true
        }

        It 'Has correct default virustotal values' {
            # Act
            $result = Get-VeriHashDefaultConfig

            # Assert
            $result.virustotal.apiKey | Should -Be ''
            $result.virustotal.enabled | Should -Be $true
            $result.virustotal.preferApi | Should -Be $true
            $result.virustotal.autoOpen | Should -Be $false
        }
    }
}

Describe 'Get-VeriHashConfig' {
    BeforeEach {
        # Clean environment before each test
        $env:VERIHASH_LOG_LEVEL = $null
        $env:VERIHASH_LOG_FILE = $null
        $env:VERIHASH_LOG_CONSOLE = $null
        $env:VERIHASH_VT_APIKEY = $null
        $env:VERIHASH_VT_ENABLED = $null
    }

    Context 'When no config file exists' {
        It 'Returns default configuration' {
            # Arrange
            $nonExistentPath = Join-Path $script:TestConfigDir "nonexistent"

            # Act
            $result = Get-VeriHashConfig -ConfigDirectory $nonExistentPath

            # Assert
            $result.logging.level | Should -Be 'INFO'
            $result.virustotal.enabled | Should -Be $true
        }
    }

    Context 'When config file exists' {
        It 'Loads configuration from file' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "filetest"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $configFile = Join-Path $testDir "config.json"
            @{
                logging = @{
                    level = 'DEBUG'
                    file = $false
                    console = $true
                }
                virustotal = @{
                    apiKey = 'test-api-key'
                    enabled = $false
                    preferApi = $false
                    autoOpen = $true
                }
            } | ConvertTo-Json -Depth 3 | Set-Content $configFile

            # Act
            $result = Get-VeriHashConfig -ConfigDirectory $testDir

            # Assert
            $result.logging.level | Should -Be 'DEBUG'
            $result.logging.file | Should -Be $false
            $result.virustotal.apiKey | Should -Be 'test-api-key'
            $result.virustotal.enabled | Should -Be $false
        }

        It 'Merges partial config with defaults' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "partialtest"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $configFile = Join-Path $testDir "config.json"
            # Only set logging.level, everything else should be defaults
            @{
                logging = @{
                    level = 'WARNING'
                }
            } | ConvertTo-Json -Depth 3 | Set-Content $configFile

            # Act
            $result = Get-VeriHashConfig -ConfigDirectory $testDir

            # Assert
            $result.logging.level | Should -Be 'WARNING'
            $result.logging.file | Should -Be $true  # Default
            $result.logging.console | Should -Be $true  # Default
            $result.virustotal.enabled | Should -Be $true  # Default
        }
    }

    Context 'Environment variable overrides' {
        It 'Environment variable overrides config file for log level' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "envtest1"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $configFile = Join-Path $testDir "config.json"
            @{
                logging = @{ level = 'INFO' }
            } | ConvertTo-Json -Depth 3 | Set-Content $configFile
            $env:VERIHASH_LOG_LEVEL = 'DEBUG'

            # Act
            $result = Get-VeriHashConfig -ConfigDirectory $testDir

            # Assert
            $result.logging.level | Should -Be 'DEBUG'
        }

        It 'Environment variable overrides config file for VirusTotal API key' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "envtest2"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $configFile = Join-Path $testDir "config.json"
            @{
                virustotal = @{ apiKey = 'file-key' }
            } | ConvertTo-Json -Depth 3 | Set-Content $configFile
            $env:VERIHASH_VT_APIKEY = 'env-key'

            # Act
            $result = Get-VeriHashConfig -ConfigDirectory $testDir

            # Assert
            $result.virustotal.apiKey | Should -Be 'env-key'
        }

        It 'Environment variable overrides for boolean values' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "envtest3"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $env:VERIHASH_LOG_FILE = 'false'
            $env:VERIHASH_VT_ENABLED = 'false'

            # Act
            $result = Get-VeriHashConfig -ConfigDirectory $testDir

            # Assert
            $result.logging.file | Should -Be $false
            $result.virustotal.enabled | Should -Be $false
        }
    }

    Context 'Config source tracking' {
        It 'Tracks source of each setting' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "sourcetest"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $configFile = Join-Path $testDir "config.json"
            @{
                logging = @{ level = 'WARNING' }
            } | ConvertTo-Json -Depth 3 | Set-Content $configFile
            $env:VERIHASH_VT_APIKEY = 'env-key'

            # Act
            $result = Get-VeriHashConfig -ConfigDirectory $testDir -IncludeSource

            # Assert
            $result._source | Should -Not -BeNullOrEmpty
            $result._source.'logging.level' | Should -Be 'file'
            $result._source.'virustotal.apiKey' | Should -Be 'env'
            $result._source.'logging.file' | Should -Be 'default'
        }
    }
}

Describe 'Set-VeriHashConfig' {
    BeforeEach {
        # Clean environment before each test to prevent leakage
        $env:VERIHASH_LOG_LEVEL = $null
        $env:VERIHASH_LOG_FILE = $null
        $env:VERIHASH_LOG_CONSOLE = $null
        $env:VERIHASH_VT_APIKEY = $null
        $env:VERIHASH_VT_ENABLED = $null
    }

    Context 'Writing configuration' {
        It 'Creates config file in specified directory' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "writetest1"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $config = @{
                logging = @{
                    level = 'DEBUG'
                    file = $true
                    console = $false
                }
                virustotal = @{
                    apiKey = 'my-key'
                    enabled = $true
                    preferApi = $true
                    autoOpen = $false
                }
            }

            # Act
            Set-VeriHashConfig -Config $config -ConfigDirectory $testDir

            # Assert
            $configFile = Join-Path $testDir "config.json"
            Test-Path $configFile | Should -Be $true
        }

        It 'Writes valid JSON content' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "writetest2"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $config = @{
                logging = @{ level = 'VERBOSE' }
                virustotal = @{ apiKey = 'test' }
            }

            # Act
            Set-VeriHashConfig -Config $config -ConfigDirectory $testDir

            # Assert
            $configFile = Join-Path $testDir "config.json"
            $content = Get-Content $configFile -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Creates directory if it does not exist' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "writetest3\nested\dir"
            $config = @{
                logging = @{ level = 'INFO' }
            }

            # Act
            Set-VeriHashConfig -Config $config -ConfigDirectory $testDir

            # Assert
            Test-Path $testDir | Should -Be $true
            Test-Path (Join-Path $testDir "config.json") | Should -Be $true
        }

        It 'Round-trips configuration correctly' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "roundtrip"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $config = @{
                logging = @{
                    level = 'DEBUG'
                    file = $false
                    console = $true
                }
                virustotal = @{
                    apiKey = 'roundtrip-key'
                    enabled = $false
                    preferApi = $false
                    autoOpen = $true
                }
            }

            # Act
            Set-VeriHashConfig -Config $config -ConfigDirectory $testDir
            $loaded = Get-VeriHashConfig -ConfigDirectory $testDir

            # Assert
            $loaded.logging.level | Should -Be 'DEBUG'
            $loaded.logging.file | Should -Be $false
            $loaded.virustotal.apiKey | Should -Be 'roundtrip-key'
            $loaded.virustotal.autoOpen | Should -Be $true
        }
    }
}

Describe 'Initialize-VeriHashConfig' {
    Context 'First run initialization' {
        It 'Creates config directory if it does not exist' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "inittest1"

            # Act
            Initialize-VeriHashConfig -ConfigDirectory $testDir

            # Assert
            Test-Path $testDir | Should -Be $true
        }

        It 'Creates default config file' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "inittest2"

            # Act
            Initialize-VeriHashConfig -ConfigDirectory $testDir

            # Assert
            $configFile = Join-Path $testDir "config.json"
            Test-Path $configFile | Should -Be $true
        }

        It 'Does not overwrite existing config' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "inittest3"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $configFile = Join-Path $testDir "config.json"
            @{ logging = @{ level = 'CUSTOM' } } | ConvertTo-Json | Set-Content $configFile

            # Act
            Initialize-VeriHashConfig -ConfigDirectory $testDir

            # Assert
            $loaded = Get-Content $configFile | ConvertFrom-Json
            $loaded.logging.level | Should -Be 'CUSTOM'
        }

        It 'Force parameter overwrites existing config' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "inittest4"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $configFile = Join-Path $testDir "config.json"
            @{ logging = @{ level = 'CUSTOM' } } | ConvertTo-Json | Set-Content $configFile

            # Act
            Initialize-VeriHashConfig -ConfigDirectory $testDir -Force

            # Assert
            $loaded = Get-Content $configFile | ConvertFrom-Json
            $loaded.logging.level | Should -Be 'INFO'  # Default value
        }

        It 'Returns the initialized config' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "inittest5"

            # Act
            $result = Initialize-VeriHashConfig -ConfigDirectory $testDir

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.logging.level | Should -Be 'INFO'
        }
    }
}

Describe 'Config Validation' {
    Context 'Invalid log levels' {
        It 'Rejects invalid log level and uses default' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "validtest1"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $configFile = Join-Path $testDir "config.json"
            @{ logging = @{ level = 'INVALID_LEVEL' } } | ConvertTo-Json | Set-Content $configFile

            # Act
            $result = Get-VeriHashConfig -ConfigDirectory $testDir

            # Assert
            $result.logging.level | Should -Be 'INFO'  # Falls back to default
        }
    }

    Context 'Malformed config file' {
        It 'Returns defaults when config file is malformed JSON' {
            # Arrange
            $testDir = Join-Path $script:TestConfigDir "validtest2"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $configFile = Join-Path $testDir "config.json"
            "this is not valid json {{{" | Set-Content $configFile

            # Act
            $result = Get-VeriHashConfig -ConfigDirectory $testDir

            # Assert
            $result.logging.level | Should -Be 'INFO'  # Default
        }
    }
}
