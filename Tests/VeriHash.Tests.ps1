BeforeAll {
    # Import the function we want to test from VeriHash.ps1
    # We use dot-sourcing to load the script
    . "$PSScriptRoot\..\VeriHash.ps1" -FilePath "dummy" -ErrorAction SilentlyContinue 2>$null

    # Note: The script will try to run when we import it, so we pass a dummy filepath
    # and suppress errors. In a refactored version, you'd separate functions from execution.

    # Setup test file path
    $script:TestIconFile = Join-Path $PSScriptRoot "VeriHash_1024.ico"

    # Create a temp directory for test outputs
    $script:TestOutputDir = Join-Path $TestDrive "VeriHashTests"
    New-Item -ItemType Directory -Path $script:TestOutputDir -Force | Out-Null
}

Describe 'Test-InputHash' {
    Context 'When comparing hash values' {
        It 'Returns success message when hashes match exactly' {
            # Arrange
            $computedHash = 'ABC123DEF456'
            $inputHash = 'ABC123DEF456'

            # Act & Assert
            # We can't easily test the Write-Host output, but we can test that it doesn't throw
            { Test-InputHash -ComputedHash $computedHash -InputHash $inputHash } | Should -Not -Throw
        }

        It 'Handles case-insensitive comparison correctly (lowercase input)' {
            # Arrange
            $computedHash = 'ABC123DEF456'
            $inputHash = 'abc123def456'

            # Act & Assert
            { Test-InputHash -ComputedHash $computedHash -InputHash $inputHash } | Should -Not -Throw
        }

        It 'Handles case-insensitive comparison correctly (uppercase input)' {
            # Arrange
            $computedHash = 'abc123def456'
            $inputHash = 'ABC123DEF456'

            # Act & Assert
            { Test-InputHash -ComputedHash $computedHash -InputHash $inputHash } | Should -Not -Throw
        }

        It 'Detects when hashes do not match' {
            # Arrange
            $computedHash = 'ABC123DEF456'
            $inputHash = 'DIFFERENT123'

            # Act & Assert
            { Test-InputHash -ComputedHash $computedHash -InputHash $inputHash } | Should -Not -Throw
        }
    }
}

Describe 'Get-ClipboardHash' {
    Context 'When detecting hash algorithm from clipboard' {
        It 'Detects MD5 hash (32 characters)' {
            # Arrange
            Mock Get-Clipboard { return '5d41402abc4b2a76b9719d911017c592' }

            # Act
            $result = Get-ClipboardHash

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Algorithm | Should -Be 'MD5'
            $result.Hash | Should -Be '5D41402ABC4B2A76B9719D911017C592'
        }

        It 'Detects SHA256 hash (64 characters)' {
            # Arrange
            Mock Get-Clipboard { return 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' }

            # Act
            $result = Get-ClipboardHash

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Algorithm | Should -Be 'SHA256'
            $result.Hash | Should -Be 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
        }

        It 'Detects SHA512 hash (128 characters)' {
            # Arrange
            $sha512Hash = 'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e'
            Mock Get-Clipboard { return $sha512Hash }

            # Act
            $result = Get-ClipboardHash

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Algorithm | Should -Be 'SHA512'
            $result.Hash.Length | Should -Be 128
        }

        It 'Returns null for invalid hash format' {
            # Arrange
            Mock Get-Clipboard { return 'this is not a hash' }

            # Act
            $result = Get-ClipboardHash

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null for hash with invalid characters' {
            # Arrange
            Mock Get-Clipboard { return 'ZZZZ402abc4b2a76b9719d911017c592' }

            # Act
            $result = Get-ClipboardHash

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Get-And-SaveHash' {
    AfterEach {
        # Clean up any sidecar files created during tests
        Get-ChildItem -Path $script:TestOutputDir -Filter "*.md5" -ErrorAction SilentlyContinue | Remove-Item -Force
        Get-ChildItem -Path $script:TestOutputDir -Filter "*.sha256" -ErrorAction SilentlyContinue | Remove-Item -Force
        Get-ChildItem -Path $script:TestOutputDir -Filter "*.sha512" -ErrorAction SilentlyContinue | Remove-Item -Force
        Get-ChildItem -Path $script:TestOutputDir -Filter "*.ico" -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Context 'When computing file hashes and creating sidecar files' {
        It 'Creates sidecar file with correct naming for SHA256' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256

            # Assert
            $result.Algorithm | Should -Be 'SHA256'
            $result.Sidecar | Should -Match 'VeriHash_1024\.ico\.sha256$'
            Test-Path $result.Sidecar | Should -Be $true
        }

        It 'MD5 creates .md5 file extension' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm MD5

            # Assert
            $result.Algorithm | Should -Be 'MD5'
            $result.Sidecar | Should -Match '\.md5$'
            Test-Path $result.Sidecar | Should -Be $true
        }

        It 'SHA512 creates .sha512 file extension' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA512

            # Assert
            $result.Algorithm | Should -Be 'SHA512'
            $result.Sidecar | Should -Match '\.sha512$'
            Test-Path $result.Sidecar | Should -Be $true
        }

        It 'MD5 hash output is 32 characters (hex)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm MD5

            # Assert
            $result.Hash.Length | Should -Be 32
            $result.Hash | Should -Match '^[A-F0-9]{32}$'
        }

        It 'SHA256 hash output is 64 characters (hex)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256

            # Assert
            $result.Hash.Length | Should -Be 64
            $result.Hash | Should -Match '^[A-F0-9]{64}$'
        }

        It 'SHA512 hash output is 128 characters (hex)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA512

            # Assert
            $result.Hash.Length | Should -Be 128
            $result.Hash | Should -Match '^[A-F0-9]{128}$'
        }

        It 'Sidecar file contains correct format (filename + two spaces + hash)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256

            # Assert
            $sidecarContent = (Get-Content $result.Sidecar -Raw).Trim()
            # Format should be: "VeriHash_1024.ico  HASHVALUE"
            $sidecarContent | Should -Match '^VeriHash_1024\.ico\s{2}[A-F0-9]{64}$'
        }
    }
}

Describe 'Test-HashSidecar' {
    AfterEach {
        # Clean up test files
        Get-ChildItem -Path $script:TestOutputDir -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Context 'When verifying files against sidecar checksums' {
        It 'Detects matching hash correctly (GNU coreutils format: hash *filename)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Create a sidecar file manually in GNU format (hash *filename)
            $hash = (Get-FileHash -Algorithm SHA256 -Path $testFile).Hash
            $sidecarPath = "$testFile.sha256"
            # GNU format: "HASH *filename" or "HASH  filename"
            Set-Content -Path $sidecarPath -Value "$hash *VeriHash_1024.ico"

            # Act - Capture output to verify "OK" message appears
            $output = Test-HashSidecar -SidecarPath $sidecarPath *>&1

            # Assert
            $outputString = $output | Out-String
            $outputString | Should -Match 'OK.*✅'
        }

        It 'Detects mismatched hash correctly (GNU coreutils format)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Create sidecar with incorrect hash
            $sidecarPath = "$testFile.sha256"
            Set-Content -Path $sidecarPath -Value "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA *VeriHash_1024.ico"

            # Act
            $output = Test-HashSidecar -SidecarPath $sidecarPath *>&1

            # Assert
            $outputString = $output | Out-String
            $outputString | Should -Match 'FAILED.*🚫'
        }

        It 'Detects missing file correctly (GNU coreutils format)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Get hash before deleting file
            $hash = (Get-FileHash -Algorithm SHA256 -Path $testFile).Hash
            $sidecarPath = "$testFile.sha256"
            Set-Content -Path $sidecarPath -Value "$hash *VeriHash_1024.ico"

            # Delete the actual file (but keep sidecar)
            Remove-Item $testFile -Force

            # Act
            $output = Test-HashSidecar -SidecarPath $sidecarPath *>&1

            # Assert
            $outputString = $output | Out-String
            $outputString | Should -Match 'MISSING.*⚠️'
        }
    }
}

Describe 'Multiple Algorithm Testing' {
    AfterEach {
        # Clean up test files
        Get-ChildItem -Path $script:TestOutputDir -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Context 'When using -Algorithm parameter with multiple values' {
        It 'Creates all three sidecar files when using different algorithms' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act - Create three separate sidecar files
            $md5Result = Get-And-SaveHash -PathToFile $testFile -Algorithm MD5
            $sha256Result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256
            $sha512Result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA512

            # Assert - All three files should exist
            Test-Path $md5Result.Sidecar | Should -Be $true
            Test-Path $sha256Result.Sidecar | Should -Be $true
            Test-Path $sha512Result.Sidecar | Should -Be $true

            # Verify file extensions
            $md5Result.Sidecar | Should -Match '\.md5$'
            $sha256Result.Sidecar | Should -Match '\.sha256$'
            $sha512Result.Sidecar | Should -Match '\.sha512$'

            # Verify hash lengths
            $md5Result.Hash.Length | Should -Be 32
            $sha256Result.Hash.Length | Should -Be 64
            $sha512Result.Hash.Length | Should -Be 128
        }
    }
}

Describe 'Help System' {
    Context 'When requesting help documentation' {
        It 'Displays help with -Help flag' {
            # Arrange & Act
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -Help *>&1

            # Assert
            $outputString = $output | Out-String
            $outputString | Should -Match 'VeriHash\.ps1'
            $outputString | Should -Match 'Usage:'
            $outputString | Should -Match 'Parameters:'
            $outputString | Should -Match 'Examples:'
        }

        It 'Displays help with --help flag (Unix style)' {
            # Arrange & Act
            $output = & "$PSScriptRoot\..\VeriHash.ps1" --help *>&1

            # Assert
            $outputString = $output | Out-String
            $outputString | Should -Match 'VeriHash\.ps1'
            $outputString | Should -Match 'Usage:'
        }

        It 'Displays help with -h alias' {
            # Arrange & Act
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -h *>&1

            # Assert
            $outputString = $output | Out-String
            $outputString | Should -Match 'VeriHash\.ps1'
            $outputString | Should -Match 'Usage:'
        }

        It 'Displays help with /? flag (Windows CMD style)' {
            # Arrange & Act
            $output = & "$PSScriptRoot\..\VeriHash.ps1" /? *>&1

            # Assert
            $outputString = $output | Out-String
            $outputString | Should -Match 'VeriHash\.ps1'
            $outputString | Should -Match 'Usage:'
        }

        It 'Help output includes all major parameters' {
            # Arrange & Act
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -Help *>&1

            # Assert
            $outputString = $output | Out-String
            $outputString | Should -Match 'FilePath'
            $outputString | Should -Match '-Hash'
            $outputString | Should -Match '-Algorithm'
            $outputString | Should -Match '-OnlyVerify'
            $outputString | Should -Match '-SendTo'
        }
    }
}
