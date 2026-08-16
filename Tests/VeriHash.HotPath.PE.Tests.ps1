BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    $script:PEFixture    = Join-Path $PSScriptRoot 'Fixtures/tiny-pe.bin'
    $script:NotPEFixture = Join-Path $PSScriptRoot 'Fixtures/tiny-not-pe.bin'
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
}
AfterAll {
    Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'Test-IsPEFile (PERF-01: content-based PE detection)' {
    It 'Returns $true for a file whose first two bytes are MZ' {
        $p = $script:PEFixture
        InModuleScope VeriHash.HotPath -Parameters @{ p = $p } { param($p) Test-IsPEFile -Path $p } | Should -BeTrue
    }

    It 'Returns $false for a file whose first two bytes are not MZ' {
        $p = $script:NotPEFixture
        InModuleScope VeriHash.HotPath -Parameters @{ p = $p } { param($p) Test-IsPEFile -Path $p } | Should -BeFalse
    }

    It 'Returns $false (no throw) for a missing file' {
        $missing = Join-Path $TestDrive 'does-not-exist.bin'
        InModuleScope VeriHash.HotPath -Parameters @{ p = $missing } { param($p) Test-IsPEFile -Path $p } | Should -BeFalse
    }

    It 'Returns $false (no throw) for a directory path' {
        $d = "$TestDrive"
        InModuleScope VeriHash.HotPath -Parameters @{ p = $d } { param($p) Test-IsPEFile -Path $p } | Should -BeFalse
    }

    It 'Returns $false for a 1-byte file (smaller than MZ)' {
        $oneByte = Join-Path $TestDrive 'one-byte.bin'
        [IO.File]::WriteAllBytes($oneByte, [byte[]](0x4D))
        InModuleScope VeriHash.HotPath -Parameters @{ p = $oneByte } { param($p) Test-IsPEFile -Path $p } | Should -BeFalse
    }
}
