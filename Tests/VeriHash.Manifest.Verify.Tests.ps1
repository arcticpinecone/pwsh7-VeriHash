BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
}
AfterAll {
    Remove-Module VeriHash.Manifest -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'Test-VeriHashManifest (MANIFEST-04, -05)' {

    BeforeEach {
        $script:testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
        $script:f1 = Join-Path $script:testDir 'file1.txt'
        $script:f2 = Join-Path $script:testDir 'file2.txt'
        $utf8 = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($script:f1, "content one`n", $utf8)
        [System.IO.File]::WriteAllText($script:f2, "content two`n", $utf8)
        $h1 = (Get-VeriHashResult -Path $script:f1 -Algorithm SHA256).Hash
        $h2 = (Get-VeriHashResult -Path $script:f2 -Algorithm SHA256).Hash
        $script:manifestPath = Join-Path $script:testDir 'test_manifest.sha256'
        $manifestContent = "$h1 *file1.txt`n$h2 *file2.txt`n"
        [System.IO.File]::WriteAllText($script:manifestPath, $manifestContent, $utf8)
    }

    Context 'Valid manifest - all files match' {
        It 'Returns VeriHash.ManifestVerifyResult with ExitCode 0' {
            $r = Test-VeriHashManifest -Path $script:manifestPath
            $r.PSTypeNames | Should -Contain 'VeriHash.ManifestVerifyResult'
            $r.ExitCode | Should -Be 0
        }

        It 'Entries array has 2 items, all with Status pass' {
            $r = Test-VeriHashManifest -Path $script:manifestPath
            $r.Entries.Count | Should -Be 2
            $r.Entries | ForEach-Object { $_.Status | Should -Be 'pass' }
        }

        It 'Summary counts are correct' {
            $r = Test-VeriHashManifest -Path $script:manifestPath
            $r.Summary.Total | Should -Be 2
            $r.Summary.Passed | Should -Be 2
            $r.Summary.Failed | Should -Be 0
            $r.Summary.Missing | Should -Be 0
        }

        It 'ManifestPath on result matches input' {
            $r = Test-VeriHashManifest -Path $script:manifestPath
            $r.ManifestPath | Should -Be (Resolve-Path -LiteralPath $script:manifestPath).ProviderPath
        }
    }

    Context 'MANIFEST-04: Strict regex parsing' {
        It 'Malformed line (short hash) produces ExitCode 3' {
            $utf8 = [System.Text.UTF8Encoding]::new($false)
            $badManifest = Join-Path $script:testDir 'bad.sha256'
            [System.IO.File]::WriteAllText($badManifest, "abc123 *file1.txt`n", $utf8)
            $r = Test-VeriHashManifest -Path $badManifest
            $r.ExitCode | Should -Be 3
        }

        It 'Malformed line (no mode indicator) produces ExitCode 3' {
            $utf8 = [System.Text.UTF8Encoding]::new($false)
            $h = 'a' * 64
            $badManifest = Join-Path $script:testDir 'bad2.sha256'
            [System.IO.File]::WriteAllText($badManifest, "${h}file1.txt`n", $utf8)
            $r = Test-VeriHashManifest -Path $badManifest
            $r.ExitCode | Should -Be 3
        }
    }

    Context 'D-04: Comments and blank lines skipped' {
        It 'Blank lines and # comments do not cause parse errors' {
            $utf8 = [System.Text.UTF8Encoding]::new($false)
            $h1 = (Get-VeriHashResult -Path $script:f1 -Algorithm SHA256).Hash
            $content = "`n# This is a comment`n$h1 *file1.txt`n`n# Another comment`n"
            $commentManifest = Join-Path $script:testDir 'comments.sha256'
            [System.IO.File]::WriteAllText($commentManifest, $content, $utf8)
            $r = Test-VeriHashManifest -Path $commentManifest
            $r.ExitCode | Should -Be 0
            $r.Entries.Count | Should -Be 1
        }
    }

    Context 'MANIFEST-05: Path traversal hard reject' {
        It 'Entry with ../ is rejected with ExitCode 3' {
            $utf8 = [System.Text.UTF8Encoding]::new($false)
            $h = 'a' * 64
            $evilManifest = Join-Path $script:testDir 'evil.sha256'
            [System.IO.File]::WriteAllText($evilManifest, "$h *../evil.txt`n", $utf8)
            $r = Test-VeriHashManifest -Path $evilManifest
            $r.ExitCode | Should -Be 3
        }

        It 'Entry with absolute path is rejected with ExitCode 3' {
            $utf8 = [System.Text.UTF8Encoding]::new($false)
            $h = 'a' * 64
            $evilManifest = Join-Path $script:testDir 'evil2.sha256'
            [System.IO.File]::WriteAllText($evilManifest, "$h *C:\Windows\System32\cmd.exe`n", $utf8)
            $r = Test-VeriHashManifest -Path $evilManifest
            $r.ExitCode | Should -Be 3
        }

        It 'Paths resolve relative to manifest directory, not CWD' {
            $sub = Join-Path $script:testDir 'sub'
            New-Item $sub -ItemType Directory -Force | Out-Null
            $subFile = Join-Path $sub 'deep.txt'
            $utf8 = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::WriteAllText($subFile, "deep content`n", $utf8)
            $h = (Get-VeriHashResult -Path $subFile -Algorithm SHA256).Hash
            $manifest = Join-Path $script:testDir 'subref.sha256'
            [System.IO.File]::WriteAllText($manifest, "$h *sub/deep.txt`n", $utf8)
            Push-Location $env:TEMP
            try {
                $r = Test-VeriHashManifest -Path $manifest
                $r.ExitCode | Should -Be 0
            } finally {
                Pop-Location
            }
        }
    }

    Context 'Hash mismatch detection' {
        It 'Tampered file produces ExitCode 1 with Status mismatch' {
            $utf8 = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::WriteAllText($script:f1, "tampered content`n", $utf8)
            $r = Test-VeriHashManifest -Path $script:manifestPath
            $r.ExitCode | Should -Be 1
            ($r.Entries | Where-Object { $_.Status -eq 'mismatch' }).Count | Should -BeGreaterOrEqual 1
        }
    }

    Context 'Missing file detection' {
        It 'Deleted file produces ExitCode 2 with Status missing' {
            Remove-Item $script:f1 -Force
            $r = Test-VeriHashManifest -Path $script:manifestPath
            $r.ExitCode | Should -Be 2
            ($r.Entries | Where-Object { $_.Status -eq 'missing' }).Count | Should -Be 1
        }
    }

    Context 'Per-entry result object shape (D-12)' {
        It 'Each entry has Path, ExpectedHash, ActualHash, Status' {
            $r = Test-VeriHashManifest -Path $script:manifestPath
            foreach ($e in $r.Entries) {
                $e.PSObject.Properties.Name | Should -Contain 'Path'
                $e.PSObject.Properties.Name | Should -Contain 'ExpectedHash'
                $e.PSObject.Properties.Name | Should -Contain 'ActualHash'
                $e.PSObject.Properties.Name | Should -Contain 'Status'
            }
        }
    }
}
