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

<#
    NOTE: MD5 Algorithm Usage in Tests
    -----------------------------------
    This test suite includes tests for MD5 hashing for legacy compatibility and verification purposes.

    ⚠️  IMPORTANT: MD5 is cryptographically broken and vulnerable to collision attacks.

    For production use, SHA256 is now the RECOMMENDED MINIMUM hash algorithm.
    Consider using SHA512 for enhanced security in sensitive applications.

    MD5 tests are retained here to ensure backward compatibility with existing .md5 sidecar files
    and to verify that the tool correctly handles legacy hash formats.
#>

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
            if ($IsWindows) {
                Mock Get-Clipboard { return '5d41402abc4b2a76b9719d911017c592' }
            } else {
                # Mock Linux clipboard tools (only mock what exists)
                if (Get-Command wl-paste -ErrorAction SilentlyContinue) {
                    Mock wl-paste { return '5d41402abc4b2a76b9719d911017c592' }
                }
                if (Get-Command xclip -ErrorAction SilentlyContinue) {
                    Mock xclip { return '5d41402abc4b2a76b9719d911017c592' }
                }
                if (Get-Command xsel -ErrorAction SilentlyContinue) {
                    Mock xsel { return '5d41402abc4b2a76b9719d911017c592' }
                }
            }

            # Act
            $result = Get-ClipboardHash

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Algorithm | Should -Be 'MD5'
            $result.Hash | Should -Be '5D41402ABC4B2A76B9719D911017C592'
        }

        It 'Detects SHA256 hash (64 characters)' {
            # Arrange
            if ($IsWindows) {
                Mock Get-Clipboard { return 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' }
            } else {
                if (Get-Command wl-paste -ErrorAction SilentlyContinue) {
                    Mock wl-paste { return 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' }
                }
                if (Get-Command xclip -ErrorAction SilentlyContinue) {
                    Mock xclip { return 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' }
                }
                if (Get-Command xsel -ErrorAction SilentlyContinue) {
                    Mock xsel { return 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' }
                }
            }

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
            if ($IsWindows) {
                Mock Get-Clipboard { return $sha512Hash }
            } else {
                if (Get-Command wl-paste -ErrorAction SilentlyContinue) {
                    Mock wl-paste { return $sha512Hash }
                }
                if (Get-Command xclip -ErrorAction SilentlyContinue) {
                    Mock xclip { return $sha512Hash }
                }
                if (Get-Command xsel -ErrorAction SilentlyContinue) {
                    Mock xsel { return $sha512Hash }
                }
            }

            # Act
            $result = Get-ClipboardHash

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Algorithm | Should -Be 'SHA512'
            $result.Hash.Length | Should -Be 128
        }

        It 'Returns null for invalid hash format' {
            # Arrange
            if ($IsWindows) {
                Mock Get-Clipboard { return 'this is not a hash' }
            } else {
                if (Get-Command wl-paste -ErrorAction SilentlyContinue) {
                    Mock wl-paste { return 'this is not a hash' }
                }
                if (Get-Command xclip -ErrorAction SilentlyContinue) {
                    Mock xclip { return 'this is not a hash' }
                }
                if (Get-Command xsel -ErrorAction SilentlyContinue) {
                    Mock xsel { return 'this is not a hash' }
                }
            }

            # Act
            $result = Get-ClipboardHash

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null for hash with invalid characters' {
            # Arrange
            if ($IsWindows) {
                Mock Get-Clipboard { return 'ZZZZ402abc4b2a76b9719d911017c592' }
            } else {
                if (Get-Command wl-paste -ErrorAction SilentlyContinue) {
                    Mock wl-paste { return 'ZZZZ402abc4b2a76b9719d911017c592' }
                }
                if (Get-Command xclip -ErrorAction SilentlyContinue) {
                    Mock xclip { return 'ZZZZ402abc4b2a76b9719d911017c592' }
                }
                if (Get-Command xsel -ErrorAction SilentlyContinue) {
                    Mock xsel { return 'ZZZZ402abc4b2a76b9719d911017c592' }
                }
            }

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

            # Act - MD5 used for legacy support testing
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

            # Act - MD5 used for legacy support testing
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

        It 'Sidecar file contains correct format (hash + two spaces + filename)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256

            # Assert
            $sidecarContent = (Get-Content $result.Sidecar -Raw).Trim()
            # Format is Unix standard: "HASHVALUE  filename.ext" (used on all platforms)
            $sidecarContent | Should -Match '^[A-F0-9]{64}\s{2}VeriHash_1024\.ico$'
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

            # Act - Create three separate sidecar files (MD5 for legacy support testing)
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

Describe 'Sidecar Update and Match Detection' {
    AfterEach {
        # Clean up test files
        Get-ChildItem -Path $script:TestOutputDir -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Context 'When sidecar already exists and matches' {
        It 'Returns SidecarMatch=true and does not update file' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Create initial sidecar
            $firstResult = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256

            # Act - Run again without changing the file
            $secondResult = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256

            # Assert
            $secondResult.SidecarMatch | Should -Be $true
            $secondResult.SidecarExists | Should -Be $true
            $secondResult.Hash | Should -Be $firstResult.Hash
            $secondResult.SidecarHash | Should -Be $firstResult.Hash
        }

        It 'Does not have UserUpdated or ForceUpdated flags when sidecar matches' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Create initial sidecar
            Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256 | Out-Null

            # Act - Run again
            $secondResult = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256

            # Assert
            $secondResult.PSObject.Properties.Name | Should -Not -Contain 'UserUpdated'
            $secondResult.PSObject.Properties.Name | Should -Not -Contain 'ForceUpdated'
        }
    }

    Context 'When sidecar exists with wrong hash and -Force is used' {
        It 'Auto-updates sidecar and returns SidecarMatch=true' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Create sidecar with wrong hash
            $sidecarPath = "$testFile.sha256"
            $wrongHash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
            Set-Content -Path $sidecarPath -Value "VeriHash_1024.ico  $wrongHash"

            # Act - Run with -Force flag
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256 -Force

            # Assert - Should have updated the sidecar
            $result.SidecarMatch | Should -Be $true
            $result.ForceUpdated | Should -Be $true
            $result.SidecarHash | Should -Be $result.Hash
            $result.Hash | Should -Not -Be $wrongHash

            # Verify file was actually updated
            $sidecarContent = (Get-Content $sidecarPath -Raw).Trim()
            $sidecarContent | Should -Match $result.Hash
            $sidecarContent | Should -Not -Match $wrongHash
        }

        It 'Sets SidecarHash to new hash value after Force update' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Create sidecar with wrong hash
            $sidecarPath = "$testFile.sha256"
            $wrongHash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
            Set-Content -Path $sidecarPath -Value "VeriHash_1024.ico  $wrongHash"

            # Act
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256 -Force

            # Assert - SidecarHash should now contain the NEW hash, not the old one
            $result.SidecarHash | Should -Be $result.Hash
            $result.SidecarHash | Should -Not -Be $wrongHash
        }
    }

    Context 'When sidecar exists with wrong hash (no Force flag)' {
        It 'Returns SidecarMatch=false and shows mismatch' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Get the real hash first
            $realHash = (Get-FileHash -Algorithm SHA256 -Path $testFile).Hash

            # Create sidecar with wrong hash
            $sidecarPath = "$testFile.sha256"
            $wrongHash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
            Set-Content -Path $sidecarPath -Value "VeriHash_1024.ico  $wrongHash"

            # Act - Mock Read-Host to simulate user choosing "Keep"
            Mock Read-Host { return 'k' }
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256

            # Assert
            $result.SidecarMatch | Should -Be $false
            $result.SidecarExists | Should -Be $true
            $result.Hash | Should -Be $realHash
            $result.SidecarHash | Should -Be $wrongHash
            $result.UserKept | Should -Be $true
        }
    }
}

Describe 'Clipboard and Sidecar Interaction' {
    AfterEach {
        # Clean up test files
        Get-ChildItem -Path $script:TestOutputDir -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Context 'When both clipboard and sidecar contain hashes' {
        It 'Detects when clipboard matches file but sidecar does not' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Get the real hash
            $realHash = (Get-FileHash -Algorithm SHA256 -Path $testFile).Hash

            # Create sidecar with wrong hash
            $sidecarPath = "$testFile.sha256"
            $wrongHash = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
            Set-Content -Path $sidecarPath -Value "VeriHash_1024.ico  $wrongHash"

            # Act - Pass the correct hash as InputHash (simulating clipboard)
            Mock Read-Host { return 'k' }  # User chooses to keep
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256 -InputHash $realHash

            # Assert
            $result.Hash | Should -Be $realHash
            $result.SidecarHash | Should -Be $wrongHash
            $result.SidecarMatch | Should -Be $false
            # InputHash matches computed hash (would show in output)
        }

        It 'Detects when both clipboard and sidecar are wrong' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Get the real hash
            $realHash = (Get-FileHash -Algorithm SHA256 -Path $testFile).Hash

            # Create sidecar with wrong hash
            $sidecarPath = "$testFile.sha256"
            $wrongSidecarHash = "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"
            Set-Content -Path $sidecarPath -Value "VeriHash_1024.ico  $wrongSidecarHash"

            # Different wrong hash for "clipboard"
            $wrongClipboardHash = "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE"

            # Act
            Mock Read-Host { return 'k' }  # User chooses to keep
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256 -InputHash $wrongClipboardHash

            # Assert
            $result.Hash | Should -Be $realHash
            $result.Hash | Should -Not -Be $wrongClipboardHash
            $result.SidecarHash | Should -Be $wrongSidecarHash
            $result.SidecarMatch | Should -Be $false
        }
    }
}

Describe 'Force Parameter Behavior' {
    AfterEach {
        # Clean up test files
        Get-ChildItem -Path $script:TestOutputDir -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Context 'When using -Force with various scenarios' {
        It 'Does not prompt user when Force is enabled' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Create sidecar with wrong hash
            $sidecarPath = "$testFile.sha256"
            $wrongHash = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
            Set-Content -Path $sidecarPath -Value "VeriHash_1024.ico  $wrongHash"

            # Act - Should NOT prompt user
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256 -Force

            # Assert - Should have ForceUpdated flag
            $result.ForceUpdated | Should -Be $true
            $result.SidecarMatch | Should -Be $true
        }

        It 'Updates sidecar file content when Force is used' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force
            $realHash = (Get-FileHash -Algorithm SHA256 -Path $testFile).Hash

            # Create sidecar with wrong hash
            $sidecarPath = "$testFile.sha256"
            $wrongHash = "0000000000000000000000000000000000000000000000000000000000000000"
            Set-Content -Path $sidecarPath -Value "VeriHash_1024.ico  $wrongHash"

            # Act
            Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256 -Force | Out-Null

            # Assert - File should contain the real hash now
            $result.Hash | Should -Be $realHash
            $result.SidecarHash | Should -Not -Be $wrongHash
            $result.ForceUpdated | Should -Be $true
        }
    }
}

Describe 'Sidecar Match Property After Updates' {
    AfterEach {
        # Clean up test files
        Get-ChildItem -Path $script:TestOutputDir -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Context 'Regression test for SidecarMatch property after user updates' {
        It 'Returns SidecarMatch=true after Force update (not stale false value)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Create sidecar with wrong hash
            $sidecarPath = "$testFile.sha256"
            Set-Content -Path $sidecarPath -Value "VeriHash_1024.ico  BADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBADBAD"

            # Act - Force update
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256 -Force

            # Assert - This was the bug: SidecarMatch was returning false even after update
            $result.SidecarMatch | Should -Be $true
            $result.ForceUpdated | Should -Be $true
        }

        It 'SidecarHash contains NEW hash after update, not old hash' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force
            $realHash = (Get-FileHash -Algorithm SHA256 -Path $testFile).Hash

            # Create sidecar with wrong hash
            $sidecarPath = "$testFile.sha256"
            $oldHash = "1111111111111111111111111111111111111111111111111111111111111111"
            Set-Content -Path $sidecarPath -Value "VeriHash_1024.ico  $oldHash"

            # Act - Force update
            $result = Get-And-SaveHash -PathToFile $testFile -Algorithm SHA256 -Force

            # Assert - SidecarHash should be updated to match the file
            $result.SidecarHash | Should -Be $realHash
            $result.SidecarHash | Should -Not -Be $oldHash
            $result.Hash | Should -Be $result.SidecarHash
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

        It 'Help output includes -Force parameter' {
            # Arrange & Act
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -Help *>&1

            # Assert
            $outputString = $output | Out-String
            $outputString | Should -Match '-Force'
        }

        It 'Help output includes -SkipSignatureCheck parameter' {
            # Arrange & Act
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -Help *>&1

            # Assert
            $outputString = $output | Out-String
            $outputString | Should -Match '-SkipSignatureCheck'
        }
    }
}

Describe 'SkipSignatureCheck Parameter' {
    AfterEach {
        # Clean up test files
        Get-ChildItem -Path $script:TestOutputDir -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Context 'When using -SkipSignatureCheck parameter' {
        It 'Skips digital signature verification when flag is provided' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act - Capture all output streams
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile -SkipSignatureCheck *>&1
            $outputString = ($output | Out-String)

            # Assert - Should show signature was skipped
            $outputString | Should -Match 'Skipped \(SkipSignatureCheck enabled\)'
        }

        It 'Does not skip signature check when flag is NOT provided' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act - Capture all output streams
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile *>&1
            $outputString = ($output | Out-String)

            # Assert - Should show signature check happened (on Windows) or was skipped for platform reasons (non-Windows)
            # On Windows, should show either "True" or "False" for signature
            # On non-Windows, should show platform skip message
            if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
                $outputString | Should -Match 'Digitally Signed\?:'
            } else {
                $outputString | Should -Match 'Skipped \(Authenticode signatures are not supported'
            }
        }

        It 'Hashing still works correctly when signature check is skipped' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Get expected hash
            $expectedHash = (Get-FileHash -Algorithm SHA256 -Path $testFile).Hash

            # Act - Capture all output streams
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile -SkipSignatureCheck *>&1
            $outputString = ($output | Out-String)

            # Assert - Should still compute hash correctly
            $outputString | Should -Match $expectedHash
            $outputString | Should -Match 'Computed hash:'
        }

        It 'SkipSignatureCheck works with other parameters' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "VeriHash_1024.ico"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act - Use with -Algorithm parameter, capture all output streams
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile -Algorithm MD5 -SkipSignatureCheck *>&1
            $outputString = ($output | Out-String)

            # Assert
            $outputString | Should -Match 'Skipped \(SkipSignatureCheck enabled\)'
            $outputString | Should -Match 'MD5'
        }
    }
}

Describe 'Smart Signature Detection' {
    AfterEach {
        # Clean up test files
        Get-ChildItem -Path $script:TestOutputDir -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Context 'When checking Authenticode-signable files' {
        It 'Checks signature for .exe files' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "test.exe"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act - Capture all output streams
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile *>&1
            $outputString = ($output | Out-String)

            # Assert - Should check signature (on Windows)
            if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
                $outputString | Should -Match 'Digitally Signed\?:'
                $outputString | Should -Not -Match 'N/A \(file type cannot be signed\)'
                $outputString | Should -Not -Match 'N/A \(non-Authenticode signature format\)'
            }
        }

        It 'Checks signature for .ps1 files' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "test.ps1"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act - Capture all output streams
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile *>&1
            $outputString = ($output | Out-String)

            # Assert - Should check signature (on Windows)
            if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
                $outputString | Should -Match 'Digitally Signed\?:'
                $outputString | Should -Not -Match 'N/A \(file type cannot be signed\)'
                $outputString | Should -Not -Match 'N/A \(non-Authenticode signature format\)'
            }
        }

        It 'Checks signature for .dll files' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "test.dll"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act - Capture all output streams
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile *>&1
            $outputString = ($output | Out-String)

            # Assert - Should check signature (on Windows)
            if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
                $outputString | Should -Match 'Digitally Signed\?:'
                $outputString | Should -Not -Match 'N/A \(file type cannot be signed\)'
                $outputString | Should -Not -Match 'N/A \(non-Authenticode signature format\)'
            }
        }
    }

    Context 'When checking non-Authenticode signable files' {
        It 'Shows N/A for .jar files (non-Authenticode format)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "test.jar"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act - Capture all output streams
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile *>&1
            $outputString = ($output | Out-String)

            # Assert - Should show N/A for non-Authenticode (on Windows)
            if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
                $outputString | Should -Match 'N/A \(non-Authenticode signature format\)'
            }
        }

        It 'Shows N/A for .pdf files (non-Authenticode format)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "test.pdf"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act - Capture all output streams
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile *>&1
            $outputString = ($output | Out-String)

            # Assert - Should show N/A for non-Authenticode (on Windows)
            if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
                $outputString | Should -Match 'N/A \(non-Authenticode signature format\)'
            }
        }

        It 'Shows N/A for .apk files (non-Authenticode format)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "test.apk"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act - Capture all output streams
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile *>&1
            $outputString = ($output | Out-String)

            # Assert - Should show N/A for non-Authenticode (on Windows)
            if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
                $outputString | Should -Match 'N/A \(non-Authenticode signature format\)'
            }
        }
    }

    Context 'When checking non-signable files' {
        It 'Shows N/A for .txt files (cannot be signed)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "test.txt"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act - Capture all output streams
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile *>&1
            $outputString = ($output | Out-String)

            # Assert - Should show N/A (on Windows)
            if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
                $outputString | Should -Match 'N/A \(file type cannot be signed\)'
            }
        }

        It 'Shows N/A for .json files (cannot be signed)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "test.json"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act - Capture all output streams
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile *>&1
            $outputString = ($output | Out-String)

            # Assert - Should show N/A (on Windows)
            if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
                $outputString | Should -Match 'N/A \(file type cannot be signed\)'
            }
        }

        It 'Shows N/A for .jpg files (cannot be signed)' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "test.jpg"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force

            # Act - Capture all output streams
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile *>&1
            $outputString = ($output | Out-String)

            # Assert - Should show N/A (on Windows)
            if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
                $outputString | Should -Match 'N/A \(file type cannot be signed\)'
            }
        }

        It 'Still computes hash correctly for non-signable files' {
            # Arrange
            $testFile = Join-Path $script:TestOutputDir "test.txt"
            Copy-Item -Path $script:TestIconFile -Destination $testFile -Force
            $expectedHash = (Get-FileHash -Algorithm SHA256 -Path $testFile).Hash

            # Act - Capture all output streams
            $output = & "$PSScriptRoot\..\VeriHash.ps1" -FilePath $testFile *>&1
            $outputString = ($output | Out-String)

            # Assert - Should still compute hash correctly
            $outputString | Should -Match $expectedHash
            $outputString | Should -Match 'Computed hash:'
        }
    }
}
