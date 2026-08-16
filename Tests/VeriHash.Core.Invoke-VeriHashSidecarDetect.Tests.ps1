BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
}

AfterAll {
    Remove-Module VeriHash.Manifest -ErrorAction SilentlyContinue
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'Invoke-VeriHashSidecarDetect' {

    Context 'Single-line GNU format sidecar (SIDE-01, SIDE-02)' {
        It 'Returns SidecarVerifyResult with pass for matching hash' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $companion = Join-Path $testDir 'testfile.bin'
            [System.IO.File]::WriteAllText($companion, 'hello world', $utf8)
            $hash = (Get-VeriHashResult -Path $companion -Algorithm SHA256).Hash

            $sidecar = Join-Path $testDir 'testfile.bin.sha256'
            [System.IO.File]::WriteAllText($sidecar, "$hash *testfile.bin`n", $utf8)

            $r = Invoke-VeriHashSidecarDetect -Path $sidecar
            $r.PSObject.TypeNames[0] | Should -Be 'VeriHash.SidecarVerifyResult'
            $r.Status | Should -Be 'pass'
            $r.Algorithm | Should -Be 'SHA256'
            $r.ExpectedHash | Should -Be $hash
            $r.ActualHash | Should -Be $hash
            $r.CompanionPath | Should -Match 'testfile\.bin$'
            $r.SidecarPath | Should -Match '\.sha256$'
        }

        It 'Returns mismatch for non-matching hash' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $companion = Join-Path $testDir 'testfile.bin'
            [System.IO.File]::WriteAllText($companion, 'hello world', $utf8)
            $wrongHash = 'a' * 64

            $sidecar = Join-Path $testDir 'testfile.bin.sha256'
            [System.IO.File]::WriteAllText($sidecar, "$wrongHash *testfile.bin`n", $utf8)

            $r = Invoke-VeriHashSidecarDetect -Path $sidecar
            $r.Status | Should -Be 'mismatch'
            $r.ExpectedHash | Should -Be $wrongHash
        }
    }

    Context 'Single-line bare hash sidecar (SIDE-02)' {
        It 'Strips extension to find companion from sidecar filename' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $companion = Join-Path $testDir 'testfile.bin'
            [System.IO.File]::WriteAllText($companion, 'bare hash test', $utf8)
            $hash = (Get-VeriHashResult -Path $companion -Algorithm SHA256).Hash

            $sidecar = Join-Path $testDir 'testfile.bin.sha256'
            [System.IO.File]::WriteAllText($sidecar, "$hash`n", $utf8)

            $r = Invoke-VeriHashSidecarDetect -Path $sidecar
            $r.Status | Should -Be 'pass'
            $r.CompanionPath | Should -Match 'testfile\.bin$'
        }
    }

    Context 'Multi-line sidecar routes to manifest (SIDE-01)' {
        It 'Returns ManifestVerifyResult for N-line file' {
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

            $r = Invoke-VeriHashSidecarDetect -Path $manifest
            $r.PSObject.TypeNames[0] | Should -Be 'VeriHash.ManifestVerifyResult'
            $r.ExitCode | Should -Be 0
        }
    }

    Context 'Companion relative to sidecar dir (SIDE-03)' {
        It 'Resolves companion from sidecar dir when CWD differs' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $companion = Join-Path $testDir 'testfile.bin'
            [System.IO.File]::WriteAllText($companion, 'cwd independence test', $utf8)
            $hash = (Get-VeriHashResult -Path $companion -Algorithm SHA256).Hash

            $sidecar = Join-Path $testDir 'testfile.bin.sha256'
            [System.IO.File]::WriteAllText($sidecar, "$hash *testfile.bin`n", $utf8)

            Push-Location $env:TEMP
            try {
                $r = Invoke-VeriHashSidecarDetect -Path $sidecar
                $r.Status | Should -Be 'pass'
            } finally {
                Pop-Location
            }
        }
    }

    Context 'Missing companion (SIDE-04)' {
        It 'Writes error when companion file not found' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)
            $fakeHash = 'a' * 64

            $sidecar = Join-Path $testDir 'missing.bin.sha256'
            [System.IO.File]::WriteAllText($sidecar, "$fakeHash *missing.bin`n", $utf8)

            $r = Invoke-VeriHashSidecarDetect -Path $sidecar -ErrorVariable err -ErrorAction SilentlyContinue
            $r | Should -BeNullOrEmpty
            $err | Should -Not -BeNullOrEmpty
            $err[0].Exception.Message | Should -Match 'Companion file not found'
        }
    }

    Context 'Empty sidecar (SIDE-05)' {
        It 'Writes error for zero non-blank lines' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $sidecar = Join-Path $testDir 'empty.sha256'
            [System.IO.File]::WriteAllText($sidecar, "`n   `n", $utf8)

            $r = Invoke-VeriHashSidecarDetect -Path $sidecar -ErrorVariable err -ErrorAction SilentlyContinue
            $r | Should -BeNullOrEmpty
            $err | Should -Not -BeNullOrEmpty
            $err[0].Exception.Message | Should -Match 'Sidecar file is empty'
        }
    }

    Context 'Path traversal guard (T-6-01)' {
        It 'Rejects companion with ../ traversal' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)
            $fakeHash = 'a' * 64

            $sidecar = Join-Path $testDir 'traversal.sha256'
            [System.IO.File]::WriteAllText($sidecar, "$fakeHash *../../etc/shadow`n", $utf8)

            $r = Invoke-VeriHashSidecarDetect -Path $sidecar -ErrorVariable err -ErrorAction SilentlyContinue
            $r | Should -BeNullOrEmpty
            $err | Should -Not -BeNullOrEmpty
            $err[0].Exception.Message | Should -Match 'escapes sidecar directory'
        }

        It 'Rejects companion with absolute path' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)
            $fakeHash = 'a' * 64

            $sidecar = Join-Path $testDir 'absolute.sha256'
            [System.IO.File]::WriteAllText($sidecar, "$fakeHash *C:\Windows\System32\cmd.exe`n", $utf8)

            $r = Invoke-VeriHashSidecarDetect -Path $sidecar -ErrorVariable err -ErrorAction SilentlyContinue
            $r | Should -BeNullOrEmpty
            $err | Should -Not -BeNullOrEmpty
            $err[0].Exception.Message | Should -Match 'absolute path'
        }
    }

    Context 'Hash length warning (D-04)' {
        It 'Warns but still compares when length mismatches' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $companion = Join-Path $testDir 'testfile.bin'
            [System.IO.File]::WriteAllText($companion, 'hash length test', $utf8)
            $shortHash = 'a' * 32

            $sidecar = Join-Path $testDir 'testfile.bin.sha256'
            [System.IO.File]::WriteAllText($sidecar, "$shortHash *testfile.bin`n", $utf8)

            $r = Invoke-VeriHashSidecarDetect -Path $sidecar -WarningVariable warn 3>$null
            $r.Status | Should -Be 'mismatch'
            $r.Warning | Should -Match 'Unexpected hash length'
            $warn | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Algorithm detection from extension' {
        It 'Uses SHA512 for .sha512 extension' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $companion = Join-Path $testDir 'testfile.bin'
            [System.IO.File]::WriteAllText($companion, 'sha512 test', $utf8)
            $hash = (Get-VeriHashResult -Path $companion -Algorithm SHA512).Hash

            $sidecar = Join-Path $testDir 'testfile.bin.sha512'
            [System.IO.File]::WriteAllText($sidecar, "$hash *testfile.bin`n", $utf8)

            $r = Invoke-VeriHashSidecarDetect -Path $sidecar
            $r.Algorithm | Should -Be 'SHA512'
            $r.Status | Should -Be 'pass'
        }

        It 'Uses MD5 for .md5 extension' {
            $testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $utf8 = [System.Text.UTF8Encoding]::new($false)

            $companion = Join-Path $testDir 'testfile.bin'
            [System.IO.File]::WriteAllText($companion, 'md5 test', $utf8)
            $hash = (Get-VeriHashResult -Path $companion -Algorithm MD5).Hash

            $sidecar = Join-Path $testDir 'testfile.bin.md5'
            [System.IO.File]::WriteAllText($sidecar, "$hash *testfile.bin`n", $utf8)

            $r = Invoke-VeriHashSidecarDetect -Path $sidecar
            $r.Algorithm | Should -Be 'MD5'
            $r.Status | Should -Be 'pass'
        }
    }
}
