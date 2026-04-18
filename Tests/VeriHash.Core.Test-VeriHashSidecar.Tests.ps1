BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    $script:Fixture     = Join-Path $PSScriptRoot 'Fixtures/VeriHash_1024.ico'
    $script:TwoSpaceSrc = Join-Path $PSScriptRoot 'Fixtures/sidecar-twospace.sha256'
    $script:AsteriskSrc = Join-Path $PSScriptRoot 'Fixtures/sidecar-asterisk.sha256'
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
