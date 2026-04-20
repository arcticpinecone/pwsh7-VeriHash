BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
    $script:cliScript = "$PSScriptRoot/../VeriHash.ps1"
}

AfterAll {
    Remove-Module VeriHash.Manifest -ErrorAction SilentlyContinue
    Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'CLI sidecar auto-detect (SIDE-06)' {

    Context 'Single-line sidecar — unified behavior (SIDE-06)' {
        It 'Auto-detects without -Manifest' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $companion = Join-Path $testDir 'testfile.bin'
            [System.IO.File]::WriteAllText($companion, 'auto-detect test', $utf8)
            $hash = (Get-VeriHashResult -Path $companion -Algorithm SHA256).Hash

            $sidecar = Join-Path $testDir 'testfile.bin.sha256'
            [System.IO.File]::WriteAllText($sidecar, "$hash *testfile.bin`n", $utf8)

            $output = & $script:cliScript -FilePath $sidecar -NoPause *>&1 | Out-String
            $output | Should -Match 'Sidecar verify:'
            $output | Should -Match 'testfile\.bin'
        }

        It 'Auto-detects with -Manifest' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $companion = Join-Path $testDir 'testfile.bin'
            [System.IO.File]::WriteAllText($companion, 'auto-detect test', $utf8)
            $hash = (Get-VeriHashResult -Path $companion -Algorithm SHA256).Hash

            $sidecar = Join-Path $testDir 'testfile.bin.sha256'
            [System.IO.File]::WriteAllText($sidecar, "$hash *testfile.bin`n", $utf8)

            $output = & $script:cliScript -FilePath $sidecar -Manifest -NoPause *>&1 | Out-String
            $output | Should -Match 'Sidecar verify:'
            $output | Should -Match 'testfile\.bin'
        }

        It 'Produces identical output with and without -Manifest' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $companion = Join-Path $testDir 'testfile.bin'
            [System.IO.File]::WriteAllText($companion, 'identical output test', $utf8)
            $hash = (Get-VeriHashResult -Path $companion -Algorithm SHA256).Hash

            $sidecar = Join-Path $testDir 'testfile.bin.sha256'
            [System.IO.File]::WriteAllText($sidecar, "$hash *testfile.bin`n", $utf8)

            $outputPlain = & $script:cliScript -FilePath $sidecar -NoPause *>&1 | Out-String
            $outputManifest = & $script:cliScript -FilePath $sidecar -Manifest -NoPause *>&1 | Out-String
            $outputPlain | Should -Be $outputManifest
        }
    }

    Context 'Multi-line sidecar routes to manifest verify' {
        It 'Routes to manifest verify without -Manifest' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $file1 = Join-Path $testDir 'file1.txt'
            $file2 = Join-Path $testDir 'file2.txt'
            [System.IO.File]::WriteAllText($file1, 'content one', $utf8)
            [System.IO.File]::WriteAllText($file2, 'content two', $utf8)
            $h1 = (Get-VeriHashResult -Path $file1 -Algorithm SHA256).Hash
            $h2 = (Get-VeriHashResult -Path $file2 -Algorithm SHA256).Hash

            $manifest = Join-Path $testDir 'checksums.sha256'
            [System.IO.File]::WriteAllText($manifest, "$h1 *file1.txt`n$h2 *file2.txt`n", $utf8)

            $output = & $script:cliScript -FilePath $manifest -NoPause *>&1 | Out-String
            $output | Should -Match 'Manifest verify:'
            $output | Should -Match 'passed'
        }

        It 'Routes to manifest verify with -Manifest' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $file1 = Join-Path $testDir 'file1.txt'
            $file2 = Join-Path $testDir 'file2.txt'
            [System.IO.File]::WriteAllText($file1, 'content one', $utf8)
            [System.IO.File]::WriteAllText($file2, 'content two', $utf8)
            $h1 = (Get-VeriHashResult -Path $file1 -Algorithm SHA256).Hash
            $h2 = (Get-VeriHashResult -Path $file2 -Algorithm SHA256).Hash

            $manifest = Join-Path $testDir 'checksums.sha256'
            [System.IO.File]::WriteAllText($manifest, "$h1 *file1.txt`n$h2 *file2.txt`n", $utf8)

            $output = & $script:cliScript -FilePath $manifest -Manifest -NoPause *>&1 | Out-String
            $output | Should -Match 'Manifest verify:'
        }
    }

    Context 'Non-sidecar files unchanged (regression guard)' {
        It 'Normal file hashes via hot-path' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $testFile = Join-Path $testDir 'test.txt'
            [System.IO.File]::WriteAllText($testFile, 'normal file content', $utf8)

            $output = & $script:cliScript -FilePath $testFile -NoPause *>&1 | Out-String
            $output | Should -Match 'SHA256'
        }

        It 'Normal files create manifest with -Manifest' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $testFile = Join-Path $testDir 'test.txt'
            [System.IO.File]::WriteAllText($testFile, 'normal file content', $utf8)

            $output = & $script:cliScript -FilePath $testFile -Manifest -NoPause *>&1 | Out-String
            $output | Should -Match 'Manifest created:'
        }
    }

    Context 'Error and exit code paths' {
        It 'Empty sidecar returns exit code 1' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $sidecar = Join-Path $testDir 'empty.sha256'
            [System.IO.File]::WriteAllText($sidecar, "`n   `n", $utf8)

            $output = & $script:cliScript -FilePath $sidecar -NoPause *>&1 | Out-String
            $LASTEXITCODE | Should -Be 1
        }

        It 'Missing companion returns exit code 1' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)
            $fakeHash = 'a' * 64

            $sidecar = Join-Path $testDir 'missing.bin.sha256'
            [System.IO.File]::WriteAllText($sidecar, "$fakeHash *missing.bin`n", $utf8)

            $output = & $script:cliScript -FilePath $sidecar -NoPause *>&1 | Out-String
            $LASTEXITCODE | Should -Be 1
        }

        It 'Matching sidecar returns exit code 0' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $companion = Join-Path $testDir 'testfile.bin'
            [System.IO.File]::WriteAllText($companion, 'exit code test', $utf8)
            $hash = (Get-VeriHashResult -Path $companion -Algorithm SHA256).Hash

            $sidecar = Join-Path $testDir 'testfile.bin.sha256'
            [System.IO.File]::WriteAllText($sidecar, "$hash *testfile.bin`n", $utf8)

            $output = & $script:cliScript -FilePath $sidecar -NoPause *>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
        }
    }
}
