<#
.SYNOPSIS
    Pester tests for Profile-VeriHashTiming.ps1

.DESCRIPTION
    Validates the VeriHash timing profiler functionality
#>

BeforeAll {
    $script:ProfilerScript = Join-Path $PSScriptRoot "..\Profile-VeriHashTiming.ps1"
    $script:TestIconFile = Join-Path $PSScriptRoot "VeriHash_1024.ico"
    $script:TestOutputDir = Join-Path $PSScriptRoot "TimingTestOutput"

    # Create test output directory
    if (-not (Test-Path $script:TestOutputDir)) {
        New-Item -ItemType Directory -Path $script:TestOutputDir -Force | Out-Null
    }
}

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
        }
    }
}

Describe 'Timing Profiler Execution' {
    Context 'When profiling a valid test file' {
        It 'Runs successfully with SHA256 algorithm' {
            # Act
            {
                & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm SHA256
            } | Should -Not -Throw
        }

        It 'Runs successfully with MD5 algorithm' {
            {
                & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm MD5
            } | Should -Not -Throw
        }

        It 'Runs successfully with SHA512 algorithm' {
            {
                & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm SHA512
            } | Should -Not -Throw
        }
    }

    Context 'When profiling output validation' {
        It 'Returns performance breakdown measurements' {
            # Act
            $result = & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm SHA256

            # Assert - Check for all expected measurement categories in returned object
            $result.Measurements.Keys | Should -Contain 'Get-Item'
            $result.Measurements.Keys | Should -Contain 'Size Formatting'
            $result.Measurements.Keys | Should -Contain 'DateTime Operations'
            $result.Measurements.Keys | Should -Contain 'Digital Signature Check'
            $result.Measurements.Keys | Should -Contain 'Hash Computation'
            $result.Measurements.Keys | Should -Contain 'Sidecar File Write'
            $result.Measurements.Keys | Should -Contain 'Console Output (10 lines)'
        }

        It 'Returns total time calculation' {
            # Act
            $result = & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm SHA256

            # Assert
            $result.Total | Should -BeGreaterThan 0
            $result.Total | Should -BeOfType [double]
        }

        It 'Returns sorted measurements in descending order' {
            # Act
            $result = & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm SHA256

            # Assert - Measurements should be sorted by value descending
            $times = @($result.SortedMeasurements.Value)
            for ($i = 0; $i -lt ($times.Count - 1); $i++) {
                $times[$i] | Should -BeGreaterOrEqual $times[$i + 1]
            }
        }
    }
}

Describe 'Timing Profiler Measurements' {
    Context 'When validating measurement accuracy' {
        It 'Digital Signature Check takes measurable time' {
            # Act
            $result = & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm SHA256

            # Assert - Should be > 0 (it does actual work)
            $result.Measurements['Digital Signature Check'] | Should -BeGreaterThan 0
        }

        It 'Hash Computation takes measurable time' {
            # Act
            $result = & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm SHA256

            # Assert - Should be > 0
            $result.Measurements['Hash Computation'] | Should -BeGreaterThan 0
        }

        It 'Total time equals sum of individual measurements' {
            # Act
            $result = & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm SHA256

            # Calculate sum of individual measurements
            $sum = ($result.Measurements.Values | Measure-Object -Sum).Sum

            # Assert - Should match TOTAL (within 0.01ms rounding tolerance)
            $result.Total | Should -BeGreaterThan 0
            [Math]::Abs($sum - $result.Total) | Should -BeLessThan 0.01
        }
    }
}

Describe 'Timing Profiler Error Handling' {
    Context 'When provided invalid input' {
        It 'Fails gracefully with non-existent file' {
            # Act & Assert
            {
                & $script:ProfilerScript -FilePath "C:\NonExistent\File.txt" -Algorithm SHA256 -ErrorAction Stop
            } | Should -Throw
        }

        It 'Validates algorithm parameter' {
            # Act & Assert - Invalid algorithm should fail
            {
                & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm "INVALID" -ErrorAction Stop
            } | Should -Throw
        }
    }
}

Describe 'Timing Profiler Performance Insights' {
    Context 'When analyzing overhead breakdown' {
        It 'Identifies digital signature check as significant overhead' {
            # Act
            $result = & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm SHA256

            # Calculate percentage
            $sigTime = $result.Measurements['Digital Signature Check']
            $sigPercentage = ($sigTime / $result.Total) * 100

            # Assert - For small files, signature check should be a significant portion
            # Based on our profiling, it's typically 50-70% for small files
            $sigPercentage | Should -BeGreaterThan 10  # At least 10% of total time
        }

        It 'Shows hash computation is relatively fast for small files' {
            # Act
            $result = & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm SHA256

            # Calculate percentage
            $hashTime = $result.Measurements['Hash Computation']
            $hashPercentage = ($hashTime / $result.Total) * 100

            # Assert - For small files (1KB), hashing should be < 30% of total time
            $hashPercentage | Should -BeLessThan 30
        }

        It 'Measurements are sorted by time (descending)' {
            # Act
            $result = & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm SHA256

            # Extract times from sorted measurements
            $times = @($result.SortedMeasurements.Value)

            # Assert - Times should be in descending order
            for ($i = 0; $i -lt ($times.Count - 1); $i++) {
                $times[$i] | Should -BeGreaterOrEqual $times[$i + 1]
            }
        }
    }
}

AfterAll {
    # Clean up test output directory
    if (Test-Path $script:TestOutputDir) {
        Remove-Item -Path $script:TestOutputDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
