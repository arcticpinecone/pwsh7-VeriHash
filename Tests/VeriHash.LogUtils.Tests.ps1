BeforeAll {
    # Import the LogUtils functions
    $script:LogUtilsPath = "$PSScriptRoot\..\VeriHash.LogUtils.ps1"
    . $script:LogUtilsPath

    # Create a temp directory for test outputs
    $script:TestOutputDir = Join-Path $TestDrive "LogUtilsTests"
    New-Item -ItemType Directory -Path $script:TestOutputDir -Force | Out-Null

    # Create sample log files for testing
    $script:TestLogDir = Join-Path $script:TestOutputDir "logs"
    New-Item -ItemType Directory -Path $script:TestLogDir -Force | Out-Null
}

Describe 'Get-VeriHashLogPath' {
    Context 'Returns platform-appropriate path' {
        It 'Returns a valid path string' {
            # Act
            $result = Get-VeriHashLogPath

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [string]
        }

        It 'Returns Windows path on Windows' {
            # Skip if not Windows
            if (-not ($PSVersionTable.Platform -eq 'Win32NT')) {
                Set-ItResult -Skipped -Because "Not running on Windows"
                return
            }

            # Act
            $result = Get-VeriHashLogPath

            # Assert
            $result | Should -Match 'AppData.*VeriHash.*logs'
        }

        It 'Returns Unix path on Linux/macOS' {
            # Skip if on Windows
            if ($PSVersionTable.Platform -eq 'Win32NT') {
                Set-ItResult -Skipped -Because "Running on Windows"
                return
            }

            # Act
            $result = Get-VeriHashLogPath

            # Assert
            $result | Should -Match '\.verihash/logs'
        }
    }
}

Describe 'ConvertFrom-VeriHashLog' {
    BeforeAll {
        # Create sample log files with JSON content
        $script:SampleLogFile = Join-Path $script:TestLogDir "verihash-2026-01-17.jsonl"

        $sampleEntries = @(
            '{"Timestamp":"2026-01-17T10:00:00.000Z","Level":"Verbose","Message":"Computing hash","FunctionName":"Get-And-SaveHash","Tags":["Hash","Compute"],"Data":{"Path":"C:\\test.txt","Algorithm":"SHA256"}}'
            '{"Timestamp":"2026-01-17T10:00:01.000Z","Level":"Verbose","Message":"Hash computed","FunctionName":"Get-And-SaveHash","Tags":["Hash","Result"],"Data":{"Hash":"ABC123"}}'
            '{"Timestamp":"2026-01-17T10:00:02.000Z","Level":"Warning","Message":"File not found","FunctionName":"Test-HashSidecar","Tags":["Verify","Error"]}'
            '{"Timestamp":"2026-01-17T10:00:03.000Z","Level":"Debug","Message":"Debug info","FunctionName":"Get-ClipboardHash","Tags":["Clipboard"]}'
        )

        $sampleEntries | Set-Content $script:SampleLogFile
    }

    Context 'When reading log files' {
        It 'Returns log entries from a specific file' {
            # Act
            $result = ConvertFrom-VeriHashLog -Path $script:SampleLogFile

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 4
        }

        It 'Returns log entries from a directory' {
            # Act
            $result = ConvertFrom-VeriHashLog -Path $script:TestLogDir

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual 1
        }

        It 'Returns empty array when path does not exist' {
            # Act
            $result = ConvertFrom-VeriHashLog -Path "C:\nonexistent\path"

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It 'Parses JSON fields correctly' {
            # Act
            $result = ConvertFrom-VeriHashLog -Path $script:SampleLogFile

            # Assert - Timestamp may have varying precision after JSON parsing
            # Convert to string and check prefix (handles both DateTime and string types)
            $timestampStr = $result[0].Timestamp.ToString()
            $timestampStr | Should -BeLike "2026-01-17*10:00:00*"
            $result[0].Level | Should -Be "Verbose"
            $result[0].Message | Should -Be "Computing hash"
            $result[0].FunctionName | Should -Be "Get-And-SaveHash"
        }

        It 'Flattens Tags to comma-separated string' {
            # Act
            $result = ConvertFrom-VeriHashLog -Path $script:SampleLogFile

            # Assert
            $result[0].Tags | Should -Be "Hash,Compute"
        }
    }

    Context 'When filtering logs' {
        It 'Filters by Level' {
            # Act
            $result = ConvertFrom-VeriHashLog -Path $script:SampleLogFile -Level Warning

            # Assert
            $result.Count | Should -Be 1
            $result[0].Level | Should -Be "Warning"
        }

        It 'Filters by Tag' {
            # Act
            $result = ConvertFrom-VeriHashLog -Path $script:SampleLogFile -Tag "Hash"

            # Assert
            $result.Count | Should -Be 2
            $result | ForEach-Object { $_.Tags | Should -Match "Hash" }
        }
    }

    Context 'When exporting to CSV' {
        It 'Creates CSV file when ExportCsv is specified' {
            # Arrange
            $csvPath = Join-Path $script:TestOutputDir "export-test.csv"

            # Act
            ConvertFrom-VeriHashLog -Path $script:SampleLogFile -ExportCsv $csvPath

            # Assert
            Test-Path $csvPath | Should -BeTrue

            # Verify CSV content
            $csvContent = Import-Csv $csvPath
            $csvContent.Count | Should -Be 4
        }
    }
}

Describe 'Get-VeriHashLogSummary' {
    BeforeAll {
        # Ensure sample log file exists from previous describe block
        if (-not (Test-Path $script:SampleLogFile)) {
            $sampleEntries = @(
                '{"Timestamp":"2026-01-17T10:00:00.000Z","Level":"Verbose","Message":"Computing hash","FunctionName":"Get-And-SaveHash","Tags":["Hash","Compute"]}'
                '{"Timestamp":"2026-01-17T10:00:01.000Z","Level":"Verbose","Message":"Hash computed","FunctionName":"Get-And-SaveHash","Tags":["Hash","Result"]}'
                '{"Timestamp":"2026-01-17T10:00:02.000Z","Level":"Warning","Message":"File not found","FunctionName":"Test-HashSidecar","Tags":["Verify","Error"]}'
            )
            $sampleEntries | Set-Content $script:SampleLogFile
        }
    }

    Context 'When generating summary' {
        It 'Returns a summary object' {
            # Mock Get-VeriHashLogPath to return test directory
            Mock Get-VeriHashLogPath { return $script:TestLogDir }

            # Act
            $result = Get-VeriHashLogSummary -Days 30

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.TotalEntries | Should -BeGreaterOrEqual 0
            $result.Period | Should -Be "30 days"
        }

        It 'Includes operation counts' {
            # Mock Get-VeriHashLogPath to return test directory
            Mock Get-VeriHashLogPath { return $script:TestLogDir }

            # Act
            $result = Get-VeriHashLogSummary -Days 30

            # Assert
            $result.PSObject.Properties.Name | Should -Contain "HashOperations"
            $result.PSObject.Properties.Name | Should -Contain "VerifyOperations"
        }
    }
}

Describe 'Code Quality - PSScriptAnalyzer' {
    It 'VeriHash.LogUtils.ps1 passes PSScriptAnalyzer with no warnings or errors' {
        # Skip if PSScriptAnalyzer is not available
        if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
            Set-ItResult -Skipped -Because "PSScriptAnalyzer module is not installed"
            return
        }

        # Act
        $results = Invoke-ScriptAnalyzer -Path $script:LogUtilsPath -Severity Warning, Error

        # Assert
        $results | Should -BeNullOrEmpty -Because "PSScriptAnalyzer found issues: $($results | ForEach-Object { "`n  [$($_.Severity)] $($_.RuleName) at line $($_.Line): $($_.Message)" })"
    }
}
