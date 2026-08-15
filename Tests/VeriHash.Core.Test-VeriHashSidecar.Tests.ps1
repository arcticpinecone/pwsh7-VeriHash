BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    $script:Fixture     = Join-Path $PSScriptRoot 'Fixtures/VeriHash_1024.ico'
    $script:TwoSpaceSrc = Join-Path $PSScriptRoot 'Fixtures/sidecar-twospace.sha256'
    $script:AsteriskSrc = Join-Path $PSScriptRoot 'Fixtures/sidecar-asterisk.sha256'

    function script:BogusSha256 {
        param($Path)
        # A deliberately WRONG digest tagged SHA256. Re-hashing the file produces the
        # real (matching) digest, so 'matched' proves a second compute happened and
        # 'mismatch' proves the supplied value was reused. No mocks needed.
        [pscustomobject]@{
            PSTypeName = 'VeriHash.Result'
            FilePath   = $Path
            Size       = 1234
            Algorithm  = 'SHA256'
            Hash       = 'f' * 64
            ElapsedMs  = 999
        }
    }
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Test-VeriHashSidecar (CORE-05)' {
    BeforeEach {
        $script:IconCopy = Join-Path $TestDrive 'VeriHash_1024.ico'
        Copy-Item -LiteralPath $script:Fixture -Destination $script:IconCopy -Force
    }

    It 'Verifies a HASH  filename (two-space) sidecar' {
        Copy-Item -LiteralPath $script:TwoSpaceSrc -Destination (Join-Path $TestDrive 'VeriHash_1024.ico.sha256') -Force
        $r = Test-VeriHashSidecar -Path $script:IconCopy
        $r | Should -Not -BeNullOrEmpty
        $r.Sidecar | Should -Match 'matched'
    }

    It 'Verifies a HASH *filename (asterisk) sidecar' {
        Copy-Item -LiteralPath $script:AsteriskSrc -Destination (Join-Path $TestDrive 'VeriHash_1024.ico.sha256') -Force
        $r = Test-VeriHashSidecar -Path $script:IconCopy
        $r | Should -Not -BeNullOrEmpty
        $r.Sidecar | Should -Match 'matched'
    }

    It 'Picks sha512 over sha256 over md5' {
        $sha256 = (Get-FileHash -LiteralPath $script:IconCopy -Algorithm SHA256).Hash.ToLowerInvariant()
        $sha512 = (Get-FileHash -LiteralPath $script:IconCopy -Algorithm SHA512).Hash.ToLowerInvariant()
        $md5    = (Get-FileHash -LiteralPath $script:IconCopy -Algorithm MD5).Hash.ToLowerInvariant()
        $enc = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText((Join-Path $TestDrive 'VeriHash_1024.ico.md5'),    "$md5  VeriHash_1024.ico`n",    $enc)
        [System.IO.File]::WriteAllText((Join-Path $TestDrive 'VeriHash_1024.ico.sha256'), "$sha256  VeriHash_1024.ico`n", $enc)
        [System.IO.File]::WriteAllText((Join-Path $TestDrive 'VeriHash_1024.ico.sha512'), "$sha512  VeriHash_1024.ico`n", $enc)
        $r = Test-VeriHashSidecar -Path $script:IconCopy
        $r.Algorithm | Should -Be 'SHA512'
    }

    It 'Returns $null when no sidecar exists' {
        $bare = Join-Path $TestDrive 'no-sidecar.bin'
        Set-Content -LiteralPath $bare -Value 'hello' -NoNewline
        Test-VeriHashSidecar -Path $bare | Should -BeNullOrEmpty
    }
}

Describe 'Test-VeriHashSidecar structured fields (FMT)' {
    BeforeEach {
        $script:IconCopy = Join-Path $TestDrive 'VeriHash_1024.ico'
        Copy-Item -LiteralPath $script:Fixture -Destination $script:IconCopy -Force
    }

    It 'Exposes SidecarStatus and SidecarName alongside the legacy Sidecar string' {
        Copy-Item -LiteralPath $script:TwoSpaceSrc `
                  -Destination (Join-Path $TestDrive 'VeriHash_1024.ico.sha256') -Force
        $r = Test-VeriHashSidecar -Path $script:IconCopy
        $r.SidecarStatus | Should -BeExactly 'matched'
        $r.SidecarName   | Should -BeExactly 'VeriHash_1024.ico.sha256'
        $r.Sidecar       | Should -Match 'matched'   # legacy contract intact
        $r.ExpectedHash  | Should -BeExactly $r.Hash
    }

    It 'Reports mismatch as structured status and surfaces the expected hash' {
        $enc = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText((Join-Path $TestDrive 'VeriHash_1024.ico.sha256'),
            ('0' * 64) + "  VeriHash_1024.ico`n", $enc)
        $r = Test-VeriHashSidecar -Path $script:IconCopy
        $r.SidecarStatus | Should -BeExactly 'mismatch'
        # Without this the report can say MISMATCH but cannot show what was expected.
        $r.ExpectedHash  | Should -BeExactly ('0' * 64)
    }

    It 'Reports an unparseable sidecar as error with no expected hash' {
        $enc = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText((Join-Path $TestDrive 'VeriHash_1024.ico.sha256'), "not a hash line`n", $enc)
        $r = Test-VeriHashSidecar -Path $script:IconCopy
        $r.SidecarStatus | Should -BeExactly 'error'
        $r.ExpectedHash  | Should -BeNullOrEmpty
    }
}

Describe 'Test-VeriHashSidecar -ComputedResult reuse (PERF)' {
    BeforeEach {
        $script:IconCopy = Join-Path $TestDrive 'VeriHash_1024.ico'
        Copy-Item -LiteralPath $script:Fixture -Destination $script:IconCopy -Force
        Copy-Item -LiteralPath $script:TwoSpaceSrc `
                  -Destination (Join-Path $TestDrive 'VeriHash_1024.ico.sha256') -Force
    }

    It 'Compares against the supplied digest instead of re-hashing the file' {
        $r = Test-VeriHashSidecar -Path $script:IconCopy -ComputedResult (script:BogusSha256 $script:IconCopy)
        $r.SidecarStatus | Should -BeExactly 'mismatch'
        $r.Hash          | Should -BeExactly ('f' * 64)
    }

    It 'Carries the supplied digest''s own ElapsedMs rather than reporting a fresh compute' {
        $r = Test-VeriHashSidecar -Path $script:IconCopy -ComputedResult (script:BogusSha256 $script:IconCopy)
        $r.ElapsedMs | Should -Be 999
    }

    It 'Re-hashes when the strongest sidecar uses a different algorithm' {
        # The correctness guard: a .sha512 sidecar outranks .sha256, and a SHA256
        # digest cannot answer it. Reuse must NOT apply here.
        $sha512 = (Get-FileHash -LiteralPath $script:IconCopy -Algorithm SHA512).Hash.ToLowerInvariant()
        $enc = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText((Join-Path $TestDrive 'VeriHash_1024.ico.sha512'),
            "$sha512  VeriHash_1024.ico`n", $enc)

        $r = Test-VeriHashSidecar -Path $script:IconCopy -ComputedResult (script:BogusSha256 $script:IconCopy)
        $r.Algorithm     | Should -BeExactly 'SHA512'
        $r.SidecarStatus | Should -BeExactly 'matched'
    }

    It 'Still re-hashes when no ComputedResult is supplied at all' {
        $r = Test-VeriHashSidecar -Path $script:IconCopy
        $r.SidecarStatus | Should -BeExactly 'matched'
    }
}
