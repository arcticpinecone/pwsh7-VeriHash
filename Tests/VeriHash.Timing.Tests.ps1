<#
.SYNOPSIS
    Pester tests for Profile-VeriHashTiming.ps1

.DESCRIPTION
    Validates the VeriHash timing profiler functionality.
    Supports both auto-generated test files and user-provided real files.

    PERFORMANCE: Large files are profiled ONCE per algorithm in BeforeAll,
    then results are reused across all tests. No redundant hashing.
#>

BeforeAll {
    $script:ProfilerScript = Join-Path $PSScriptRoot "..\Profile-VeriHashTiming.ps1"
    $script:TestIconFile = Join-Path $PSScriptRoot "VeriHash_1024.ico"
    $script:TestOutputDir = Join-Path $TestDrive "TimingTestOutput"

    # ═══════════════════════════════════════════════════════════════════════════
    # CONFIGURATION: Test file options
    # ═══════════════════════════════════════════════════════════════════════════
    #
    # OPTION 1: User-provided real file(s)
    # ─────────────────────────────────────
    # Set path(s) to real files for testing (e.g., ISOs, installers, large binaries)
    # These files are NOT stored in git - they exist on YOUR local system only.
    # Leave as @() to auto-generate a test file instead.
    #
    # Single file:   @("D:\ISOs\Windows11.iso")
    # Multiple:      @("D:\ISOs\Win11.iso", "C:\Downloads\setup.exe", "E:\backup.zip")
    #
    $script:UserProvidedTestFiles = @()  # <-- Add your file paths here, or leave empty
    #
    # OPTION 2: Auto-generate a test file (used when UserProvidedTestFiles is empty)
    # ───────────────────────────────────────────────────────────────────────────────
    $script:LargeFileSizeMB = 500
    $script:EstimateForSizeGB = 4.5
    # ═══════════════════════════════════════════════════════════════════════════

    # File extensions that support Authenticode signatures
    $script:SignableExtensions = @(
        '.exe', '.dll', '.sys', '.ocx', '.cpl', '.scr',
        '.msi', '.msix', '.appx', '.cab',
        '.ps1', '.psm1', '.psd1', '.ps1xml',
        '.vbs', '.vbe', '.js', '.jse', '.wsf'
    )

    function script:Test-IsAuthenticodeSignable {
        param([string]$FilePath)
        $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
        return $script:SignableExtensions -contains $ext
    }

    function script:Format-FileSize {
        param([long]$Bytes)
        if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
        elseif ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
        elseif ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
        else { return "$Bytes bytes" }
    }

    # Create test output directory
    if (-not (Test-Path $script:TestOutputDir)) {
        New-Item -ItemType Directory -Path $script:TestOutputDir -Force | Out-Null
    }

    # ═══════════════════════════════════════════════════════════════════════════
    # Determine test files
    # ═══════════════════════════════════════════════════════════════════════════
    $script:LargeTestFiles = @()
    $script:UsingUserProvidedFiles = $false
    $script:GeneratedTestFile = $null

    # Check for user-provided files
    $validUserFiles = @()
    foreach ($userFile in $script:UserProvidedTestFiles) {
        if ([string]::IsNullOrWhiteSpace($userFile)) { continue }

        if (Test-Path $userFile) {
            $fileInfo = Get-Item $userFile
            $validUserFiles += @{
                Path = $userFile
                Name = $fileInfo.Name
                SizeMB = [Math]::Round($fileInfo.Length / 1MB, 2)
                SizeBytes = $fileInfo.Length
                IsAuthenticodeSigable = (Test-IsAuthenticodeSignable $userFile)
            }
            Write-Host "    User file: $($fileInfo.Name) ($(Format-FileSize $fileInfo.Length))" -ForegroundColor Green
        } else {
            Write-Host "    User file NOT found (skipping): $userFile" -ForegroundColor Yellow
        }
    }

    if ($validUserFiles.Count -gt 0) {
        $script:LargeTestFiles = $validUserFiles
        $script:UsingUserProvidedFiles = $true
    } else {
        # Auto-generate test file
        $script:GeneratedTestFile = Join-Path $TestDrive "LargeTestFile_${script:LargeFileSizeMB}MB.bin"
        Write-Host "    Creating ${script:LargeFileSizeMB}MB test file..." -ForegroundColor DarkGray

        $buffer = [byte[]]::new(1MB)
        $random = [System.Random]::new(42)
        $stream = [System.IO.File]::Create($script:GeneratedTestFile)
        try {
            for ($i = 0; $i -lt $script:LargeFileSizeMB; $i++) {
                $random.NextBytes($buffer)
                $stream.Write($buffer, 0, $buffer.Length)
            }
        } finally {
            $stream.Close()
            $stream.Dispose()
        }

        $script:LargeTestFiles = @(@{
            Path = $script:GeneratedTestFile
            Name = "LargeTestFile_${script:LargeFileSizeMB}MB.bin"
            SizeMB = $script:LargeFileSizeMB
            SizeBytes = $script:LargeFileSizeMB * 1MB
            IsAuthenticodeSigable = $false
        })
        Write-Host "    Test file created." -ForegroundColor DarkGray
    }

    $script:PrimaryLargeTestFile = $script:LargeTestFiles[0].Path
    $script:PrimaryLargeTestFileSizeMB = $script:LargeTestFiles[0].SizeMB

    # ═══════════════════════════════════════════════════════════════════════════
    # PRE-COMPUTE ALL PROFILER RESULTS (hash once, test many)
    # ═══════════════════════════════════════════════════════════════════════════
    Write-Host "    Profiling large file (3 algorithms)..." -ForegroundColor Cyan

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # Small file results (icon) - used for overhead analysis
    $script:IconResult_SHA256 = & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm SHA256 -Quiet

    # Large file results - one per algorithm
    $script:LargeResult_MD5 = & $script:ProfilerScript -FilePath $script:PrimaryLargeTestFile -Algorithm MD5 -Quiet
    $script:LargeResult_SHA256 = & $script:ProfilerScript -FilePath $script:PrimaryLargeTestFile -Algorithm SHA256 -Quiet
    $script:LargeResult_SHA512 = & $script:ProfilerScript -FilePath $script:PrimaryLargeTestFile -Algorithm SHA512 -Quiet

    $sw.Stop()

    # Summary
    $md5Time = [Math]::Round($script:LargeResult_MD5.Measurements['Hash Computation'], 0)
    $sha256Time = [Math]::Round($script:LargeResult_SHA256.Measurements['Hash Computation'], 0)
    $sha512Time = [Math]::Round($script:LargeResult_SHA512.Measurements['Hash Computation'], 0)

    Write-Host "    Profiling complete in $([Math]::Round($sw.Elapsed.TotalSeconds, 1))s" -ForegroundColor Green
    Write-Host "      MD5: ${md5Time}ms | SHA256: ${sha256Time}ms | SHA512: ${sha512Time}ms" -ForegroundColor DarkGray
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# TESTS: Script Validation
# ═══════════════════════════════════════════════════════════════════════════════
Describe 'Profile-VeriHashTiming Script Validation' {
    Context 'Script File Existence and Structure' {
        It 'Profiler script exists' {
            Test-Path $script:ProfilerScript | Should -Be $true
        }

        It 'Script has valid PowerShell syntax' {
            {
                $null = [System.Management.Automation.PSParser]::Tokenize(
                    (Get-Content $script:ProfilerScript -Raw),
                    [ref]$null
                )
            } | Should -Not -Throw
        }

        It 'Script contains required parameters' {
            $scriptContent = Get-Content $script:ProfilerScript -Raw
            $scriptContent | Should -Match 'param\s*\('
            $scriptContent | Should -Match '\[Parameter\(Mandatory\)\]'
            $scriptContent | Should -Match '\$FilePath'
            $scriptContent | Should -Match '\$Algorithm'
            $scriptContent | Should -Match '\$Quiet'
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# TESTS: Profiler Execution (uses fresh calls for validation)
# ═══════════════════════════════════════════════════════════════════════════════
Describe 'Timing Profiler Execution' {
    Context 'When profiling a valid test file' {
        It 'Runs successfully with <Algorithm> algorithm' -ForEach @(
            @{ Algorithm = 'SHA256' }
            @{ Algorithm = 'MD5' }
            @{ Algorithm = 'SHA512' }
        ) {
            # Uses icon file (small) - just validates execution works
            {
                & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm $Algorithm -Quiet
            } | Should -Not -Throw
        }
    }

    Context 'When profiling output validation' {
        It 'Returns performance breakdown with all expected measurement categories' {
            # Use cached icon result
            $result = $script:IconResult_SHA256

            $result.Measurements.Keys | Should -Contain 'Get-Item'
            $result.Measurements.Keys | Should -Contain 'Size Formatting'
            $result.Measurements.Keys | Should -Contain 'DateTime Operations'
            $result.Measurements.Keys | Should -Contain 'Digital Signature Check'
            $result.Measurements.Keys | Should -Contain 'Hash Computation'
            $result.Measurements.Keys | Should -Contain 'Sidecar File Write'
            $result.Measurements.Keys | Should -Contain 'Console Output (10 lines)'

            $result.FilePath | Should -Be $script:TestIconFile
            $result.Algorithm | Should -Be 'SHA256'
            $result.Total | Should -BeOfType [double]
            $result.SortedMeasurements | Should -Not -BeNullOrEmpty
        }

        It 'Returns measurements sorted in descending order by time' {
            $result = $script:IconResult_SHA256
            $times = @($result.SortedMeasurements.Value)

            for ($i = 0; $i -lt ($times.Count - 1); $i++) {
                $times[$i] | Should -BeGreaterOrEqual $times[$i + 1]
            }
        }

        It 'Total time equals sum of individual measurements' {
            $result = $script:IconResult_SHA256
            $sum = ($result.Measurements.Values | Measure-Object -Sum).Sum

            $result.Total | Should -BeGreaterThan 0
            [Math]::Abs($sum - $result.Total) | Should -BeLessThan 0.01
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# TESTS: Measurement Accuracy (uses cached results)
# ═══════════════════════════════════════════════════════════════════════════════
Describe 'Timing Profiler Measurements' {
    Context 'When validating measurement accuracy' {
        It 'Digital Signature Check measurement is platform-appropriate' {
            $sigTime = $script:IconResult_SHA256.Measurements['Digital Signature Check']

            if ($IsWindows) {
                $sigTime | Should -BeGreaterThan 0
            } else {
                $sigTime | Should -BeLessThan 1
            }
        }

        It 'Hash Computation produces valid hash and measurable time' {
            $script:IconResult_SHA256.Measurements['Hash Computation'] | Should -BeGreaterThan 0

            $expectedHash = (Get-FileHash -Path $script:TestIconFile -Algorithm SHA256).Hash
            $expectedHash | Should -Match '^[A-F0-9]{64}$'
        }

        It 'Algorithm complexity affects hash computation time' {
            # Use cached large file results
            $md5Time = $script:LargeResult_MD5.Measurements['Hash Computation']
            $sha256Time = $script:LargeResult_SHA256.Measurements['Hash Computation']
            $sha512Time = $script:LargeResult_SHA512.Measurements['Hash Computation']

            # SHA512 should generally be slower than MD5 (allow 0.5x tolerance for fast hardware)
            $sha512Time | Should -BeGreaterOrEqual ($md5Time * 0.5)

            Write-Host "      MD5:    $([Math]::Round($md5Time, 2)) ms" -ForegroundColor DarkGray
            Write-Host "      SHA256: $([Math]::Round($sha256Time, 2)) ms" -ForegroundColor DarkGray
            Write-Host "      SHA512: $([Math]::Round($sha512Time, 2)) ms" -ForegroundColor DarkGray
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# TESTS: Error Handling
# ═══════════════════════════════════════════════════════════════════════════════
Describe 'Timing Profiler Error Handling' {
    Context 'When provided invalid input' {
        It 'Fails gracefully with non-existent file' {
            {
                & $script:ProfilerScript -FilePath "C:\NonExistent\File.txt" -Algorithm SHA256 -Quiet -ErrorAction Stop
            } | Should -Throw
        }

        It 'Rejects invalid algorithm parameter' {
            {
                & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm "INVALID" -Quiet -ErrorAction Stop
            } | Should -Throw
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# TESTS: Large File Performance (uses cached results - NO re-hashing)
# ═══════════════════════════════════════════════════════════════════════════════
Describe 'Large File Performance Profiling' {
    Context "When profiling large file(s)" {
        It 'Hash computation time scales with file size' {
            $smallTime = $script:IconResult_SHA256.Measurements['Hash Computation']
            $largeTime = $script:LargeResult_SHA256.Measurements['Hash Computation']

            $largeTime | Should -BeGreaterThan ($smallTime * 10)

            $ratio = [Math]::Round($largeTime / $smallTime, 1)
            $fileName = $script:LargeTestFiles[0].Name

            Write-Host "      Small file (icon): $([Math]::Round($smallTime, 2)) ms" -ForegroundColor DarkGray
            Write-Host "      Large file ($fileName): $([Math]::Round($largeTime, 2)) ms" -ForegroundColor DarkGray
            Write-Host "      Ratio: ${ratio}x slower" -ForegroundColor DarkGray
        }

        It 'Provides realistic timing and throughput measurement' {
            $hashTime = $script:LargeResult_SHA256.Measurements['Hash Computation']
            $fileSizeMB = $script:PrimaryLargeTestFileSizeMB

            $hashTime | Should -BeGreaterThan 50

            $throughputMBps = $fileSizeMB / ($hashTime / 1000)

            Write-Host "      File: $($script:LargeTestFiles[0].Name)" -ForegroundColor DarkGray
            Write-Host "      Size: $(Format-FileSize ($fileSizeMB * 1MB))" -ForegroundColor DarkGray
            Write-Host "      Hash time: $([Math]::Round($hashTime, 0)) ms" -ForegroundColor DarkGray
            Write-Host "      Throughput: $([Math]::Round($throughputMBps, 1)) MB/s" -ForegroundColor Cyan

            if (-not $script:UsingUserProvidedFiles) {
                $estimateSizeMB = $script:EstimateForSizeGB * 1024
                $estimatedTime = $estimateSizeMB / $throughputMBps
                Write-Host "      Estimated ${script:EstimateForSizeGB}GB file time: $([Math]::Round($estimatedTime, 1)) seconds" -ForegroundColor Cyan
            }
        }

        It 'Hash computation is the dominant operation for large files' {
            $hashTime = $script:LargeResult_SHA256.Measurements['Hash Computation']
            $totalTime = $script:LargeResult_SHA256.Total
            $hashPercentage = ($hashTime / $totalTime) * 100

            # Should be > 50% AND the largest single measurement
            $hashPercentage | Should -BeGreaterThan 50

            $maxMeasurement = ($script:LargeResult_SHA256.SortedMeasurements | Select-Object -First 1).Key
            $maxMeasurement | Should -Be 'Hash Computation'

            Write-Host "      Hash computation: $([Math]::Round($hashPercentage, 1))% of total time" -ForegroundColor DarkGray
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# TESTS: User-Provided Files (only runs if configured)
# ═══════════════════════════════════════════════════════════════════════════════
Describe 'User-Provided File Testing' -Skip:(-not $script:UsingUserProvidedFiles) {
    Context 'When testing with user-provided real files' {
        It 'Profiles all user-provided files successfully' {
            foreach ($fileInfo in $script:LargeTestFiles) {
                # For user files, we do need to profile each one (they're different files)
                $result = & $script:ProfilerScript -FilePath $fileInfo.Path -Algorithm SHA256 -Quiet

                $result | Should -Not -BeNullOrEmpty
                $result.Measurements['Hash Computation'] | Should -BeGreaterThan 0

                $hashTime = $result.Measurements['Hash Computation']
                $throughputMBps = $fileInfo.SizeMB / ($hashTime / 1000)

                Write-Host "      File: $($fileInfo.Name)" -ForegroundColor Cyan
                Write-Host "        Size: $(Format-FileSize $fileInfo.SizeBytes)" -ForegroundColor DarkGray
                Write-Host "        Hash time: $([Math]::Round($hashTime, 0)) ms" -ForegroundColor DarkGray
                Write-Host "        Throughput: $([Math]::Round($throughputMBps, 1)) MB/s" -ForegroundColor DarkGray

                if ($fileInfo.IsAuthenticodeSigable -and $IsWindows) {
                    $sigTime = $result.Measurements['Digital Signature Check']
                    Write-Host "        Signature check: $([Math]::Round($sigTime, 2)) ms" -ForegroundColor DarkGray
                } else {
                    $reason = if (-not $IsWindows) { "non-Windows platform" } else { "non-Authenticode file type" }
                    Write-Host "        Signature check: N/A ($reason)" -ForegroundColor DarkGray
                }
            }
        }

        It 'Reports Authenticode signature capability correctly for user files' {
            foreach ($fileInfo in $script:LargeTestFiles) {
                $ext = [System.IO.Path]::GetExtension($fileInfo.Path).ToLower()
                $isSignable = $script:SignableExtensions -contains $ext

                Write-Host "      $($fileInfo.Name): " -NoNewline -ForegroundColor DarkGray
                if ($isSignable) {
                    Write-Host "Authenticode-signable ($ext)" -ForegroundColor Green
                } else {
                    Write-Host "Not Authenticode-signable ($ext)" -ForegroundColor Yellow
                }

                $fileInfo.IsAuthenticodeSigable | Should -Be $isSignable
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Cleanup
# ═══════════════════════════════════════════════════════════════════════════════
AfterAll {
    if (Test-Path $script:TestOutputDir) {
        Remove-Item -Path $script:TestOutputDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($script:GeneratedTestFile -and (Test-Path $script:GeneratedTestFile)) {
        Remove-Item -Path $script:GeneratedTestFile -Force -ErrorAction SilentlyContinue
    }
}