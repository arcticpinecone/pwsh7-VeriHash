BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
}
AfterAll {
    Remove-Module VeriHash.Manifest -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'Test-VeriHashManifest exit code precedence (MANIFEST-06)' {
    BeforeAll {
        $script:utf8 = [System.Text.UTF8Encoding]::new($false)
    }

    BeforeEach {
        $script:dir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -Path $script:dir -ItemType Directory -Force | Out-Null
    }

    It 'ExitCode 0 - all files pass' {
        $f = Join-Path $script:dir 'ok.txt'
        [IO.File]::WriteAllText($f, 'ok', $script:utf8)
        $h = (Get-VeriHashResult -Path $f -Algorithm SHA256).Hash
        $m = Join-Path $script:dir 'manifest.sha256'
        [IO.File]::WriteAllText($m, "$h *ok.txt`n", $script:utf8)
        $r = Test-VeriHashManifest -Path $m
        $r.ExitCode | Should -Be 0
        $r.Summary.Passed | Should -Be 1
    }

    It 'ExitCode 1 - hash mismatch' {
        $f = Join-Path $script:dir 'bad.txt'
        [IO.File]::WriteAllText($f, 'real content', $script:utf8)
        $wrongHash = 'a' * 64
        $m = Join-Path $script:dir 'manifest.sha256'
        [IO.File]::WriteAllText($m, "$wrongHash *bad.txt`n", $script:utf8)
        $r = Test-VeriHashManifest -Path $m
        $r.ExitCode | Should -Be 1
        $r.Summary.Failed | Should -Be 1
    }

    It 'ExitCode 2 - missing file, no mismatches' {
        $m = Join-Path $script:dir 'manifest.sha256'
        $h = 'b' * 64
        [IO.File]::WriteAllText($m, "$h *gone.txt`n", $script:utf8)
        $r = Test-VeriHashManifest -Path $m
        $r.ExitCode | Should -Be 2
        $r.Summary.Missing | Should -Be 1
    }

    It 'ExitCode 3 - malformed manifest line' {
        $m = Join-Path $script:dir 'manifest.sha256'
        [IO.File]::WriteAllText($m, "not-a-valid-line`n", $script:utf8)
        $r = Test-VeriHashManifest -Path $m
        $r.ExitCode | Should -Be 3
    }

    It 'ExitCode 3 - path traversal entry' {
        $m = Join-Path $script:dir 'manifest.sha256'
        $h = 'c' * 64
        [IO.File]::WriteAllText($m, "$h *../../etc/passwd`n", $script:utf8)
        $r = Test-VeriHashManifest -Path $m
        $r.ExitCode | Should -Be 3
    }

    It 'Precedence: mismatch (1) wins over missing (2)' {
        $fa = Join-Path $script:dir 'exists.txt'
        [IO.File]::WriteAllText($fa, 'real', $script:utf8)
        $wrongHash = 'd' * 64
        $missingHash = 'e' * 64
        $m = Join-Path $script:dir 'manifest.sha256'
        [IO.File]::WriteAllText($m, "$wrongHash *exists.txt`n$missingHash *gone.txt`n", $script:utf8)
        $r = Test-VeriHashManifest -Path $m
        $r.ExitCode | Should -Be 1
    }

    It 'Precedence: parse error (3) wins over mismatch (1) + missing (2)' {
        $fa = Join-Path $script:dir 'exists.txt'
        [IO.File]::WriteAllText($fa, 'real', $script:utf8)
        $wrongHash = 'f' * 64
        $m = Join-Path $script:dir 'manifest.sha256'
        $content = "bad-line-here`n$wrongHash *exists.txt`n"
        [IO.File]::WriteAllText($m, $content, $script:utf8)
        $r = Test-VeriHashManifest -Path $m
        $r.ExitCode | Should -Be 3
    }
}
