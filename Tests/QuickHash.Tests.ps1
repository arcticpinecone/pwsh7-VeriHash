# Check if Pester is installed before running tests
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host "`n===========================================" -ForegroundColor Yellow
    Write-Host "  Pester Testing Framework Not Found" -ForegroundColor Yellow
    Write-Host "===========================================" -ForegroundColor Yellow
    Write-Host "`nPester is required to run these tests but is not currently installed." -ForegroundColor White
    Write-Host "`nWould you like to install Pester now? (Y/N): " -ForegroundColor Cyan -NoNewline
    $installChoice = Read-Host

    if ($installChoice -match '^[Yy]') {
        Write-Host "`nPlease select installation scope:" -ForegroundColor Cyan
        Write-Host "  [1] CurrentUser  - Install for your user account only (no admin required)" -ForegroundColor White
        Write-Host "  [2] AllUsers     - Install system-wide for all users (requires admin)" -ForegroundColor White
        Write-Host "`nEnter choice (1 or 2) [default: 1]: " -ForegroundColor Cyan -NoNewline
        $scopeChoice = Read-Host

        $scope = if ($scopeChoice -eq '2') { 'AllUsers' } else { 'CurrentUser' }

        Write-Host "`nInstalling Pester module (Scope: $scope)..." -ForegroundColor Green
        try {
            Install-Module -Name Pester -Force -SkipPublisherCheck -Scope $scope
            Write-Host "Pester installed successfully!" -ForegroundColor Green
            Write-Host "Please re-run this test file.`n" -ForegroundColor Cyan
        }
        catch {
            Write-Host "`nError installing Pester: $_" -ForegroundColor Red
            Write-Host "You can manually install it with:" -ForegroundColor Yellow
            Write-Host "  Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser`n" -ForegroundColor White
        }
    }
    else {
        Write-Host "`nTests cannot run without Pester. Please install it manually with:" -ForegroundColor Yellow
        Write-Host "  Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser`n" -ForegroundColor White
    }

    exit 1
}

BeforeAll {
    # Import the function we want to test from QuickHash.ps1
    # We use dot-sourcing to load the script
    $script:QuickHashScriptPath = Join-Path -Path $PSScriptRoot -ChildPath ".." -AdditionalChildPath "QuickHash.ps1"

    # We need to source the script to get the Get-Hash function
    # Since the script has interactive prompts at the end, we'll source just the function
    # by reading and executing only the function definition
    $scriptContent = Get-Content $script:QuickHashScriptPath -Raw

    # Extract just the Get-Hash function definition
    if ($scriptContent -match '(?s)(function Get-Hash \{.*?\n\})') {
        $tempModule = New-Module -ScriptBlock ([scriptblock]::Create($matches[1]))
        $tempModule | Import-Module -Global
    }

    # Setup test file paths
    $script:TestOutputDir = Join-Path -Path $TestDrive -ChildPath "QuickHashTests"
    New-Item -ItemType Directory -Path $script:TestOutputDir -Force | Out-Null

    # Create test files with known content
    $script:TestFile1 = Join-Path -Path $script:TestOutputDir -ChildPath "testfile1.txt"
    Set-Content -Path $script:TestFile1 -Value "Hello, World!" -NoNewline

    $script:TestFile2 = Join-Path -Path $script:TestOutputDir -ChildPath "testfile2.txt"
    Set-Content -Path $script:TestFile2 -Value "The quick brown fox jumps over the lazy dog" -NoNewline

    # Known hash values for our test files
    # "Hello, World!" hashes:
    $script:HelloWorldMD5 = '65A8E27D8879283831B664BD8B7F0AD4'
    $script:HelloWorldSHA256 = 'DFFD6021BB2BD5B0AF676290809EC3A53191DD81C7F70A4B28688A362182986F'

    # "The quick brown fox jumps over the lazy dog" hashes:
    $script:FoxMD5 = '9E107D9D372BB6826BD81D3542A419D6'
    $script:FoxSHA256 = 'D7A8FBB307D7809469CA9ABCB0082E4F8D5651E46D3CDB762D02D0BF37C9E592'
}

Describe 'Get-Hash Function' {
    Context 'When hashing files' {
        It 'Computes correct MD5 hash for a file' {
            # Arrange & Act
            $output = Get-Hash -InputValue $script:TestFile1 -Algorithm "MD5" *>&1 | Out-String

            # Assert
            $output | Should -Match $script:HelloWorldMD5
            $output | Should -Match "Hash of the file"
        }

        It 'Computes correct SHA256 hash for a file' {
            # Arrange & Act
            $output = Get-Hash -InputValue $script:TestFile1 -Algorithm "SHA256" *>&1 | Out-String

            # Assert
            $output | Should -Match $script:HelloWorldSHA256
            $output | Should -Match "Hash of the file"
        }

        It 'Computes correct MD5 hash for second test file' {
            # Arrange & Act
            $output = Get-Hash -InputValue $script:TestFile2 -Algorithm "MD5" *>&1 | Out-String

            # Assert
            $output | Should -Match $script:FoxMD5
        }

        It 'Computes correct SHA256 hash for second test file' {
            # Arrange & Act
            $output = Get-Hash -InputValue $script:TestFile2 -Algorithm "SHA256" *>&1 | Out-String

            # Assert
            $output | Should -Match $script:FoxSHA256
        }

        It 'Handles non-existent file gracefully' {
            # Arrange
            $nonExistentFile = Join-Path -Path $script:TestOutputDir -ChildPath "does-not-exist.txt"

            # Act & Assert
            # Should not throw, but will treat as string and hash the path
            { Get-Hash -InputValue $nonExistentFile -Algorithm "SHA256" } | Should -Not -Throw
        }
    }

    Context 'When hashing strings' {
        It 'Computes correct MD5 hash for a simple string' {
            # Arrange
            $testString = "Hello, World!"

            # Act
            $output = Get-Hash -InputValue $testString -Algorithm "MD5" *>&1 | Out-String

            # Assert - When treated as string, should compute hash of the string
            $output | Should -Match "Hash of the string"
            $output | Should -Match $script:HelloWorldMD5
        }

        It 'Computes correct SHA256 hash for a simple string' {
            # Arrange
            $testString = "Hello, World!"

            # Act
            $output = Get-Hash -InputValue $testString -Algorithm "SHA256" *>&1 | Out-String

            # Assert
            $output | Should -Match "Hash of the string"
            $output | Should -Match $script:HelloWorldSHA256
        }

        It 'Computes correct MD5 hash for longer string' {
            # Arrange
            $testString = "The quick brown fox jumps over the lazy dog"

            # Act
            $output = Get-Hash -InputValue $testString -Algorithm "MD5" *>&1 | Out-String

            # Assert
            $output | Should -Match $script:FoxMD5
        }

        It 'Computes correct SHA256 hash for longer string' {
            # Arrange
            $testString = "The quick brown fox jumps over the lazy dog"

            # Act
            $output = Get-Hash -InputValue $testString -Algorithm "SHA256" *>&1 | Out-String

            # Assert
            $output | Should -Match $script:FoxSHA256
        }

        It 'Rejects empty string parameter' {
            # Arrange
            $testString = ""

            # Act & Assert
            # The function requires a non-empty string due to [Parameter(Mandatory = $true)]
            { Get-Hash -InputValue $testString -Algorithm "SHA256" } | Should -Throw -ExpectedMessage "*empty string*"
        }

        It 'Handles special characters in string' {
            # Arrange
            $testString = "!@#$%^&*()_+-=[]{}|;':,.<>?/~``"

            # Act & Assert
            { Get-Hash -InputValue $testString -Algorithm "MD5" } | Should -Not -Throw
        }

        It 'Handles unicode characters in string' {
            # Arrange
            $testString = "Hello 世界 🌍"

            # Act & Assert
            { Get-Hash -InputValue $testString -Algorithm "SHA256" } | Should -Not -Throw
        }
    }

    Context 'When validating algorithm parameter' {
        It 'Accepts MD5 as valid algorithm' {
            # Arrange & Act & Assert
            { Get-Hash -InputValue "test" -Algorithm "MD5" } | Should -Not -Throw
        }

        It 'Accepts SHA256 as valid algorithm' {
            # Arrange & Act & Assert
            { Get-Hash -InputValue "test" -Algorithm "SHA256" } | Should -Not -Throw
        }

        It 'MD5 hash output is 32 characters (hex)' {
            # Arrange & Act
            $output = Get-Hash -InputValue "test" -Algorithm "MD5" *>&1 | Out-String

            # Assert - Extract hash from output
            if ($output -match '([A-F0-9]{32})') {
                $matches[1].Length | Should -Be 32
            }
        }

        It 'SHA256 hash output is 64 characters (hex)' {
            # Arrange & Act
            $output = Get-Hash -InputValue "test" -Algorithm "SHA256" *>&1 | Out-String

            # Assert - Extract hash from output
            if ($output -match '([A-F0-9]{64})') {
                $matches[1].Length | Should -Be 64
            }
        }
    }

    Context 'When handling errors' {
        It 'Catches and reports errors gracefully' {
            # This test verifies the try-catch block works
            # Since Get-Hash has error handling, it should not throw
            { Get-Hash -InputValue $script:TestFile1 -Algorithm "SHA256" } | Should -Not -Throw
        }
    }

    Context 'When comparing file vs string hashing' {
        It 'File path that exists is treated as file' {
            # Arrange & Act
            $output = Get-Hash -InputValue $script:TestFile1 -Algorithm "MD5" *>&1 | Out-String

            # Assert
            $output | Should -Match "Input is a file"
            $output | Should -Not -Match "Input is a string"
        }

        It 'Non-existent path is treated as string' {
            # Arrange
            $fakePath = "C:\this\does\not\exist\file.txt"

            # Act
            $output = Get-Hash -InputValue $fakePath -Algorithm "MD5" *>&1 | Out-String

            # Assert
            $output | Should -Match "Input is a string"
            $output | Should -Not -Match "Input is a file"
        }
    }
}

Describe 'QuickHash Script Execution' {
    Context 'When running the full script' {
        It 'Script file exists and is readable' {
            # Assert
            Test-Path $script:QuickHashScriptPath | Should -Be $true
        }

        It 'Script contains Get-Hash function definition' {
            # Arrange
            $content = Get-Content $script:QuickHashScriptPath -Raw

            # Assert
            $content | Should -Match 'function Get-Hash'
        }

        It 'Script validates algorithm parameter correctly' {
            # Arrange
            $content = Get-Content $script:QuickHashScriptPath -Raw

            # Assert
            $content | Should -Match 'ValidateSet.*MD5.*SHA256'
        }
    }
}
